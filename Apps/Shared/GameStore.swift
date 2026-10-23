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
    /// A collection that could be restored: a local/CloudKit backup row, or the
    /// backup the paired iPhone published over WatchConnectivity.
    private(set) var availableBackup: CollectionBackup?
    private(set) var lastSyncAt: Date?
    private(set) var companionHandoff = CompanionHandoff()
    private(set) var settingsHandoff = PlayerSettingsHandoff()
    private(set) var settingsRequestError: String?
    private(set) var companionRequestError: String?
    private(set) var companionArrival: String?
    private(set) var lastStepReadAt: Date?
    private(set) var isDemo = false
    @ObservationIgnored var analytics: AnalyticsSink = NoopAnalytics()
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var record: SaveRecord?
    @ObservationIgnored private let archive: SaveArchive
    @ObservationIgnored private let commit: (ModelContext) throws -> Void
    @ObservationIgnored private let onCommit: ((Data) -> Void)?
    @ObservationIgnored private var visitSaveID: UUID?
    @ObservationIgnored private var visits = BatVisitMemory()
    @ObservationIgnored private var openingMemory = BatOpeningMemory()
    @ObservationIgnored private var openingSaveID: UUID?

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
        if role == .phone, let metadata = self.archive.loadPhoneMetadata() {
            if metadata.saveID == state.saveID, metadata.revision == state.revision { lastSyncAt = metadata.lastSyncAt }
            companionHandoff = metadata.handoff
            settingsHandoff = metadata.settingsHandoff ?? PlayerSettingsHandoff()
            refreshHandoff()
        }
    }

    func load() {
        guard !isDemo else { return }
        if role == .phone { try? archive.sanitizeMirrorCopies() }
        if role == .phone, let cached = archive.load() {
            // The read-only phone cache is newer than any legacy SwiftData row.
            if !state.hasStarted || cached.isRicher(than: state) { state = cached.collectionMirror() }
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
                if !state.hasStarted || best.1.isRicher(than: state) { state = role == .phone ? best.1.collectionMirror() : best.1 }
                // Only point writes at the record whose state we actually selected.
                if state.saveID == best.1.saveID || state == best.1 { record = best.0 }
                recoveryRequired = false
            } else if let recovered = archive.load() {
                state = role == .phone ? recovered.collectionMirror() : recovered
                recoveryRequired = false
                if role == .watch { try persistRecovered() }
            } else if !records.isEmpty {
                recoveryRequired = true
                lastError = "Your save could not be opened. It has been kept safe. Try again or restore a collection backup."
            }
            // Keep conflicting/corrupt rows available for recovery.
            let backups = try context.fetch(FetchDescriptor<CollectionBackupRecord>())
            var candidates = backups.compactMap { row -> (CollectionBackup, Date)? in
                guard let backup = try? JSONDecoder().decode(CollectionBackup.self, from: row.payload),
                      backup.version == 1, backup.hasStarted else { return nil }
                return (backup, row.updatedAt)
            }
            // A re-paired Watch has no rows, but the phone may still hold the mirror.
            if role == .watch, let phone = PhoneSync.shared.receivedPhoneBackup(), phone.hasStarted {
                candidates.append((phone, .now))
            }
            availableBackup = candidates.sorted { a, b in
                if a.0.saveID == b.0.saveID { return a.0.revision > b.0.revision }
                if a.0.collection.count != b.0.collection.count { return a.0.collection.count > b.0.collection.count }
                if a.0.history.count != b.0.history.count { return a.0.history.count > b.0.history.count }
                return a.1 > b.1
            }.first?.0
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

    /// Call only from the visible Home companion. This cosmetic ledger never
    /// changes game rewards, revisions, sync snapshots or collection backups.
    func companionVisitEvents(day: String) -> [BatAnimationEvent] {
        guard role == .watch, let bat = state.companion else { return [] }
        if visitSaveID != state.saveID {
            visits = isDemo ? BatVisitMemory() : archive.loadVisits(saveID: state.saveID) ?? BatVisitMemory()
            visitSaveID = state.saveID
        }
        let previous = visits
        let events = visits.visit(speciesID: bat.speciesID, day: day, creditedSteps: state.lifetimeCreditedSteps)
        if !isDemo, previous != visits { try? archive.saveVisits(visits, saveID: state.saveID) }
        return events
    }

    func endCompanionVisit() { openingMemory.leaveApp() }

    /// Called only by the visible, active Watch companion. No rewards or save writes.
    func companionOpeningRequest(time: TimeOfDay, motionAllowed: Bool) -> BatAnimationRequest? {
        guard role == .watch, let bat = state.companion else { return nil }
        if openingSaveID != state.saveID {
            openingMemory.leaveApp()
            openingSaveID = state.saveID
        }
        return openingMemory.request(speciesID: bat.speciesID,
            friendshipLevel: Friendship.level(forEXP: bat.friendshipEXP), time: time, motionAllowed: motionAllowed)
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

    /// Watch only: the paired iPhone published its mirror of the collection.
    /// Offered when this Watch has nothing yet, or strictly less than the phone remembers.
    func offerPhoneBackup(_ backup: CollectionBackup) {
        guard role == .watch, !isDemo, backup.version == 1, backup.hasStarted else { return }
        let richerThanLocal = availableBackup.map { backup.collection.count > $0.collection.count } ?? true
        guard richerThanLocal, !state.hasStarted || backup.collection.count > state.collection.count else { return }
        availableBackup = backup
    }

    /// iPhone only: keep the Watch's fallback copy of the collection current.
    func publishBackupToWatch() {
        guard role == .phone, !isDemo, state.hasStarted else { return }
        PhoneSync.shared.publish(phoneBackup: CollectionBackup(state: state))
    }

    func loadDemo(_ demo: GameState) {
        isDemo = true; state = demo
        if role == .phone {
            lastSyncAt = demo.hasStarted ? .now.addingTimeInterval(DemoMode.scenario == "phone-stale" ? -7200 : 0) : nil
            if DemoMode.scenario == "phone-birthday-pending" {
                settingsHandoff.begin(PlayerSettingsRequest(saveID: demo.saveID, baseRevision: demo.revision,
                                                            birthday: MonthDay(month: 2, day: 29)))
            }
            if DemoMode.scenario == "phone-pending" {
                companionHandoff.begin(CompanionChangeRequest(speciesID: "sticky", saveID: demo.saveID))
            }
        }
    }
    func clearError() { lastError = nil }

    func applyMirror(_ data: Data, updatedAt: Date? = nil) {
        guard role == .phone, !isDemo else { return }
        guard let decoded = try? JSONDecoder().decode(GameState.self, from: data) else {
            // Tell the player why nothing is arriving instead of silently showing an old mirror.
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if (json?["schemaVersion"] as? Int ?? 1) > GameState.currentSchemaVersion {
                lastError = "Your Watch has a newer Batwalk. Update Batwalk on this iPhone to see your latest progress."
            }
            return
        }
        let incoming = decoded.collectionMirror()
        if incoming.saveID == state.saveID, incoming.revision < state.revision { return }
        do {
            try archive.save(JSONEncoder().encode(incoming))
            let changed = state != incoming
            state = incoming
            if let updatedAt { lastSyncAt = min(updatedAt, .now) }
            else if changed || lastSyncAt == nil { lastSyncAt = .now }
            companionHandoff.reconcile(with: state)
            settingsHandoff.reconcile(with: state)
            persistPhoneMetadata()
            recoveryRequired = false
            lastError = nil
            saveIntentSnapshot()
            publishBackupToWatch()
        } catch { lastError = "Your Watch data arrived, but the offline copy could not be saved." }
    }

    /// Persist the intent before handing it to the system queue. The phone never edits GameState.
    func chooseCompanion(_ speciesID: String, send: ((CompanionChangeRequest) -> PhoneSync.SendResult)? = nil) {
        guard role == .phone else { return }
        refreshHandoff()
        guard !companionHandoff.isWaiting, state.collection[speciesID] != nil,
              state.companionID != speciesID else { return }
        let previous = companionHandoff
        let request = CompanionChangeRequest(speciesID: speciesID, saveID: state.saveID)
        companionHandoff.begin(request)
        companionRequestError = nil
        do { if !isDemo { try archive.savePhoneMetadata(phoneMetadata) } }
        catch {
            companionHandoff = previous
            companionRequestError = "Your request could not be saved. Please try again."
            return
        }
        let result = isDemo ? .sent : (send?(request) ?? PhoneSync.shared.send(request: request))
        if result != .sent {
            companionHandoff = previous
            companionRequestError = result == .noWatchApp
                ? "Install Batwalk on your paired Apple Watch, then try again."
                : "Watch connection is starting. Open both apps, then try again."
            persistPhoneMetadata()
        }
    }

    func receiveCompanionReceipt(_ receipt: CompanionChangeReceipt) {
        guard role == .phone, !isDemo else { return }
        companionHandoff.receive(receipt, state: state)
        persistPhoneMetadata()
    }

    func refreshHandoff() {
        guard role == .phone else { return }
        let before = companionHandoff
        let settingsBefore = settingsHandoff
        companionHandoff.reconcile(with: state)
        settingsHandoff.reconcile(with: state)
        if before != companionHandoff || settingsBefore != settingsHandoff { persistPhoneMetadata() }
    }

    /// Return a result even for unchanged selections and failed saves; the phone must not hang.
    func applyCompanionRequest(_ request: CompanionChangeRequest, now: Date = .now) -> CompanionChangeReceipt {
        precondition(role == .watch)
        var receipts = isDemo ? [] : archive.loadReceipts().filter { $0.request.expiresAt > now }
        if let previous = receipts.first(where: { $0.request.id == request.id }) { return previous }
        let outcome: CompanionChangeOutcome
        if now >= request.expiresAt { outcome = .expired }
        else if request.saveID != state.saveID { outcome = .saveChanged }
        else if state.collection[request.speciesID] == nil { outcome = .notOwned }
        else {
            do {
                try mutate { try $0.setCompanion(request.speciesID) }
                companionArrival = request.speciesID
                outcome = .applied
            } catch { outcome = .saveFailed }
        }
        let receipt = CompanionChangeReceipt(request: request, outcome: outcome, revision: state.revision)
        receipts.append(receipt)
        if !isDemo { try? archive.saveReceipts(receipts) }
        return receipt
    }

    /// Only an expiring request is saved locally. The phone never edits the game save.
    func chooseBirthday(_ birthday: MonthDay?, send: ((PlayerSettingsRequest) -> PhoneSync.SendResult)? = nil) {
        guard role == .phone, state.hasStarted else { return }
        refreshHandoff()
        guard !settingsHandoff.isWaiting else { return }
        if state.birthday == birthday {
            settingsHandoff = PlayerSettingsHandoff(); settingsRequestError = nil
            persistPhoneMetadata(); return
        }
        let previous = settingsHandoff
        let request = PlayerSettingsRequest(saveID: state.saveID, baseRevision: state.revision, birthday: birthday)
        settingsHandoff.begin(request); settingsRequestError = nil
        do { if !isDemo { try archive.savePhoneMetadata(phoneMetadata) } }
        catch {
            settingsHandoff = previous
            settingsRequestError = "Your birthday request could not be saved. Please try again."
            return
        }
        let result = isDemo ? .sent : (send?(request) ?? PhoneSync.shared.send(settings: request))
        if result != .sent {
            settingsHandoff = previous
            settingsRequestError = result == .noWatchApp
                ? "Install Batwalk on your paired Apple Watch, then try again."
                : "Watch connection is starting. Open both apps, then try again."
            persistPhoneMetadata()
        }
    }

    func receiveSettingsReceipt(_ receipt: PlayerSettingsReceipt) {
        guard role == .phone, !isDemo else { return }
        settingsHandoff.receive(receipt, state: state)
        persistPhoneMetadata()
    }

    func applySettingsRequest(_ request: PlayerSettingsRequest, now: Date = .now) -> PlayerSettingsReceipt {
        precondition(role == .watch)
        let outcome: PlayerSettingsOutcome
        do { outcome = try mutate { $0.applyPlayerSettings(request, now: now) } }
        catch { return PlayerSettingsReceipt(request: request, outcome: .saveFailed, revision: state.revision) }
        return PlayerSettingsReceipt(request: request, outcome: outcome, revision: state.revision)
    }

    private var phoneMetadata: SaveArchive.PhoneMetadata {
        SaveArchive.PhoneMetadata(lastSyncAt: lastSyncAt, saveID: state.saveID,
                                  revision: state.revision, handoff: companionHandoff, settingsHandoff: settingsHandoff)
    }

    private func persistPhoneMetadata() {
        guard !isDemo else { return }
        do { try archive.savePhoneMetadata(phoneMetadata) }
        catch {
            companionRequestError = "The latest connection status could not be saved. Open both apps to refresh it."
            settingsRequestError = "The latest connection status could not be saved. Open both apps to refresh it."
        }
    }

    // MARK: Complication / intent snapshot

    private var snapshot: ComplicationSnapshot {
        let previous = ComplicationSnapshot.load()
        return ComplicationSnapshot(
            companionName: state.companion?.displayName,
            companionSpeciesID: state.companion?.speciesID,
            companionIsShiny: state.companion?.showsShiny ?? false,
            eggType: state.egg?.type.rawValue,
            eggProgress: state.egg?.progress,
            eggStepsRemaining: state.egg?.stepsRemaining,
            eggVisualState: state.egg?.visualState.rawValue,
            isEggReady: state.isEggReady,
            duskHour: Tuning.default.duskStartHour,
            // A freshly launched process (background wake, phone request) has no step
            // read yet; keep the last known freshness instead of flashing "stale".
            updatedAt: lastStepReadAt ?? previous.updatedAt)
    }

    func refreshComplication() {
        guard !isDemo, role == .watch else { return }
        guard snapshot.save() else { return }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "BatwalkComplication")
        #endif
    }

    /// iPhone: the in-app copy that Siri's "Check my egg" reads (no App Group needed).
    private func saveIntentSnapshot() {
        guard role == .phone, !isDemo else { return }
        var copy = snapshot
        copy.updatedAt = lastSyncAt ?? .now
        copy.save()
    }

    func recordStepRead(at date: Date) { lastStepReadAt = date; refreshComplication() }

    private func writeCollectionBackup() {
        guard SharedConfig.cloudBackupEnabled, role == .watch else { return }
        do {
            let current = CollectionBackup(state: state)
            let rows = try context.fetch(FetchDescriptor<CollectionBackupRecord>())
            let existing = rows.first { $0.saveID == state.saveID.uuidString }
            // Never rewrite the cloud record for step churn alone: its modification
            // times would otherwise trace when the player was walking (guideline 5.1.3).
            if let existing, let previous = try? JSONDecoder().decode(CollectionBackup.self, from: existing.payload),
               previous.hasSameContent(as: current) { return }
            let payload = try JSONEncoder().encode(current)
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
