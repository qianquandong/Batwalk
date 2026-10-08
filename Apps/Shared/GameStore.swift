import Foundation
import Observation
import SwiftData
import BatwalkCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Owns the in-memory `GameState` and persists it.
///
/// - On the **Watch** the store is authoritative: every mutation is saved locally
///   (SwiftData → CloudKit), pushed to the iPhone over WatchConnectivity, and
///   summarised for the complication.
/// - On the **iPhone** the store is a read-only mirror: it loads the CloudKit
///   copy and applies whatever the Watch sends. It never writes the save, so the
///   two devices can never produce conflicting saves.
@MainActor
@Observable
final class GameStore {
    enum Role { case watch, phone }

    private(set) var state = GameState()
    let role: Role

    private let context: ModelContext
    @ObservationIgnored private var record: SaveRecord?
    /// In-memory demo (screenshots): never loads, saves, or syncs.
    @ObservationIgnored private(set) var isDemo = false
    @ObservationIgnored var analytics: AnalyticsSink = NoopAnalytics()

    init(container: ModelContainer, role: Role) {
        self.context = container.mainContext
        self.role = role
        load()
    }

    // MARK: Loading

    /// Loads the richest save on disk. After a CloudKit restore races a fresh
    /// install there can briefly be two rows; the richer one wins and the other is removed.
    func load() {
        guard !isDemo else { return }
        let records = (try? context.fetch(FetchDescriptor<SaveRecord>())) ?? []
        var best: (record: SaveRecord, state: GameState)?
        let decoder = JSONDecoder()
        for candidate in records {
            guard let decoded = try? decoder.decode(GameState.self, from: candidate.payload) else { continue }
            if best == nil || decoded.isRicher(than: best!.state) {
                best = (candidate, decoded)
            }
        }

        if let best {
            // Never replace a richer in-memory state with a poorer disk copy.
            if best.state.isRicher(than: state) || !state.hasStarted {
                state = best.state
            }
            record = best.record
            if role == .watch {
                for other in records where other !== best.record { context.delete(other) }
                try? context.save()
            }
        }
    }

    // MARK: Mutating (Watch only)

    /// Apply a rule from BatwalkCore and persist the result.
    @discardableResult
    func mutate<T>(_ body: (inout GameState) throws -> T) rethrows -> T {
        precondition(role == .watch, "The iPhone mirror never mutates the save")
        let result = try body(&state)
        persist()
        return result
    }

    /// Replace the state with a demo scenario that is never persisted.
    func loadDemo(_ demo: GameState) {
        isDemo = true
        state = demo
    }

    private func persist() {
        guard !isDemo else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        if let record {
            record.payload = data
            record.updatedAt = .now
        } else {
            let new = SaveRecord(payload: data, updatedAt: .now, writer: "watch")
            context.insert(new)
            record = new
        }
        try? context.save()

        PhoneSync.shared.push(save: data)
        writeComplicationSnapshot()
    }

    private func writeComplicationSnapshot() {
        let companion = state.companion
        let snapshot = ComplicationSnapshot(
            companionName: companion?.displayName,
            companionSpeciesID: companion?.speciesID,
            eggProgress: state.egg?.progress,
            eggStepsRemaining: state.egg?.stepsRemaining,
            isEggReady: state.isEggReady,
            updatedAt: .now
        )
        guard snapshot.withoutTimestamp != ComplicationSnapshot.load().withoutTimestamp else { return }
        snapshot.save()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: Mirror (iPhone)

    /// Apply a save pushed from the Watch. WatchConnectivity's application
    /// context always carries the Watch's latest state, so it simply wins.
    func applyMirror(_ data: Data) {
        guard role == .phone, !isDemo,
              let incoming = try? JSONDecoder().decode(GameState.self, from: data) else { return }
        state = incoming
    }
}

private extension ComplicationSnapshot {
    var withoutTimestamp: ComplicationSnapshot {
        var copy = self
        copy.updatedAt = .distantPast
        return copy
    }
}
