import XCTest
@testable import BatwalkCore

final class BirthdayTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func date(_ year: Int = 2026, _ month: Int = 10, _ day: Int = 23, hour: Int = 12, calendar: Calendar? = nil) -> Date {
        (calendar ?? cal).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    private func setBirthday(_ birthday: MonthDay?, state: inout GameState, now: Date) {
        let request = PlayerSettingsRequest(saveID: state.saveID, baseRevision: state.revision, requestedAt: now, birthday: birthday)
        XCTAssertEqual(state.applyPlayerSettings(request, now: now), .applied)
        state.advanceRevision()
    }
    @discardableResult
    private func hatch(_ state: inout GameState, at now: Date, calendar: Calendar? = nil) throws -> HatchResult {
        let tuning = Tuning(shinyChance: 0, shinyPityHatches: 0, newSpeciesPityHatches: 0)
        if !state.hasStarted { state.start(seed: 1, now: now, tuning: tuning) }
        else { try state.startEgg(.starter, seed: 1, now: now, tuning: tuning) }
        let day = DayKey.make(now, calendar: calendar ?? cal)
        state.ingestSteps(dayKey: day, dailyTotal: (state.ledger.dailyTotals[day] ?? 0) + state.egg!.targetSteps)
        return try state.hatch(now: now, tuning: tuning, calendar: calendar ?? cal)
    }

