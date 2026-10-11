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
    public let fruit: Int
    public let moonDust: Int
    public let trialEggUsed: Bool

    public init(state: GameState) {
        version = 1
        saveID = state.saveID
        revision = state.revision
        hasStarted = state.hasStarted
        collection = state.collection
        companionID = state.companionID
        history = state.history
        fruit = state.fruit
        moonDust = state.moonDust
        trialEggUsed = state.trialEggUsed
    }

    private init(version: Int, saveID: UUID, revision: UInt64, hasStarted: Bool, collection: [String: OwnedBat],
                 companionID: String?, history: [HatchRecord], fruit: Int, moonDust: Int, trialEggUsed: Bool) {
        self.version = version
        self.saveID = saveID
        self.revision = revision
        self.hasStarted = hasStarted
        self.collection = collection
        self.companionID = companionID
        self.history = history
        self.fruit = fruit
        self.moonDust = moonDust
        self.trialEggUsed = trialEggUsed
    }

    private enum CodingKeys: String, CodingKey {
        case version, saveID, revision, hasStarted, collection, companionID, history, fruit, moonDust, trialEggUsed
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
        history = try c.decodeIfPresent([HatchRecord].self, forKey: .history) ?? []
        fruit = try c.decodeIfPresent(Int.self, forKey: .fruit) ?? 0
        moonDust = try c.decodeIfPresent(Int.self, forKey: .moonDust) ?? 0
        trialEggUsed = try c.decodeIfPresent(Bool.self, forKey: .trialEggUsed) ?? false
    }

    /// True when nothing a player would notice differs. The cloud record is only
    /// rewritten when this is false, so its modification times never trace walks
    /// (revision changes on every step credit and fruit every ~1,500 steps).
    public func hasSameContent(as other: CollectionBackup) -> Bool {
        saveID == other.saveID && hasStarted == other.hasStarted && collection == other.collection
            && companionID == other.companionID && history == other.history
            && moonDust == other.moonDust && trialEggUsed == other.trialEggUsed
    }

    /// A copy keeping only the newest `limit` hatch records, for size-limited
    /// transports such as the WatchConnectivity application context.
    public func trimmingHistory(to limit: Int) -> CollectionBackup {
        guard history.count > limit else { return self }
        return CollectionBackup(version: version, saveID: saveID, revision: revision, hasStarted: hasStarted,
                                collection: collection, companionID: companionID,
                                history: Array(history.suffix(max(0, limit))), fruit: fruit,
                                moonDust: moonDust, trialEggUsed: trialEggUsed)
    }
}
