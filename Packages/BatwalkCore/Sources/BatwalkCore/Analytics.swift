import Foundation

/// Minimum analytics events (PRD §4.6). Game events only — never raw Health history (PRD §4.5).
public enum AnalyticsEvent: String, CaseIterable, Sendable {
    case onboardingComplete = "onboarding_complete"
    case stepPermissionResult = "step_permission_result"
    case firstHatch = "first_hatch"
    case eggComplete = "egg_complete"
    case batCollected = "bat_collected"
    case duplicateFriendship = "duplicate_friendship"
    case companionChanged = "companion_changed"
    case feedBat = "feed_bat"
    case purchaseUnlock = "purchase_unlock"
    case restorePurchase = "restore_purchase"
}

/// Pluggable sink. The MVP ships `NoopAnalytics`; a privacy-respecting provider can be swapped in later.
public protocol AnalyticsSink: Sendable {
    func log(_ event: AnalyticsEvent, properties: [String: String])
}

public struct NoopAnalytics: AnalyticsSink {
    public init() {}
    public func log(_ event: AnalyticsEvent, properties: [String: String]) {
        #if DEBUG
        print("[analytics]", event.rawValue, properties)
        #endif
    }
}