    func testMonthDayValidationAndNoBirthYearStored() throws {
        XCTAssertNil(MonthDay(month: 0, day: 1)); XCTAssertNil(MonthDay(month: 13, day: 1))
        XCTAssertNil(MonthDay(month: 4, day: 31)); XCTAssertNil(MonthDay(month: 2, day: 30))
        XCTAssertNotNil(MonthDay(month: 2, day: 29))
        let data = try JSONEncoder().encode(MonthDay(month: 10, day: 23)!)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Int]
        XCTAssertEqual(Set(json.keys), ["month", "day"])
        XCTAssertThrowsError(try JSONDecoder().decode(MonthDay.self, from: Data("{\"month\":2,\"day\":30}".utf8)))
    }

    func testLeapDayIsObservedOnFebruary28InNonLeapYears() {
        let birthday = MonthDay(month: 2, day: 29)!
        XCTAssertTrue(birthday.matches(date(2027, 2, 28), calendar: cal))
        XCTAssertFalse(birthday.matches(date(2027, 3, 1), calendar: cal))
        XCTAssertTrue(birthday.matches(date(2028, 2, 29), calendar: cal))
        XCTAssertFalse(birthday.matches(date(2028, 2, 28), calendar: cal))
        XCTAssertTrue(birthday.matches(date(2100, 2, 28), calendar: cal))
        XCTAssertTrue(birthday.matches(date(2000, 2, 29), calendar: cal))
    }

    func testBirthdayHatchAwardsOnePermanentHatPerYearEvenForDuplicates() throws {
        var state = GameState()
        setBirthday(MonthDay(month: 10, day: 23), state: &state, now: date(hour: 8))
        let first = try hatch(&state, at: date())
        XCTAssertEqual(first.record.birthdayYear, 2026)
        XCTAssertEqual(first.bat.birthdayYears, [2026])
        let duplicate = try hatch(&state, at: date(hour: 13))
        XCTAssertEqual(duplicate.record.outcome, .duplicate)
        XCTAssertEqual(duplicate.bat.birthdayYears, [2026])
        _ = try hatch(&state, at: date(2027))
        XCTAssertEqual(state.collection["mochi"]?.birthdayYears, [2026, 2027])
        XCTAssertEqual(state.birthdayHatYear(for: "mochi", now: date(2027, 10, 24), calendar: cal), 2027)
    }

    func testNoHatchStillShowsTemporaryHatAndDoesNotChangeSave() throws {
        var state = GameState()
        _ = try hatch(&state, at: date(2026, 10, 22))
        setBirthday(MonthDay(month: 10, day: 23), state: &state, now: date(hour: 8))
        let before = state
        XCTAssertEqual(state.birthdayHatYear(for: "mochi", now: date(), calendar: cal), 2026)
        XCTAssertNil(state.birthdayHatYear(for: "mochi", now: date(2026, 10, 24), calendar: cal))
        XCTAssertNil(state.birthdayHatYear(for: "cocoa", now: date(), calendar: cal))
        XCTAssertNil(state.collection["mochi"]?.birthdayYears)
        XCTAssertEqual(state, before)
    }

    func testHatchUsesLocalCalendarAtTimeZoneBoundary() throws {
        var west = cal; west.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let instant = date(2026, 10, 23, hour: 1)
        let birthday = MonthDay(month: 10, day: 22)!
        XCTAssertTrue(birthday.matches(instant, calendar: west))
        XCTAssertFalse(birthday.matches(instant, calendar: cal))
        var state = GameState()
        setBirthday(birthday, state: &state, now: instant)
        XCTAssertEqual(try hatch(&state, at: instant, calendar: west).record.birthdayYear, 2026)
    }

    func testKeepsakesAndBirthdaySurviveSaveBackupTrimRestoreAndMirror() throws {
        var state = GameState()
        setBirthday(MonthDay(month: 10, day: 23), state: &state, now: date())
        _ = try hatch(&state, at: date())
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        let backup = CollectionBackup(state: state).trimmingHistory(to: 0)
        var restored = GameState(); restored.restoreCollection(backup)
        XCTAssertEqual(restored.birthday, state.birthday)
        XCTAssertEqual(restored.collection["mochi"]?.birthdayYears, [2026])
        XCTAssertEqual(state.collectionMirror().history.first?.birthdayYear, 2026)
        XCTAssertNil(state.collectionMirror().history.first?.eggSteps)
        XCTAssertNil(state.collectionMirror().history.first?.eggStartedAt)
        let stale = PlayerSettingsRequest(saveID: restored.saveID, baseRevision: 0, requestedAt: date(), birthday: nil)
        XCTAssertEqual(restored.applyPlayerSettings(stale, now: date()), .superseded)
    }

    func testOldSavesDecodeWithoutBirthdayFields() throws {
        var state = GameState(); _ = try hatch(&state, at: date())
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        for key in ["birthday", "lastBirthdayRequest", "birthdayRequestFloorRevision"] { json.removeValue(forKey: key) }
        var collection = json["collection"] as! [String: [String: Any]]
        collection["mochi"]?.removeValue(forKey: "birthdayYears"); json["collection"] = collection
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.birthday); XCTAssertNil(decoded.collection["mochi"]?.birthdayYears)
        XCTAssertNil(decoded.history.first?.birthdayYear)
    }

    func testSettingsRejectExpiredWrongSaveFutureRevisionAndOutOfOrderRequests() {
        var state = GameState(); let now = date()
        let old = PlayerSettingsRequest(saveID: state.saveID, baseRevision: 0, requestedAt: now.addingTimeInterval(-20), birthday: MonthDay(month: 1, day: 1))
        let latest = PlayerSettingsRequest(saveID: state.saveID, baseRevision: 0, requestedAt: now, birthday: MonthDay(month: 10, day: 23))
        XCTAssertEqual(state.applyPlayerSettings(latest, now: now), .applied)
        let before = state
        XCTAssertEqual(state.applyPlayerSettings(latest, now: now), .applied)
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.applyPlayerSettings(old, now: now), .superseded)
        XCTAssertEqual(state.applyPlayerSettings(PlayerSettingsRequest(saveID: UUID(), baseRevision: 0, requestedAt: now, birthday: nil), now: now), .saveChanged)
        XCTAssertEqual(state.applyPlayerSettings(PlayerSettingsRequest(saveID: state.saveID, baseRevision: 99, requestedAt: now, birthday: nil), now: now), .saveChanged)
        XCTAssertEqual(state.applyPlayerSettings(PlayerSettingsRequest(saveID: state.saveID, baseRevision: 0, requestedAt: now.addingTimeInterval(-901), birthday: nil), now: now), .expired)
        XCTAssertEqual(state.applyPlayerSettings(PlayerSettingsRequest(saveID: state.saveID, baseRevision: 0, requestedAt: now.addingTimeInterval(121), birthday: nil), now: now), .expired)
        XCTAssertEqual(state, before)
    }

    func testQueuedBirthdayCanApplyAfterUnrelatedStepRevisionAndCanBeRemoved() throws {
        var state = GameState(); let now = date()
        let request = PlayerSettingsRequest(saveID: state.saveID, baseRevision: 0, requestedAt: now, birthday: MonthDay(month: 10, day: 23))
        state.start(seed: 1, now: now); state.ingestSteps(dayKey: "2026-10-23", dailyTotal: 10); state.advanceRevision()
        let egg = state.egg
        XCTAssertEqual(state.applyPlayerSettings(request, now: now), .applied)
        XCTAssertEqual(state.egg, egg)
        state.advanceRevision()
        setBirthday(nil, state: &state, now: now.addingTimeInterval(1))
        XCTAssertNil(state.birthday)
        XCTAssertEqual(state.applyPlayerSettings(request, now: now.addingTimeInterval(2)), .superseded)
    }

    func testSettingsHandoffWaitsForReceiptAndMirrorInEitherOrder() {
        for receiptFirst in [true, false] {
            var watch = GameState(); let phone = watch; let now = date()
            let request = PlayerSettingsRequest(saveID: watch.saveID, baseRevision: 0, requestedAt: now, birthday: MonthDay(month: 10, day: 23))
            var handoff = PlayerSettingsHandoff()
            XCTAssertTrue(handoff.begin(request)); XCTAssertFalse(handoff.begin(request))
            XCTAssertEqual(watch.applyPlayerSettings(request, now: now), .applied); watch.advanceRevision()
            let receipt = PlayerSettingsReceipt(request: request, outcome: .applied, revision: watch.revision)
            if receiptFirst {
                handoff.receive(receipt, state: phone, now: now); XCTAssertTrue(handoff.isWaiting)
                handoff.reconcile(with: watch, now: now)
            } else {
                handoff.reconcile(with: watch, now: now); XCTAssertTrue(handoff.isWaiting)
                handoff.receive(receipt, state: watch, now: now)
            }
            XCTAssertFalse(handoff.isWaiting); XCTAssertNil(handoff.failure)
        }
    }

    func testLateReceiptCanConfirmARequestTheWatchSavedBeforeExpiry() {
        var watch = GameState(); let phone = watch; let now = date()
        let request = PlayerSettingsRequest(saveID: watch.saveID, baseRevision: 0, requestedAt: now,
                                            birthday: MonthDay(month: 10, day: 23))
        var handoff = PlayerSettingsHandoff(); handoff.begin(request)
        XCTAssertEqual(watch.applyPlayerSettings(request, now: now), .applied); watch.advanceRevision()
        let later = now.addingTimeInterval(1_800)
        handoff.reconcile(with: phone, now: later)
        XCTAssertEqual(handoff.failure, .expired)
        let receipt = PlayerSettingsReceipt(request: request, outcome: .applied, revision: watch.revision)
        handoff.receive(receipt, state: phone, now: later)
        XCTAssertTrue(handoff.isWaiting); XCTAssertNil(handoff.failure)
        handoff.reconcile(with: watch, now: later)
        XCTAssertFalse(handoff.isWaiting); XCTAssertNil(handoff.failure)
    }

}
