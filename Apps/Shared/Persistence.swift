import Foundation
import SwiftData

@Model
final class SaveRecord {
    var payload: Data = Data()
    var updatedAt: Date = Date.distantPast
    var writer: String = ""
    init(payload: Data, updatedAt: Date, writer: String) {
        self.payload = payload; self.updatedAt = updatedAt; self.writer = writer
    }
}

@Model
final class CollectionBackupRecord {
    var saveID: String = ""
    var payload: Data = Data()
    var updatedAt: Date = Date.distantPast
    init() {}
}

@MainActor
enum Persistence {
    static var storageUnavailable = false

    static func makeContainer() -> ModelContainer {
        storageUnavailable = false
        let localSchema = Schema([SaveRecord.self])
        let backupSchema = Schema([CollectionBackupRecord.self])
        let schema = Schema([SaveRecord.self, CollectionBackupRecord.self])
        // The original default.store URL stays unchanged. App Groups share only
        // the widget snapshot, and SaveRecord is never configured for CloudKit.
        let local = ModelConfiguration(schema: localSchema, cloudKitDatabase: .none)
        let backups = ModelConfiguration("CollectionBackup", schema: backupSchema,
            cloudKitDatabase: SharedConfig.cloudBackupEnabled ? .private(SharedConfig.cloudKitContainer) : .none)
        do {
            try excludeFromBackup(local.url)
            let container = try ModelContainer(for: schema, configurations: local, backups)
            return container
        } catch {
            let fallback = ModelConfiguration("CollectionBackup", schema: backupSchema, cloudKitDatabase: .none)
            do {
                try excludeFromBackup(local.url)
                let container = try ModelContainer(for: schema, configurations: local, fallback)
                return container
            } catch {
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                guard let container = try? ModelContainer(for: schema, configurations: memory) else {
                    fatalError("Unable to initialize the recovery interface")
                }
                storageUnavailable = true
                return container
            }
        }
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var directoryValues = URLResourceValues(); directoryValues.isExcludedFromBackup = true
        // Mark the directory before opening SQLite so later WAL/SHM files inherit
        // exclusion. If this fails, don't create a Health-derived save there.
        try directory.setResourceValues(directoryValues)
        for suffix in ["", "-wal", "-shm"] {
            var target = URL(fileURLWithPath: url.path + suffix)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try? target.setResourceValues(values)
        }
    }
}
