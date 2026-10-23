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
        Tuning.eggTargetSteps[self]!
    }

    /// Available without the full unlock.
    public var isFree: Bool {
        switch self {
        case .starter, .tiny: return true
        case .forest, .moon, .crystal: return false
        }
    }

    /// The Starter Egg is given once, during onboarding. It is never offered afterwards.
    public var isPickable: Bool { self != .starter }

    /// Species that can hatch from this egg for a player with the full unlock,
    /// limited to the content waves enabled in this build (`Roster.enabledWave`).
    /// Derived from the "Primary Egg" column of the PRD roster (§6, §6.3).
    public var pool: [String] { designedPool.filter(Roster.isAvailable) }

    /// The full designed pool, including species from waves not shipped yet.
    public var designedPool: [String] {
        switch self {
        case .starter:
            // First hatch is always the mascot — guaranteed delightful first success.
            return ["mochi"]
        // Oddball Bats (PRD §6.3) are listed after each egg's launch species.
        case .tiny:
            // Long Ear joins the paid Tiny pool so the free roster's third bat has a
            // free egg to come from (Q1, decided 2026-10-10: Primary Egg "Tiny / Forest").
            return ["mochi", "cocoa", "long-ear", "cave", "sleepy", "pebble",
                    "bumblebee", "sticky"]
        case .forest:
            // Kept Common + Uncommon only, so Forest odds are unchanged (Q6).
            return ["long-ear", "fruit", "cave", "dust", "strawberry", "blossom", "moss", "sunset",
                    "marshmallow", "honk", "ember", "nectar"]
        case .moon:
            return ["sunset", "moonwing", "vampire", "galaxy", "eclipse",
                    "tube-nose", "polka", "wrinkle"]
        case .crystal:
            // The longest walk is where the Walker Bat lives.
            return ["snow", "cloud", "golden", "crystal", "galaxy",
                    "walker", "fox", "ghost"]
        }
    }

    /// Species pool for a free-tier player: exactly the free species, from the free eggs.
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

    /// Eggs the player can choose after a hatch (without the free trial egg —
    /// see `GameState.pickableEggs`).
    public static func pickable(isUnlocked: Bool) -> [EggType] {
        allCases.filter { $0.isPickable && (isUnlocked || $0.isFree) }
    }

    /// The first pickable egg a species is designed to hatch from (Batpedia "Primary Egg").
    public static func primaryEgg(for speciesID: String) -> EggType {
        allCases.first { $0.isPickable && $0.designedPool.contains(speciesID) } ?? .tiny
    }
}
