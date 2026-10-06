import Foundation
import SwiftData
import BatwalkCore

/// The save is one Codable `GameState` blob in a single SwiftData row.
/// See docs/decisions/0002-save-as-single-blob.md for why (CloudKit-safe,
/// schema evolves in Swift, all rules stay unit-tested in BatwalkCore).
///
/// CloudKit rules respected: every attribute has a default, no unique constraints,
/// no required relationships.
@Model
final class SaveRecord {
    var payload: Data = Data()
    var updatedAt: Date = Date.distantPast
    /// "watch" or "phone" — only the Watch ever writes a save.
    var writer: String = ""

    init(payload: Data, updatedAt: Date, writer: String) {
        self.payload = payload
        self.updatedAt = updatedAt
        self.writer = writer
    }
}

enum Persistence {
    /// Local SwiftData store in the App Group, mirrored to the user's private
    /// CloudKit database for backup / restore. Falls back to local-only so the
    /// game is always playable even if iCloud is unavailable.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([SaveRecord.self])
        do {
            let config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(SharedConfig.appGroup),
                cloudKitDatabase: .private(SharedConfig.cloudKitContainer)
            )
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("[persistence] CloudKit store unavailable, using local-only store: \(error)")
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: local)
            } catch {
                fatalError("Could not create even a local store: \(error)")
            }
        }
    }
}
