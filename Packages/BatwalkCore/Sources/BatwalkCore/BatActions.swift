import Foundation

// Bat actions (docs/BAT_ACTIONS.md). Tamagotchi-style: every bat shares five
// universal actions, and each species has its own signature actions taken
// from a real bat behaviour. Unique actions unlock with Friendship (PRD §2.7),
// so a bond only ever adds behaviour — nothing is ever taken away.

/// The five actions every bat has (concept board: Idle · Sleep · Fly · Pet · Eat).
public enum UniversalAction: String, CaseIterable, Sendable {
    case idle, sleep, fly, pet, eat

    /// The pose each one plays, in the existing `bat_<id>_<mood>` sprite contract.
    public var mood: BatMood {
        switch self {
        case .idle: return .awake
        case .sleep: return .sleeping
        case .fly: return .playing
        case .pet: return .happy
        case .eat: return .eating
        }
    }
}

/// When a unique action may play. All are moments the player is already
/// looking at the bat — nothing polls or runs in the background (battery rules).
public enum ActionTrigger: String, CaseIterable, Sendable {
    /// A random beat while the bat is awake at night.
    case idleNight
    /// The dusk wake-up.
    case dusk
    /// While the bat sleeps during the day.
    case asleep
    /// Right after the player pets the bat.
    case pet
    /// Right after the player feeds the bat.
    case feed
    /// Opening the app after new steps were credited ("while you walked").
    case walkReturn
    /// The first look of a new local day.
    case newDay
    /// The hatch reveal.
    case hatch
    /// A rare random beat (legendary secrets).
    case rare
}

/// Which slot an action fills, and so which Friendship level unlocks it.
public enum ActionTier: String, CaseIterable, Sendable {
    /// PRD §2.7 Lv.2 — "additional idle animation".
    case idleQuirk
    /// PRD §2.7 Lv.3 — "new interaction reaction".
    case reaction
    /// PRD §2.7 Lv.4 — "special signature animation".
    case signature
    /// Legendary only: its own hatch entrance, seen from the very first hatch.
    case hatchReveal
    /// Legendary only: a rare secret at Lv.5, alongside the Friendship badge.
    case secret

    public var unlockLevel: Int {
        switch self {
        case .hatchReveal: return 1
        case .idleQuirk: return 2
        case .reaction: return 3
        case .signature: return 4
        case .secret: return 5
        }
    }
}

/// One species-specific action.
public struct BatAction: Hashable, Sendable {
    public let speciesID: String
    /// Stable slug, unique within the species. Never change once art exists:
    /// it is the asset name `bat_<speciesID>_<id>` (see Art/README.md).
    public let id: String
    public let name: String
    public let tier: ActionTier
    public let trigger: ActionTrigger
    /// What the animation shows (art brief).
    public let summary: String
    /// The real bat behaviour it comes from (sources in docs/BAT_ACTIONS.md).
    public let realBasis: String

    public var unlockLevel: Int { tier.unlockLevel }
    public var assetName: String { "bat_\(speciesID)_\(id)" }
}

public enum ActionCatalog {
    /// Unique actions for a species, in unlock order.
    public static func actions(for speciesID: String) -> [BatAction] {
        bySpecies[speciesID] ?? []
    }

    /// Unique actions available at a Friendship level.
    public static func unlocked(for speciesID: String, friendshipLevel: Int) -> [BatAction] {
        actions(for: speciesID).filter { $0.unlockLevel <= friendshipLevel }
    }

    /// Unlocked actions that may play for a trigger. Empty means "play the universal action".
    public static func available(for speciesID: String, friendshipLevel: Int,
                                 trigger: ActionTrigger) -> [BatAction] {
        unlocked(for: speciesID, friendshipLevel: friendshipLevel).filter { $0.trigger == trigger }
    }

    /// The action unlocked exactly at a level, if any — for the "new action!" moment on level-up.
    public static func newlyUnlocked(for speciesID: String, atLevel level: Int) -> [BatAction] {
        actions(for: speciesID).filter { $0.unlockLevel == level }
    }

