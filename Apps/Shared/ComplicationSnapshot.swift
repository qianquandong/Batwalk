import Foundation

/// Tiny summary the app writes for the WidgetKit complication (App Group) and
/// for in-app readers such as the Siri "Check my egg" intent (standard defaults).
/// The complication never opens the game database — it only reads this.
struct ComplicationSnapshot: Codable, Equatable {
    var companionName: String?
    var companionSpeciesID: String?
    var companionIsShiny = false
    var eggType: String?
    var eggProgress: Double?
    var eggStepsRemaining: Int?
    /// `EggVisualState` raw value, so the face can show cracks at 50 % (PRD §3.5).
    var eggVisualState: String?
    var isEggReady: Bool
    /// Local hour the bat wakes — the Smart Stack relevance window.
    var duskHour = 18
    var updatedAt: Date

    static let empty = ComplicationSnapshot(isEggReady: false, updatedAt: .distantPast)

    private static let key = "complicationSnapshot"

    init(companionName: String? = nil, companionSpeciesID: String? = nil, companionIsShiny: Bool = false,
         eggType: String? = nil, eggProgress: Double? = nil, eggStepsRemaining: Int? = nil,
         eggVisualState: String? = nil, isEggReady: Bool, duskHour: Int = 18, updatedAt: Date) {
        self.companionName = companionName
        self.companionSpeciesID = companionSpeciesID
        self.companionIsShiny = companionIsShiny
        self.eggType = eggType
        self.eggProgress = eggProgress
        self.eggStepsRemaining = eggStepsRemaining
        self.eggVisualState = eggVisualState
        self.isEggReady = isEggReady
        self.duskHour = duskHour
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case companionName, companionSpeciesID, companionIsShiny, eggType, eggProgress, eggStepsRemaining
        case eggVisualState, isEggReady, duskHour, updatedAt
    }

    /// Snapshots written by an older app lack the newer keys; keep showing them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        companionName = try c.decodeIfPresent(String.self, forKey: .companionName)
        companionSpeciesID = try c.decodeIfPresent(String.self, forKey: .companionSpeciesID)
        companionIsShiny = try c.decodeIfPresent(Bool.self, forKey: .companionIsShiny) ?? false
        eggType = try c.decodeIfPresent(String.self, forKey: .eggType)
        eggProgress = try c.decodeIfPresent(Double.self, forKey: .eggProgress)
        eggStepsRemaining = try c.decodeIfPresent(Int.self, forKey: .eggStepsRemaining)
        eggVisualState = try c.decodeIfPresent(String.self, forKey: .eggVisualState)
        isEggReady = try c.decodeIfPresent(Bool.self, forKey: .isEggReady) ?? false
        duskHour = try c.decodeIfPresent(Int.self, forKey: .duskHour) ?? 18
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    func isStale(at date: Date) -> Bool {
        updatedAt == .distantPast || date.timeIntervalSince(updatedAt) >= 2 * 60 * 60
    }

    var destination: URL {
        URL(string: "batwalk://\(isEggReady ? "hatch" : eggProgress == nil ? "home" : "progress")")!
    }

    /// The App Group copy when this build has one, else the in-app copy.
    static func load() -> ComplicationSnapshot {
        if SharedConfig.appGroupEnabled, let defaults = UserDefaults(suiteName: SharedConfig.appGroup),
           let snapshot = decode(defaults.data(forKey: key)) {
            return snapshot
        }
        return decode(UserDefaults.standard.data(forKey: key)) ?? .empty
    }

    private static func decode(_ data: Data?) -> ComplicationSnapshot? {
        data.flatMap { try? JSONDecoder().decode(ComplicationSnapshot.self, from: $0) }
    }

    /// Writes the in-app copy always and the App Group copy when enabled.
    /// Returns whether the complication should reload: only for visible changes or
    /// the transition from a stale snapshot to fresh data (background reload budget).
    @discardableResult
    func save() -> Bool {
        guard let data = try? JSONEncoder().encode(self) else { return false }
        let previous = Self.load()
        UserDefaults.standard.set(data, forKey: Self.key)
        guard SharedConfig.appGroupEnabled, let defaults = UserDefaults(suiteName: SharedConfig.appGroup) else { return false }
        var comparable = previous
        comparable.updatedAt = updatedAt
        let needsReload = comparable != self || previous.isStale(at: updatedAt)
        defaults.set(data, forKey: Self.key)
        // The shared summary also contains Health-derived progress.
        if let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConfig.appGroup) {
            var preferences = root.appendingPathComponent("Library/Preferences", isDirectory: true)
            try? FileManager.default.createDirectory(at: preferences, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try? preferences.setResourceValues(values)
        }
        return needsReload
    }
}
