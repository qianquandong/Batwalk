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

    static func load() -> ComplicationSnapshot {
        guard let defaults = UserDefaults(suiteName: SharedConfig.appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ComplicationSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: SharedConfig.appGroup),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
