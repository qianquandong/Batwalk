import Foundation
import BatwalkCore

/// Atomic rotating local copies. Health-derived state is excluded from device backup.
struct SaveArchive {
    let directory: URL
    init(name: String, directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory
            .appendingPathComponent("BatwalkRecovery", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    func save(_ data: Data) throws {
        try prepareDirectory()
        let current = directory.appendingPathComponent("current.json")
        let previous = directory.appendingPathComponent("previous.json")
        if let old = try? Data(contentsOf: current),
           (try? JSONDecoder().decode(GameState.self, from: old)) != nil {
            try old.write(to: previous, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        try data.write(to: current, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    private struct Visits: Codable { let saveID: UUID; let memory: BatVisitMemory }

    /// Step watermarks are Health-derived. Keep them beside the protected local
    /// save, excluded from backup, rather than in UserDefaults or CloudKit.
    func saveVisits(_ memory: BatVisitMemory, saveID: UUID) throws {
        try prepareDirectory()
        let data = try JSONEncoder().encode(Visits(saveID: saveID, memory: memory))
        try data.write(to: directory.appendingPathComponent("visits.json"),
                       options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func loadVisits(saveID: UUID) -> BatVisitMemory? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("visits.json")),
              let visits = try? JSONDecoder().decode(Visits.self, from: data), visits.saveID == saveID else { return nil }
        return visits.memory
    }

    func load() -> GameState? {
        for name in ["current.json", "previous.json"] {
            if let data = try? Data(contentsOf: directory.appendingPathComponent(name)),
               let state = try? JSONDecoder().decode(GameState.self, from: data) { return state }
        }
        return nil
    }
}