    private static let bySpecies: [String: [BatAction]] =
        Dictionary(grouping: all, by: \.speciesID)
            .mapValues { $0.sorted { $0.unlockLevel < $1.unlockLevel } }

    private static func act(_ species: String, _ id: String, _ name: String,
                            _ tier: ActionTier, _ trigger: ActionTrigger,
                            _ summary: String, basis: String) -> BatAction {
        BatAction(speciesID: species, id: id, name: name, tier: tier, trigger: trigger,
                  summary: summary, realBasis: basis)
    }

    public static let all: [BatAction] = launchRoster + oddballs

    // MARK: Launch roster (#1–20)

    private static let launchRoster: [BatAction] = [
        // 1 Mochi — everyday bat behaviour, done adorably.
        act("mochi", "thumb-ear-wash", "Thumb Ear-Wash", .idleQuirk, .idleNight,
            "Licks its thumb and scrubs inside one big ear, then the other.",
            basis: "Bats groom like cats for an hour or more a day, using a licked thumb to clean inside their ears."),
        act("mochi", "wing-eye-mask", "Wing Eye-Mask", .reaction, .pet,
            "Pulls one wing over its eyes like a sleep mask, then peeks out at you.",
            basis: "Bats shade their eyes with a wing on bright days."),
        act("mochi", "cartwheel-landing", "Cartwheel Landing", .signature, .walkReturn,
            "Swoops up, does a half-cartwheel and catches the ceiling feet-first.",
            basis: "Bats land upside down by tucking one wing and flapping the other, flipping in a half-cartwheel."),

        // 2 Cocoa — chocolate wattled bat.
        act("cocoa", "sunrise-doze", "Sunrise Doze", .idleQuirk, .asleep,
            "Melts into a deep morning nap, nose bubble and all, then stretches awake.",
            basis: "Chocolate wattled bats dropped into torpor at sunrise on most summer days and woke mid-morning."),
        act("cocoa", "wattle-wiggle", "Wattle Wiggle", .reaction, .pet,
            "Its little lip wattles wiggle and its pug nose scrunches.",
            basis: "The chocolate wattled bat has a pug nose and a small fleshy lobe (wattle) on its lip."),
        act("cocoa", "creche-babysitter", "Crèche Babysitter", .signature, .idleNight,
            "Tucks three tiny pink pups under one wing and rocks them to sleep.",
            basis: "Chocolate wattled bat colonies keep a crèche where a few adults babysit the pups while the rest hunt."),

        // 3 Long Ear — brown long-eared bat.
        act("long-ear", "ram-horn-ears", "Ram-Horn Ears", .idleQuirk, .asleep,
            "Curls both ears back like ram's horns, then tucks them under its wings.",
            basis: "Resting brown long-eared bats curl their ears back or tuck them under their wings, leaving only the small inner flaps up."),
        act("long-ear", "ladybird-listen", "Ladybird Listen", .reaction, .pet,
            "Freezes, ears swivelling, to follow a ladybird walking across a leaf.",
            basis: "The brown long-eared bat can hear a ladybird walking on a leaf."),
        act("long-ear", "butterfly-hover", "Butterfly Hover", .signature, .idleNight,
            "Goes quiet, hovers like a butterfly, and plucks a snack off a leaf.",
            basis: "It stops calling, hovers, listens, and picks insects straight off leaves."),

        // 4 Fruit — Egyptian fruit bat.
        act("fruit", "fruit-hug", "Fruit Hug", .idleQuirk, .idleNight,
            "Hugs a fruit to its chest and glances left and right for snack thieves.",
            basis: "Egyptian fruit bats carry fruit to a perch and hug it to their chest so neighbours can't steal it."),
        act("fruit", "spat-pop", "Spat Pop", .reaction, .feed,
            "Squishes the fruit, slurps the juice and spits out a tiny pulp pellet: ptoo!",
            basis: "Fruit bats press fruit against the palate, swallow the juice and spit out a pulp pellet called a spat."),
        act("fruit", "squabble-squeaks", "Squabble Squeaks", .signature, .walkReturn,
            "Squeak-argues with an invisible neighbour over a perch, then scoots over to share.",
            basis: "Decoded Egyptian fruit bat calls are mostly squabbles about food, sleeping spots and personal space."),

        // 5 Cave — lesser horseshoe bat + big cave nurseries.
        act("cave", "plum-wrap", "Plum Wrap", .idleQuirk, .asleep,
            "Wraps up into a plum-sized ball and sways gently from the ceiling.",
            basis: "Lesser horseshoe bats hang free with their wings wrapped around them, about the size of a plum."),
        act("cave", "peek-twist", "Peek Twist", .reaction, .pet,
            "Twists around inside its wings to peek at you before deciding you're safe.",
            basis: "A lesser horseshoe bat twists its body to look around before flying off."),
        act("cave", "find-you-call", "Find-You Call", .signature, .walkReturn,
            "Calls into a crowd of tiny sleeping shapes until one answers, then beams.",
            basis: "In huge cave nurseries, mothers find their own pup by voice, scent and memory."),

        // 6 Sleepy — little brown bat and hibernation.
        act("sleepy", "one-big-breath", "One Big Breath", .idleQuirk, .asleep,
            "Snoozes perfectly still, then takes one enormous, slow breath.",
            basis: "A hibernating little brown bat may breathe only about once every 47 minutes."),
        act("sleepy", "groggy-wake", "Groggy Wake", .reaction, .pet,
            "Blinks awake, licks a dewdrop off its fur, mumbles, and is asleep again.",
            basis: "Hibernating bats wake now and then and lick condensation droplets off their fur to drink."),
        act("sleepy", "pitcher-plant-bed", "Pitcher Plant Bed", .signature, .newDay,
            "Climbs into a pitcher plant like a sleeping bag and settles in.",
            basis: "Hardwicke's woolly bat sleeps inside pitcher plants that guide it in with an echo reflector."),

        // 7 Dust — a forever-learning young flier.
        act("dust", "flap-practice", "Flap Practice", .idleQuirk, .idleNight,
            "Hangs and does a burst of frantic wing-flaps, then pants, very proud.",
            basis: "Hanging bat pups practise flight with bursts of fast wing-flapping, peaking around two weeks old."),
        act("dust", "drop-start", "Drop Start", .reaction, .pet,
            "Lets go, plops down, remembers to flap, and flutters back up.",
            basis: "Bats take off by simply letting go and dropping into flight."),
        act("dust", "almost-landing", "Almost Landing", .signature, .walkReturn,
            "Tries the upside-down landing, misses, somersaults, then sticks it in a puff of fluff.",
            basis: "Young free-tailed bats sometimes do a near-somersault to land back on the cave wall."),

        // 8 Pebble — eastern small-footed bat.
        act("pebble", "crack-squeeze", "Crack Squeeze", .idleQuirk, .asleep,
            "Flattens like a pancake and slides into a rock crack until only its mask shows.",
            basis: "Eastern small-footed bats have flattened skulls for squeezing into rock cracks."),
        act("pebble", "bandit-peek", "Bandit Peek", .reaction, .pet,
            "Pops out of its pebble pile wearing its black bandit mask.",
            basis: "The eastern small-footed bat has a black mask across golden fur."),
        act("pebble", "new-rock-every-day", "New Rock Every Day", .signature, .newDay,
            "Each new day it hops to a different pebble and settles in.",
            basis: "It roosts on sunny rock slopes and moves to a new rock nearly every day."),

        // 9 Strawberry — eastern red bat.
        act("strawberry", "one-foot-sway", "One-Foot Sway", .idleQuirk, .asleep,
            "Hangs by one foot and twirls in the breeze like a ripe berry.",
            basis: "Eastern red bats hang by one foot among leaves, twisting in the breeze like a dead leaf."),
        act("strawberry", "tail-blanket", "Tail Blanket", .reaction, .pet,
            "Wraps itself in its furry tail like a blanket until only its face shows.",
            basis: "Red bats wrap themselves almost completely in their furry tail membrane."),
        act("strawberry", "berry-bunch", "Berry Bunch", .signature, .walkReturn,
            "Three tiny pups dangle beside it like a bunch of strawberries.",
            basis: "Eastern red bats usually have about three pups, which hold mum with one foot and the branch with the other."),

        // 10 Blossom — common blossom bat.
        act("blossom", "brush-tongue-sip", "Brush-Tongue Sip", .idleQuirk, .idleNight,
            "Hovers at a flower and paints out nectar with its brushy tongue.",
            basis: "The common blossom bat has a brush-tipped tongue and hovers at or lands on flowers."),
        act("blossom", "pollen-sneeze", "Pollen Sneeze", .reaction, .pet,
            "A pet sends up a puff of pollen from its fur — achoo!",
            basis: "Its fur is built to hold pollen; it carries about six times more than birds do."),
        act("blossom", "flower-patrol", "Flower Patrol", .signature, .dusk,
            "Shoos a rival off its flower patch, then fluffs up proudly.",
            basis: "Common blossom bats guard their flower patches fiercely."),

        // 11 Moss — Seminole bat in Spanish moss.
        act("moss", "moss-hideout", "Moss Hideout", .idleQuirk, .asleep,
            "Burrows into a hanging tuft of Spanish moss, ears poking out.",
            basis: "Seminole bats roost alone inside clumps of Spanish moss in oak trees."),
        act("moss", "let-go-drop", "Let-Go Drop", .reaction, .pet,
            "Lets go of the moss, drops straight down, and swoops back up.",
            basis: "Seminole bats pick roosts with open air below so they can drop straight into flight."),
        act("moss", "sprout-planting", "Sprout Planting", .signature, .walkReturn,
            "Drops a seed as it flies; a tiny sprout pops up behind it.",
            basis: "Bats really replant forests: one fruit bat colony in Ghana spreads over 300,000 seeds a night."),

        // 12 Sunset — free-tailed bat emergence + sunset compass.
        act("sunset", "sunset-compass", "Sunset Compass", .idleQuirk, .dusk,
            "Stares at the sunset glow while a tiny compass needle spins and settles.",
            basis: "Greater mouse-eared bats set their magnetic compass by the sunset glow."),
        act("sunset", "crowd-dodge", "Crowd Dodge", .reaction, .pet,
            "Zig-zags into an invisible crowd of friends and pops out the other side.",
            basis: "Free-tailed bats emerge in a dense crowd so no single bat stands out."),
        act("sunset", "batnado", "Batnado", .signature, .dusk,
            "Spirals up in a swirling column of silhouette friends, then streams away like a river.",
            basis: "Millions of Mexican free-tailed bats spiral out of Bracken Cave at dusk in a 'batnado'."),

        // 13 Snow — hoary bat + frosty hibernation.
        act("snow", "frost-beads", "Frost Beads", .idleQuirk, .asleep,
            "Tiny droplets bead and sparkle all over its fur while it sleeps.",
            basis: "Hibernating bats cool to cave temperature, so condensation beads all over their fur."),
        act("snow", "sleeping-bag", "Sleeping Bag", .reaction, .pet,
            "Shivers, then zips itself into its furry tail like a sleeping bag.",
            basis: "In harsh weather the hoary bat wraps its furry tail membrane around itself like a blanket."),
        act("snow", "great-migration", "Great Migration", .signature, .walkReturn,
            "Pulls on a tiny scarf and flaps off over the horizon — and back.",
            basis: "Hoary bats are long-distance migrants; Hawaii's hoary bats descend from ancestors that crossed 2,000+ miles of ocean."),

        // 14 Cloud — free-tailed bats high in the sky.
        act("cloud", "radar-bloom", "Radar Bloom", .idleQuirk, .idleNight,
            "A ring of tiny dots blooms around it like a cloud on a weather radar.",
            basis: "Bat emergences show up on Doppler weather radar as blooming, ring-shaped clouds."),
        act("cloud", "gust-surf", "Gust Surf", .reaction, .pet,
            "A puff of wind catches it and it surfs the gust, ears flapping.",
            basis: "Radar showed a distant storm's gust front sweeping a Texas cave's bats away like a broom."),
        act("cloud", "sky-high-snack", "Sky-High Snack", .signature, .walkReturn,
            "Rockets up to the clouds, snaps a snack from the wind and zooms back in speed lines.",
            basis: "Free-tailed bats hunt moths on night winds hundreds of metres up, with bursts near 100 mph."),

        // 15 Moonwing — lunar phobia + a termite-nest home.
        act("moonwing", "moon-shy", "Moon Shy", .idleQuirk, .idleNight,
            "When the moon is bright it hides behind a wing and peeks up at it.",
            basis: "Many bats fly less on bright full-moon nights ('lunar phobia')."),
        act("moonwing", "katydid-hush", "Katydid Hush", .reaction, .pet,
            "Holds a wing to its lips — shh — and a tiny katydid goes quiet too.",
            basis: "On bright moonlit nights a Panamanian bat and the katydids it hunts both go quiet."),
        act("moonwing", "termite-mound-den", "Termite-Mound Den", .signature, .asleep,
            "Chews a round, cosy den into a mound and curls up inside.",
            basis: "Male white-throated round-eared bats chew roost cavities into active termite nests."),

        // 16 Golden — golden-tipped bat.
        act("golden", "nest-blend", "Nest Blend", .idleQuirk, .asleep,
            "Fluffs its gold-tipped fur and vanishes into a hanging bird nest.",
            basis: "Golden-tipped bats live in hanging bird nests, their woolly fur blending with the nest fibres."),
        act("golden", "web-pluck", "Web Pluck", .reaction, .pet,
            "Hovers at a dewy spider web and plucks off a snack with a flourish.",
            basis: "It eats almost only orb-weaving spiders, plucking them off their webs."),
        act("golden", "nest-party", "Nest Party", .signature, .walkReturn,
            "The nest wiggles and golden faces pop out one by one — up to twelve.",
            basis: "Up to 12 golden-tipped bats have been found in a single nest."),

        // 17 Crystal — glowing, self-healing wings.
        act("crystal", "blacklight-glow", "Blacklight Glow", .idleQuirk, .idleNight,
            "Its wings flash a soft green glow, as if under a blacklight.",
            basis: "Several North American bats glow green on their wings under UV light, and nobody knows why."),
        act("crystal", "wind-hairs", "Wind Hairs", .reaction, .pet,
            "Tiny hairs on its wings sparkle as it tests the air.",
            basis: "Tiny domed hairs on bat wings work as airspeed sensors."),
        act("crystal", "crystal-mend", "Crystal Mend", .signature, .newDay,
            "A crack in one crystal wing glimmers and seals itself shut.",
            basis: "Bat wings heal themselves: 8 mm holes closed in about four weeks in summer."),

        // 18 Vampire — common vampire bat, cozy version.
        act("vampire", "gorilla-gallop", "Gorilla Gallop", .idleQuirk, .idleNight,
            "Drops to the ground and gallops along on its wings like a tiny gorilla.",
            basis: "The common vampire bat is the only bat known to truly run, about 2.5 mph on a treadmill."),
        act("vampire", "grooming-buddy", "Grooming Buddy", .reaction, .pet,
            "Grooms your finger right back — that's how bat friendships start.",
            basis: "Vampire bat strangers become friends by grooming first, then sharing food."),
        act("vampire", "share-dinner", "Share Dinner", .signature, .feed,
            "Splits its fruit in two and offers you the bigger half.",
            basis: "Well-fed vampire bats share dinner with hungry roost-mates, even unrelated ones."),

        // 19 Galaxy (Legendary) — bat navigation and migration.
        act("galaxy", "star-map-hatch", "Star-Map Hatch", .hatchReveal, .hatch,
            "The egg cracks into a little constellation map that folds into its body.",
            basis: "Wild Egyptian fruit bats carry a mental map of their home range."),
        act("galaxy", "shortcut-map", "Shortcut Map", .idleQuirk, .idleNight,
            "Dotted lines draw a shortcut between twinkling fruit trees.",
            basis: "Egyptian fruit bats fly straight to trees they can't see or smell, and take shortcuts."),
        act("galaxy", "inner-compass", "Inner Compass", .reaction, .pet,
            "The stars fade out — and the compass inside it still points true.",
            basis: "Neurons in wild bats keep an internal compass that works with or without the moon and stars."),
        act("galaxy", "migration-trail", "Migration Trail", .signature, .walkReturn,
            "Draws today's walk across its starry body as a migration route.",
            basis: "A Nathusius' pipistrelle flew 2,224 km from Latvia to Spain."),
        act("galaxy", "storm-surf", "Storm Surf", .secret, .rare,
            "Rides a warm wind ahead of a storm, streaking across the whole sky.",
            basis: "Noctule bats surf warm winds ahead of storm fronts, covering nearly 400 km in a night."),

        // 20 Eclipse (Legendary) — the whispering barbastelle + eclipses.
        act("eclipse", "totality-hatch", "Totality Hatch", .hatchReveal, .hatch,
            "The screen dims to totality and the bat appears inside the golden ring.",
            basis: "During solar eclipses some bats behave as if dusk has come."),
        act("eclipse", "whisper-sonar", "Whisper Sonar", .idleQuirk, .idleNight,
            "Sends sonar ripples so tiny that a moth drifts right past without noticing.",
            basis: "The barbastelle's calls are up to 100 times quieter; moths only notice it about 3.5 m away."),
        act("eclipse", "halo-ears", "Halo Ears", .reaction, .pet,
            "Pulls its joined ears down like a hood, then pops them up into a halo.",
            basis: "Barbastelles have ears that join across the forehead."),
        act("eclipse", "old-wood-hideaway", "Old-Wood Hideaway", .signature, .newDay,
            "Slips into a crack in an ancient dead tree; only the halo glints.",
            basis: "The barbastelle, one of the UK's rarest mammals, favours old woods with dead trees."),
        act("eclipse", "midday-dusk", "Midday Dusk", .secret, .rare,
            "In broad daylight the sky darkens; it wakes, peeks out as if dusk came, then shrugs back to sleep.",
            basis: "During a 1991 eclipse, gray sac-winged bats left their roost as if dusk had come."),
    ]

