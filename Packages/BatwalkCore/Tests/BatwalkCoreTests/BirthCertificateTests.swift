import XCTest
@testable import BatwalkCore

final class BirthCertificateTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func record(start: Date?, end: Date, steps: Int? = 10_000) -> HatchRecord {
        HatchRecord(speciesID: "mochi", isShiny: false, eggType: .tiny, hatchedAt: end,
                    outcome: .newSpecies, eggStartedAt: start, eggSteps: steps)
    }

    func testHatchStoresTheFrozenTargetAndOriginalStart() throws {
        let start = date("2026-10-01T12:00:00Z")
        var state = GameState()
        state.start(seed: 1, now: start)
        state.ingestSteps(dayKey: "2026-10-01", dailyTotal: Tuning.introEggTargetSteps)
        let result = try state.hatch(now: date("2026-10-03T12:00:00Z"))
        XCTAssertEqual(result.record.eggStartedAt, start)
        XCTAssertEqual(result.record.eggSteps, 2_000)
        XCTAssertEqual(result.record.eggType.displayName(forTargetSteps: result.record.eggSteps), "Starter Egg")
        XCTAssertEqual(try JSONDecoder().decode(HatchRecord.self, from: JSONEncoder().encode(result.record)), result.record)
        try state.startEgg(.tiny, seed: 4, now: start)
        XCTAssertEqual(state.egg?.targetSteps, 10_000)
    }

    func testOldRecordsStayUnknownRatherThanInventingWalks() throws {
        let old = record(start: nil, end: date("2026-10-01T12:00:00Z"), steps: nil)
        let restored = try JSONDecoder().decode(HatchRecord.self, from: JSONEncoder().encode(old))
        XCTAssertNil(restored.eggStartedAt)
        XCTAssertNil(restored.eggSteps)
        XCTAssertNil(restored.certificateDays())
    }

    func testCalendarDaysHandleDSTAndSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let start = date("2026-03-07T18:00:00Z")
        let end = date("2026-03-09T17:00:00Z") // 47 hours, two calendar-day boundaries
        XCTAssertEqual(record(start: start, end: end).certificateDays(calendar: calendar), 2)
        XCTAssertEqual(record(start: start, end: start).certificateDays(calendar: calendar), 1)
        XCTAssertNil(record(start: end, end: start).certificateDays(calendar: calendar))
    }

    func testMetricsRequestRejectsForeignSaveWrongIndexAndMissingReceipt() throws {
        var state = GameState()
        state.start(seed: 1, now: .distantPast)
        state.ingestSteps(dayKey: "2026-10-01", dailyTotal: Tuning.introEggTargetSteps)
        let record = try state.hatch(now: .now).record
        let request = CertificateMetricsRequest(saveID: state.saveID, recordIndex: 0,
                                               speciesID: record.speciesID, hatchedAt: record.hatchedAt)
        XCTAssertEqual(request.metrics(in: state)?.eggSteps, 2_000)
        XCTAssertNil(request.metrics(in: state.collectionMirror()))
        XCTAssertNil(CertificateMetricsRequest(saveID: UUID(), recordIndex: 0, speciesID: record.speciesID,
                                               hatchedAt: record.hatchedAt).metrics(in: state))
        XCTAssertNil(CertificateMetricsRequest(saveID: state.saveID, recordIndex: 1, speciesID: record.speciesID,
                                               hatchedAt: record.hatchedAt).metrics(in: state))
    }

    func testDefaultMirrorsAndBackupsStripReceiptMetricsAndAllWalkingTotals() throws {
        var state = GameState()
        state.start(seed: 1, now: date("2026-10-01T12:00:00Z"))
        state.ingestSteps(dayKey: "2026-10-01", dailyTotal: Tuning.introEggTargetSteps)
        _ = try state.hatch(now: date("2026-10-02T12:00:00Z"))
        try state.startEgg(.tiny, seed: 1, now: .now)
        state.ingestSteps(dayKey: "2026-10-02", dailyTotal: 6_789)
        let mirror = state.collectionMirror()
        XCTAssertNil(mirror.egg)
        XCTAssertEqual(mirror.ledger, StepLedger())
        XCTAssertEqual(mirror.lifetimeCreditedSteps, 0)
        XCTAssertEqual(mirror.bankedSteps, 0)
        XCTAssertEqual(mirror.fruitProgressSteps, 0)
        XCTAssertNil(mirror.history.first?.eggSteps)
        XCTAssertNil(mirror.history.first?.eggStartedAt)
        XCTAssertEqual(mirror.collection, state.collection)
        XCTAssertEqual(mirror.saveID, state.saveID)
        XCTAssertEqual(mirror.revision, state.revision)
        XCTAssertEqual(mirror.collectionMirror(), mirror)
        let backup = CollectionBackup(state: state)
        XCTAssertNil(backup.history.first?.eggSteps)
        XCTAssertNil(backup.history.first?.eggStartedAt)
        // Even an old/exported backup carrying these fields is redacted on decode.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as? [String: Any])
        json["history"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state.history))
        let decoded = try JSONDecoder().decode(CollectionBackup.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.history.first?.eggSteps)
        XCTAssertNil(decoded.history.first?.eggStartedAt)
    }

    func testEggMilestonesKeepStableSaveKeysAndHonestLegacyNames() {
        XCTAssertEqual(EggType.allCases.map(\.rawValue), ["starter", "tiny", "forest", "moon", "crystal"])
        XCTAssertEqual(EggType.allCases.map(\.targetSteps), [10_000, 10_000, 21_097, 42_195, 100_000])
        XCTAssertEqual(EggType.forest.displayName, "Half Marathon Egg")
        XCTAssertEqual(EggType.forest.displayName(forTargetSteps: 40_000), "Forest Egg")
        XCTAssertEqual(EggType.moon.displayName(forTargetSteps: nil), "Moon Egg")
    }

    func testMoonPhaseKnownNewAndFullMoonAndDatesBeforeEpoch() {
        XCTAssertEqual(MoonPhase.on(date("2000-01-06T18:15:00Z")), .newMoon)
        XCTAssertEqual(MoonPhase.on(date("2000-01-21T04:42:00Z")), .fullMoon)
        let epoch = date("2000-01-06T18:15:00Z")
        for index in 0..<8 {
            let offset = Double(index) * 29.530588 * 86_400 / 8
            XCTAssertEqual(MoonPhase.on(epoch.addingTimeInterval(offset)).rawValue, index)
            XCTAssertEqual(MoonPhase.on(epoch.addingTimeInterval(offset - 29.530588 * 86_400)).rawValue, index)
        }
    }
}
