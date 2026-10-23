import XCTest
@testable import BatwalkCore

/// Collection pacing rules added after the 2026-10-10 review: Shiny pity and
/// max-Friendship boost, new-species pity, Moon Dust, the free trial egg,
/// sanity clamps and tolerant decoding.
final class EconomyTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let day = "2026-10-10"

    /// No luck involved: every randomised rule is switched off unless a test turns it on.
    private func quiet(shinyChance: Double = 0) -> Tuning {
        Tuning(shinyChance: shinyChance, shinyPityHatches: 0, maxFriendshipShinyMultiplier: 1, newSpeciesPityHatches: 0)
    }

    /// First seed whose base roll of `egg` yields `species`, like DemoMode does for screenshots.
    private func seed(for species: String, egg: EggType, isUnlocked: Bool = true) -> UInt64 {
        for candidate in UInt64(1)..<200_000 {
            let roll = HatchEngine.roll(egg: egg, seed: candidate, isUnlocked: isUnlocked, tuning: Tuning(shinyChance: 0))
            if roll.species.id == species { return candidate }
        }
        XCTFail("No seed rolls \(species) from \(egg)")
        return 1
    }

    private func walkAndHatch(_ s: inout GameState, _ egg: EggType, seed: UInt64, total: inout Int,
                              tuning: Tuning) throws -> HatchResult {
        try s.startEgg(egg, seed: seed, now: now, tuning: tuning)
        total += egg.targetSteps
        s.ingestSteps(dayKey: day, dailyTotal: total, tuning: tuning)
        return try s.hatch(now: now, tuning: tuning)
    }

    private func paidPlayer(tuning: Tuning, total: inout Int) throws -> GameState {
        var s = GameState()
        s.setUnlocked(true)
        s.start(seed: 1, now: now, tuning: tuning)
        total = 2_000
        s.ingestSteps(dayKey: day, dailyTotal: total, tuning: tuning)
        _ = try s.hatch(now: now, tuning: tuning) // Mochi, the starter
        return s
    }

    // MARK: Shiny

    func testShinyPityGuaranteesAShinyEveryNHatches() throws {
        var tuning = quiet()
        tuning.shinyPityHatches = 5
        var total = 0
        var s = try paidPlayer(tuning: tuning, total: &total)
        XCTAssertFalse(s.history[0].isShiny)
        var shinies: [Bool] = []
        for i in 0..<10 {
            shinies.append(try walkAndHatch(&s, .tiny, seed: UInt64(100 + i), total: &total, tuning: tuning).record.isShiny)
        }
        // Hatch 5 overall is forced Shiny, the counter resets, hatch 10 is the next.
        XCTAssertEqual(shinies, [false, false, false, true, false, false, false, false, true, false])
        XCTAssertEqual(s.hatchesSinceShiny, 1)
    }

    func testMaxFriendshipBatsRollShinyMoreOften() throws {
        var base = quiet(shinyChance: 0.05)
        base.maxFriendshipShinyMultiplier = 3
        var boosted = base
        boosted.friendshipThresholds = [0, 0, 0, 0, 0] // every owned bat counts as Lv.5

        func mochiShinyRate(_ tuning: Tuning) throws -> Double {
            var mochi = 0, shiny = 0
            for seed in UInt64(0)..<6_000 {
                var total = 0
                var s = try paidPlayer(tuning: tuning, total: &total)
                try s.startEgg(.tiny, seed: seed, now: now, tuning: tuning)
                guard s.egg?.frozenSpeciesID == "mochi" else { continue }
                mochi += 1
                if s.egg?.frozenIsShiny == true { shiny += 1 }
            }
            XCTAssertGreaterThan(mochi, 500)
            return Double(shiny) / Double(mochi)
        }
        XCTAssertEqual(try mochiShinyRate(base), 0.05, accuracy: 0.025)
        XCTAssertEqual(try mochiShinyRate(boosted), 0.15, accuracy: 0.04)
    }

    func testSealedOutcomeIsDeterministicWithPityRules() throws {
        var tuning = quiet(shinyChance: 0.03)
        tuning.shinyPityHatches = 40
        tuning.newSpeciesPityHatches = 10
        tuning.maxFriendshipShinyMultiplier = 3
        var a = GameState(); a.setUnlocked(true); a.start(seed: 7, now: now, tuning: tuning)
        var b = a
        a.ingestSteps(dayKey: day, dailyTotal: 2_000, tuning: tuning)
        b.ingestSteps(dayKey: day, dailyTotal: 2_000, tuning: tuning)
        _ = try a.hatch(now: now, tuning: tuning)
        _ = try b.hatch(now: now, tuning: tuning)
        try a.startEgg(.moon, seed: 99, now: now, tuning: tuning)
        try b.startEgg(.moon, seed: 99, now: now, tuning: tuning)
        XCTAssertEqual(a.egg, b.egg)
    }

    // MARK: New-species pity

    func testNewSpeciesPityTurnsALongDuplicateStreakIntoANewBat() throws {
        var tuning = quiet()
        tuning.newSpeciesPityHatches = 3
        var total = 0
        var s = try paidPlayer(tuning: tuning, total: &total)
        let mochiSeed = seed(for: "mochi", egg: .tiny)
        for _ in 0..<3 {
            try s.startEgg(.tiny, seed: mochiSeed, now: now, tuning: tuning)
            XCTAssertEqual(s.egg?.frozenSpeciesID, "mochi")
            total += EggType.tiny.targetSteps
            s.ingestSteps(dayKey: day, dailyTotal: total, tuning: tuning)
            XCTAssertEqual(try s.hatch(now: now, tuning: tuning).record.outcome, .duplicate)
        }
        XCTAssertEqual(s.hatchesSinceNewSpecies, 3)

        // The same seed would be Mochi again; pity seals an unmet Tiny species instead.
        try s.startEgg(.tiny, seed: mochiSeed, now: now, tuning: tuning)
        let sealed = try XCTUnwrap(s.egg?.frozenSpeciesID)
        XCTAssertNotEqual(sealed, "mochi")
        XCTAssertTrue(EggType.tiny.pool.contains(sealed))
        XCTAssertNil(s.collection[sealed])
        total += EggType.tiny.targetSteps
        s.ingestSteps(dayKey: day, dailyTotal: total, tuning: tuning)
        XCTAssertEqual(try s.hatch(now: now, tuning: tuning).record.outcome, .newSpecies)
        XCTAssertEqual(s.hatchesSinceNewSpecies, 0)
    }

    // MARK: Moon Dust

    func testDuplicatesOfAMaxFriendshipBatPayMoonDustThatCallsANewBat() throws {
        var tuning = quiet()
        tuning.moonDustPerMaxLevelDuplicate = 1
        tuning.moonDustForNewBat = 2
        tuning.friendshipThresholds = [0, 0, 0, 0, 0]
        var total = 0
        var s = try paidPlayer(tuning: tuning, total: &total)
        XCTAssertEqual(s.moonDust, 0)
        XCTAssertThrowsError(try s.callNewBat(seed: 1, now: now, tuning: tuning)) {
            XCTAssertEqual($0 as? GameError, .notEnoughMoonDust)
        }
        let mochiSeed = seed(for: "mochi", egg: .tiny)
        for _ in 0..<2 {
            let result = try walkAndHatch(&s, .tiny, seed: mochiSeed, total: &total, tuning: tuning)
            XCTAssertEqual(result.record.outcome, .duplicate)
            XCTAssertEqual(result.moonDustGained, 1)
        }
        XCTAssertEqual(s.moonDust, 2)
        XCTAssertTrue(s.canCallNewBat(tuning: tuning))

        let called = try s.callNewBat(seed: 9, now: now, tuning: tuning)
        XCTAssertNotEqual(called.record.speciesID, "mochi")
        XCTAssertEqual(called.record.outcome, .newSpecies)
        XCTAssertEqual(called.record.source, .moonDust)
        XCTAssertEqual(called.moonDustGained, 0)
        XCTAssertEqual(s.moonDust, 0)
        XCTAssertEqual(s.collection.count, 2)
        XCTAssertEqual(s.history.last?.source, .moonDust)
        XCTAssertTrue(s.collection[called.record.speciesID]?.hasNormal ?? false)
    }

    func testDuplicatesBelowMaxFriendshipStillPayEXPNotDust() throws {
        let tuning = quiet()
        var total = 0
        var s = try paidPlayer(tuning: tuning, total: &total)
        let result = try walkAndHatch(&s, .tiny, seed: seed(for: "mochi", egg: .tiny), total: &total, tuning: tuning)
        XCTAssertEqual(result.record.outcome, .duplicate)
        XCTAssertEqual(result.friendshipGained, tuning.duplicateEXP[.common])
        XCTAssertEqual(result.moonDustGained, 0)
        XCTAssertEqual(s.moonDust, 0)
    }

    // MARK: Free tier

    func testFreePlayerWhoMetEveryFreeBatGetsOneTrialEggAndCannotCallMore() throws {
        var tuning = quiet()
        tuning.moonDustForNewBat = 1
        tuning.moonDustPerMaxLevelDuplicate = 1 // exercise legacy balances/redemption
        tuning.friendshipThresholds = [0, 0, 0, 0, 0]
        var s = GameState()
        s.start(seed: 1, now: now, tuning: tuning)
        var total = 2_000
        s.ingestSteps(dayKey: day, dailyTotal: total, tuning: tuning)
        _ = try s.hatch(now: now, tuning: tuning)
        XCTAssertEqual(s.pickableEggs(tuning: tuning), [.tiny])
        XCTAssertNil(s.trialEgg(tuning: tuning))
        XCTAssertFalse(s.hasCompletedFreeRoster)
        XCTAssertThrowsError(try s.startEgg(.forest, seed: 1, now: now, tuning: tuning)) {
            XCTAssertEqual($0 as? GameError, .eggLocked(.forest))
        }

        for species in ["cocoa", "long-ear"] {
            let result = try walkAndHatch(&s, .tiny, seed: seed(for: species, egg: .tiny, isUnlocked: false),
                                          total: &total, tuning: tuning)
            XCTAssertEqual(result.record.speciesID, species)
        }
        XCTAssertTrue(s.hasCompletedFreeRoster)
        XCTAssertEqual(s.pickableEggs(tuning: tuning), [.tiny, .forest])
        XCTAssertEqual(s.trialEgg(tuning: tuning), .forest)
        XCTAssertThrowsError(try s.startEgg(.moon, seed: 1, now: now, tuning: tuning))

        // Dust never buys paid content: with every free bat met there is nothing left to call.
        let dup = try walkAndHatch(&s, .tiny, seed: seed(for: "mochi", egg: .tiny, isUnlocked: false),
                                   total: &total, tuning: tuning)
        XCTAssertEqual(dup.moonDustGained, 1)
        XCTAssertFalse(s.canCallNewBat(tuning: tuning))
        XCTAssertThrowsError(try s.callNewBat(seed: 1, now: now, tuning: tuning)) {
            XCTAssertEqual($0 as? GameError, .nothingToDiscover)
        }

        // The trial egg uses the paid Forest pool, exactly once, at the full step target.
        try s.startEgg(.forest, seed: 5, now: now, tuning: tuning)
        XCTAssertTrue(s.trialEggUsed)
        let sealed = try XCTUnwrap(s.egg?.frozenSpeciesID)
        XCTAssertTrue(EggType.forest.pool.contains(sealed))
        XCTAssertEqual(s.egg?.stepsRemaining, EggType.forest.targetSteps)
        total += EggType.forest.targetSteps
        s.ingestSteps(dayKey: day, dailyTotal: total, tuning: tuning)
        XCTAssertEqual(try s.hatch(now: now, tuning: tuning).record.eggType, .forest)
        XCTAssertEqual(s.pickableEggs(tuning: tuning), [.tiny])
        XCTAssertNil(s.trialEgg(tuning: tuning))
        XCTAssertThrowsError(try s.startEgg(.forest, seed: 6, now: now, tuning: tuning)) {
            XCTAssertEqual($0 as? GameError, .eggLocked(.forest))
        }
    }

    func testTrialEggCanBeDisabledByTuning() throws {
        var tuning = quiet()
        tuning.freeTrialEgg = nil
        var s = GameState()
        s.start(seed: 1, now: now, tuning: tuning)
        var total = 2_000
        s.ingestSteps(dayKey: day, dailyTotal: total, tuning: tuning)
        _ = try s.hatch(now: now, tuning: tuning)
        for species in ["cocoa", "long-ear"] {
            _ = try walkAndHatch(&s, .tiny, seed: seed(for: species, egg: .tiny, isUnlocked: false), total: &total, tuning: tuning)
        }
        XCTAssertTrue(s.hasCompletedFreeRoster)
        XCTAssertEqual(s.pickableEggs(tuning: tuning), [.tiny])
    }

    // MARK: Safety and compatibility

    func testAbsurdDailyTotalsAreClampedBeforeTheyReachRewards() {
        var s = GameState()
        s.start(seed: 1, now: now)
        let update = s.ingestSteps(dayKey: day, dailyTotal: 50_000_000)
        XCTAssertEqual(update.creditedSteps, Tuning.default.maxDailySteps)
        XCTAssertEqual(s.lifetimeCreditedSteps, Tuning.default.maxDailySteps)
        XCTAssertEqual(s.fruit, Tuning.default.maxFruit)
        XCTAssertEqual(s.bankedSteps, Tuning.default.maxBankedSteps)
        XCTAssertEqual(s.ingestSteps(dayKey: day, dailyTotal: 60_000_000).creditedSteps, 0)
    }

    func testRecordsAndBackupsWithoutNewKeysStillDecode() throws {
        let record = HatchRecord(speciesID: "mochi", isShiny: false, eggType: .tiny, hatchedAt: now, outcome: .duplicate)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        json.removeValue(forKey: "source")
        let decoded = try JSONDecoder().decode(HatchRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.source, .egg)
        XCTAssertEqual(decoded, record)

        var s = GameState(); s.setUnlocked(true); s.start(seed: 1, now: now)
        s.ingestSteps(dayKey: day, dailyTotal: 2_000)
        _ = try s.hatch(now: now)
        var backup = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(CollectionBackup(state: s))) as? [String: Any])
        for key in ["moonDust", "trialEggUsed"] { backup.removeValue(forKey: key) }
        let old = try JSONDecoder().decode(CollectionBackup.self, from: JSONSerialization.data(withJSONObject: backup))
        XCTAssertEqual(old.moonDust, 0)
        XCTAssertFalse(old.trialEggUsed)
        XCTAssertEqual(old.collection, s.collection)

        var saveJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as? [String: Any])
        for key in ["hatchesSinceShiny", "hatchesSinceNewSpecies", "moonDust", "trialEggUsed"] { saveJSON.removeValue(forKey: key) }
        let oldSave = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: saveJSON))
        XCTAssertEqual(oldSave.collection, s.collection)
        XCTAssertEqual(oldSave.moonDust, 0)
    }

    func testBackupContentComparisonIgnoresStepDerivedChurn() throws {
        var s = GameState(); s.setUnlocked(true); s.start(seed: 1, now: now)
        s.ingestSteps(dayKey: day, dailyTotal: 2_000)
        _ = try s.hatch(now: now)
        let before = CollectionBackup(state: s)
        s.ingestSteps(dayKey: day, dailyTotal: 5_000) // more steps, a fruit, a new revision
        s.advanceRevision()
        XCTAssertTrue(CollectionBackup(state: s).hasSameContent(as: before))
        try s.rename("mochi", to: "Luna")
        XCTAssertFalse(CollectionBackup(state: s).hasSameContent(as: before))
        XCTAssertEqual(before.trimmingHistory(to: 0).history, [])
        XCTAssertEqual(before.trimmingHistory(to: 5), before)
    }

    func testRestoreJumpsAheadOfAnyMirrorRevision() throws {
        var original = GameState(); original.start(seed: 1, now: now)
        original.ingestSteps(dayKey: day, dailyTotal: 2_000)
        _ = try original.hatch(now: now)
        for _ in 0..<480 { original.advanceRevision() }
        let backup = CollectionBackup(state: original)
        var mirror = original
        for _ in 0..<20 { mirror.advanceRevision() } // the phone saw revision 500 before the Watch was lost
        var restored = GameState()
        restored.restoreCollection(backup)
        XCTAssertEqual(restored.saveID, mirror.saveID)
        XCTAssertTrue(restored.isRicher(than: mirror))
        XCTAssertGreaterThanOrEqual(restored.revision, 1_480)
        XCTAssertEqual(restored.hatchesSinceShiny, 0)
    }

    func testReconciliationStartIsCappedForVeryLongAbsences() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let ledger = StepLedger(dayKey: "2026-01-01", lastDailyTotal: 300)
        let today = DayKey.date(from: "2026-10-09", calendar: cal)!
        XCTAssertEqual(DayKey.make(ledger.reconciliationStart(now: today, calendar: cal), calendar: cal), "2026-08-26")
        XCTAssertEqual(DayKey.make(ledger.reconciliationStart(now: today, calendar: cal, maxLookbackDays: 400), calendar: cal), "2026-01-01")
    }
}
