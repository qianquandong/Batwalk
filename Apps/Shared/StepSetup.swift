import Foundation
import Observation
import BatwalkCore

/// A completed permission sheet is NOT proof of Health read access. The first
/// playable egg waits for an actual positive reading; zero remains ambiguous.
@MainActor
@Observable
final class StepSetupCoordinator {
    enum Status: Equatable {
        case idle, checking, noSteps, requestFailed, readFailed, ready
    }

    private(set) var status: Status = .idle
    var isWorking: Bool { status == .checking }
    @ObservationIgnored private let sync: StepSyncCoordinator

    init(sync: StepSyncCoordinator? = nil) { self.sync = sync ?? .shared }

    /// Existing saves with real readings stay usable at midnight and on rest
    /// days. This is evidence of past data flow, never a read-permission claim.
    static func needsSetup(for state: GameState) -> Bool {
        state.lifetimeCreditedSteps == 0 &&
        state.ledger.lastDailyTotal == 0 &&
        !state.ledger.dailyTotals.values.contains(where: { $0 > 0 })
    }

    func connect(store: GameStore, reader: any StepTotalReader,
                 requestAuthorization: (() async -> Bool)? = nil,
                 now: Date = .now) async {
        guard !isWorking, !store.isDemo, !store.recoveryRequired, store.role == .watch else { return }
        status = .checking
        if let requestAuthorization, !(await requestAuthorization()) {
            status = .requestFailed
            return
        }

        do {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = store.state.ledger.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
            let today = calendar.startOfDay(for: now)
            let key = DayKey.make(today, calendar: calendar)
            guard let end = calendar.date(byAdding: .day, value: 1, to: today) else {
                status = .readFailed
                return
            }
            let readings = try await reader.totals(from: today, through: end, calendar: calendar)
            guard let total = readings.filter({ $0.day == key }).map(\.total).max(), total >= 0 else {
                status = .readFailed
                return
            }
            guard total > 0 else {
                status = .noSteps // No walking, delayed data and denied access look the same.
                return
            }

            let firstStart = !store.state.hasStarted
            if firstStart {
                try store.mutate { $0.start(seed: UInt64.random(in: .min ... .max), now: now) }
            }
            // Use the normal reconciliation gate: no separate reward rules,
            // no resetting an existing egg, and no double credit on retries.
            _ = await sync.sync(store: store, reader: reader, now: now)
            status = Self.needsSetup(for: store.state) ? .readFailed : .ready
            if firstStart, status == .ready {
                store.analytics.log(.onboardingComplete, properties: [:])
            }
        } catch {
            status = .readFailed
        }
    }
}
