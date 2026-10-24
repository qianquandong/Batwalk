import XCTest
import SwiftData
import BatwalkCore
@testable import Batwalk

final class AnimationTestingStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @MainActor
    func testReviewBuildConvertsSavedEggOnceAndPersistsBeforePublishing() throws {
        var original = GameState()
        original.start(seed: 42, now: now)
        original.ingestSteps(dayKey: "2026-10-24", dailyTotal: 750)
        let (container, archive) = try fixture(saved: original)
        var published: [GameState] = []
        let store = GameStore(container: container, role: .watch, archive: archive,
                              tuning: .animationTesting, onCommit: { data in
            if let snapshot = try? JSONDecoder().decode(GameState.self, from: data) {
                published.append(snapshot)
            }
        })

        var expected = original
        expected.applyEggTargetOverride(using: .animationTesting)
        expected.advanceRevision()
        XCTAssertEqual(store.state, expected)
        XCTAssertEqual(try persisted(in: container), expected)
        XCTAssertEqual(archive.load(), expected)
        XCTAssertEqual(published, [expected])
        XCTAssertTrue(store.state.isEggReady)
        store.load()
        XCTAssertEqual(store.state, expected)
        XCTAssertEqual(published.count, 1, "Repeated load must not rewrite or republish the same target")

        let reopened = GameStore(container: container, role: .watch, archive: archive,
                                 tuning: .animationTesting, onCommit: { _ in XCTFail("No new mutation on restart") })
        XCTAssertEqual(reopened.state, expected)
        XCTAssertEqual(reopened.state.egg?.frozenSpeciesID, original.egg?.frozenSpeciesID)
        XCTAssertEqual(reopened.state.egg?.frozenIsShiny, original.egg?.frozenIsShiny)
        XCTAssertEqual(reopened.state.egg?.seed, original.egg?.seed)
    }

    @MainActor
    func testFailedUpgradeCommitLeavesSavedEggAndArchiveUnchangedUntilRetry() throws {
        enum Failure: Error { case disk }
        var original = GameState()
        original.start(seed: 42, now: now)
        original.ingestSteps(dayKey: "2026-10-24", dailyTotal: 750)
        let (container, archive) = try fixture(saved: original)
        var fail = true
        var published = 0
        let store = GameStore(container: container, role: .watch, archive: archive,
                              tuning: .animationTesting, commit: { context in
            if fail { throw Failure.disk }
            try context.save()
        }, onCommit: { _ in published += 1 })

        XCTAssertEqual(store.state, original)
        XCTAssertEqual(try persisted(in: container), original)
        XCTAssertEqual(archive.load(), original)
        XCTAssertEqual(published, 0)
        XCTAssertNotNil(store.lastError)
        XCTAssertFalse(store.recoveryRequired)
        XCTAssertFalse(store.state.isEggReady)

        fail = false
        store.load()
        XCTAssertEqual(store.state.egg?.targetSteps, 1)
        XCTAssertEqual(store.state.egg?.creditedSteps, 750)
        XCTAssertEqual(store.state.saveID, original.saveID)
        XCTAssertEqual(store.state.revision, original.revision + 1)
        XCTAssertTrue(store.state.isEggReady)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(published, 1)
        XCTAssertEqual(try persisted(in: container), store.state)
    }

    @MainActor
    func testNormalStoreKeepsNormalIntroAndNextEggTargets() throws {
        let (container, archive) = try fixture()
        let store = GameStore(container: container, role: .watch, archive: archive,
                              tuning: .default, onCommit: { _ in })
        XCTAssertFalse(store.state.hasStarted)
        try store.mutate { $0.start(seed: 42, now: now, tuning: store.tuning) }
        XCTAssertEqual(store.state.egg?.targetSteps, 2_000)
        try store.mutate { $0.ingestSteps(dayKey: "2026-10-24", dailyTotal: 2_000) }
        try store.mutate { try $0.hatch(now: now) }
        try store.mutate { try $0.startEgg(.moon, seed: 7, now: now, tuning: store.tuning) }
        XCTAssertEqual(store.state.egg?.targetSteps, 42_195)
        XCTAssertEqual(store.state.egg?.creditedSteps, 0)
        let saved = store.state
        store.load()
        XCTAssertEqual(store.state, saved)
    }

    @MainActor
    func testStepSetupUsesSelectedTuningButStillRequiresRealPositiveReading() async throws {
        let (container, archive) = try fixture()
        let store = GameStore(container: container, role: .watch, archive: archive,
                              tuning: .animationTesting, onCommit: { _ in })
        let reader = AnimationTestStepReader(total: 0)
        let setup = StepSetupCoordinator(sync: StepSyncCoordinator())
        await setup.connect(store: store, reader: reader, requestAuthorization: { true }, now: now)
        XCTAssertEqual(setup.status, .noSteps)
        XCTAssertFalse(store.state.hasStarted)
        XCTAssertNil(store.state.egg)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 0)

        reader.total = 1
        await setup.connect(store: store, reader: reader, now: now)
        XCTAssertEqual(setup.status, .ready)
        XCTAssertEqual(store.state.egg?.targetSteps, 1)
        XCTAssertEqual(store.state.egg?.creditedSteps, 1)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 1)
        XCTAssertTrue(store.state.isEggReady)
        let saved = store.state
        await setup.connect(store: store, reader: reader, now: now)
        XCTAssertEqual(store.state, saved, "Retrying the same reading must not create steps or a new egg")
    }

    @MainActor
    func testNextEggConsumesOnlyOneAlreadyBankedStep() throws {
        var original = GameState()
        original.start(seed: 42, now: now)
        original.ingestSteps(dayKey: "2026-10-24", dailyTotal: 5_000)
        XCTAssertEqual(original.bankedSteps, 3_000)
        let (container, archive) = try fixture(saved: original)
        let store = GameStore(container: container, role: .watch, archive: archive,
                              tuning: .animationTesting, onCommit: { _ in })
        XCTAssertEqual(store.state.bankedSteps, 3_000)
        try store.mutate { try $0.hatch(now: now) }
        let update = try store.mutate { try $0.startEgg(.moon, seed: 7, now: now, tuning: store.tuning) }
        XCTAssertEqual(update.creditedSteps, 1)
        XCTAssertTrue(update.eggBecameReady)
        XCTAssertEqual(store.state.egg?.targetSteps, 1)
        XCTAssertEqual(store.state.egg?.creditedSteps, 1)
        XCTAssertEqual(store.state.bankedSteps, 2_999)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 5_000)
        XCTAssertEqual(store.state.ledger, original.ledger)
    }

    @MainActor
    private func fixture(saved: GameState? = nil) throws -> (ModelContainer, SaveArchive) {
        let schema = Schema([SaveRecord.self, CollectionBackupRecord.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        container.mainContext.autosaveEnabled = false
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let archive = SaveArchive(name: "animation-testing", directory: directory)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        if let saved {
            let data = try JSONEncoder().encode(saved)
            container.mainContext.insert(SaveRecord(payload: data, updatedAt: now, writer: "watch"))
            try container.mainContext.save()
            try archive.save(data)
        }
        return (container, archive)
    }

    @MainActor
    private func persisted(in container: ModelContainer) throws -> GameState {
        let rows = try container.mainContext.fetch(FetchDescriptor<SaveRecord>())
        XCTAssertEqual(rows.count, 1)
        return try JSONDecoder().decode(GameState.self, from: XCTUnwrap(rows.first?.payload))
    }
}

@MainActor
private final class AnimationTestStepReader: StepTotalReader {
    var total: Int
    init(total: Int) { self.total = total }
    func totals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal] {
        var day = start
        var readings: [DailyStepTotal] = []
        while day < end {
            readings.append(DailyStepTotal(day: DayKey.make(day, calendar: calendar), total: total))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return readings
    }
}
