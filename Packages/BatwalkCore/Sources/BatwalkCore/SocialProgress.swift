import Foundation

public enum HatchDaySymbol: String, Codable, Sendable { case egg = "🥚", bat = "🦇", shiny = "✨" }

public enum SocialCalendar {
    public static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 2000, c.month ?? 1)
    }
    public static func monthStart(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, (1...12).contains(parts[1]) else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
    }
    public static func weekStart(_ date: Date, calendar: Calendar = .current) -> Date {
        var c = calendar; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4
        return c.dateInterval(of: .weekOfYear, for: date)?.start ?? c.startOfDay(for: date)
    }
    public static func recapStart(_ date: Date, calendar: Calendar = .current) -> Date {
        let start = weekStart(date, calendar: calendar)
        return calendar.component(.weekday, from: date) == 2
            ? calendar.date(byAdding: .day, value: -7, to: start)! : start
    }
    public static func showsWeeklyRecap(_ date: Date, calendar: Calendar = .current) -> Bool {
        [1, 2].contains(calendar.component(.weekday, from: date))
    }
}

public struct WeeklyRecap: Equatable, Sendable {
    public let weekStart: Date
    public let symbols: [HatchDaySymbol]
    public let bats: Int
    public let shiny: Int
    public let weekNumber: Int
    public var symbolLine: String { symbols.map(\.rawValue).joined() }
    public var shareText: String {
        let ending = bats == 0 ? "an egg on the way" : "\(bats) \(bats == 1 ? "bat" : "bats"), \(shiny) Shiny"
        return "Batwalk · Week \(weekNumber) · \(symbolLine) · \(ending)"
    }
    public static func make(history: [HatchRecord], weekStart: Date, calendar: Calendar = .current) -> Self {
        let start = calendar.startOfDay(for: weekStart)
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        let eggs = history.filter { $0.source == .egg }
        let records = eggs.filter { $0.hatchedAt >= start && $0.hatchedAt < end }
        var symbols = Array(repeating: HatchDaySymbol.egg, count: 7)
        for record in records {
            let index = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: record.hatchedAt)).day ?? 0
            if (0..<7).contains(index), symbols[index] != .shiny { symbols[index] = record.isShiny ? .shiny : .bat }
        }
        let first = eggs.map(\.hatchedAt).min() ?? start
        let firstStart = SocialCalendar.weekStart(first, calendar: calendar)
        let days = calendar.dateComponents([.day], from: firstStart, to: start).day ?? 0
        return Self(weekStart: start, symbols: symbols, bats: records.count,
                    shiny: records.filter(\.isShiny).count, weekNumber: max(1, days / 7 + 1))
    }
}

public enum ChallengeTier: Int, Codable, Comparable, Sendable, CaseIterable {
    case none, bronze, silver, gold
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    public var title: String { ["A little beginning", "Bronze", "Silver", "Gold"][rawValue] }
}

public struct ChallengeCosmetic: Equatable, Sendable {
    public let name: String
    public let motif: String
    public let color: String
}

public enum ChallengeCatalog {
    public static func cosmetic(for monthKey: String) -> ChallengeCosmetic {
        switch monthKey {
        case "2026-10": return .init(name: "Pumpkin Cape", motif: "leaf", color: "pumpkin")
        case "2026-11": return .init(name: "Acorn Scarf", motif: "leaf", color: "amber")
        case "2026-12": return .init(name: "Snowflake Collar", motif: "snowflake", color: "frost")
        case "2027-01": return .init(name: "Starlight Scarf", motif: "star", color: "lilac")
        default: return .init(name: "Moonlight Scarf", motif: "moon", color: "sage")
        }
    }
}

public struct MonthlyChallenge: Equatable, Sendable {
    public let monthKey: String
    public let hatches: Int
    public let tier: ChallengeTier
    public let symbols: [HatchDaySymbol]
    public let firstWeekday: Int
    public var cosmetic: ChallengeCosmetic { ChallengeCatalog.cosmetic(for: monthKey) }
    public var nextTier: ChallengeTier? { ChallengeTier(rawValue: tier.rawValue + 1) }
    public var hatchesToNextTier: Int? { nextTier.flatMap { Tuning.challengeThresholds[$0] }.map { max(0, $0 - hatches) } }
    public static func make(state: GameState, monthKey: String, calendar: Calendar = .current) -> Self {
        make(history: state.history, monthKey: monthKey, calendar: calendar,
             savedCount: state.challengeHatchCounts?[monthKey])
    }
    public static func make(history: [HatchRecord], monthKey: String, calendar: Calendar = .current,
                            savedCount: Int? = nil) -> Self {
        guard let start = SocialCalendar.monthStart(monthKey, calendar: calendar),
              let range = calendar.range(of: .day, in: .month, for: start) else {
            return Self(monthKey: monthKey, hatches: 0, tier: .none, symbols: [], firstWeekday: 1)
        }
        let records = history.filter { $0.source == .egg && ($0.challengeMonthKey ?? SocialCalendar.monthKey($0.hatchedAt, calendar: calendar)) == monthKey }
        let count = max(records.count, savedCount ?? 0)
        let tier = ChallengeTier.allCases.last { (Tuning.challengeThresholds[$0] ?? 0) <= count } ?? .none
        var symbols = Array(repeating: HatchDaySymbol.egg, count: range.count)
        for record in records {
            let index = (record.challengeDay ?? calendar.component(.day, from: record.hatchedAt)) - 1
            if symbols.indices.contains(index), symbols[index] != .shiny { symbols[index] = record.isShiny ? .shiny : .bat }
        }
        return Self(monthKey: monthKey, hatches: count, tier: tier, symbols: symbols,
                    firstWeekday: calendar.component(.weekday, from: start))
    }
}

