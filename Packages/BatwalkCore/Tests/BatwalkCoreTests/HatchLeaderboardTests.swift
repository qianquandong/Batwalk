import XCTest
@testable import BatwalkCore

final class HatchLeaderboardTests: XCTestCase {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func record(_ text: String, source: HatchSource = .egg) -> HatchRecord {
        HatchRecord(speciesID: "mochi", isShiny: false, eggType: .tiny,
                    hatchedAt: date(text), outcome: .duplicate, source: source)
    }

    func testRealCalendarMonthsIncludeThirtyFirstAndExcludeOtherMonthsAndDust() {
        let history = [record("2026-10-01T00:00:00Z"), record("2026-10-31T23:59:59Z"),
                       record("2026-09-30T23:59:59Z"), record("2026-11-01T00:00:00Z"),
                       record("2026-10-15T12:00:00Z", source: .moonDust)]
        let score = HatchLeaderboards.monthlyScore(history: history, now: date("2026-10-31T23:59:59Z"))
        XCTAssertEqual(score, HatchLeaderboardScore(board: .month, value: 2, context: 202610))
        XCTAssertFalse(HatchLeaderboards.isCurrent(score, at: date("2026-11-01T00:00:00Z")))
    }

    func testLeapFebruaryAndUTCMonthBoundary() {
        let history = [record("2028-02-29T23:59:59Z"), record("2028-03-01T00:00:00Z")]
        XCTAssertEqual(HatchLeaderboards.monthlyScore(history: history,
            now: date("2028-02-29T23:59:59Z")).value, 1)
        XCTAssertEqual(HatchLeaderboards.monthKey(at: date("2026-10-31T19:00:00-05:00")), 202611)
    }

    func testNoFutureHatchesAndNoHealthBoard() {
        XCTAssertEqual(HatchLeaderboard.allCases.map(\.rawValue), ["bats.month", "bats.total"])
        XCTAssertEqual(HatchLeaderboards.monthlyScore(history: [record("2026-10-20T00:00:00Z")],
            now: date("2026-10-19T00:00:00Z")).value, 0)
        XCTAssertEqual(HatchLeaderboards.totalScore(hatchCount: 123),
                       HatchLeaderboardScore(board: .total, value: 123, context: 0))
    }

    func testLifetimeCountAndOrdinalSurviveTrimmedBackupAndLegacyDecode() throws {
        var state = GameState()
        state.start(seed: 1, now: date("2026-10-01T00:00:00Z"))
        state.ingestSteps(dayKey: "2026-10-01", dailyTotal: 2_000)
        let first = try state.hatch(now: date("2026-10-01T01:00:00Z"))
        XCTAssertEqual(first.record.hatchOrdinal, 1)
        XCTAssertEqual(state.lifetimeHatchCount, 1)
        let backup = CollectionBackup(state: state).trimmingHistory(to: 0)
        XCTAssertEqual(backup.lifetimeHatchCount, 1)
        XCTAssertEqual(backup.monthlyHatchCounts, ["202610": 1])
        var restored = GameState()
        restored.restoreCollection(try JSONDecoder().decode(CollectionBackup.self, from: JSONEncoder().encode(backup)))
        XCTAssertTrue(restored.history.isEmpty)
        XCTAssertEqual(restored.lifetimeHatchCount, 1)
        XCTAssertEqual(HatchLeaderboards.monthlyScore(history: restored.history, now: date("2026-10-02T00:00:00Z"),
            savedCounts: restored.monthlyHatchCounts).value, 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "lifetimeHatchCount")
        json.removeValue(forKey: "monthlyHatchCounts")
        let legacy = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.lifetimeHatchCount, 1)
        XCTAssertEqual(legacy.monthlyHatchCounts, ["202610": 1])
        XCTAssertEqual(CollectionBackup(state: legacy).trimmingHistory(to: 0).monthlyHatchCounts, ["202610": 1])
    }
}
