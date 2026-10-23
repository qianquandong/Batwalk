import XCTest
@testable import BatwalkCore

final class StepLedgerTests: XCTestCase {
    func testFirstReadingCreditsTodaysStepsImmediately() {
        var ledger = StepLedger()
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: 3_120), 3_120)
    }

    func testSameDayCreditsOnlyTheIncrease() {
        var ledger = StepLedger()
        ledger.ingest(dayKey: "2026-10-06", dailyTotal: 1_000)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: 1_450), 450)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: 1_450), 0)
    }

    func testTotalGoingDownCreditsNothingAndDoesNotDoubleCountLater() {
        var ledger = StepLedger()
        ledger.ingest(dayKey: "2026-10-06", dailyTotal: 2_000)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: 1_500), 0)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: 2_100), 100)
    }

    func testMidnightRolloverCapturesYesterdaysTailThenToday() {
        var ledger = StepLedger()
        ledger.ingest(dayKey: "2026-10-06", dailyTotal: 5_000)
        // App wakes after midnight: re-read yesterday's final total first.
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: 5_800), 800)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-07", dailyTotal: 300), 300)
        XCTAssertEqual(ledger.dayKey, "2026-10-07")
    }

    func testOlderDayReappearingCreditsNothing() {
        var ledger = StepLedger()
        ledger.ingest(dayKey: "2026-10-07", dailyTotal: 200)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: 9_000), 0)
        XCTAssertEqual(ledger.dayKey, "2026-10-07")
    }

    func testNegativeTotalsAreClamped() {
        var ledger = StepLedger()
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-06", dailyTotal: -5), 0)
    }

    func testDaysToSync() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 8))!
        let keys = { (days: [Date]) in days.map { DayKey.make($0, calendar: cal) } }

        XCTAssertEqual(keys(DayKey.daysToSync(lastKey: nil, now: now, calendar: cal)), ["2026-10-09"])
        XCTAssertEqual(keys(DayKey.daysToSync(lastKey: "2026-10-09", now: now, calendar: cal)), ["2026-10-09"])
        XCTAssertEqual(keys(DayKey.daysToSync(lastKey: "2026-10-07", now: now, calendar: cal)),
                       ["2026-10-07", "2026-10-08", "2026-10-09"])
        XCTAssertEqual(DayKey.daysToSync(lastKey: "2026-08-01", now: now, calendar: cal).count, 7)
        // Ledger ahead of the clock (time-zone travel): only today.
        XCTAssertEqual(keys(DayKey.daysToSync(lastKey: "2026-10-10", now: now, calendar: cal)), ["2026-10-09"])
    }

    func testDayKeyIsZeroPaddedAndCalendarAware() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        // 2026-03-08 07:30 UTC = 01:30 CST on DST-change day.
        let date = Date(timeIntervalSince1970: 1_772_955_000)
        XCTAssertEqual(DayKey.make(date, calendar: cal), "2026-03-08")
    }
}

