import XCTest
import SwiftData
import BatwalkCore
@testable import Batwalk

final class AppReliabilityTests: XCTestCase {
    @MainActor
    func makeStore(role: GameStore.Role = .watch,
                   commit: @escaping (ModelContext) throws -> Void = { try $0.save() },
                   onCommit: ((Data) -> Void)? = { _ in }) throws -> (GameStore, ModelContainer) {
        let schema = Schema([SaveRecord.self, CollectionBackupRecord.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let archive = SaveArchive(name: "test", directory: directory)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return (GameStore(container: container, role: role, archive: archive, commit: commit, onCommit: onCommit), container)
    }

    @MainActor
    func testFailedCommitDoesNotPublishOrSyncHatch() async throws {
        enum Failure: Error { case disk }
        var fail = false
        var syncs = 0
        let (store, _) = try makeStore(commit: { context in
            if fail { throw Failure.disk }; try context.save()
        }, onCommit: { _ in syncs += 1 })
        try store.mutate { $0.start(seed: 1, now: .now) }
        try store.mutate { $0.ingestSteps(dayKey: "2026-10-09", dailyTotal: 2_000) }
        let before = store.state; let priorSyncs = syncs
        fail = true
        XCTAssertThrowsError(try store.mutate { try $0.hatch(now: .now) })
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(syncs, priorSyncs)
        XCTAssertNotNil(store.lastError)
        fail = false
        _ = try store.mutate { try $0.hatch(now: .now) }
        XCTAssertEqual(store.state.history.count, 1)
    }

    @MainActor
    func testNoOpDoesNotWriteOrAdvanceRevision() async throws {
        var commits = 0
        let (store, _) = try makeStore(commit: { context in commits += 1; try context.save() })
        let revision = store.state.revision
        try store.mutate { $0.setUnlocked(false) }
        XCTAssertEqual(commits, 0); XCTAssertEqual(store.state.revision, revision)
    }

    @MainActor
    func testFailedYesterdayCannotBeSkippedBySuccessfulToday() async throws {
        let (store, _) = try makeStore()
        try store.mutate { $0.start(seed: 1, now: .now) }
        try store.mutate {
            $0.beginStepTracking(on: "2026-10-08", timeZone: "UTC")
            _ = $0.ingestSteps(dayKey: "2026-10-08", dailyTotal: 1_000)
        }
        let sync = StepSyncCoordinator()
        let reader = FakeStepReader()
        reader.missingDay = "2026-10-08"
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let now = DayKey.date(from: "2026-10-09", calendar: cal)!
        let before = store.state
        let failed = await sync.sync(store: store, reader: reader, now: now)
        XCTAssertNil(failed); XCTAssertEqual(store.state, before)
        reader.missingDay = nil
        let update = await sync.sync(store: store, reader: reader, now: now)
        XCTAssertEqual(update?.creditedSteps, 1_000)
        XCTAssertEqual(store.state.ledger.dayKey, "2026-10-09")
    }

    @MainActor
    func testConcurrentTriggersNeverOverlapQueriesOrDoubleCredit() async throws {
        let (store, _) = try makeStore()
        try store.mutate { $0.start(seed: 1, now: .now) }
        let sync = StepSyncCoordinator(); let reader = FakeStepReader()
        let first = Task { await sync.sync(store: store, reader: reader) }
        await Task.yield()
        let second = Task { await sync.sync(store: store, reader: reader) }
        _ = await first.value; _ = await second.value
        XCTAssertEqual(reader.maxActive, 1)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 1_000)
    }

    @MainActor
    func testPhoneRejectsOlderSnapshot() async throws {
        let (phone, _) = try makeStore(role: .phone)
        var state = GameState(); state.start(seed: 1, now: .now); state.advanceRevision()
        let old = try JSONEncoder().encode(state)
        state.ingestSteps(dayKey: "2026-10-09", dailyTotal: 1_000); state.advanceRevision()
        phone.applyMirror(try JSONEncoder().encode(state))
        phone.applyMirror(old)
        XCTAssertEqual(phone.state.revision, 2)
        XCTAssertEqual(phone.state.egg?.creditedSteps, 1_000)
    }

    @MainActor
    func testRotatingArchiveRecoversPreviousCopy() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = SaveArchive(name: "test", directory: directory)
        var state = GameState(); state.start(seed: 1, now: .now)
        try archive.save(JSONEncoder().encode(state))
        let previous = state
        state.ingestSteps(dayKey: "2026-10-09", dailyTotal: 1_000)
        try archive.save(JSONEncoder().encode(state))
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent("current.json"))
        XCTAssertEqual(archive.load(), previous)
    }

    @MainActor
    func testReloadKeepsRenameWithUnchangedStepAndHatchCounts() async throws {
        let (store, container) = try makeStore()
        try store.mutate { $0.start(seed: 1, now: .now); $0.ingestSteps(dayKey: "2026-10-09", dailyTotal: 2_000) }
        try store.mutate { try $0.hatch(now: .now) }
        try store.mutate { try $0.rename("mochi", to: "Midnight") }
        let reload = GameStore(container: container, role: .watch, onCommit: { _ in })
        XCTAssertEqual(reload.state.companion?.nickname, "Midnight")
        XCTAssertEqual(reload.state.revision, store.state.revision)
    }

    @MainActor
    func testRestoredCollectionBaselinesInsteadOfRecreditingToday() async throws {
        let (store, _) = try makeStore()
        var original = GameState(); original.start(seed: 1, now: .now)
        original.ingestSteps(dayKey: "2026-10-08", dailyTotal: 2_000)
        _ = try original.hatch(now: .now)
        try store.restore(CollectionBackup(state: original))
        let reader = FakeStepReader(); let sync = StepSyncCoordinator()
        let result = await sync.sync(store: store, reader: reader)
        XCTAssertEqual(result?.creditedSteps, 0)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 0)
        XCTAssertFalse(store.state.needsStepBaseline)
        XCTAssertEqual(store.state.collection.count, 1)
    }

    func testWidgetFreshnessAndRoutes() throws {
        let now = Date()
        let snapshot = ComplicationSnapshot(eggProgress: 0.5, eggStepsRemaining: 500, isEggReady: false, updatedAt: now)
        XCTAssertFalse(snapshot.isStale(at: now))
        XCTAssertTrue(snapshot.isStale(at: now.addingTimeInterval(7_201)))
        XCTAssertEqual(WatchRoute(url: snapshot.destination), .progress)
        XCTAssertEqual(WatchRoute(url: URL(string: "batwalk://hatch")!), .hatch)
        XCTAssertNil(WatchRoute(url: URL(string: "https://hatch")!))
        XCTAssertNil(WatchRoute(url: URL(string: "batwalk://hatch/unexpected")!))
        XCTAssertFalse(PhoneSync.usesFileTransfer(forByteCount: 50_000))
        XCTAssertTrue(PhoneSync.usesFileTransfer(forByteCount: 50_001))
    }

    @MainActor
    func testUnreadableSaveCannotBeOverwrittenWithFreshOnboarding() async throws {
        let (store, container) = try makeStore()
        let payload = Data("{}".utf8)
        container.mainContext.insert(SaveRecord(payload: payload, updatedAt: .now, writer: "watch"))
        try container.mainContext.save()
        store.load()
        XCTAssertTrue(store.recoveryRequired)
        XCTAssertThrowsError(try store.mutate { $0.start(seed: 1, now: .now) })
        let rows = try container.mainContext.fetch(FetchDescriptor<SaveRecord>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.payload, payload)
    }

    @MainActor
    func testFutureSchemaCannotBeOverwritten() async throws {
        let (store, container) = try makeStore()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(GameState())) as? [String: Any])
        json["schemaVersion"] = 999
        let payload = try JSONSerialization.data(withJSONObject: json)
        container.mainContext.insert(SaveRecord(payload: payload, updatedAt: .now, writer: "watch"))
        try container.mainContext.save(); store.load()
        XCTAssertTrue(store.recoveryRequired)
        XCTAssertThrowsError(try store.mutate { $0.start(seed: 1, now: .now) })
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SaveRecord>()).first?.payload, payload)
    }

    @MainActor
    func testExistingSingleStoreReopensWithSeparatedBackupConfiguration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        var original = GameState(); original.start(seed: 1, now: .now)
        original.ingestSteps(dayKey: "2026-10-09", dailyTotal: 1_250)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        for key in ["schemaVersion", "saveID", "revision", "needsStepBaseline"] { legacy.removeValue(forKey: key) }
        let payload = try JSONSerialization.data(withJSONObject: legacy)
        try autoreleasepool {
            let schema = Schema([SaveRecord.self])
            let container = try ModelContainer(for: schema,
                configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            container.mainContext.insert(SaveRecord(payload: payload, updatedAt: .now, writer: "watch"))
            try container.mainContext.save()
        }
        let container = Persistence.makeContainer(localURL: url)
        XCTAssertFalse(Persistence.storageUnavailable)
        let store = GameStore(container: container, role: .watch,
            archive: SaveArchive(name: "migration", directory: directory.appendingPathComponent("recovery")), onCommit: { _ in })
        XCTAssertTrue(store.state.hasStarted)
        XCTAssertEqual(store.state.egg?.creditedSteps, 1_250)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 1_250)
        try store.mutate { $0.setUnlocked(true) }
        let stored = try JSONDecoder().decode(GameState.self,
            from: XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SaveRecord>()).first?.payload))
        XCTAssertEqual(stored.schemaVersion, 2)
        XCTAssertEqual(stored.revision, 1)
        XCTAssertEqual(try url.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    @MainActor
    func testFreeCompanionsHaveDedicatedNormalAndShinyPoses() async throws {
        for species in ["cocoa", "long-ear"] {
            for mood in [BatMood.sleeping, .awake, .happy] {
                for shiny in [false, true] {
                    let art = try XCTUnwrap(SpriteResolver.bat(species, mood: mood, shiny: shiny))
                    XCTAssertEqual(art.name, SpriteName.bat(species, mood: mood, shiny: shiny))
                    XCTAssertEqual(art.hueDegrees, 0)
                }
            }
        }
    }
}

@MainActor
private final class FakeStepReader: StepTotalReader {
    var missingDay: String?
    var active = 0
    var maxActive = 0
    func totals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal] {
        active += 1; maxActive = max(maxActive, active)
        defer { active -= 1 }
        try await Task.sleep(for: .milliseconds(30))
        var day = start; var readings: [DailyStepTotal] = []
        while day < end {
            let key = DayKey.make(day, calendar: calendar)
            if key != missingDay { readings.append(DailyStepTotal(day: key, total: 1_000)) }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return readings
    }
}
