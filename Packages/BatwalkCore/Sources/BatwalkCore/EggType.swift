import Foundation

/// Egg types (PRD §2.6). Each egg has a step target and a species pool.
public enum EggType: String, Codable, CaseIterable, Sendable {
    case starter
    case tiny
    case forest
    case moon
    case crystal

    public var displayName: String {
        switch self {
        case .starter: return "Starter Egg"
        case .tiny: return "Tiny Egg"
        case .forest: return "Forest Egg"
        case .moon: return "Moon Egg"
        case .crystal: return "Crystal Egg"
        }
    }

    /// Steps required to hatch.
    public var targetSteps: Int {
        switch self {
        case .starter: return 2_000
        case .tiny: return 2_500
        case .forest: return 4_000
        case .moon: return 5_000
        case .crystal: return 6_000
        }
    }

    /// Available without the $1.99 unlock.
    public var isFree: Bool {
        switch self {
        case .starter, .tiny: return true
        case .forest, .moon, .crystal: return false
        }
    }

    /// The Starter Egg is given once, during onboarding. It is never offered afterwards.
    public var isPickable: Bool { self != .starter }

    /// Species that can hatch from this egg for a player with the full unlock.
    /// Derived from the "Primary Egg" column of the PRD roster (§6).
    public var pool: [String] {
        switch self {
        case .starter:
            // First hatch is always the mascot — guaranteed delightful first success.
            return ["mochi"]
        case .tiny:
            return ["mochi", "cocoa", "cave", "sleepy", "pebble"]
        case .forest:
            return ["long-ear", "fruit", "cave", "dust", "strawberry", "blossom", "moss", "sunset"]
        case .moon:
            return ["sunset", "moonwing", "vampire", "galaxy", "eclipse"]
        case .crystal:
            return ["snow", "cloud", "golden", "crystal", "galaxy"]
        }
    }

    /// Species pool for a free-tier player.
    ///
    /// NOTE (open question Q1 in docs/OPEN_QUESTIONS.md): the PRD's free roster is
    /// Mochi + Cocoa + Long Ear, but Long Ear's primary egg is Forest (a paid egg).
    /// Until that is decided, the free Tiny Egg yields exactly the three free species.
    public var freePool: [String] {
        switch self {
        case .starter: return ["mochi"]
        case .tiny: return Roster.freeSpecies.map(\.id)
        case .forest, .moon, .crystal: return []
        }
    }

    public func pool(isUnlocked: Bool) -> [String] {
        isUnlocked ? pool : freePool
    }

    /// Eggs the player can choose after a hatch.
    public static func pickable(isUnlocked: Bool) -> [EggType] {
        allCases.filter { $0.isPickable && (isUnlocked || $0.isFree) }
    }
}
