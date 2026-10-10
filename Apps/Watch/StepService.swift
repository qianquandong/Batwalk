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

    func totals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal] {
        guard isAvailable else { throw QueryError.unavailable }
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
                    readings.append(DailyStepTotal(day: DayKey.make(day, calendar: calendar), total: max(0, Int(total))))
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

private final class QueryCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[DailyStepTotal], Error>?
    init(_ continuation: CheckedContinuation<[DailyStepTotal], Error>) { self.continuation = continuation }
    @discardableResult
    func finish(_ result: Result<[DailyStepTotal], Error>) -> Bool {
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