final class GameStateTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func started() -> GameState {
        var s = GameState()
        s.start(seed: 42, now: t0)
        return s
    }

    func testOnboardingStartsStarterEgg() {
        let s = started()
        XCTAssertEqual(s.egg?.type, .starter)
        XCTAssertEqual(s.egg?.creditedSteps, 0)
        XCTAssertNil(s.companionID)
    }

    func testStartIsIdempotent() {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 500)
        s.start(seed: 99, now: t0)
        XCTAssertEqual(s.egg?.creditedSteps, 500)
    }

    func testZeroToThresholdHatchProgression() throws {
        var s = started()
        var u = s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 1_999)
        XCTAssertFalse(u.eggBecameReady)
        XCTAssertEqual(s.egg?.visualState, .rattling)
        XCTAssertThrowsError(try s.hatch(now: t0)) { XCTAssertEqual($0 as? GameError, .eggNotReady) }

        u = s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        XCTAssertTrue(u.eggBecameReady)
        XCTAssertEqual(s.egg?.visualState, .ready)

        let result = try s.hatch(now: t0)
        XCTAssertEqual(result.record.speciesID, "mochi")
        XCTAssertEqual(result.record.outcome, .newSpecies)
        XCTAssertEqual(s.companionID, "mochi")
        XCTAssertNil(s.egg)
        XCTAssertEqual(s.history.count, 1)
    }

    func testLargeJumpFillsEggAndBanksRemainderWithCap() throws {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 30_000)
        XCTAssertTrue(s.isEggReady)
        XCTAssertEqual(s.egg?.creditedSteps, 2_000)
        XCTAssertEqual(s.bankedSteps, Tuning.default.maxBankedSteps)
    }

    func testStepsWhileReadyAreBanked() {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_700)
        XCTAssertEqual(s.egg?.creditedSteps, 2_000)
        XCTAssertEqual(s.bankedSteps, 700)
    }

    func testBankedStepsApplyToNextEgg() throws {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 3_000)
        _ = try s.hatch(now: t0)
        let u = try s.startEgg(.tiny, seed: 7, now: t0)
        XCTAssertEqual(u.creditedSteps, 1_000)
        XCTAssertEqual(s.egg?.creditedSteps, 1_000)
        XCTAssertEqual(s.bankedSteps, 0)
    }

    func testCannotStartTwoEggsButAllFiveCanBeChosenAfterHatch() throws {
        var s = started()
        XCTAssertThrowsError(try s.startEgg(.tiny, seed: 1, now: t0)) {
            XCTAssertEqual($0 as? GameError, .eggAlreadyIncubating)
        }
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0)
        for egg in EggType.allCases {
            var next = s
            XCTAssertFalse(next.isUnlocked, "The saved legacy entitlement stays dormant")
            XCTAssertNoThrow(try next.startEgg(egg, seed: 1, now: t0))
            XCTAssertEqual(next.egg?.type, egg)
        }
    }

    func testDuplicateAddsFriendshipInsteadOfCopy() throws {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0) // Mochi
        // Find a Tiny seed that yields a non-shiny Mochi for a free player.
        let seed = (UInt64(0)..<10_000).first { HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: false).species.id == "mochi" }!
        try s.startEgg(.tiny, seed: seed, now: t0)
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: EggType.starter.targetSteps + EggType.tiny.targetSteps)
        let result = try s.hatch(now: t0)
        XCTAssertEqual(result.record.outcome, .duplicate)
        XCTAssertEqual(result.friendshipGained, Tuning.default.duplicateEXP[.common])
        XCTAssertEqual(s.collection.count, 1)
        XCTAssertEqual(s.collection["mochi"]?.hatchCount, 2)
        XCTAssertEqual(s.collection["mochi"]?.friendshipEXP, Tuning.default.duplicateEXP[.common])
    }

    func testShinyOfOwnedSpeciesSetsShinyFlagNotDuplicate() throws {
        var s = started()
        s.setUnlocked(true)
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0) // Normal Mochi
        let seed = (UInt64(0)..<2_000_000).first {
            let r = HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: true)
            return r.species.id == "mochi" && r.isShiny
        }!
        try s.startEgg(.tiny, seed: seed, now: t0)
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: EggType.starter.targetSteps + EggType.tiny.targetSteps)
        let result = try s.hatch(now: t0)
        XCTAssertEqual(result.record.outcome, .newShiny)
        XCTAssertEqual(s.collection["mochi"]?.hasNormal, true)
        XCTAssertEqual(s.collection["mochi"]?.hasShiny, true)
        XCTAssertEqual(s.collection["mochi"]?.friendshipEXP, 0)
    }

    func testPaidEggKeepsPaidPoolIfEntitlementLost() throws {
        var s = started()
        s.setUnlocked(true)
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0)
        try s.startEgg(.moon, seed: 3, now: t0)
        s.setUnlocked(false)
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: EggType.starter.targetSteps + EggType.moon.targetSteps)
        XCTAssertNoThrow(try s.hatch(now: t0)) // must not crash on an empty free pool
    }

    func testFruitFeedingAndNoPunishment() throws {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0)
        XCTAssertEqual(s.fruit, 1) // 2,000 steps / 1,500 per fruit
        XCTAssertEqual(try s.feed("mochi"), Tuning.default.feedEXP)
        XCTAssertEqual(s.fruit, 0)
        XCTAssertThrowsError(try s.feed("mochi")) { XCTAssertEqual($0 as? GameError, .noFruit) }
        // Friendship never decays: nothing in the API can lower EXP.
        XCTAssertEqual(s.collection["mochi"]?.friendshipEXP, Tuning.default.feedEXP)
    }

    func testFruitInventoryCaps() {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 100_000)
        XCTAssertEqual(s.fruit, Tuning.default.maxFruit)
    }

    func testPetEXPDailyCapResetsNextDay() throws {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0)
        let cap = Tuning.default.petEXPDailyCap
        for _ in 0..<cap { XCTAssertEqual(try s.pet("mochi", dayKey: "2026-10-06"), Tuning.default.petEXP) }
        XCTAssertEqual(try s.pet("mochi", dayKey: "2026-10-06"), 0)
        XCTAssertEqual(try s.pet("mochi", dayKey: "2026-10-07"), Tuning.default.petEXP)
    }

    func testRenameTrimsCapsAndResets() throws {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0)
        try s.rename("mochi", to: "  Luna  ")
        XCTAssertEqual(s.companion?.displayName, "Luna")
        try s.rename("mochi", to: String(repeating: "x", count: 40))
        XCTAssertEqual(s.companion?.nickname?.count, Tuning.default.maxNicknameLength)
        try s.rename("mochi", to: "   ")
        XCTAssertEqual(s.companion?.displayName, "Mochi Bat")
        XCTAssertThrowsError(try s.rename("galaxy", to: "Nope"))
    }

    func testSetCompanionRequiresOwnership() {
        var s = started()
        XCTAssertThrowsError(try s.setCompanion("eclipse")) { XCTAssertEqual($0 as? GameError, .notOwned("eclipse")) }
    }

    func testRicherSavePrefersMoreHatches() throws {
        let fresh = started()
        var played = started()
        played.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        XCTAssertTrue(played.isRicher(than: fresh))
        _ = try played.hatch(now: t0)
        var stepsOnly = started()
        stepsOnly.ingestSteps(dayKey: "2026-10-06", dailyTotal: 9_000)
        XCTAssertTrue(played.isRicher(than: stepsOnly))
        XCTAssertFalse(fresh.isRicher(than: fresh))
    }

    func testSaveRoundTripsThroughJSON() throws {
        var s = started()
        s.ingestSteps(dayKey: "2026-10-06", dailyTotal: 2_000)
        _ = try s.hatch(now: t0)
        try s.rename("mochi", to: "Luna")
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(decoded, s)
    }
}

