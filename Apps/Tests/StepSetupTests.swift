import XCTest
import BatwalkCore
@testable import Batwalk

extension AppReliabilityTests {
    @MainActor
    func testStepSetupDismissalDoesNotCreateAnEggOrReadHealth() async throws {
        let (store, _) = try makeStore()
        let before = store.state
        let reader = SetupStepReader(total: 1_250)
        let setup = StepSetupCoordinator(sync: StepSyncCoordinator())
        await setup.connect(store: store, reader: reader, requestAuthorization: { false })
        XCTAssertEqual(setup.status, .requestFailed)
        XCTAssertEqual(reader.calls, 0)
        XCTAssertEqual(store.state, before)
    }

    @MainActor
    func testCompletedPermissionSheetWithZeroStepsDoesNotStartGame() async throws {
        let (store, _) = try makeStore()
        let before = store.state
        let setup = StepSetupCoordinator(sync: StepSyncCoordinator())
        await setup.connect(store: store, reader: SetupStepReader(total: 0), requestAuthorization: { true })
        XCTAssertEqual(setup.status, .noSteps) // Not "denied": HealthKit hides that distinction.
        XCTAssertEqual(store.state, before)
        XCTAssertTrue(StepSetupCoordinator.needsSetup(for: store.state))
    }

    @MainActor
    func testStepSetupQueryFailureDoesNotStartGame() async throws {
        let (store, _) = try makeStore()
        let before = store.state
        let reader = SetupStepReader(total: 1_250)
        reader.fails = true
        let setup = StepSetupCoordinator(sync: StepSyncCoordinator())
        await setup.connect(store: store, reader: reader, requestAuthorization: { true })
        XCTAssertEqual(setup.status, .readFailed)
        XCTAssertEqual(store.state, before)
    }

    @MainActor
    func testStepsArrivingAfterSetupStartAndCreditOnlyOnce() async throws {
        let (store, _) = try makeStore()
        let reader = SetupStepReader(total: 0)
        let setup = StepSetupCoordinator(sync: StepSyncCoordinator())
        let now = Date()
        await setup.connect(store: store, reader: reader, requestAuthorization: { true }, now: now)
        XCTAssertFalse(store.state.hasStarted)
        reader.total = 1_250
        // Returning from Settings only rechecks; it does not require a new prompt.
        await setup.connect(store: store, reader: reader, now: now)
        XCTAssertEqual(setup.status, .ready)
        XCTAssertEqual(store.state.egg?.creditedSteps, 1_250)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 1_250)
        XCTAssertFalse(StepSetupCoordinator.needsSetup(for: store.state))
        let first = store.state
        await setup.connect(store: store, reader: reader, now: now)
        XCTAssertEqual(store.state, first)
    }

    @MainActor
    func testLegacyZeroStepSaveRecoversWithoutReplacingTheEgg() async throws {
        let (store, _) = try makeStore()
        let now = Date()
        try store.mutate { $0.start(seed: 42, now: now) }
        var expected = store.state
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let key = DayKey.make(now, calendar: calendar)
        expected.beginStepTracking(on: key, timeZone: calendar.timeZone.identifier)
        expected.ingestSteps(dayKey: key, dailyTotal: 750)
        let setup = StepSetupCoordinator(sync: StepSyncCoordinator())
        await setup.connect(store: store, reader: SetupStepReader(total: 750), now: now)
        XCTAssertEqual(setup.status, .ready)
        XCTAssertEqual(store.state.saveID, expected.saveID)
        XCTAssertEqual(store.state.egg, expected.egg)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 750)
    }

    @MainActor
    func testEstablishedPlayerCanEnterOnAZeroStepDay() async throws {
        var state = GameState()
        state.start(seed: 1, now: .now)
        state.ingestSteps(dayKey: "2026-10-21", dailyTotal: 750)
        state.ingestSteps(dayKey: "2026-10-22", dailyTotal: 0)
        XCTAssertFalse(StepSetupCoordinator.needsSetup(for: state))
        state.establishStepBaseline(day: "2026-10-22", total: 800, timeZone: "UTC")
        XCTAssertFalse(StepSetupCoordinator.needsSetup(for: state))
    }

    @MainActor
    func testConcurrentStepSetupCannotStartTwoEggs() async throws {
        let (store, _) = try makeStore()
        let reader = SetupStepReader(total: 1_250)
        let setup = StepSetupCoordinator(sync: StepSyncCoordinator())
        var prompts = 0
        let first = Task {
            await setup.connect(store: store, reader: reader, requestAuthorization: {
                prompts += 1
                try? await Task.sleep(for: .milliseconds(30))
                return true
            })
        }
        await Task.yield()
        let second = Task {
            await setup.connect(store: store, reader: reader, requestAuthorization: {
                prompts += 1
                return true
            })
        }
        await first.value
        await second.value
        XCTAssertEqual(prompts, 1)
        XCTAssertEqual(store.state.lifetimeCreditedSteps, 1_250)
        XCTAssertEqual(setup.status, .ready)
    }
}

@MainActor
private final class SetupStepReader: StepTotalReader {
    var total: Int
    var fails = false
    var calls = 0
    init(total: Int) { self.total = total }
    func totals(from start: Date, through end: Date, calendar: Calendar) async throws -> [DailyStepTotal] {
        calls += 1
        if fails { throw Failure.unavailable }
        var day = start
        var readings: [DailyStepTotal] = []
        while day < end {
            readings.append(DailyStepTotal(day: DayKey.make(day, calendar: calendar), total: total))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return readings
    }
    enum Failure: Error { case unavailable }
}
