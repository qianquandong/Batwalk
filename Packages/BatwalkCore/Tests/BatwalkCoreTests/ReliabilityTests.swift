import XCTest
@testable import BatwalkCore

final class ReliabilityTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testLateYesterdayStepsAreCreditedOnceAfterToday() {
        var ledger = StepLedger()
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-08", dailyTotal: 1_000), 1_000)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-09", dailyTotal: 200), 200)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-08", dailyTotal: 1_250), 250)
        XCTAssertEqual(ledger.ingest(dayKey: "2026-10-08", dailyTotal: 1_250), 0)
        XCTAssertEqual(ledger.dayKey, "2026-10-09")
        XCTAssertEqual(ledger.lastDailyTotal, 200)
    }

    func testLongAbsenceStartsAtCheckpointWithoutSevenDayLoss() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let ledger = StepLedger(dayKey: "2026-09-01", lastDailyTotal: 300)
        let today = DayKey.date(from: "2026-10-09", calendar: cal)!
        XCTAssertEqual(DayKey.make(ledger.reconciliationStart(now: today, calendar: cal), calendar: cal), "2026-09-01")
    }

    func testTinyOutcomeSurvivesPurchaseRefundAndTuningChange() throws {
        for paid in [false, true] {
            var state = GameState(); state.setUnlocked(paid); state.start(seed: 1, now: now)
            state.ingestSteps(dayKey: "2026-10-09", dailyTotal: 2_000)
            _ = try state.hatch(now: now)
            try state.startEgg(.tiny, seed: 42, now: now)
            let expectedID = state.egg?.frozenSpeciesID
            let expectedShiny = state.egg?.frozenIsShiny
            state.setUnlocked(!paid)
            state.ingestSteps(dayKey: "2026-10-09", dailyTotal: Tuning.introEggTargetSteps + EggType.tiny.targetSteps)
            let hatch = try state.hatch(now: now, tuning: Tuning(shinyChance: 1))
            XCTAssertEqual(hatch.record.speciesID, expectedID)
            XCTAssertEqual(hatch.record.isShiny, expectedShiny)
        }
    }

    func testV1SaveAndEggMigrateWithoutLosingProgress() throws {
        var state = GameState(); state.start(seed: 42, now: now)
        state.ingestSteps(dayKey: "2026-10-09", dailyTotal: 1_500)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        json["schemaVersion"] = 1
        for key in ["saveID", "revision", "needsStepBaseline"] { json.removeValue(forKey: key) }
        var egg = json["egg"] as! [String: Any]
        egg.removeValue(forKey: "frozenSpeciesID"); egg.removeValue(forKey: "frozenIsShiny")
        json["egg"] = egg
        json["ledger"] = ["dayKey": "2026-10-09", "lastDailyTotal": 1_500]
        let migrated = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(migrated.schemaVersion, 2)
        XCTAssertEqual(migrated.egg?.creditedSteps, 1_500)
        XCTAssertEqual(migrated.egg?.frozenSpeciesID, "mochi")
        XCTAssertEqual(migrated.ledger.dailyTotals["2026-10-09"], 1_500)
    }

    func testLegacyUnsealedTinyKeepsItsOriginalFreePool() throws {
        let seed = (UInt64(0)..<10_000).first {
            let legacy = HatchEngine.legacyRoll(egg: .tiny, seed: $0, isUnlocked: false)
            let current = HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: false)
            return legacy.species.id != current.species.id
        }!
        var state = GameState()
        state.start(seed: 1, now: now)
        state.ingestSteps(dayKey: "2026-10-09", dailyTotal: 2_000)
        _ = try state.hatch(now: now)
        try state.startEgg(.tiny, seed: seed, now: now)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        var egg = json["egg"] as! [String: Any]
        for key in ["frozenSpeciesID", "frozenIsShiny", "frozenTargetSteps"] { egg.removeValue(forKey: key) }
        egg["creditedSteps"] = 2_500
        json["egg"] = egg
        var restored = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        let expected = HatchEngine.legacyRoll(egg: .tiny, seed: seed, isUnlocked: false)
        XCTAssertEqual(restored.egg?.targetSteps, 2_500)
        XCTAssertTrue(restored.isEggReady)
        let hatched = try restored.hatch(now: now)
        XCTAssertEqual(hatched.record.speciesID, expected.species.id)
        XCTAssertEqual(hatched.record.isShiny, expected.isShiny)
        XCTAssertEqual(restored.pickableEggs, EggType.allCases)
        XCTAssertNoThrow(try restored.startEgg(.crystal, seed: 7, now: now))
    }

    func testFutureSaveIsRejectedRatherThanDowngraded() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameState())) as! [String: Any]
        json["schemaVersion"] = 99
        XCTAssertThrowsError(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json)))
    }

    func testRevisionSelectsRenameWithSameStepsAndHatches() throws {
        var original = GameState(); original.start(seed: 1, now: now)
        original.ingestSteps(dayKey: "2026-10-09", dailyTotal: 2_000); _ = try original.hatch(now: now)
        var renamed = original
        try renamed.rename("mochi", to: "Luna"); renamed.advanceRevision()
        XCTAssertTrue(renamed.isRicher(than: original))
        XCTAssertFalse(original.isRicher(than: renamed))
    }

    func testCloudBackupExcludesHealthAndRestoreBaselinesSteps() throws {
        var original = GameState(); original.setUnlocked(true); original.start(seed: 1, now: now)
        original.ingestSteps(dayKey: "2026-10-09", dailyTotal: 2_000); _ = try original.hatch(now: now)
        let backup = CollectionBackup(state: original)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as! [String: Any]
        for key in ["ledger", "lifetimeCreditedSteps", "bankedSteps", "egg", "fruitProgressSteps", "isUnlocked"] {
            XCTAssertNil(json[key])
        }
        var restored = GameState(); restored.restoreCollection(backup)
        XCTAssertEqual(restored.collection, original.collection)
        XCTAssertFalse(restored.isUnlocked)
        XCTAssertTrue(restored.needsStepBaseline)
        restored.establishStepBaseline(day: "2026-10-09", total: 2_000, timeZone: "UTC")
        XCTAssertEqual(restored.ingestSteps(dayKey: "2026-10-09", dailyTotal: 2_300).creditedSteps, 300)
    }
}