final class PresentationTests: XCTestCase {
    func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func date(hour: Int) -> Date {
        cal().date(from: DateComponents(year: 2026, month: 10, day: 6, hour: hour, minute: 30))!
    }

    func testTimeOfDayWindows() {
        XCTAssertEqual(TimeOfDay.at(date(hour: 6), calendar: cal()), .night)
        XCTAssertEqual(TimeOfDay.at(date(hour: 7), calendar: cal()), .day)
        XCTAssertEqual(TimeOfDay.at(date(hour: 17), calendar: cal()), .day)
        XCTAssertEqual(TimeOfDay.at(date(hour: 18), calendar: cal()), .dusk)
        XCTAssertEqual(TimeOfDay.at(date(hour: 19), calendar: cal()), .night)
        XCTAssertEqual(TimeOfDay.at(date(hour: 0), calendar: cal()), .night)
    }

    func testEggVisualStates() {
        XCTAssertEqual(EggVisualState.forProgress(0), .calm)
        XCTAssertEqual(EggVisualState.forProgress(0.25), .shaking)
        XCTAssertEqual(EggVisualState.forProgress(0.5), .cracked)
        XCTAssertEqual(EggVisualState.forProgress(0.99), .rattling)
        XCTAssertEqual(EggVisualState.forProgress(1), .ready)
    }

    func testFriendshipLevels() {
        XCTAssertEqual(Friendship.level(forEXP: 0), 1)
        XCTAssertEqual(Friendship.level(forEXP: 99), 1)
        XCTAssertEqual(Friendship.level(forEXP: 100), 2)
        XCTAssertEqual(Friendship.level(forEXP: 999), 4)
        XCTAssertEqual(Friendship.level(forEXP: 50_000), 5)
        XCTAssertEqual(Friendship.progressToNext(exp: 175), 0.5, accuracy: 0.001)
        XCTAssertEqual(Friendship.progressToNext(exp: 5_000), 1)
    }

    func testFriendshipLevelProgressLabels() {
        XCTAssertEqual(Friendship.levelProgress(exp: 20).current, 20)
        XCTAssertEqual(Friendship.levelProgress(exp: 20).span, 100)
        XCTAssertEqual(Friendship.levelProgress(exp: 175).current, 75)
        XCTAssertEqual(Friendship.levelProgress(exp: 175).span, 150)
        XCTAssertEqual(Friendship.levelProgress(exp: 1_500).current, 500)
        XCTAssertNil(Friendship.levelProgress(exp: 1_500).span)
    }

    func testFavoriteFruitIsLoreOnly() {
        XCTAssertEqual(Roster.species("mochi")?.favoriteFruit, "Berry")
        XCTAssertNil(Roster.species("cocoa")?.favoriteFruit)
    }
}
