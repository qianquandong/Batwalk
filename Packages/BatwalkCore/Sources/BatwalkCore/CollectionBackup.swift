import Foundation

/// Explicit cloud allowlist. Never add HealthKit dates/totals, the step ledger,
/// lifetime steps, banked steps or exact egg-step progress to this type.
public struct CollectionBackup: Codable, Equatable, Sendable {
    public let version: Int
    public let saveID: UUID
    public let revision: UInt64
    public let hasStarted: Bool
    public let collection: [String: OwnedBat]
    public let companionID: String?
    public let history: [HatchRecord]
    public let lifetimeHatchCount: Int
    public let monthlyHatchCounts: [String: Int]
    public let fruit: Int
    public let moonDust: Int
    public let trialEggUsed: Bool
    public let outfitPreferences: [String: OutfitPreference]?
    public let earnedChallengeOutfits: [String: [String: ChallengeTier]]?
    public let challengeHatchCounts: [String: Int]?
    public let birthday: MonthDay?

    public init(state: GameState) {
        var state = state
        state.materializeChallenges()
        version = 1
        saveID = state.saveID
        revision = state.revision
        hasStarted = state.hasStarted
        collection = state.collection
        companionID = state.companionID
        history = state.history.map { $0.withoutActivityMetrics }
        lifetimeHatchCount = state.lifetimeHatchCount
        monthlyHatchCounts = state.monthlyHatchCounts
        fruit = state.fruit
        moonDust = state.moonDust
        trialEggUsed = state.trialEggUsed
        outfitPreferences = state.outfitPreferences
        earnedChallengeOutfits = state.earnedChallengeOutfits
        challengeHatchCounts = state.challengeHatchCounts
        birthday = state.birthday
    }

    private init(version: Int, saveID: UUID, revision: UInt64, hasStarted: Bool, collection: [String: OwnedBat],
                 companionID: String?, history: [HatchRecord], lifetimeHatchCount: Int, monthlyHatchCounts: [String: Int], fruit: Int, moonDust: Int, trialEggUsed: Bool,
                 outfitPreferences: [String: OutfitPreference]?, earnedChallengeOutfits: [String: [String: ChallengeTier]]?,
                 challengeHatchCounts: [String: Int]?, birthday: MonthDay?) {
        self.version = version
        self.saveID = saveID
        self.revision = revision
        self.hasStarted = hasStarted
        self.collection = collection
        self.companionID = companionID
        self.history = history.map { $0.withoutActivityMetrics }
        self.lifetimeHatchCount = lifetimeHatchCount
        self.monthlyHatchCounts = monthlyHatchCounts
        self.fruit = fruit
        self.moonDust = moonDust
        self.trialEggUsed = trialEggUsed
        self.outfitPreferences = outfitPreferences
        self.earnedChallengeOutfits = earnedChallengeOutfits
        self.challengeHatchCounts = challengeHatchCounts
        self.birthday = birthday
    }

    private enum CodingKeys: String, CodingKey {
        case version, saveID, revision, hasStarted, collection, companionID, history, fruit, moonDust, trialEggUsed, outfitPreferences, earnedChallengeOutfits, challengeHatchCounts, birthday, lifetimeHatchCount, monthlyHatchCounts
    }

    /// Backups written before Moon Dust / the trial egg existed have no such keys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        saveID = try c.decode(UUID.self, forKey: .saveID)
        revision = try c.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        hasStarted = try c.decodeIfPresent(Bool.self, forKey: .hasStarted) ?? true
        collection = try c.decode([String: OwnedBat].self, forKey: .collection)
        companionID = try c.decodeIfPresent(String.self, forKey: .companionID)
        history = (try c.decodeIfPresent([HatchRecord].self, forKey: .history) ?? []).map { $0.withoutActivityMetrics }
        lifetimeHatchCount = max(history.filter { $0.source == .egg }.count,
            try c.decodeIfPresent(Int.self, forKey: .lifetimeHatchCount) ?? 0)
        monthlyHatchCounts = try c.decodeIfPresent([String: Int].self, forKey: .monthlyHatchCounts)
            ?? HatchLeaderboards.monthlyCounts(history: history)
        fruit = try c.decodeIfPresent(Int.self, forKey: .fruit) ?? 0
        moonDust = try c.decodeIfPresent(Int.self, forKey: .moonDust) ?? 0
        trialEggUsed = try c.decodeIfPresent(Bool.self, forKey: .trialEggUsed) ?? false
        outfitPreferences = try c.decodeIfPresent([String: OutfitPreference].self, forKey: .outfitPreferences)
        let archive = ChallengeArchive(history: history)
        earnedChallengeOutfits = try c.decodeIfPresent([String: [String: ChallengeTier]].self, forKey: .earnedChallengeOutfits)
            ?? (archive.outfits.isEmpty ? nil : archive.outfits)
        challengeHatchCounts = try c.decodeIfPresent([String: Int].self, forKey: .challengeHatchCounts)
            ?? (archive.counts.isEmpty ? nil : archive.counts)
        birthday = try c.decodeIfPresent(MonthDay.self, forKey: .birthday)
    }

    /// True when nothing a player would notice differs. The cloud record is only
    /// rewritten when this is false, so its modification times never trace walks
    /// (revision changes on every step credit and fruit every ~1,500 steps).
    public func hasSameContent(as other: CollectionBackup) -> Bool {
        saveID == other.saveID && hasStarted == other.hasStarted && collection == other.collection
            && companionID == other.companionID && history == other.history
            && lifetimeHatchCount == other.lifetimeHatchCount && monthlyHatchCounts == other.monthlyHatchCounts
            && moonDust == other.moonDust && trialEggUsed == other.trialEggUsed && outfitPreferences == other.outfitPreferences
            && earnedChallengeOutfits == other.earnedChallengeOutfits && challengeHatchCounts == other.challengeHatchCounts && birthday == other.birthday
    }

    /// A copy keeping only the newest `limit` hatch records, for size-limited
    /// transports such as the WatchConnectivity application context.
    public func trimmingHistory(to limit: Int) -> CollectionBackup {
        guard history.count > limit else { return self }
        return CollectionBackup(version: version, saveID: saveID, revision: revision, hasStarted: hasStarted,
                                collection: collection, companionID: companionID,
                                history: Array(history.suffix(max(0, limit))), lifetimeHatchCount: lifetimeHatchCount, monthlyHatchCounts: monthlyHatchCounts, fruit: fruit,
                                moonDust: moonDust, trialEggUsed: trialEggUsed, outfitPreferences: outfitPreferences,
                                earnedChallengeOutfits: earnedChallengeOutfits, challengeHatchCounts: challengeHatchCounts, birthday: birthday)
    }
}
