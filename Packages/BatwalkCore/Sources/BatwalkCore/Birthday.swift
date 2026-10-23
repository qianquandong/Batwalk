import Foundation

/// A birthday without a birth year. Leap-day birthdays are observed on February 28
/// in non-leap years, using the player's local time zone and Gregorian month/day.
public struct MonthDay: Codable, Equatable, Hashable, Sendable {
    public let month: Int
    public let day: Int

    public init?(month: Int, day: Int) {
        guard (1...12).contains(month), (1...Self.days(in: month)).contains(day) else { return nil }
        self.month = month; self.day = day
    }

    public static func days(in month: Int) -> Int {
        switch month {
        case 2: return 29
        case 4, 6, 9, 11: return 30
        case 1, 3, 5, 7, 8, 10, 12: return 31
        default: return 0
        }
    }

    public func matches(_ date: Date, calendar: Calendar = .current) -> Bool {
        let cal = Self.localGregorian(calendar)
        let parts = cal.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 2000
        let leap = year.isMultiple(of: 400) || (year.isMultiple(of: 4) && !year.isMultiple(of: 100))
        let observedDay = month == 2 && day == 29 && !leap ? 28 : day
        return parts.month == month && parts.day == observedDay
    }

    public static func year(at date: Date, calendar: Calendar = .current) -> Int {
        localGregorian(calendar).component(.year, from: date)
    }

    private static func localGregorian(_ calendar: Calendar) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = calendar.timeZone
        return result
    }

    private enum CodingKeys: String, CodingKey { case month, day }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let month = try c.decode(Int.self, forKey: .month)
        let day = try c.decode(Int.self, forKey: .day)
        guard let value = Self(month: month, day: day) else {
            throw DecodingError.dataCorruptedError(forKey: .day, in: c, debugDescription: "Invalid birthday month/day")
        }
        self = value
    }
}

public extension GameState {
    /// A temporary hat on the companion needs no hatch and never changes the save.
    /// A permanent keepsake remains visible on its bat on every other day.
    func birthdayHatYear(for speciesID: String, now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let bat = collection[speciesID] else { return nil }
        if companionID == speciesID, birthday?.matches(now, calendar: calendar) == true {
            return MonthDay.year(at: now, calendar: calendar)
        }
        return bat.birthdayYears?.max()
    }
}
