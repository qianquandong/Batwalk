import Foundation

/// Rarity tiers. Order matters: it is used for sorting and for display.
public enum Rarity: String, Codable, CaseIterable, Comparable, Sendable {
    case common
    case uncommon
    case rare
    case legendary

    public var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .legendary: return "Legendary"
        }
    }

    private var order: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .legendary: return 3
        }
    }

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.order < rhs.order }
}

/// A bat species. Species identity is fixed; the player's nickname lives on `OwnedBat`.
public struct Species: Identifiable, Hashable, Codable, Sendable {
    /// Stable string ID. Never change once shipped — it is the save-file key
    /// and the sprite-sheet prefix (`<id>_<anim>.png`).
    public let id: String
    /// Batpedia number (1–20 at launch).
    public let number: Int
    public let name: String
    public let rarity: Rarity
    /// Personality / visual hook from the PRD roster (art brief).
    public let hook: String
    /// Part of the free tier.
    public let isFree: Bool

    public init(id: String, number: Int, name: String, rarity: Rarity, hook: String, isFree: Bool = false) {
        self.id = id
        self.number = number
        self.name = name
        self.rarity = rarity
        self.hook = hook
        self.isFree = isFree
    }
}

/// The 20-bat launch roster (PRD §6).
public enum Roster {
    public static let all: [Species] = [
        Species(id: "mochi", number: 1, name: "Mochi Bat", rarity: .common,
                hook: "Round, sleepy, friendly starter mascot", isFree: true),
        Species(id: "cocoa", number: 2, name: "Cocoa Bat", rarity: .common,
                hook: "Chocolate brown, calm, wraps in wings", isFree: true),
        Species(id: "long-ear", number: 3, name: "Long Ear Bat", rarity: .common,
                hook: "Oversized ears, curious reactions", isFree: true),
        Species(id: "fruit", number: 4, name: "Fruit Bat", rarity: .common,
                hook: "Round face, food-loving"),
        Species(id: "cave", number: 5, name: "Cave Bat", rarity: .common,
                hook: "Shy, hides in wings"),
        Species(id: "sleepy", number: 6, name: "Sleepy Bat", rarity: .common,
                hook: "Half-closed eyes, tiny sleep cap"),
        Species(id: "dust", number: 7, name: "Dust Bat", rarity: .common,
                hook: "Fluffy gray, clumsy flight"),
        Species(id: "pebble", number: 8, name: "Pebble Bat", rarity: .common,
                hook: "Stone-like round sleeper"),
        Species(id: "strawberry", number: 9, name: "Strawberry Bat", rarity: .uncommon,
                hook: "Pink/red, strawberry motif, cheerful"),
        Species(id: "blossom", number: 10, name: "Blossom Bat", rarity: .uncommon,
                hook: "Soft pink, petal particles"),
        Species(id: "moss", number: 11, name: "Moss Bat", rarity: .uncommon,
                hook: "Green/brown, tiny sprout"),
        Species(id: "sunset", number: 12, name: "Sunset Bat", rarity: .uncommon,
                hook: "Orange/purple, energetic at dusk"),
        Species(id: "snow", number: 13, name: "Snow Bat", rarity: .uncommon,
                hook: "White/blue, snowflake particles"),
        Species(id: "cloud", number: 14, name: "Cloud Bat", rarity: .uncommon,
                hook: "Fluffy white-gray, dreamy"),
        Species(id: "moonwing", number: 15, name: "Moonwing", rarity: .rare,
                hook: "Deep blue, moon motifs, mysterious"),
        Species(id: "golden", number: 16, name: "Golden Bat", rarity: .rare,
                hook: "Gold accents, confident sparkle"),
        Species(id: "crystal", number: 17, name: "Crystal Bat", rarity: .rare,
                hook: "Blue/purple crystalline wings"),
        Species(id: "vampire", number: 18, name: "Vampire Bat", rarity: .rare,
                hook: "Cute black/red cape, dramatic not scary"),
        Species(id: "galaxy", number: 19, name: "Galaxy Bat", rarity: .legendary,
                hook: "Starfield body, premium particles"),
        Species(id: "eclipse", number: 20, name: "Eclipse Bat", rarity: .legendary,
                hook: "Black/gold halo, silent and rare"),
    ]

    private static let byID: [String: Species] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func species(_ id: String) -> Species? { byID[id] }

    public static var freeSpecies: [Species] { all.filter(\.isFree) }
}
