import Foundation

/// A decorative, offline phase estimate, not an astronomical ephemeris.
/// Uses the mean synodic month (29.530588 days) from NASA's phase tables:
/// https://eclipse.gsfc.nasa.gov/phase/phases0001.html
/// Reference new moon: 2000-01-06 18:15 UTC (NASA lunar phases table).
public enum MoonPhase: Int, CaseIterable, Codable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous
    case fullMoon, waningGibbous, lastQuarter, waningCrescent

    public static func on(_ date: Date) -> MoonPhase {
        let reference = Date(timeIntervalSince1970: 947_182_500)
        let cycle = 29.530588 * 86_400
        let elapsed = date.timeIntervalSince(reference).truncatingRemainder(dividingBy: cycle)
        let fraction = (elapsed < 0 ? elapsed + cycle : elapsed) / cycle
        return MoonPhase(rawValue: Int((fraction * 8 + 0.5).rounded(.down)) % 8)!
    }

    public var name: String {
        switch self {
        case .newMoon: return "New moon"
        case .waxingCrescent: return "Waxing crescent"
        case .firstQuarter: return "First quarter"
        case .waxingGibbous: return "Waxing gibbous"
        case .fullMoon: return "Full moon"
        case .waningGibbous: return "Waning gibbous"
        case .lastQuarter: return "Last quarter"
        case .waningCrescent: return "Waning crescent"
        }
    }
    public var symbol: String { ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"][rawValue] }
}
