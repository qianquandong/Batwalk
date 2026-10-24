import XCTest
@testable import BatwalkCore

final class AnimationTestingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let day = "2026-10-24"

    func testAnimationTestingIntroStillRequiresOneCreditedStep() throws {
        var state = GameState()
        state.start(seed: 42, now: now, tuning: .animationTesting)
        XCTAssertEqual(state.egg?.targetSteps, 1)
        XCTAssertEqual(state.egg?.creditedSteps, 0)
        XCTAssertFalse(state.isEggReady)
        XCTAssertThrowsError(try state.hatch(now: now, tuning: .animationTesting)) {
            XCTAssertEqual($0 as? GameError, .eggNotReady)
        }

        let update = state.ingestSteps(dayKey: day, dailyTotal: 1, tuning: .animationTesting)
        XCTAssertEqual(update.creditedSteps, 1)
        XCTAssertTrue(update.eggBecameReady)
        XCTAssertEqual(state.lifetimeCreditedSteps, 1)
        XCTAssertEqual(state.fruit, 0)
        let hatch = try state.hatch(now: now, tuning: .animationTesting)
        XCTAssertEqual(hatch.record.speciesID, "mochi")
        XCTAssertEqual(hatch.record.eggSteps, 1)
        XCTAssertEqual(state.lifetimeHatchCount, 1)
    }

    func testAllFiveEggsUseOneStepWithoutManufacturingCredit() throws {
        var state = GameState()
        state.start(seed: 42, now: now, tuning: .animationTesting)
        state.ingestSteps(dayKey: day, dailyTotal: 1, tuning: .animationTesting)
        _ = try state.hatch(now: now, tuning: .animationTesting)
        var total = 1

        for type in EggType.allCases {
            let update = try state.startEgg(type, seed: UInt64(total), now: now, tuning: .animationTesting)
            XCTAssertEqual(state.egg?.type, type)
            XCTAssertEqual(state.egg?.targetSteps, 1)
            XCTAssertEqual(state.egg?.creditedSteps, 0)
            XCTAssertEqual(update.creditedSteps, 0)
            XCTAssertFalse(state.isEggReady)
            // Repeating the same Health total cannot make the next egg ready.
            XCTAssertEqual(state.ingestSteps(dayKey: day, dailyTotal: total).creditedSteps, 0)
            XCTAssertFalse(state.isEggReady)
            total += 1
            XCTAssertTrue(state.ingestSteps(dayKey: day, dailyTotal: total).eggBecameReady)
            XCTAssertEqual(try state.hatch(now: now).record.eggSteps, 1)
        }
        XCTAssertEqual(state.lifetimeCreditedSteps, 6)
        XCTAssertEqual(state.lifetimeHatchCount, 6)
    }

    func testDefaultAndNewNormalEggTargetsAreUnchanged() throws {
        XCTAssertNil(Tuning.default.eggTargetStepsOverride)
        XCTAssertEqual(Tuning.default.targetSteps(for: .starter, isIntro: true), 2_000)
        XCTAssertEqual(EggType.allCases.map { Tuning.default.targetSteps(for: $0) },
                       [10_000, 10_000, 21_097, 42_195, 100_000])

        var state = GameState()
        state.start(seed: 42, now: now)
        XCTAssertEqual(state.egg?.targetSteps, 2_000)
        state.ingestSteps(dayKey: day, dailyTotal: 2_000)
        _ = try state.hatch(now: now)
        for (type, target) in zip(EggType.allCases, [10_000, 10_000, 21_097, 42_195, 100_000]) {
            var next = state
            try next.startEgg(type, seed: 42, now: now)
            XCTAssertEqual(next.egg?.targetSteps, target)
        }

        var expectedTestTuning = Tuning.default
        expectedTestTuning.eggTargetStepsOverride = 1
        XCTAssertEqual(Tuning.animationTesting, expectedTestTuning,
                       "The test preset must not alter odds, rewards, or accounting rules")
    }

    func testExistingEggOverrideChangesOnlyItsTargetAndPreservesSealedOutcome() throws {
        // Check both an incubating egg and a ready egg with nonzero banked steps.
        for total in [750, 2_500] {
            var state = GameState()
            state.start(seed: 42, now: now)
            state.beginStepTracking(on: day, timeZone: "UTC")
            state.ingestSteps(dayKey: day, dailyTotal: total)
            let before = state
            let originalEgg = try XCTUnwrap(state.egg)
            XCTAssertEqual(before.isEggReady, total >= Tuning.introEggTargetSteps)

            XCTAssertTrue(state.applyEggTargetOverride(using: .animationTesting))
            XCTAssertEqual(state.egg?.targetSteps, 1)
            XCTAssertTrue(state.isEggReady)
            XCTAssertEqual(state.egg?.stepsRemaining, 0)
            // Whole-save comparison catches accidental changes to credits,
            // bank, ledger watermarks, save identity, rewards, and sealed result.
            var expected = try object(before)
            var egg = try XCTUnwrap(expected["egg"] as? [String: Any])
            egg["frozenTargetSteps"] = 1
            expected["egg"] = egg
            XCTAssertEqual(NSDictionary(dictionary: try object(state)), NSDictionary(dictionary: expected))

            let overridden = state
            XCTAssertFalse(state.applyEggTargetOverride(using: .animationTesting))
            XCTAssertEqual(state, overridden)
            let result = try state.hatch(now: now)
            XCTAssertEqual(result.record.speciesID, originalEgg.frozenSpeciesID)
            XCTAssertEqual(result.record.isShiny, originalEgg.frozenIsShiny)
            XCTAssertEqual(result.record.eggStartedAt, originalEgg.startedAt)
        }
    }

    func testOverrideWithNoEggOrNoCreditCannotCreateProgress() throws {
        var state = GameState()
        let empty = state
        XCTAssertFalse(state.applyEggTargetOverride(using: .animationTesting))
        XCTAssertEqual(state, empty)

        state.start(seed: 42, now: now)
        XCTAssertTrue(state.applyEggTargetOverride(using: .animationTesting))
        XCTAssertEqual(state.egg?.creditedSteps, 0)
        XCTAssertEqual(state.lifetimeCreditedSteps, 0)
        XCTAssertEqual(state.bankedSteps, 0)
        XCTAssertFalse(state.isEggReady)
        XCTAssertThrowsError(try state.hatch(now: now)) {
            XCTAssertEqual($0 as? GameError, .eggNotReady)
        }
    }

    func testNoOverrideIsANoopAndSavedOneStepTargetSurvivesDecoding() throws {
        var state = GameState()
        state.start(seed: 42, now: now)
        state.ingestSteps(dayKey: day, dailyTotal: 750)
        let original = state
        XCTAssertFalse(state.applyEggTargetOverride(using: .default))
        XCTAssertEqual(state, original)
        state.applyEggTargetOverride(using: .animationTesting)
        let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored, state)
        XCTAssertEqual(restored.egg?.targetSteps, 1)
        XCTAssertTrue(restored.isEggReady)
        XCTAssertFalse(state.applyEggTargetOverride(using: .default))
        XCTAssertEqual(state, restored, "Normal configuration preserves the egg's saved target")
    }

    func testOverrideClampsToPositiveOnInitializationAndMutation() {
        for input in [Int.min, -1, 0, 1] {
            let tuning = Tuning(eggTargetStepsOverride: input)
            XCTAssertEqual(tuning.eggTargetStepsOverride, 1)
            XCTAssertEqual(tuning.targetSteps(for: .starter, isIntro: true), 1)
            XCTAssertEqual(tuning.targetSteps(for: .crystal), 1)
        }
        var tuning = Tuning(eggTargetStepsOverride: 7)
        XCTAssertEqual(tuning.targetSteps(for: .moon), 7)
        tuning.eggTargetStepsOverride = -50
        XCTAssertEqual(tuning.eggTargetStepsOverride, 1)
        tuning.eggTargetStepsOverride = nil
        XCTAssertEqual(tuning, .default)
    }

    private func object(_ state: GameState) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    }
}
