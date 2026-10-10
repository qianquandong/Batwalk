import Foundation

/// A local calendar day, encoded as zero-padded "yyyy-MM-dd" so string order == date order.
public enum DayKey {
    public static func make(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Start of the day a key names, in `calendar`'s time zone.
    public static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Days whose HealthKit totals the app should ingest, oldest first:
    /// the ledger's current day (to capture its tail), any missed days, then today.
    /// Capped at `maxDays` so a months-long absence does not trigger dozens of queries.
    public static func daysToSync(lastKey: String?, now: Date, calendar: Calendar = .current, maxDays: Int = 7) -> [Date] {
        let today = calendar.startOfDay(for: now)
        guard let lastKey, let last = date(from: lastKey, calendar: calendar), last < today else {
            return [today]
        }
        let earliest = calendar.date(byAdding: .day, value: -(maxDays - 1), to: today) ?? today
        var day = max(last, earliest)
        var days: [Date] = []
        while day <= today {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}

/// Converts HealthKit's "cumulative steps today" readings into game credit,
/// exactly once per step.
///
/// The platform adapter supplies cumulative totals for each accounting day.
/// Retained high-water marks credit only positive changes, including late data:
///
/// - **First launch**: today's steps so far are credited immediately (PRD §2.2 step 6).
/// - **Large jump between launches**: the whole jump is credited once.
/// - **Midnight rollover**: the app first re-reads the *previous* day's final
///   total (`ingest(dayKey: ledger.dayKey, …)`) to capture the tail, then today's.
/// - **App not opened for several days**: the app ingests each missed day's
///   total in order (oldest first); a skipped day is simply never credited.
/// - **Total goes down** (Health data deleted / source changed): credit 0, never negative.
/// - **An unknown old day reappears**: credit 0, so trimmed days cannot be reopened.
/// - **Travel**: the adapter uses the ledger's original time zone and verifies
///   statistics bucket boundaries before supplying totals.
public struct StepLedger: Codable, Equatable, Sendable {
    public private(set) var dayKey: String?
    public private(set) var lastDailyTotal: Int
    /// Per-day high-water marks allow late arrivals to be reconciled independently.
    public private(set) var dailyTotals: [String: Int]
    public private(set) var trackingStartDay: String?
    /// Fixed accounting boundaries prevent travel from crediting overlapping days.
    public private(set) var timeZoneIdentifier: String?

    public init(dayKey: String? = nil, lastDailyTotal: Int = 0) {
        self.dayKey = dayKey
        self.lastDailyTotal = lastDailyTotal
        self.dailyTotals = dayKey.map { [$0: lastDailyTotal] } ?? [:]
        self.trackingStartDay = dayKey
        self.timeZoneIdentifier = nil
    }

    private enum CodingKeys: String, CodingKey {
        case dayKey, lastDailyTotal, dailyTotals, trackingStartDay, timeZoneIdentifier
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try c.decodeIfPresent(String.self, forKey: .dayKey)
        lastDailyTotal = try c.decodeIfPresent(Int.self, forKey: .lastDailyTotal) ?? 0
        let legacyDay = dayKey
        let legacyTotal = lastDailyTotal
        dailyTotals = try c.decodeIfPresent([String: Int].self, forKey: .dailyTotals)
            ?? legacyDay.map { [$0: legacyTotal] } ?? [:]
        trackingStartDay = try c.decodeIfPresent(String.self, forKey: .trackingStartDay) ?? dayKey
        timeZoneIdentifier = try c.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
    }

    public mutating func beginTracking(on day: String, timeZone: String) {
        if trackingStartDay == nil { trackingStartDay = day }
        if timeZoneIdentifier == nil { timeZoneIdentifier = timeZone }
    }

    public func reconciliationStart(now: Date, calendar: Calendar, lookbackDays: Int = 7) -> Date {
        let today = calendar.startOfDay(for: now)
        let first = trackingStartDay.flatMap { DayKey.date(from: $0, calendar: calendar) } ?? today
        let last = dayKey.flatMap { DayKey.date(from: $0, calendar: calendar) } ?? first
        let lookback = calendar.date(byAdding: .day, value: -(max(1, lookbackDays) - 1), to: today) ?? today
        // A long absence is queried in one statistics collection, without dropping days.
        return min(today, max(first, min(last, lookback)))
    }

    /// Used after a collection-only restore: today's existing steps are a baseline,
    /// not a second reward for steps already consumed by the lost device.
    public mutating func establishBaseline(dayKey: String, total: Int, timeZone: String) {
        self = StepLedger(dayKey: dayKey, lastDailyTotal: max(0, total))
        timeZoneIdentifier = timeZone
    }

    /// Feed a cumulative daily total; returns the newly creditable steps (>= 0).
    @discardableResult
    public mutating func ingest(dayKey newDay: String, dailyTotal: Int) -> Int {
        let total = max(0, dailyTotal)

        guard let current = dayKey else {
            dayKey = newDay
            lastDailyTotal = total
            dailyTotals[newDay] = total
            if trackingStartDay == nil { trackingStartDay = newDay }
            return total
        }

        if let previous = dailyTotals[newDay] {
            let delta = max(0, total - previous)
            dailyTotals[newDay] = max(previous, total)
            if newDay == current { lastDailyTotal = dailyTotals[newDay]! }
            return delta
        }

        if newDay > current {
            dayKey = newDay
            lastDailyTotal = total
            dailyTotals[newDay] = total
            // Keep fourteen known days. Unknown older days stay closed forever;
            // seven-day reconciliation cannot recreate and double-credit them.
            for key in dailyTotals.keys.sorted().dropLast(14) { dailyTotals.removeValue(forKey: key) }
            return total
        }

        // An older day reappeared (time-zone change). Credit nothing.
        return 0
    }
}
