import XCTest
import SwiftData
import BatwalkCore
@testable import Batwalk

extension AppReliabilityTests {
    @MainActor
    private func handoffWatch() throws -> GameStore {
        let (watch, _) = try makeStore()
        try watch.mutate {
            $0.start(seed: 1, now: .now)
            $0.ingestSteps(dayKey: "2026-10-10", dailyTotal: 2_000)
            _ = try $0.hatch(now: .now)
            try $0.startEgg(.tiny, seed: 1, now: .now)
        }
        return watch
    }

    @MainActor
    func testCompanionRequestKeepsEggAndNoOpRevision() async throws {
        let watch = try handoffWatch()
        let before = watch.state
        let request = CompanionChangeRequest(speciesID: "mochi", saveID: before.saveID)
        let receipt = watch.applyCompanionRequest(request)
        XCTAssertEqual(receipt.outcome, .applied)
        XCTAssertEqual(watch.state, before)
        XCTAssertEqual(watch.applyCompanionRequest(request), receipt)
    }

    @MainActor
    func testWatchRejectsExpiredAndForeignSaveCommands() async throws {
        let watch = try handoffWatch()
        let before = watch.state
        let stale = CompanionChangeRequest(speciesID: "mochi", saveID: before.saveID,
                                           requestedAt: .now.addingTimeInterval(-901))
        XCTAssertEqual(watch.applyCompanionRequest(stale).outcome, .expired)
        XCTAssertEqual(watch.applyCompanionRequest(CompanionChangeRequest(speciesID: "mochi", saveID: UUID())).outcome, .saveChanged)
        XCTAssertEqual(watch.state, before)
    }

    @MainActor
    func testUnknownBatRequestReturnsFailureWithoutChangingSave() async throws {
        let watch = try handoffWatch()
        let before = watch.state
        let result = watch.applyCompanionRequest(CompanionChangeRequest(speciesID: "ghost", saveID: before.saveID))
        XCTAssertEqual(result.outcome, .notOwned)
        XCTAssertEqual(watch.state, before)
    }

    @MainActor
    func testMirrorTimestampSurvivesPhoneRelaunchAndCachedDelivery() async throws {
        let watch = try handoffWatch()
        let schema = Schema([SaveRecord.self, CollectionBackupRecord.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = SaveArchive(name: "test", directory: directory)
        let phone = GameStore(container: container, role: .phone, archive: archive)
        let stamp = Date().addingTimeInterval(-7_200)
        let data = try JSONEncoder().encode(watch.state)
        phone.applyMirror(data, updatedAt: stamp)
        let reload = GameStore(container: container, role: .phone, archive: archive)
        XCTAssertEqual(reload.lastSyncAt, stamp)
        reload.applyMirror(data) // legacy cached context is not a new sync
        XCTAssertEqual(reload.lastSyncAt, stamp)
        XCTAssertEqual(reload.state, watch.state)
    }

    @MainActor
    func testPendingRequestRestoresWithoutChangingPhoneSave() async throws {
        let watch = try handoffWatch()
        let (phone, container) = try makeStore(role: .phone)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = SaveArchive(name: "test", directory: directory)
        let data = try JSONEncoder().encode(watch.state)
        try archive.save(data)
        var handoff = CompanionHandoff()
        handoff.begin(CompanionChangeRequest(speciesID: "sticky", saveID: watch.state.saveID))
        try archive.savePhoneMetadata(SaveArchive.PhoneMetadata(lastSyncAt: .now, saveID: watch.state.saveID,
                                                                revision: watch.state.revision, handoff: handoff))
        let reload = GameStore(container: container, role: .phone, archive: archive)
        XCTAssertTrue(reload.companionHandoff.isWaiting)
        XCTAssertEqual(reload.state, watch.state)
        XCTAssertNotEqual(phone.state.saveID, reload.state.saveID)
    }

    @MainActor
    private func twoBatState() throws -> GameState {
        var state = GameState()
        state.start(seed: 1, now: .now)
        state.ingestSteps(dayKey: "2026-10-10", dailyTotal: 2_000)
        _ = try state.hatch(now: .now)
        let seed = (UInt64(1)...1000).first { HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: false).species.id == "cocoa" }!
        try state.startEgg(.tiny, seed: seed, now: .now)
        state.ingestSteps(dayKey: "2026-10-10", dailyTotal: EggType.starter.targetSteps + EggType.tiny.targetSteps)
        _ = try state.hatch(now: .now)
        try state.setCompanion("mochi")
        try state.startEgg(.tiny, seed: 7, now: .now)
        return state
    }

    @MainActor
    func testEndToEndReceiptBeforeMirrorAndNoDuplicatePhoneQueue() async throws {
        let (watch, _) = try makeStore()
        let fixture = try twoBatState()
        try watch.mutate { $0 = fixture }
        let (phone, _) = try makeStore(role: .phone)
        phone.applyMirror(try JSONEncoder().encode(watch.state))
        let before = phone.state
        var queued: [CompanionChangeRequest] = []
        phone.chooseCompanion("cocoa", send: { queued.append($0); return .sent })
        phone.chooseCompanion("cocoa", send: { queued.append($0); return .sent })
        XCTAssertEqual(queued.count, 1); XCTAssertEqual(phone.state, before)
        let receipt = watch.applyCompanionRequest(try XCTUnwrap(queued.first))
        XCTAssertEqual(receipt.outcome, .applied)
        XCTAssertEqual(watch.state.egg, before.egg)
        phone.receiveCompanionReceipt(receipt)
        XCTAssertTrue(phone.companionHandoff.isWaiting)
        XCTAssertEqual(phone.state.companionID, "mochi")
        phone.applyMirror(try JSONEncoder().encode(watch.state))
        XCTAssertFalse(phone.companionHandoff.isWaiting)
        XCTAssertEqual(phone.state.companionID, "cocoa")
    }

    @MainActor
    func testFailedWatchCommitReturnsFailureAndKeepsOldCompanion() async throws {
        enum Failure: Error { case disk }
        var fail = false
        let (watch, _) = try makeStore(commit: { context in if fail { throw Failure.disk }; try context.save() })
        let fixture = try twoBatState()
        try watch.mutate { $0 = fixture }
        let before = watch.state
        fail = true
        let receipt = watch.applyCompanionRequest(CompanionChangeRequest(speciesID: "cocoa", saveID: before.saveID))
        XCTAssertEqual(receipt.outcome, .saveFailed)
        XCTAssertEqual(watch.state, before)
    }

    @MainActor
    func testDuplicateReceiptDoesNotUndoLaterWatchChoice() async throws {
        let (watch, _) = try makeStore()
        let fixture = try twoBatState()
        try watch.mutate { $0 = fixture }
        let request = CompanionChangeRequest(speciesID: "cocoa", saveID: watch.state.saveID)
        let receipt = watch.applyCompanionRequest(request)
        try watch.mutate { try $0.setCompanion("mochi") }
        XCTAssertEqual(watch.applyCompanionRequest(request), receipt)
        XCTAssertEqual(watch.state.companionID, "mochi")
    }

    @MainActor
    func testUnavailableSessionDoesNotLeaveAPhantomPendingRequest() async throws {
        let (phone, _) = try makeStore(role: .phone)
        let state = try twoBatState()
        phone.applyMirror(try JSONEncoder().encode(state))
        phone.chooseCompanion("cocoa", send: { _ in .noWatchApp })
        XCTAssertFalse(phone.companionHandoff.isWaiting)
        XCTAssertNotNil(phone.companionRequestError)
        XCTAssertEqual(phone.state, state)
    }
}

