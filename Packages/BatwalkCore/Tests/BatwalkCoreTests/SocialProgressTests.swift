import XCTest
@testable import BatwalkCore

final class SocialProgressTests: XCTestCase {
    func calendar(_ zone: String = "America/Chicago") -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!; return c
    }
    func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }
    func record(_ time: String, shiny: Bool = false, source: HatchSource = .egg, key: String? = nil) -> HatchRecord {
        HatchRecord(speciesID: "mochi", isShiny: shiny, eggType: .tiny, hatchedAt: date(time), outcome: .duplicate,
                    source: source, challengeMonthKey: key)
    }
    func testWeeklyDayMappingMultipleHatchesAndTimeZones() {
        let c = calendar(); let start = date("2026-10-19T05:00:00Z")
        let history = [record("2026-10-19T04:59:59Z"), record("2026-10-19T05:00:00Z"),
                       record("2026-10-20T12:00:00Z"), record("2026-10-20T13:00:00Z", shiny: true),
                       record("2026-10-26T04:59:59Z"), record("2026-10-26T05:00:00Z")]
        let recap = WeeklyRecap.make(history: history, weekStart: start, calendar: c)
        XCTAssertEqual(recap.symbolLine, "🦇✨🥚🥚🥚🥚🦇")
        XCTAssertEqual(recap.bats, 4); XCTAssertEqual(recap.shiny, 1); XCTAssertEqual(recap.weekNumber, 2)
        let utc = WeeklyRecap.make(history: history, weekStart: date("2026-10-19T00:00:00Z"), calendar: calendar("UTC"))
        XCTAssertEqual(utc.symbolLine, "🦇✨🥚🥚🥚🥚🥚")
    }
    func testEmptyWeekAndDSTCalendarDays() {
        let c = calendar(); let start = date("2026-10-26T05:00:00Z")
        let empty = WeeklyRecap.make(history: [], weekStart: start, calendar: c)
        XCTAssertEqual(empty.symbols.count, 7); XCTAssertTrue(empty.shareText.contains("an egg on the way"))
        let dst = WeeklyRecap.make(history: [record("2026-11-02T05:59:59Z")], weekStart: start, calendar: c)
        XCTAssertEqual(dst.symbols.last, .bat)
        XCTAssertEqual(SocialCalendar.recapStart(date("2026-11-02T16:00:00Z"), calendar: c), start)
    }
    func testMonthlyThresholdsAndSourceBoundaries() {
        let c = calendar()
        for count in 0...7 {
            let history = (0..<count).map { _ in record("2026-10-15T12:00:00Z") }
                + [record("2026-11-01T05:00:00Z"), record("2026-10-01T04:59:59Z"), record("2026-10-10T10:00:00Z", source: .moonDust)]
            let result = MonthlyChallenge.make(history: history, monthKey: "2026-10", calendar: c)
            XCTAssertEqual(result.hatches, count)
            XCTAssertEqual(result.tier, count >= 6 ? .gold : count >= 3 ? .silver : count >= 1 ? .bronze : .none)
            XCTAssertEqual(result.symbols.count, 31)
        }
        let frozen = MonthlyChallenge.make(history: [record("2026-11-01T00:10:00Z", key: "2026-10")], monthKey: "2026-10", calendar: calendar("UTC"))
        XCTAssertEqual(frozen.tier, .bronze, "Travel must not remove an earned outfit")
    }
    func testOutfitChoiceSurvivesSaveAndBackupWithoutChangingPools() throws {
        var state = GameState(); let now = date("2026-10-15T12:00:00Z")
        state.start(seed: 1, now: now); state.ingestSteps(dayKey: "2026-10-15", dailyTotal: 2_000)
        let result = try state.hatch(now: now, calendar: calendar())
        let before = EggType.allCases.map { $0.pool(isUnlocked: state.isUnlocked) }
        XCTAssertEqual(state.outfit(for: result.bat.speciesID)?.tier, .bronze)
        try state.setOutfit(.none, for: result.bat.speciesID)
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertNil(decoded.outfit(for: result.bat.speciesID))
        var restored = GameState(); restored.restoreCollection(try JSONDecoder().decode(CollectionBackup.self, from: JSONEncoder().encode(CollectionBackup(state: state))))
        XCTAssertEqual(restored.outfitPreferences, state.outfitPreferences)
        var trimmedRestore = GameState(); trimmedRestore.restoreCollection(CollectionBackup(state: state).trimmingHistory(to: 0))
        XCTAssertEqual(trimmedRestore.earnedOutfits(for: result.bat.speciesID), state.earnedOutfits(for: result.bat.speciesID))
        XCTAssertEqual(before, EggType.allCases.map { $0.pool(isUnlocked: state.isUnlocked) })
    }
    func testReminderOptOutAndProgressConditions() {
        let c = calendar(); let now = date("2026-10-10T12:00:00Z")
        XCTAssertTrue(PhoneReminderPlan.make(history: [], now: now, weekly: false, challenge: false, calendar: c).isEmpty)
        let noProgress = PhoneReminderPlan.make(history: [], now: now, weekly: true, challenge: true, calendar: c)
        XCTAssertFalse(noProgress.contains { $0.id.contains("middle") })
        XCTAssertEqual(noProgress.filter { $0.id.contains("end.") }.count, 1)
        XCTAssertTrue(noProgress.allSatisfy { $0.date > now && c.component(.hour, from: $0.date) == 9 })
        let history = [record("2026-10-01T12:00:00Z"), record("2026-10-02T12:00:00Z")]
        let progress = PhoneReminderPlan.make(history: history, now: now, weekly: false, challenge: true, calendar: c)
        XCTAssertTrue(progress.contains { $0.body.contains("Silver is 1 away") })
        XCTAssertLessThan(progress.count, 64)
        XCTAssertEqual(Set(progress.map(\.id)).count, progress.count)
    }

    func testLegacyRewardsMaterializeBeforeBackupTrimming() throws {
        var state = GameState(); let now = date("2026-10-15T12:00:00Z")
        state.start(seed: 1, now: now); state.ingestSteps(dayKey: "2026-10-15", dailyTotal: 2_000)
        let bat = try state.hatch(now: now).bat
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "earnedChallengeOutfits"); json.removeValue(forKey: "challengeHatchCounts")
        let legacy = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        var restored = GameState(); restored.restoreCollection(CollectionBackup(state: legacy).trimmingHistory(to: 0))
        XCTAssertEqual(restored.earnedOutfits(for: bat.speciesID).first?.tier, .bronze)
        XCTAssertEqual(MonthlyChallenge.make(state: restored, monthKey: "2026-10").hatches, 1)
        XCTAssertEqual(WeeklyRecap.make(state: restored, weekStart: date("2026-10-26T05:00:00Z"), calendar: calendar()).weekNumber, 3)
        var backup = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(CollectionBackup(state: state))) as? [String: Any])
        backup.removeValue(forKey: "earnedChallengeOutfits"); backup.removeValue(forKey: "challengeHatchCounts")
        let oldBackup = try JSONDecoder().decode(CollectionBackup.self, from: JSONSerialization.data(withJSONObject: backup))
        restored.restoreCollection(oldBackup.trimmingHistory(to: 0))
        XCTAssertEqual(restored.earnedOutfits(for: bat.speciesID).first?.tier, .bronze)
    }

    func testFrozenCalendarDayAndArchivedReminderProgress() throws {
        var state = GameState(); let now = date("2026-11-01T00:10:00Z")
        state.start(seed: 1, now: now); state.ingestSteps(dayKey: "2026-10-31", dailyTotal: 2_000)
        let record = try state.hatch(now: now, calendar: calendar()).record
        XCTAssertEqual(record.challengeDay, 31)
        let october = MonthlyChallenge.make(state: state, monthKey: "2026-10", calendar: calendar("UTC"))
        XCTAssertEqual(october.symbols[30], record.isShiny ? .shiny : .bat)
        XCTAssertEqual(october.symbols[0], .egg)
        let plans = PhoneReminderPlan.make(history: [], now: date("2026-10-10T12:00:00Z"), weekly: false,
            challenge: true, calendar: calendar(), savedMonthCounts: ["2026-10": 3])
        XCTAssertTrue(plans.contains { $0.body.contains("Gold is 3 away") })
    }
}
