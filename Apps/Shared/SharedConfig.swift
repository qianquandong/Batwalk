import Foundation

/// Identifiers that must match project.yml, the entitlements, and App Store Connect.
enum SharedConfig {
    static let appGroup = "group.com.aimanjack.batwalk"
    static let cloudKitContainer = "iCloud.com.aimanjack.batwalk"
    /// Free launch. Future paid content may be cosmetic only; never gameplay access.
    static let paidContentEnabled = false
    static let fullUnlockProductID = "com.aimanjack.batwalk.fullunlock"

    /// Cloud collection backup and live widgets are independent capabilities.
    /// They need an App Group and an
    /// iCloud container created by hand in the developer portal — an App Store
    /// Connect API key can't create them. Until then, saves stay on the Watch
    /// and the complication opens the app. Enable each with its corresponding
    /// entitlements in project.yml (see docs/SIGNING.md).
    static var appGroupEnabled: Bool { enabled("BatwalkAppGroupEnabled") }
    static var cloudBackupEnabled: Bool { enabled("BatwalkCloudBackupEnabled") }

    /// Highest roster wave this build ships (`BATWALK_CONTENT_WAVE`; 1 = launch
    /// roster, 2 = + Oddball Bats). See `Roster.enabledWave` and open question Q12.
    static var contentWave: Int {
        if let value = Bundle.main.object(forInfoDictionaryKey: "BatwalkContentWave") as? Int { return max(1, value) }
        if let text = Bundle.main.object(forInfoDictionaryKey: "BatwalkContentWave") as? String, let value = Int(text) {
            return max(1, value)
        }
        return 1
    }

    private static func enabled(_ key: String) -> Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? Bool { return value }
        return (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.uppercased() == "YES"
    }
}
