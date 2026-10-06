import Foundation

/// Every number the beta is expected to tune lives here, so designers can
/// change balance without touching rules code. Values marked (PRD) come from
/// the PRD; the rest are first-pass defaults — see docs/OPEN_QUESTIONS.md.
public struct Tuning: Sendable, Equatable {
    // MARK: Hatch odds (PRD §4.4)

    /// Relative rarity weights. Renormalised over the rarities actually present
    /// in an egg's pool, so a Tiny Egg (all Common) always yields Common.
    public var rarityWeights: [Rarity: Double]
    /// Shiny chance per hatch, full unlock only (PRD: 0.5%).
    public var shinyChance: Double

    // MARK: Steps

    /// Max steps banked while no egg is incubating (or the egg is already ready).
    /// Stops a multi-day backlog from instantly chain-hatching several eggs.
    public var maxBankedSteps: Int

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

    // MARK: Day / Dusk / Night (PRD §2.3), local hours, [start, end)

    public var duskStartHour: Int
    public var nightStartHour: Int
    public var dayStartHour: Int

    // MARK: Naming

    public var maxNicknameLength: Int

    public init(
        rarityWeights: [Rarity: Double] = [.common: 65, .uncommon: 25, .rare: 8, .legendary: 1.5],
        shinyChance: Double = 0.005,
        maxBankedSteps: Int = 6_000,
        friendshipThresholds: [Int] = [0, 100, 250, 500, 1_000],
        duplicateEXP: [Rarity: Int] = [.common: 40, .uncommon: 60, .rare: 100, .legendary: 200],
        feedEXP: Int = 10,
        petEXP: Int = 2,
        petEXPDailyCap: Int = 10,
        stepsPerFruit: Int = 1_500,
        maxFruit: Int = 9,
        duskStartHour: Int = 18,
        nightStartHour: Int = 19,
        dayStartHour: Int = 7,
        maxNicknameLength: Int = 16
    ) {
        self.rarityWeights = rarityWeights
        self.shinyChance = shinyChance
        self.maxBankedSteps = maxBankedSteps
        self.friendshipThresholds = friendshipThresholds
        self.duplicateEXP = duplicateEXP
        self.feedEXP = feedEXP
        self.petEXP = petEXP
        self.petEXPDailyCap = petEXPDailyCap
        self.stepsPerFruit = stepsPerFruit
        self.maxFruit = maxFruit
        self.duskStartHour = duskStartHour
        self.nightStartHour = nightStartHour
        self.dayStartHour = dayStartHour
        self.maxNicknameLength = maxNicknameLength
    }

    public static let `default` = Tuning()
}
