import Foundation
import HealthKit
import BatwalkCore

/// Reads Step Count only (PRD §4.5). No GPS, no workout session, no
/// second-by-second polling (PRD §4.7): the app reads daily totals when it
/// becomes active, and HealthKit background delivery wakes it at most hourly.
final class StepService {
    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private var observer: HKObserverQuery?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Returns whether the permission sheet completed. HealthKit never reveals
    /// whether *read* access was granted — a denied user simply reads 0 steps.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            return true
        } catch {
            return false
        }
    }

    /// Whether the system would still show the permission sheet (Settings › Health Access).
    func authorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        guard isAvailable else { return .unknown }
        return (try? await healthStore.statusForAuthorizationRequest(toShare: [], read: [stepType])) ?? .unknown
    }

    /// Cumulative steps for the local calendar day containing `day`.
    /// nil means "query failed — don't ingest anything".
    func dailyTotal(for day: Date, calendar: Calendar = .current) async -> Int? {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let store = healthStore
        let type = stepType

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let sum = statistics?.sumQuantity() {
                    continuation.resume(returning: Int(sum.doubleValue(for: .count())))
                } else if let hkError = error as? HKError, hkError.code == .errorNoData {
                    continuation.resume(returning: 0)
                } else if error == nil {
                    continuation.resume(returning: 0)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(query)
        }
    }

    /// Hourly background delivery → keeps the complication and Hatch Ready notice fresh.
    func startObserving(onChange: @escaping @Sendable () async -> Void) {
        guard isAvailable, observer == nil else { return }
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            Task {
                await onChange()
                completion()
            }
        }
        observer = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }
}

extension GameStore {
    /// Pull HealthKit totals for every day the ledger hasn't fully seen, oldest first.
    @discardableResult
    func syncSteps(using service: StepService, now: Date = .now) async -> StepUpdate {
        var combined = StepUpdate()
        let calendar = Calendar.current
        let days = DayKey.daysToSync(lastKey: state.ledger.dayKey, now: now, calendar: calendar)
        for day in days {
            guard let total = await service.dailyTotal(for: day, calendar: calendar) else { continue }
            let key = DayKey.make(day, calendar: calendar)
            let update = mutate { $0.ingestSteps(dayKey: key, dailyTotal: total) }
            combined.creditedSteps += update.creditedSteps
            combined.fruitEarned += update.fruitEarned
            combined.eggBecameReady = combined.eggBecameReady || update.eggBecameReady
        }
        if combined.eggBecameReady {
            Haptics.notify()
            analytics.log(.eggComplete, properties: ["egg": state.egg?.type.rawValue ?? ""])
        }
        return combined
    }
}
