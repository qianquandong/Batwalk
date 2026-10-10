import Foundation

/// Identifiers that must match project.yml, the entitlements, and App Store Connect.
enum SharedConfig {
    static let appGroup = "group.com.aimanjack.batwalk"
    static let cloudKitContainer = "iCloud.com.aimanjack.batwalk"
    static let fullUnlockProductID = "com.aimanjack.batwalk.fullunlock"

    /// Cloud collection backup and live widgets are independent capabilities.
    /// They need an App Group and an
    /// iCloud container created by hand in the developer portal — an App Store
    /// Connect API key can't create them. Until then, saves stay on the Watch
    /// and the complication opens the app. Enable each with its corresponding
    /// entitlements in project.yml (see docs/SIGNING.md).
    static let appGroupEnabled = false
    static let cloudBackupEnabled = false
}