/// Materialize legacy rewards before a transport trims the supporting history.
struct ChallengeArchive {
    var counts: [String: Int] = [:]
    var outfits: [String: [String: ChallengeTier]] = [:]
    init(history: [HatchRecord], calendar: Calendar = .current) {
        let records = history.filter { $0.source == .egg }
        for record in records {
            let key = record.challengeMonthKey ?? SocialCalendar.monthKey(record.hatchedAt, calendar: calendar)
            counts[key, default: 0] += 1
        }
        for record in records {
            let key = record.challengeMonthKey ?? SocialCalendar.monthKey(record.hatchedAt, calendar: calendar)
            let tier = ChallengeTier.allCases.last { (Tuning.challengeThresholds[$0] ?? 0) <= (counts[key] ?? 0) } ?? .none
            outfits[record.speciesID, default: [:]][key] = tier
        }
    }
}

public enum OutfitPreference: Codable, Equatable, Sendable { case latest, none, month(String) }
public struct ChallengeOutfit: Equatable, Sendable, Identifiable {
    public var id: String { monthKey }
    public let monthKey: String
    public let tier: ChallengeTier
    public var cosmetic: ChallengeCosmetic { ChallengeCatalog.cosmetic(for: monthKey) }
}

public extension GameState {
    func earnedOutfits(for speciesID: String, calendar: Calendar = .current) -> [ChallengeOutfit] {
        if let saved = earnedChallengeOutfits {
            return (saved[speciesID] ?? [:]).sorted { $0.key > $1.key }.map { ChallengeOutfit(monthKey: $0.key, tier: $0.value) }
        }
        let months = Set(history.filter { $0.speciesID == speciesID && $0.source == .egg }
            .map { $0.challengeMonthKey ?? SocialCalendar.monthKey($0.hatchedAt, calendar: calendar) })
        return months.sorted(by: >).compactMap { key in
            let challenge = MonthlyChallenge.make(history: history, monthKey: key, calendar: calendar)
            return challenge.tier == .none ? nil : ChallengeOutfit(monthKey: key, tier: challenge.tier)
        }
    }
    func outfit(for speciesID: String, calendar: Calendar = .current) -> ChallengeOutfit? {
        let earned = earnedOutfits(for: speciesID, calendar: calendar)
        switch outfitPreferences?[speciesID] ?? .latest {
        case .latest: return earned.first
        case .none: return nil
        case .month(let key): return earned.first { $0.monthKey == key }
        }
    }
}

public struct PhoneReminder: Equatable, Sendable {
    public let id: String
    public let date: Date
    public let title: String
    public let body: String
}

public enum PhoneReminderPlan {
    /// Finite local schedule, refreshed when the mirrored collection changes or the app opens.
    public static func make(history: [HatchRecord], now: Date, weekly: Bool, challenge: Bool,
                            calendar: Calendar = .current, savedMonthCounts: [String: Int]? = nil) -> [PhoneReminder] {
        guard weekly || challenge else { return [] }
        let currentMonth = SocialCalendar.monthKey(now, calendar: calendar)
        let progress = MonthlyChallenge.make(history: history, monthKey: currentMonth, calendar: calendar,
                                             savedCount: savedMonthCounts?[currentMonth])
        var result: [PhoneReminder] = []
        for offset in 0..<60 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day), date > now else { continue }
            let key = SocialCalendar.monthKey(day, calendar: calendar)
            let dayNumber = calendar.component(.day, from: day)
            if weekly && calendar.component(.weekday, from: day) == 1 {
                result.append(.init(id: "batwalk.phone.week.\(DayKey.make(day, calendar: calendar))", date: date,
                                    title: "Your Batwalk week is ready", body: "A little collection of hellos, ready to share."))
            }
            guard challenge else { continue }
            if dayNumber == 1 {
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.calendar = calendar
                formatter.timeZone = calendar.timeZone; formatter.dateFormat = "MMMM"
                result.append(.init(id: "batwalk.phone.month.\(key)", date: date,
                                    title: "\(formatter.string(from: day))'s challenge: the \(ChallengeCatalog.cosmetic(for: key).name)",
                                    body: "Little meetings, a new outfit. Every bat is always yours to discover."))
            }
            guard key == currentMonth, let lastDay = calendar.range(of: .day, in: .month, for: day)?.count else { continue }
            let isMiddle = dayNumber == 15 && progress.hatches > 0
            let isEnd = dayNumber == lastDay - 2
            guard isMiddle || isEnd else { continue }
            let body: String
            if let next = progress.nextTier, let distance = progress.hatchesToNextTier {
                body = "\(progress.hatches) \(progress.hatches == 1 ? "bat" : "bats") this month — \(next.title) is \(distance) away."
            } else { body = "Your \(progress.cosmetic.name) has its Gold glow. A little memory to share." }
            result.append(.init(id: "batwalk.phone.\(isMiddle ? "middle" : "end").\(key)", date: date,
                                title: "This month's little meetings", body: body))
        }
        return result.sorted { $0.date < $1.date }
    }
}
