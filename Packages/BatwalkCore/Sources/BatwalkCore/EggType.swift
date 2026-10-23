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

    /// Every egg is free and selectable. Raw values remain stable save keys.
    public var isFree: Bool { true }
    public var isPickable: Bool { true }

    /// Only used to seal a pre-v2 save with its original entitlement rules.
    var legacyIsFree: Bool { self == .starter || self == .tiny }

    /// Species that can hatch from this egg for every player,
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
            // Long Ear keeps its established Tiny / Forest identity.
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

    /// All enabled species in the designed pool are available without payment.
    public var freePool: [String] { pool }

    /// The old argument remains source-compatible; entitlement cannot change odds.
    public func pool(isUnlocked: Bool) -> [String] { pool }

    public static func pickable(isUnlocked: Bool) -> [EggType] { allCases }

    /// Migration only: do not change an unsealed v1 egg's original outcome.
    func legacyPool(isUnlocked: Bool) -> [String] {
        if isUnlocked { return pool }
        switch self {
        case .starter: return ["mochi"]
        case .tiny: return ["mochi", "cocoa", "long-ear"]
        case .forest, .moon, .crystal: return []
        }
    }

    /// The first pickable egg a species is designed to hatch from (Batpedia "Primary Egg").
    public static func primaryEgg(for speciesID: String) -> EggType {
        allCases.first { $0.isPickable && $0.designedPool.contains(speciesID) } ?? .tiny
    }
}
