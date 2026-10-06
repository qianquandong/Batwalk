import Foundation

/// Day / Dusk / Night from local device time (PRD §2.3).
/// Daytime is never a lockout: Day = companionship, Night = activity.
public enum TimeOfDay: String, Codable, CaseIterable, Sendable {
    case day
    case dusk
    case night

    public static func at(_ date: Date, calendar: Calendar = .current, tuning: Tuning = .default) -> TimeOfDay {
        let hour = calendar.component(.hour, from: date)
        if hour >= tuning.dayStartHour && hour < tuning.duskStartHour { return .day }
        if hour >= tuning.duskStartHour && hour < tuning.nightStartHour { return .dusk }
        return .night
    }
}

/// What the egg sprite should show for a progress fraction (PRD §3.5).
public enum EggVisualState: String, Codable, CaseIterable, Sendable {
    case calm       // 0–25%
    case shaking    // 25–50%
    case cracked    // 50–75%
    case rattling   // 75–99%
    case ready      // 100% → haptic + tap-to-reveal

    public static func forProgress(_ progress: Double) -> EggVisualState {
        switch progress {
        case ..<0.25: return .calm
        case ..<0.50: return .shaking
        case ..<0.75: return .cracked
        case ..<1.0: return .rattling
        default: return .ready
        }
    }
}

/// Bat animation states (PRD §4.3 minus `egg`/`hatchReady`, which are egg states).
public enum BatMood: String, Codable, CaseIterable, Sendable {
    case sleeping, drowsy, awake, happy, eating, playing

    /// Resting mood for a time of day, before any interaction.
    public static func resting(at time: TimeOfDay) -> BatMood {
        switch time {
        case .day: return .sleeping
        case .dusk: return .drowsy
        case .night: return .awake
        }
    }
}

/// Friendship levels Lv.1–Lv.5 (PRD §2.7).
public enum Friendship {
    public static let maxLevel = 5

    public static func level(forEXP exp: Int, tuning: Tuning = .default) -> Int {
        var level = 1
        for (index, threshold) in tuning.friendshipThresholds.enumerated() where exp >= threshold {
            level = index + 1
        }
        return min(level, maxLevel)
    }

    /// Progress toward the next level in [0, 1]; 1 at max level.
    public static func progressToNext(exp: Int, tuning: Tuning = .default) -> Double {
        let current = Friendship.level(forEXP: exp, tuning: tuning)
        guard current < maxLevel, current < tuning.friendshipThresholds.count else { return 1 }
        let lower = tuning.friendshipThresholds[current - 1]
        let upper = tuning.friendshipThresholds[current]
        return Double(exp - lower) / Double(max(1, upper - lower))
    }
}
