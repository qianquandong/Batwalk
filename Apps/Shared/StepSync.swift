import Foundation
import Observation
import BatwalkCore

struct DailyStepTotal: Equatable, Sendable {
    let day: String
    let total: Int
}

@MainActor
protocol StepTotalReader {
    func totals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal]
}

/// One HealthKit batch -> one committed game update. Platform adapters never
/// advance the ledger on failure, and all foreground/background callers share this gate.
@MainActor
@Observable
final class StepSyncCoordinator {
    static let shared = StepSyncCoordinator()
    enum Status: Equatable {
        case idle, updating, updated(total: Int, at: Date), failed
    }
    private(set) var status: Status = .idle
    private(set) var isSyncing = false
    @ObservationIgnored private var resyncRequested = false

    func sync(store: GameStore, reader: any StepTotalReader, now: Date = .now) async -> StepUpdate? {
        guard store.state.hasStarted, !store.isDemo, !store.recoveryRequired else { return nil }
        if isSyncing { resyncRequested = true; return nil }
        isSyncing = true
        defer { isSyncing = false }
        var combined = StepUpdate()
        repeat {
            resyncRequested = false
            status = .updating
            do {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = store.state.ledger.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
                let today = calendar.startOfDay(for: now)
                let todayKey = DayKey.make(today, calendar: calendar)
                try store.mutate { $0.beginStepTracking(on: todayKey, timeZone: calendar.timeZone.identifier) }
                let start = store.state.needsStepBaseline ? today : store.state.ledger.reconciliationStart(now: now, calendar: calendar)
                let end = calendar.date(byAdding: .day, value: 1, to: today)!
                let readings = try await reader.totals(from: start, through: end, calendar: calendar)
                let byDay = Dictionary(readings.map { ($0.day, $0.total) }, uniquingKeysWith: max)
                var expected: [String] = []
                var day = start
                while day < end {
                    expected.append(DayKey.make(day, calendar: calendar))
                    guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { throw SyncError.incomplete }
                    day = next
                }
                guard expected.allSatisfy({ byDay[$0] != nil }), let total = byDay[todayKey] else { throw SyncError.incomplete }
                let update = try store.mutate { state -> StepUpdate in
                    if state.needsStepBaseline {
                        state.establishStepBaseline(day: todayKey, total: total, timeZone: calendar.timeZone.identifier)
                        return StepUpdate()
                    }
                    var batch = StepUpdate()
                    for key in expected {
                        let result = state.ingestSteps(dayKey: key, dailyTotal: byDay[key]!)
                        batch.creditedSteps += result.creditedSteps
                        batch.fruitEarned += result.fruitEarned
                        batch.eggBecameReady = batch.eggBecameReady || result.eggBecameReady
                    }
                    return batch
                }
                combined.creditedSteps += update.creditedSteps
                combined.fruitEarned += update.fruitEarned
                combined.eggBecameReady = combined.eggBecameReady || update.eggBecameReady
                status = .updated(total: total, at: now)
                store.refreshComplication()
            } catch {
                status = .failed
                return nil
            }
        } while resyncRequested
        return combined
    }

    enum SyncError: Error { case incomplete }
}
