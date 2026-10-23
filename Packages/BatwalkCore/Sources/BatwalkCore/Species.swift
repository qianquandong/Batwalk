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
    /// Batpedia number (1–20 launch roster, 21–32 Oddball Bats).
    public let number: Int
    public let name: String
    public let rarity: Rarity
    /// Personality / visual hook from the PRD roster (art brief).
    public let hook: String
    /// Part of the free tier.
    public var isFree: Bool { true }
    /// Display-only lore from the concept board. Does not affect Friendship gain.
    public let favoriteFruit: String?
    /// Display-only Batpedia fun fact: the real bat species this one is based on
    /// (PRD §6.3). Nil for the original fantasy roster.
    public let realLifeCousin: String?
    /// Content wave this species ships in: 1 = launch roster, 2 = first content
    /// update (Oddball Bats). See `Roster.enabledWave`.
    public let wave: Int

    public init(id: String, number: Int, name: String, rarity: Rarity, hook: String,
                isFree: Bool = false, favoriteFruit: String? = nil, realLifeCousin: String? = nil,
                wave: Int = 1) {
        self.id = id
        self.number = number
        self.name = name
        self.rarity = rarity
        self.hook = hook
        self.favoriteFruit = favoriteFruit
        self.realLifeCousin = realLifeCousin
        self.wave = wave
    }
}

/// The 20-bat launch roster (PRD §6) plus the 12 Oddball Bats (PRD §6.3),
/// each a cute take on a real, genuinely strange bat species.
///
/// Content ships in waves (Q12, decided 2026-10-10): wave 1 is the launch
/// roster, wave 2 the Oddball Bats as the first content update. Species from
/// later waves stay in `catalog` so saves, Batpedia numbers and asset names
/// never break; only `all` and the egg pools are gated.
public enum Roster {
    /// Highest content wave this build offers. Apps set it once at launch from
    /// their build configuration (`BatwalkContentWave`); tests and demo modes may raise it.
    nonisolated(unsafe) public static var enabledWave = 1

