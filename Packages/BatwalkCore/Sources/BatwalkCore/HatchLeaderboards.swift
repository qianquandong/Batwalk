import Foundation

/// Only game events enter this payload. There is intentionally no step score.
public enum HatchLeaderboard: String, CaseIterable, Codable, Sendable {
    case month = "bats.month"
    case total = "bats.total"
}

public struct HatchLeaderboardScore: Equatable, Sendable {
    public let board: HatchLeaderboard
    public let value: Int
    public let context: Int

    public init(board: HatchLeaderboard, value: Int, context: Int) {
        self.board = board
        self.value = max(0, value)
        self.context = context
    }
}

public enum HatchLeaderboards {
    /// All friends use one month boundary, independent of travel or DST.
    /// Local monthly challenges intentionally retain the player's own calendar.
    public static var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }

    public static func monthKey(at date: Date) -> Int {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return (parts.year ?? 0) * 100 + (parts.month ?? 0)
    }

    public static func monthlyScore(history: [HatchRecord], now: Date, savedCounts: [String: Int] = [:]) -> HatchLeaderboardScore {
        let key = monthKey(at: now)
        let count = history.filter {
            $0.source == .egg && $0.hatchedAt <= now && monthKey(at: $0.hatchedAt) == key
        }.count
        return HatchLeaderboardScore(board: .month, value: max(count, savedCounts[String(key)] ?? 0), context: key)
    }

    /// Gameplay-only archive, retained independently of the display history.
    public static func monthlyCounts(history: [HatchRecord]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for record in history where record.source == .egg {
            counts[String(monthKey(at: record.hatchedAt)), default: 0] += 1
        }
        return counts
    }

    public static func totalScore(hatchCount: Int) -> HatchLeaderboardScore {
        HatchLeaderboardScore(board: .total, value: hatchCount, context: 0)
    }

    public static func isCurrent(_ score: HatchLeaderboardScore, at date: Date) -> Bool {
        score.board == .total || score.context == monthKey(at: date)
    }
}
