import XCTest
import BatwalkCore
@testable import Batwalk

final class WatchOnboardingTests: XCTestCase {
    @MainActor
    func testIntroductionPersistsBeforeTheGameHasASavedIdentity() throws {
        try withDefaults { defaults in
            let firstLaunch = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: firstLaunch)
            XCTAssertFalse(guide.introductionSeen)
            guide.finishIntroduction()

            let nextLaunch = GameState()
            XCTAssertNotEqual(firstLaunch.saveID, nextLaunch.saveID)
            let reopened = WatchOnboarding(defaults: defaults)
            reopened.prepare(for: nextLaunch)
            XCTAssertTrue(reopened.introductionSeen)
            XCTAssertEqual(reopened.phase, .waitingForFirstHatch)
            XCTAssertFalse(nextLaunch.hasStarted)
            XCTAssertNil(nextLaunch.egg)
        }
    }

    @MainActor
    func testExistingUnhatchedAndHatchedSavesDoNotReplayTheGuide() throws {
        try withDefaults { defaults in
            var state = GameState()
            state.start(seed: 1, now: .now)
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            XCTAssertEqual(guide.phase, .complete)
            XCTAssertTrue(guide.introductionSeen)
            XCTAssertTrue(guide.eggHintSeen)
            XCTAssertTrue(guide.hatchHintSeen)
            hatchFirst(&state)
            guide.didHatchFirstCompanion()
            guide.reconcile(with: state)
            XCTAssertEqual(guide.phase, .complete)
        }
        try withDefaults { defaults in
            var state = GameState()
            state.start(seed: 1, now: .now)
            hatchFirst(&state)
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            XCTAssertEqual(guide.phase, .complete)
        }
    }

    @MainActor
    func testSavedFirstHatchRecoversWithoutHatchingOrRewardingAgain() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            guide.finishIntroduction()
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state)
            // Terminate after GameStore saved the hatch, before the UI callback.
            let committed = state
            let reopened = WatchOnboarding(defaults: defaults)
            reopened.prepare(for: state)
            XCTAssertEqual(reopened.phase, .greeting)
            XCTAssertTrue(reopened.hatchHintSeen)
            reopened.reconcile(with: state)
            XCTAssertEqual(reopened.phase, .greeting)
            XCTAssertEqual(state, committed)
            XCTAssertNil(state.egg)
            XCTAssertEqual(state.lifetimeHatchCount, 1)
        }
    }

    @MainActor
    func testHintsAndOutOfOrderCallbacksCannotCompleteInteraction() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            guide.didViewEgg()
            guide.didFinishHatchHelp()
            guide.didPet(hasFruit: true)
            guide.didFeed()
            guide.didChooseEgg()
            XCTAssertEqual(guide.phase, .waitingForFirstHatch)
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state)
            guide.didHatchFirstCompanion()
            guide.didViewEgg()
            guide.didFeed()
            guide.didChooseEgg()
            XCTAssertEqual(guide.phase, .greeting)
            XCTAssertTrue(guide.eggHintSeen)
            XCTAssertTrue(guide.hatchHintSeen)
        }
    }

    @MainActor
    func testPetAndFeedCompleteOnlyTheirOwnStepAndSurviveReopening() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state)
            guide.didHatchFirstCompanion()
            XCTAssertGreaterThan(state.fruit, 0)
            _ = try state.pet("mochi", dayKey: "2026-10-24")
            guide.didPet(hasFruit: state.fruit > 0)
            XCTAssertEqual(guide.phase, .feeding)

            let reopened = WatchOnboarding(defaults: defaults)
            reopened.prepare(for: state)
            XCTAssertEqual(reopened.phase, .feeding)
            _ = try state.feed("mochi")
            reopened.didFeed()
            XCTAssertEqual(reopened.phase, .nextEgg)
            reopened.didPet(hasFruit: true)
            XCTAssertEqual(reopened.phase, .nextEgg)
        }
    }

    @MainActor
    func testZeroFruitNeverBlocksTheGuide() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state, tuning: Tuning(stepsPerFruit: 10_000))
            guide.didHatchFirstCompanion()
            XCTAssertEqual(state.fruit, 0)
            guide.didPet(hasFruit: false)
            XCTAssertEqual(guide.phase, .nextEgg)
            guide.deferNextEgg()
            XCTAssertEqual(guide.phase, .complete)
            let before = state
            guide.reconcile(with: state)
            XCTAssertEqual(state, before)
        }
    }

    @MainActor
    func testInterruptedFeedWithNoFruitAdvancesToNextEgg() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state, tuning: Tuning(stepsPerFruit: Tuning.introEggTargetSteps))
            guide.didHatchFirstCompanion()
            guide.didPet(hasFruit: true)
            XCTAssertEqual(state.fruit, 1)
            _ = try state.feed("mochi")
            let reopened = WatchOnboarding(defaults: defaults)
            reopened.prepare(for: state)
            XCTAssertEqual(reopened.phase, .nextEgg)
        }
    }

    @MainActor
    func testNextEggSavedBeforeCallbackFinishesGuideOnReopen() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state)
            guide.didHatchFirstCompanion()
            guide.skipInteraction()
            XCTAssertEqual(guide.phase, .nextEgg)
            try state.startEgg(.forest, seed: 42, now: .now)
            let before = state
            let reopened = WatchOnboarding(defaults: defaults)
            reopened.prepare(for: state)
            XCTAssertEqual(reopened.phase, .complete)
            XCTAssertEqual(state, before)
        }
    }

    @MainActor
    func testSkippedHintsStayClosedAndHelpOnlyReplaysRelevantActions() throws {
        try withDefaults { defaults in
            var state = GameState()
            state.start(seed: 1, now: .now)
            hatchFirst(&state)
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            guide.replay(for: state)
            XCTAssertEqual(guide.phase, .greeting)
            XCTAssertTrue(guide.introductionSeen)
            guide.skipInteraction()
            guide.deferNextEgg()
            let reopened = WatchOnboarding(defaults: defaults)
            reopened.prepare(for: state)
            XCTAssertEqual(reopened.phase, .complete)
            let before = state
            reopened.replay(for: state)
            XCTAssertEqual(reopened.phase, .greeting)
            XCTAssertFalse(reopened.eggHintSeen)
            XCTAssertEqual(state, before)
        }
    }

    @MainActor
    func testRestoringAnotherCollectionDiscardsTheOldTutorialPhase() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state)
            guide.didHatchFirstCompanion()
            var restored = GameState()
            restored.start(seed: 2, now: .now)
            hatchFirst(&restored)
            state.restoreCollection(CollectionBackup(state: restored))
            let before = state
            guide.reconcile(with: state)
            XCTAssertEqual(guide.phase, .complete)
            XCTAssertEqual(state, before)
        }
    }

    @MainActor
    func testRestoreDuringIntroductionSkipsTheFirstHatchGuide() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            guide.finishIntroduction()
            var previous = GameState()
            previous.start(seed: 1, now: .now)
            hatchFirst(&previous)
            state.restoreCollection(CollectionBackup(state: previous))
            guide.reconcile(with: state)
            XCTAssertEqual(guide.phase, .complete)
        }
    }

    @MainActor
    func testRestoringTheSameSaveDoesNotResumeAStaleInteractionHint() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            state.start(seed: 1, now: .now)
            guide.reconcile(with: state)
            hatchFirst(&state)
            guide.didHatchFirstCompanion()
            let sameID = state.saveID
            state.restoreCollection(CollectionBackup(state: state))
            XCTAssertEqual(state.saveID, sameID)
            guide.reconcile(with: state)
            XCTAssertEqual(guide.phase, .complete)
        }
    }

    @MainActor
    func testDirectHatchKeepsEggNavigationTipUntilVisitedOrDismissed() throws {
        try withDefaults { defaults in
            var state = GameState()
            let guide = WatchOnboarding(defaults: defaults)
            guide.prepare(for: state)
            state.start(seed: 1, now: .now)
            hatchFirst(&state)
            guide.reconcile(with: state)
            guide.skipInteraction()
            try state.startEgg(.tiny, seed: 2, now: .now)
            guide.didChooseEgg()
            guide.reconcile(with: state)
            XCTAssertEqual(guide.phase, .complete)
            XCTAssertFalse(guide.eggHintSeen)
            let reopened = WatchOnboarding(defaults: defaults)
            reopened.prepare(for: state)
            XCTAssertFalse(reopened.eggHintSeen)
            reopened.dismissEggHint()
            let dismissed = WatchOnboarding(defaults: defaults)
            dismissed.prepare(for: state)
            XCTAssertTrue(dismissed.eggHintSeen)
            dismissed.replay(for: state)
            XCTAssertFalse(dismissed.eggHintSeen)
            dismissed.didViewEgg()
            XCTAssertTrue(dismissed.eggHintSeen)
        }
    }

    @MainActor
    func testPreviewStateIsIsolatedFromInventedGameProgress() {
        let guide = WatchOnboarding.preview(phase: .feeding, eggHintSeen: false)
        let state = GameState()
        guide.prepare(for: state)
        guide.reconcile(with: state)
        XCTAssertEqual(guide.phase, .feeding)
        XCTAssertTrue(guide.introductionSeen)
        XCTAssertFalse(guide.eggHintSeen)
        guide.didFeed()
        XCTAssertEqual(guide.phase, .nextEgg)
    }

    @MainActor
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "BatwalkTests.WatchOnboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    private func hatchFirst(_ state: inout GameState, tuning: Tuning = .default,
                            file: StaticString = #filePath, line: UInt = #line) {
        state.ingestSteps(dayKey: "2026-10-24", dailyTotal: Tuning.introEggTargetSteps, tuning: tuning)
        do { _ = try state.hatch(now: .now, tuning: tuning) }
        catch { XCTFail("First hatch fixture failed: \(error)", file: file, line: line) }
    }
}