    // MARK: Oddball Bats (#21–32, PRD §6.3)

    private static let oddballs: [BatAction] = [
        // 21 Bumblebee — Kitti's hog-nosed bat.
        act("bumblebee", "moth-hover", "Moth Hover", .idleQuirk, .idleNight,
            "Flutters in place like a tiny moth.",
            basis: "Kitti's hog-nosed bat has fluttery, moth-like flight and can hover."),
        act("bumblebee", "warm-dome", "Warm Dome", .reaction, .pet,
            "Scoots up to the warmest spot on the ceiling and sighs happily.",
            basis: "Each bat roosts alone high in the warmest dome of a limestone cave ceiling."),
        act("bumblebee", "thirty-minute-dash", "Thirty-Minute Dash", .signature, .dusk,
            "Circles the cave mouth, then zips out for a tiny dusk flight with a ticking timer.",
            basis: "It circles the cave mouth, leaves about 10 minutes after sunset, and flies only about 30 minutes."),

        // 22 Sticky — Spix's disk-winged bat.
        act("sticky", "head-up-nap", "Head-Up Nap", .idleQuirk, .asleep,
            "Naps head-UP in a rolled leaf, the wrong way round from every other bat.",
            basis: "Spix's disk-winged bats cling head-up inside rolled leaves."),
        act("sticky", "leaf-chorus", "Leaf Chorus", .reaction, .pet,
            "Gives one call, and a chorus of tiny replies echoes back out of its leaf.",
            basis: "A flying bat gives one call; bats in the leaf reply with up to about 20 notes, the leaf acting as an ear trumpet."),
        act("sticky", "moving-day", "Moving Day", .signature, .newDay,
            "Its leaf unrolls, so it suction-cups across to a fresh rolled leaf.",
            basis: "It moves to a new leaf almost every day, because the leaf unrolls as it grows."),

        // 23 Marshmallow — Honduran white bat.
        act("marshmallow", "leaf-tent", "Leaf Tent", .idleQuirk, .asleep,
            "Nibbles a leaf's veins until it droops into a tent, then snuggles under.",
            basis: "Honduran white bats cut the side veins of a Heliconia leaf so it folds into a tent."),
        act("marshmallow", "green-glow", "Green Glow", .reaction, .pet,
            "Sunlight through the leaf washes its white fluff minty green.",
            basis: "Light shining through the leaf tent makes their white fur look green."),
        act("marshmallow", "fig-yellow", "Fig Yellow", .signature, .feed,
            "Eats a fig and its nose and ears glow brighter yellow.",
            basis: "Their yellow nose and ears get their colour from lutein in the figs they eat."),

        // 24 Honk — hammer-headed bat.
        act("honk", "nose-wrap", "Nose Wrap", .idleQuirk, .asleep,
            "Sleeps with both wings wrapped over its giant nose.",
            basis: "Hammer-headed bats sleep with their wings wrapped over the nose."),
        act("honk", "happy-buzz", "Happy Buzz", .reaction, .pet,
            "Lets out a fast, choppy buzz — you picked it!",
            basis: "When a female lands beside him, the chosen male gives a buzz call."),
        act("honk", "honk-concert", "Honk Concert", .signature, .idleNight,
            "Flaps half-open wings and honks faster and faster into a buzzing crescendo.",
            basis: "Males line up and honk 60 to 120 times a minute while flapping half-open wings."),

        // 25 Ember — painted bat.
        act("ember", "banana-leaf-curl", "Banana-Leaf Curl", .idleQuirk, .asleep,
            "Rolls up inside a curled dry banana leaf like a spring roll.",
            basis: "Painted bats roost in curled dry banana leaves and hanging bird nests."),
        act("ember", "slow-mo-wake", "Slow-Mo Wake", .reaction, .pet,
            "Reacts to your pet in super slow motion. It is very sleepy by day.",
            basis: "Painted bats are drowsy by day and slow to react when disturbed."),
        act("ember", "tail-net", "Tail Net", .signature, .idleNight,
            "Flutters in low circles, scoops a firefly in its tail like a net, then lets it go.",
            basis: "Painted bats fly low in fluttery circles and scoop insects with their tail membrane."),

        // 26 Nectar — tube-lipped nectar bat.
        act("nectar", "hummingbird-hover", "Hummingbird Hover", .idleQuirk, .idleNight,
            "Hovers at a long trumpet flower, head bobbing.",
            basis: "The tube-lipped nectar bat hovers like a hummingbird at long trumpet flowers."),
        act("nectar", "mop-tongue", "Mop Tongue", .reaction, .feed,
            "Unspools a ridiculously long tongue, mop tip fanning out, then slurps it back into its chest.",
            basis: "Its tongue, about 1.5 times its body length, has a bristly tip and pulls back into its chest."),
        act("nectar", "straw-test", "Straw Test", .signature, .walkReturn,
            "Sips from a drinking straw, reaching twice as deep as you'd think, head dusted in pollen.",
            basis: "Scientists found its tongue with a straw test: it reached over twice as far as other nectar bats."),

        // 27 Tube-Nose — tube-nosed fruit bats.
        act("tube-nose", "dead-leaf-disguise", "Dead-Leaf Disguise", .idleQuirk, .asleep,
            "Wraps itself in its spotted wings and becomes a dappled leaf.",
            basis: "Tube-nosed fruit bats roost alone wrapped in spotted wings, looking like dead leaves."),
        act("tube-nose", "stereo-sniff", "Stereo Sniff", .reaction, .pet,
            "Each nose tube wiggles on its own: sniff left, sniff right, sniff left.",
            basis: "Each tubular nostril can move on its own, perhaps to smell in stereo."),
        act("tube-nose", "sideways-fig", "Sideways Fig", .signature, .feed,
            "Hangs sideways, hugs a fig half its size and squeezes out the juice, whistling.",
            basis: "It carries figs over half its body weight, hangs at an angle to eat, and whistles in flight."),

        // 28 Polka — spotted bat.
        act("polka", "ear-scarf", "Ear Scarf", .idleQuirk, .asleep,
            "Rolls its giant pink ears around its head like a scarf.",
            basis: "The spotted bat rolls its huge ears up when resting and unrolls them when active."),
        act("polka", "hear-me-chirp", "Hear-Me Chirp", .reaction, .pet,
            "Chirps a call you could actually hear, its sound rings drawn big and bold.",
            basis: "Its calls are low enough for people to hear."),
        act("polka", "same-route-loop", "Same-Route Loop", .signature, .walkReturn,
            "Flies one big oval loop, the same route as last night, and drops a lap marker.",
            basis: "Spotted bats fly wide oval loops and often follow the same route every night."),

        // 29 Wrinkle — wrinkle-faced bat.
        act("wrinkle", "wingtip-rub", "Wingtip Rub", .idleQuirk, .idleNight,
            "Rubs its wingtips together, over and over, very pleased with itself.",
            basis: "Displaying male wrinkle-faced bats spend most of their time rubbing their wingtips together."),
        act("wrinkle", "shy-mask", "Shy Mask", .reaction, .pet,
            "Pulls its fluffy chin mask up over its face with both thumbs, then peeks.",
            basis: "Male wrinkle-faced bats pull a furry chin fold up and down over the face with their thumbs."),
        act("wrinkle", "whistle-lunge", "Whistle Lunge", .signature, .dusk,
            "Seven quick wingbeats, then a bold forward lunge with a loud whistle.",
            basis: "When another bat comes near, a male gives about seven quick wingbeats, then lunges with a whistle."),

        // 30 Walker — New Zealand lesser short-tailed bat.
        act("walker", "leaf-litter-dig", "Leaf-Litter Dig", .idleQuirk, .idleNight,
            "Digs into leaf litter with its thumb claws, sniffing for snacks.",
            basis: "It has talon-like claws for digging through leaf litter and hunts partly by smell."),
        act("walker", "titter-song", "Titter Song", .reaction, .pet,
            "Sings a little tittering song from its tree.",
            basis: "Males take turns singing 'tittering' songs from roost trees."),
        act("walker", "power-walk", "Power Walk", .signature, .walkReturn,
            "Folds its wings and power-walks across the screen with you, then sips a ground flower.",
            basis: "It folds its wings, scurries on its forearms, and visits ground-flowering wood roses."),

        // 31 Fox — giant golden-crowned flying fox.
        act("fox", "big-sleep", "Big Sleep", .idleQuirk, .asleep,
            "Sleeps hard, with one lazy wing-flap and a quick groom.",
            basis: "It sleeps about 76% of the day; the rest is grooming, wing-flapping and defending its spot."),
        act("fox", "wing-fan", "Wing Fan", .reaction, .pet,
            "Fans you with one huge wing to keep you cool.",
            basis: "Mothers fan their pups with one wing to keep them cool."),
        act("fox", "leaf-juice", "Leaf Juice", .signature, .feed,
            "Munches a fig, then crushes a leaf and sips just the juice.",
            basis: "It specialises in figs and also crushes leaves to swallow only the juice."),

        // 32 Ghost (Legendary) — Australian ghost bat.
        act("ghost", "moonlit-unveiling", "Moonlit Unveiling", .hatchReveal, .hatch,
            "The egg turns see-through and a pale bat fades in from inside.",
            basis: "The ghost bat is named for its pale, ghostly fur."),
        act("ghost", "dirrup-twitter", "Dirrup Twitter", .idleQuirk, .idleNight,
            "Bobs excitedly and twitters 'dirrup dirrup'.",
            basis: "Ghost bats give a twittering 'dirrup' call when excited or before leaving the roost."),
        act("ghost", "ear-zip", "Ear Zip", .reaction, .pet,
            "Zips its giant joined ears upright and stands tall.",
            basis: "Its ears are about twice the length of its head and joined at the base."),
        act("ghost", "silhouette-watch", "Silhouette Watch", .signature, .dusk,
            "Watches a bird silhouette glide across the evening sky and waves a wing.",
            basis: "Big-eyed ghost bats can spot birds as silhouettes against the evening sky."),
        act("ghost", "cloak-swoop", "Cloak Swoop", .secret, .rare,
            "Drops from its perch, swoops, wraps its wings into a cloak, and unveils a gift fruit for you.",
            basis: "It waits on a perch, drops down, and wraps its wings around its catch."),
    ]
}