    /// Every species ever designed, in Batpedia order, including unshipped waves.
    public static let catalog: [Species] = [
        Species(id: "mochi", number: 1, name: "Mochi Bat", rarity: .common,
                hook: "Round, sleepy, friendly starter mascot", isFree: true, favoriteFruit: "Berry"),
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
                hook: "Pink/red, strawberry motif, cheerful", favoriteFruit: "Strawberry"),
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
                hook: "Deep blue, moon motifs, mysterious", favoriteFruit: "Moon Berry"),
        Species(id: "golden", number: 16, name: "Golden Bat", rarity: .rare,
                hook: "Gold accents, confident sparkle"),
        Species(id: "crystal", number: 17, name: "Crystal Bat", rarity: .rare,
                hook: "Blue/purple crystalline wings"),
        Species(id: "vampire", number: 18, name: "Vampire Bat", rarity: .rare,
                hook: "Cute black/red cape, dramatic not scary"),
        Species(id: "galaxy", number: 19, name: "Galaxy Bat", rarity: .legendary,
                hook: "Starfield body, premium particles", favoriteFruit: "Star Fruit"),
        Species(id: "eclipse", number: 20, name: "Eclipse Bat", rarity: .legendary,
                hook: "Black/gold halo, silent and rare"),

        // MARK: Oddball Bats (PRD §6.3) — cute takes on real, strange species.

        Species(id: "bumblebee", number: 21, name: "Bumblebee Bat", rarity: .common,
                hook: "Thumb-sized, piggy nose, buzzes when it flies",
                realLifeCousin: "Kitti's hog-nosed bat weighs about 2 g — one of the smallest mammals on Earth.",
                wave: 2),
        Species(id: "sticky", number: 22, name: "Sticky Bat", rarity: .common,
                hook: "Suction-cup thumbs, naps head-up in a rolled leaf",
                realLifeCousin: "Spix's disk-winged bat sticks to slippery leaves with suction disks and roosts head-up.",
                wave: 2),
        Species(id: "marshmallow", number: 23, name: "Marshmallow Bat", rarity: .uncommon,
                hook: "Snow-white puff, yellow nose and ears, sleeps in a leaf tent",
                favoriteFruit: "Fig",
                realLifeCousin: "The Honduran white bat nibbles leaves into little tents and huddles underneath.",
                wave: 2),
        Species(id: "honk", number: 24, name: "Honk Bat", rarity: .uncommon,
                hook: "Big goofy snout, honks when happy",
                favoriteFruit: "Mango",
                realLifeCousin: "Male hammer-headed bats gather at night and honk loudly to impress females.",
                wave: 2),
        Species(id: "ember", number: 25, name: "Ember Bat", rarity: .uncommon,
                hook: "Bright orange with black-trimmed wings, hides in dry leaves",
                realLifeCousin: "The painted bat's bright orange-and-black coloring may help it hide among dry leaves.",
                wave: 2),
        Species(id: "nectar", number: 26, name: "Nectar Bat", rarity: .uncommon,
                hook: "Super-long tongue, blep, always sipping flowers",
                favoriteFruit: "Banana",
                realLifeCousin: "The tube-lipped nectar bat's tongue is about 1.5× its body length and tucks into its rib cage.",
                wave: 2),
        Species(id: "tube-nose", number: 27, name: "Tube-Nose Bat", rarity: .uncommon,
                hook: "Snorkel nostrils, speckled wings, wise old face",
                favoriteFruit: "Guava",
                realLifeCousin: "Tube-nosed fruit bats have tubular nostrils and yellow-spotted wings.",
                wave: 2),
        Species(id: "polka", number: 28, name: "Polka Bat", rarity: .rare,
                hook: "Black with three white spots, gigantic pink ears",
                realLifeCousin: "The spotted bat has the biggest ears of any North American bat, and its calls are audible to people.",
                wave: 2),
        Species(id: "wrinkle", number: 29, name: "Wrinkle Bat", rarity: .rare,
                hook: "Squishy wrinkly face, hides behind a fluffy chin mask when shy",
                realLifeCousin: "Male wrinkle-faced bats pull a furry chin fold up over their face like a mask.",
                wave: 2),
        Species(id: "walker", number: 30, name: "Walker Bat", rarity: .rare,
                hook: "Folds its wings and power-walks everywhere — Batwalk's spirit animal",
                realLifeCousin: "New Zealand's lesser short-tailed bat folds its wings and scurries along the forest floor to hunt.",
                wave: 2),
        Species(id: "fox", number: 31, name: "Fox Bat", rarity: .rare,
                hook: "Huge cloak-like wings, fox face, golden crown of fur",
                favoriteFruit: "Fig",
                realLifeCousin: "The giant golden-crowned flying fox is one of the largest bats, with wings up to about 1.7 m across.",
                wave: 2),
        Species(id: "ghost", number: 32, name: "Ghost Bat", rarity: .legendary,
                hook: "Pale glow, see-through wings, gentle never spooky",
                realLifeCousin: "Australia's ghost bat has pale, ghostly fur, enormous ears and thin pale wings.",
                wave: 2),
    ]

    /// Species the player can meet in this build (enabled waves only).
    public static var all: [Species] { catalog.filter { $0.wave <= enabledWave } }

    private static let byID: [String: Species] =
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

    /// Looks up any catalogued species, shipped or not, so old saves always resolve.
    public static func species(_ id: String) -> Species? { byID[id] }

    /// Whether a species is in an enabled wave (and so can appear in egg pools).
    public static func isAvailable(_ id: String) -> Bool {
        guard let species = byID[id] else { return false }
        return species.wave <= enabledWave
    }

    public static var freeSpecies: [Species] { all.filter(\.isFree) }
}
