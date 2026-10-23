import Foundation

/// Deterministic PRNG (SplitMix64). Each egg stores its seed when it is created,
/// so the hatch outcome is fixed for that egg: force-quitting before the reveal
/// cannot reroll the result.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in [0, 1).
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0) // 2^53
    }
}

public struct HatchRoll: Equatable, Sendable {
    public let species: Species
    public let isShiny: Bool
}

/// Picks what comes out of an egg. Pure function of (egg, seed, tuning); payment never changes a roll.
public enum HatchEngine {
    public static func roll(
        egg: EggType,
        seed: UInt64,
        isUnlocked: Bool,
        tuning: Tuning = .default
    ) -> HatchRoll {
        roll(egg: egg, seed: seed, candidates: egg.pool, shinyAllowed: true, tuning: tuning)
    }

    /// Only the v1 save migration may use the old paid/free split.
    static func legacyRoll(egg: EggType, seed: UInt64, isUnlocked: Bool) -> HatchRoll {
        roll(egg: egg, seed: seed, candidates: egg.legacyPool(isUnlocked: isUnlocked),
             shinyAllowed: isUnlocked, tuning: .default)
    }

    private static func roll(egg: EggType, seed: UInt64, candidates ids: [String],
                             shinyAllowed: Bool, tuning: Tuning) -> HatchRoll {
        var rng = SeededGenerator(seed: seed)
        let candidates = ids.compactMap(Roster.species)
        precondition(!candidates.isEmpty, "Egg \(egg) has no hatchable species")

        // 1. Rarity, renormalised over the rarities present in this pool.
        let present = Rarity.allCases.filter { r in candidates.contains { $0.rarity == r } }
        let weights = present.map { max(0, tuning.rarityWeights[$0] ?? 0) }
        let rarity = pickWeighted(present, weights: weights, rng: &rng) ?? present[0]

        // 2. Species, uniform within that rarity.
        let tier = candidates.filter { $0.rarity == rarity }
        let index = Int(rng.nextUnit() * Double(tier.count))
        let species = tier[min(index, tier.count - 1)]

        // 3. Shiny — the same chance for everyone.
        let isShiny = shinyAllowed && rng.nextUnit() < tuning.shinyChance

        return HatchRoll(species: species, isShiny: isShiny)
    }

    /// Uniform pick with a seeded generator; nil for an empty list. Used by the
    /// pity rules in `GameState`, which must be as deterministic as the base roll.
    static func pick<T>(_ items: [T], rng: inout SeededGenerator) -> T? {
        guard !items.isEmpty else { return nil }
        let index = Int(rng.nextUnit() * Double(items.count))
        return items[min(index, items.count - 1)]
    }

    static func pickWeighted<T>(_ items: [T], weights: [Double], rng: inout SeededGenerator) -> T? {
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var target = rng.nextUnit() * total
        for (item, weight) in zip(items, weights) {
            if target < weight { return item }
            target -= weight
        }
        return items.last
    }
}
