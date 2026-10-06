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
/// HealthKit is asked for one number: today's total step count. The ledger
/// remembers the last total it saw for its current day and credits only the
/// increase. That makes every edge case in PRD §4.9 safe:
///
/// - **First launch**: today's steps so far are credited immediately (PRD §2.2 step 6).
/// - **Large jump between launches**: the whole jump is credited once.
/// - **Midnight rollover**: the app first re-reads the *previous* day's final
///   total (`ingest(dayKey: ledger.dayKey, …)`) to capture the tail, then today's.
/// - **App not opened for several days**: the app ingests each missed day's
///   total in order (oldest first); a skipped day is simply never credited.
/// - **Total goes down** (Health data deleted / source changed): credit 0, never negative.
/// - **Time-zone travel backwards** (an earlier day key reappears): credit 0,
///   so no step is ever counted twice. Some steps may be under-credited; that is
///   the intentional trade-off.
public struct StepLedger: Codable, Equatable, Sendable {
    public private(set) var dayKey: String?
    public private(set) var lastDailyTotal: Int

    public init(dayKey: String? = nil, lastDailyTotal: Int = 0) {
        self.dayKey = dayKey
        self.lastDailyTotal = lastDailyTotal
    }

    /// Feed a cumulative daily total; returns the newly creditable steps (>= 0).
    @discardableResult
    public mutating func ingest(dayKey newDay: String, dailyTotal: Int) -> Int {
        let total = max(0, dailyTotal)

        guard let current = dayKey else {
            dayKey = newDay
            lastDailyTotal = total
            return total
        }

        if newDay == current {
            let delta = max(0, total - lastDailyTotal)
            lastDailyTotal = max(lastDailyTotal, total)
            return delta
        }

        if newDay > current {
            dayKey = newDay
            lastDailyTotal = total
            return total
        }

        // An older day reappeared (time-zone change). Credit nothing.
        return 0
    }
}
