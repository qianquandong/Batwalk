import Foundation
import HealthKit
import BatwalkCore

@MainActor
final class StepService: StepTotalReader {
    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private var observer: HKObserverQuery?
    private var onStepsChanged: (@Sendable () async -> Void)?
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            // The launch-time registration can run before the first permission
            // dialog. Retry it after that dialog completes, including on Settings.
            if let onStepsChanged {
                if let observer { healthStore.stop(observer) }
                observer = nil
                startObserving(onChange: onStepsChanged)
            }
            return true // completion is not proof of read permission
        } catch { return false }
    }

    func authorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        guard isAvailable else { return .unknown }
        return (try? await healthStore.statusForAuthorizationRequest(toShare: [], read: [stepType])) ?? .unknown
    }

    /// Daily cumulative totals for [start, end) in the ledger's calendar.
    ///
    /// One statistics-collection query normally covers the whole range. When
    /// HealthKit buckets by a calendar that does not match the ledger's time zone
    /// (travel, DST), the buckets fail the boundary check and we fall back to one
    /// statistics query per day with an explicit [midnight, midnight) predicate —
    /// exact by construction, so a single bad day can never block every later sync
    /// (2026-10-10 review, finding 1).
    func totals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal] {
        guard isAvailable else { throw QueryError.unavailable }
        do {
            return try await collectionTotals(from: start, through: end, calendar: calendar)
        } catch QueryError.boundaries {
            return try await perDayTotals(from: start, through: end, calendar: calendar)
        }
    }

    private func collectionTotals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        var interval = DateComponents(day: 1)
        interval.calendar = calendar
        interval.timeZone = calendar.timeZone
        let store = healthStore
        return try await withCheckedThrowingContinuation { continuation in
            let completion = QueryCompletion(continuation)
            let query = HKStatisticsCollectionQuery(quantityType: stepType, quantitySamplePredicate: predicate,
                options: .cumulativeSum, anchorDate: start, intervalComponents: interval)
            query.initialResultsHandler = { _, collection, error in
                defer { store.stop(query) }
                if let error { completion.finish(.failure(error)); return }
                guard let collection else { completion.finish(.failure(QueryError.unavailable)); return }
                var readings: [DailyStepTotal] = []
                var day = start
                while day < end {
                    guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                        completion.finish(.failure(QueryError.boundaries)); return
                    }
                    let statistics = collection.statistics(for: day)
                    // If the platform cannot honor these calendar boundaries,
                    // don't credit overlapping buckets during travel or DST.
                    if let statistics,
                       abs(statistics.startDate.timeIntervalSince(day)) > 1 || abs(statistics.endDate.timeIntervalSince(next)) > 1 {
                        completion.finish(.failure(QueryError.boundaries)); return
                    }
                    let total = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    readings.append(DailyStepTotal(day: DayKey.make(day, calendar: calendar), total: Self.sanitize(total)))
                    day = next
                }
                completion.finish(.success(readings))
            }
            store.execute(query)
            // Bound background work so the observer completion is always called.
            DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
                if completion.finish(.failure(QueryError.timeout)) { store.stop(query) }
            }
        }
    }

    private func perDayTotals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal] {
        var readings: [DailyStepTotal] = []
        var day = start
        let deadline = Date().addingTimeInterval(25)
        while day < end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { throw QueryError.boundaries }
            guard Date() < deadline else { throw QueryError.timeout }
            let total = try await dailyTotal(from: day, to: next)
            readings.append(DailyStepTotal(day: DayKey.make(day, calendar: calendar), total: total))
            day = next
        }
        return readings
    }

    /// Cumulative steps whose sample start lies in [start, end).
    private func dailyTotal(from start: Date, to end: Date) async throws -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let store = healthStore
        return try await withCheckedThrowingContinuation { continuation in
            let completion = QueryCompletion(continuation)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, statistics, error in
                if let error, (error as? HKError)?.code != .errorNoData {
                    completion.finish(.failure(error)); return
                }
                let total = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                completion.finish(.success(Self.sanitize(total)))
            }
            store.execute(query)
            DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
                if completion.finish(.failure(QueryError.timeout)) { store.stop(query) }
            }
        }
    }

    /// NaN, infinite or absurd sums written by another app never reach `Int(_:)`,
    /// which traps on them. The game applies its own `Tuning.maxDailySteps` cap after this.
    nonisolated static func sanitize(_ total: Double) -> Int {
        guard total.isFinite, total > 0 else { return 0 }
        return Int(min(total, 10_000_000))
    }

    func startObserving(onChange: @escaping @Sendable () async -> Void) {
        onStepsChanged = onChange
        guard isAvailable, observer == nil else { return }
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            Task { await onChange(); completion() }
        }
        observer = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { success, error in
            if !success || error != nil { print("[health] Background delivery unavailable; foreground reconciliation remains active.") }
        }
    }

    enum QueryError: Error { case unavailable, timeout, boundaries }
}

private final class QueryCompletion<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    init(_ continuation: CheckedContinuation<Value, Error>) { self.continuation = continuation }
    @discardableResult
    func finish(_ result: Result<Value, Error>) -> Bool {
        lock.lock()
        let current = continuation
        continuation = nil
        lock.unlock()
        guard let current else { return false }
        current.resume(with: result)
        return true
    }
}

extension GameStore {
    @discardableResult
    func syncSteps(using service: StepService, now: Date = .now) async -> StepUpdate {
        let result = await StepSyncCoordinator.shared.sync(store: self, reader: service, now: now) ?? StepUpdate()
        if result.eggBecameReady { Haptics.notify() }
        return result
    }
}
