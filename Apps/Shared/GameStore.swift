import Foundation
import Observation
import SwiftData
import BatwalkCore
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class GameStore {
    enum Role { case watch, phone }
    private(set) var state = GameState()
    let role: Role
    private(set) var lastError: String?
    private(set) var recoveryRequired = false
    private(set) var availableBackup: CollectionBackup?
    private(set) var lastSyncAt: Date?
    private(set) var lastStepReadAt: Date?
    private(set) var isDemo = false
    @ObservationIgnored var analytics: AnalyticsSink = NoopAnalytics()
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var record: SaveRecord?
    @ObservationIgnored private let archive: SaveArchive
    @ObservationIgnored private let commit: (ModelContext) throws -> Void
    @ObservationIgnored private let onCommit: ((Data) -> Void)?

    init(container: ModelContainer, role: Role, archive: SaveArchive? = nil,
         commit: @escaping (ModelContext) throws -> Void = { try $0.save() },
         onCommit: ((Data) -> Void)? = nil) {
        self.container = container
        context = container.mainContext
        context.autosaveEnabled = false
        self.role = role
        self.archive = archive ?? SaveArchive(name: role == .watch ? "watch" : "phone")
        self.commit = commit
        self.onCommit = onCommit
        load()
    }

    func load() {
        guard !isDemo else { return }
        if role == .phone, let cached = archive.load() {
            // The read-only phone cache is newer than any legacy SwiftData row.
            if !state.hasStarted || cached.isRicher(than: state) { state = cached }
            recoveryRequired = false
            return
        }
        guard !Persistence.storageUnavailable else {
            recoveryRequired = true
            lastError = "Your save is temporarily unavailable. Your files have been kept safe. Please restart Batwalk and try again."
            return
        }
        do {
            let records = try context.fetch(FetchDescriptor<SaveRecord>())
            if records.contains(where: { candidate in
                let json = (try? JSONSerialization.jsonObject(with: candidate.payload)) as? [String: Any]
                return (json?["schemaVersion"] as? Int ?? 1) > GameState.currentSchemaVersion
            }) {
                recoveryRequired = true
                lastError = "This save was made by a newer Batwalk. Update the app to open it. Your files have been kept safe."
                return
            }
            let decoded = records.compactMap { candidate -> (SaveRecord, GameState)? in
                guard let value = try? JSONDecoder().decode(GameState.self, from: candidate.payload) else { return nil }
                return (candidate, value)
            }
            let best = decoded.sorted { a, b in
                if a.1.saveID == b.1.saveID, a.1.revision != b.1.revision { return a.1.revision > b.1.revision }
                if a.1.history.count != b.1.history.count { return a.1.history.count > b.1.history.count }
                if a.1.lifetimeCreditedSteps != b.1.lifetimeCreditedSteps { return a.1.lifetimeCreditedSteps > b.1.lifetimeCreditedSteps }
                return a.0.updatedAt > b.0.updatedAt
            }.first
            if let best {
                if !state.hasStarted || best.1.isRicher(than: state) { state = best.1 }
                // Only point writes at the record whose state we actually selected.
                if state.saveID == best.1.saveID || state == best.1 { record = best.0 }
                recoveryRequired = false
            } else if let recovered = archive.load() {
                state = recovered
                recoveryRequired = false
                if role == .watch { try persistRecovered() }
            } else if !records.isEmpty {
                recoveryRequired = true
                lastError = "Your save could not be opened. It has been kept safe. Try again or restore a collection backup."
            }
            // Keep conflicting/corrupt rows available for recovery.
            let backups = try context.fetch(FetchDescriptor<CollectionBackupRecord>())
            availableBackup = backups.sorted { $0.updatedAt > $1.updatedAt }.compactMap {
                try? JSONDecoder().decode(CollectionBackup.self, from: $0.payload)
            }.first(where: { $0.version == 1 && $0.hasStarted })
            if role == .watch, !state.hasStarted, !recoveryRequired, let backup = availableBackup {
                try restore(backup)
            }
        } catch {
            recoveryRequired = true
            lastError = "Your save is temporarily unavailable. Please try again."
        }
    }

    @discardableResult
    func mutate<T>(_ body: (inout GameState) throws -> T) throws -> T {
        precondition(role == .watch, "The iPhone mirror never mutates the game")
        guard !recoveryRequired else { throw StoreError.recoveryRequired }
        var next = state
        let result = try body(&next)
        guard next != state else { return result }
        if isDemo { state = next; return result }
        next.advanceRevision()
        let data = try JSONEncoder().encode(next)
        let candidate = record ?? SaveRecord(payload: data, updatedAt: .now, writer: "watch")
        if record == nil { context.insert(candidate) }
        candidate.payload = data
        candidate.updatedAt = .now
        do { try commit(context) }
        catch {
            context.rollback()
            lastError = "This change could not be saved. Your previous progress is safe. Please try again."
            throw error
        }
        record = candidate
        state = next // publish only after the local transaction commits
        lastError = nil
        do { try archive.save(data) } catch {
            lastError = "Your progress is saved. The extra recovery copy will be retried."
        }
        writeCollectionBackup()
        if let onCommit { onCommit(data) } else {
            PhoneSync.shared.push(save: data)
            refreshComplication()
        }
        return result
    }

    private func persistRecovered() throws {
        let data = try JSONEncoder().encode(state)
        let recovered = SaveRecord(payload: data, updatedAt: .now, writer: "watch")
        context.insert(recovered)
        do { try commit(context); record = recovered }
        catch { context.rollback(); throw error }
    }

    func restore(_ backup: CollectionBackup) throws {
        guard backup.version == 1, !Persistence.storageUnavailable else { throw StoreError.unsupportedBackup }
        let wasBlocked = recoveryRequired
        recoveryRequired = false
        do {
            try mutate { $0.restoreCollection(backup) }
            availableBackup = nil
        } catch { recoveryRequired = wasBlocked; throw error }
    }

    func loadDemo(_ demo: GameState) { isDemo = true; state = demo }
    func clearError() { lastError = nil }

    func applyMirror(_ data: Data) {
        guard role == .phone, !isDemo,
              let incoming = try? JSONDecoder().decode(GameState.self, from: data) else { return }
        if incoming.saveID == state.saveID, incoming.revision < state.revision { return }
        do {
            try archive.save(data)
            state = incoming
            lastSyncAt = .now
            recoveryRequired = false
            lastError = nil
        } catch { lastError = "Your Watch data arrived, but the offline copy could not be saved." }
    }

    func refreshComplication() {
        guard !isDemo, role == .watch, SharedConfig.appGroupEnabled else { return }
        let snapshot = ComplicationSnapshot(companionName: state.companion?.displayName,
            companionSpeciesID: state.companion?.speciesID, eggProgress: state.egg?.progress,
            eggStepsRemaining: state.egg?.stepsRemaining, isEggReady: state.isEggReady,
            updatedAt: lastStepReadAt ?? .distantPast)
        guard snapshot.save() else { return }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "BatwalkComplication")
        #endif
    }

    func recordStepRead(at date: Date) { lastStepReadAt = date; refreshComplication() }

    private func writeCollectionBackup() {
        guard SharedConfig.cloudBackupEnabled, role == .watch else { return }
        do {
            let payload = try JSONEncoder().encode(CollectionBackup(state: state))
            let rows = try context.fetch(FetchDescriptor<CollectionBackupRecord>())
            let existing = rows.first { $0.saveID == state.saveID.uuidString }
            let backup = existing ?? CollectionBackupRecord()
            if existing == nil { context.insert(backup) }
            backup.saveID = state.saveID.uuidString
            backup.payload = payload
            backup.updatedAt = .now
            try commit(context)
        } catch {
            context.rollback()
            lastError = "Your progress is saved on this Watch. Collection backup will be retried."
        }
    }

    enum StoreError: Error { case recoveryRequired, unsupportedBackup }
}
