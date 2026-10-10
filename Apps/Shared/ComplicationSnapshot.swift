import Foundation

/// Tiny summary the app writes to the App Group for the WidgetKit complication.
/// The complication never opens the game database — it only reads this.
struct ComplicationSnapshot: Codable, Equatable {
    var companionName: String?
    var companionSpeciesID: String?
    var eggProgress: Double?
    var eggStepsRemaining: Int?
    var isEggReady: Bool
    var updatedAt: Date

    static let empty = ComplicationSnapshot(isEggReady: false, updatedAt: .distantPast)

    private static let key = "complicationSnapshot"

    func isStale(at date: Date) -> Bool {
        updatedAt == .distantPast || date.timeIntervalSince(updatedAt) >= 2 * 60 * 60
    }

    var destination: URL {
        URL(string: "batwalk://\(isEggReady ? "hatch" : eggProgress == nil ? "home" : "progress")")!
    }

    static func load() -> ComplicationSnapshot {
        guard SharedConfig.appGroupEnabled,
              let defaults = UserDefaults(suiteName: SharedConfig.appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ComplicationSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    @discardableResult
    func save() -> Bool {
        guard SharedConfig.appGroupEnabled,
              let defaults = UserDefaults(suiteName: SharedConfig.appGroup),
              let data = try? JSONEncoder().encode(self) else { return false }
        let previous = Self.load()
        // Persist freshness on every read, but reload only for visible changes or
        // the transition from a stale snapshot to fresh data.
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
