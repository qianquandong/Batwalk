import Foundation

/// Every number the beta is expected to tune lives here, so designers can
/// change balance without touching rules code. Values marked (PRD) come from
/// the PRD; the rest are first-pass defaults — see docs/OPEN_QUESTIONS.md.
public struct Tuning: Sendable, Equatable {
    // MARK: Hatch odds (PRD §4.4)

    /// Relative rarity weights. Renormalised over the rarities actually present
    /// in an egg's pool, so a Tiny Egg (all Common) always yields Common.
    public var rarityWeights: [Rarity: Double]
    /// Shiny chance per paid hatch. Raised from the PRD's 0.5% target (2026-10-10
    /// review): at 1–2 hatches a day, 0.5% made a Shiny a once-a-year event and
    /// left the "64 collection targets" unreachable. ≈ 1 in 33 hatches now.
    public var shinyChance: Double
    /// A paid player is guaranteed a Shiny at least once every N hatches: the
    /// Nth hatch after the last Shiny is sealed Shiny. 0 disables the pity.
    public var shinyPityHatches: Int
    /// Species already at max Friendship roll Shiny with this multiplier, so
    /// bonding with one bat makes *its* Shiny more likely. 1 disables the boost.
    public var maxFriendshipShinyMultiplier: Double
    /// After N consecutive paid hatches without a new species, the next egg is
    /// sealed to a species the player has not met yet (if its pool still has
    /// one). Keeps the last few bats of a collection from taking months. 0 disables.
    public var newSpeciesPityHatches: Int

    // MARK: Moon Dust (PRD §2.7 follow-up)

    /// Legacy reward, disabled for new hatches. Existing balances remain redeemable.
    public var moonDustPerMaxLevelDuplicate: Int
    /// Dust needed to call one bat the player has not met yet.
    public var moonDustForNewBat: Int

    // MARK: Steps

    /// Targets are frozen when a new egg starts; changing these never moves an
    /// existing egg's finish line. The one-time teaching egg keeps its short walk.
    public static let eggTargetSteps: [EggType: Int] = [
        .starter: 2_000, .tiny: 10_000, .forest: 40_000, .moon: 50_000, .crystal: 60_000
    ]

    /// Only for saves made before targets were stored on ActiveEgg.
    static let legacyEggTargetSteps: [EggType: Int] = [
        .starter: 2_000, .tiny: 2_500, .forest: 4_000, .moon: 5_000, .crystal: 6_000
    ]

    /// Max steps banked while no egg is incubating (or the egg is already ready).
    /// Stops a multi-day backlog from instantly chain-hatching several eggs.
    public var maxBankedSteps: Int
    /// Sanity cap on one day's HealthKit total. Anything above this is bad data
    /// from another app, never a walk; it is clamped before it can overflow
    /// counters or spin reward loops.
    public var maxDailySteps: Int

    // MARK: Friendship (PRD §2.7)

    /// Cumulative EXP needed to reach Lv.1…Lv.5. Index 0 = Lv.1.
    public var friendshipThresholds: [Int]
    /// EXP a duplicate hatch grants to that species, by rarity.
    public var duplicateEXP: [Rarity: Int]
    public var feedEXP: Int
    public var petEXP: Int
    /// Pets per species per day that still grant EXP (stops tap-spamming; petting still animates).
    public var petEXPDailyCap: Int

    // MARK: Fruit (PRD §2.8)

    /// One fruit is earned every N credited steps.
    public var stepsPerFruit: Int
    /// Fruit inventory cap. Reaching it is never a punishment — extra fruit is simply not added.
    public var maxFruit: Int

    // MARK: Free tier

    /// One paid-pool egg a free player may start once, after meeting every free
    /// species — a taste of the full collection (never a skip: it still takes
    /// the egg's full step target). nil disables the trial.
    public var freeTrialEgg: EggType?

    // MARK: Day / Dusk / Night (PRD §2.3), local hours, [start, end)

    public var duskStartHour: Int
    public var nightStartHour: Int
    public var dayStartHour: Int

    // MARK: Naming

    public var maxNicknameLength: Int

    public init(
        rarityWeights: [Rarity: Double] = [.common: 65, .uncommon: 25, .rare: 8, .legendary: 1.5],
        shinyChance: Double = 0.03,
        shinyPityHatches: Int = 40,
        maxFriendshipShinyMultiplier: Double = 3,
        newSpeciesPityHatches: Int = 10,
        moonDustPerMaxLevelDuplicate: Int = 0,
        moonDustForNewBat: Int = 4,
        maxBankedSteps: Int = 6_000,
        maxDailySteps: Int = 200_000,
        friendshipThresholds: [Int] = [0, 100, 250, 500, 1_000],
        duplicateEXP: [Rarity: Int] = [.common: 40, .uncommon: 60, .rare: 100, .legendary: 200],
        feedEXP: Int = 10,
        petEXP: Int = 2,
        petEXPDailyCap: Int = 10,
        stepsPerFruit: Int = 1_500,
        maxFruit: Int = 9,
        freeTrialEgg: EggType? = .forest,
        duskStartHour: Int = 18,
        nightStartHour: Int = 19,
        dayStartHour: Int = 7,
        maxNicknameLength: Int = 16
    ) {
        self.rarityWeights = rarityWeights
        self.shinyChance = shinyChance
        self.shinyPityHatches = shinyPityHatches
        self.maxFriendshipShinyMultiplier = maxFriendshipShinyMultiplier
        self.newSpeciesPityHatches = newSpeciesPityHatches
        self.moonDustPerMaxLevelDuplicate = moonDustPerMaxLevelDuplicate
        self.moonDustForNewBat = moonDustForNewBat
        self.maxBankedSteps = maxBankedSteps
        self.maxDailySteps = maxDailySteps
        self.friendshipThresholds = friendshipThresholds
        self.duplicateEXP = duplicateEXP
        self.feedEXP = feedEXP
        self.petEXP = petEXP
        self.petEXPDailyCap = petEXPDailyCap
        self.stepsPerFruit = stepsPerFruit
        self.maxFruit = maxFruit
        self.freeTrialEgg = freeTrialEgg
        self.duskStartHour = duskStartHour
        self.nightStartHour = nightStartHour
        self.dayStartHour = dayStartHour
        self.maxNicknameLength = maxNicknameLength
    }

    public static let `default` = Tuning()
}
