import Foundation
import BatwalkCore
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

/// Privacy-respecting analytics (PRD §4.5–4.6, roadmap M3): anonymous game
/// events only — never Health data, never identifiers — through TelemetryDeck.
///
/// Active only when the build carries an app ID (`BatwalkTelemetryDeckAppID` in
/// Info.plist, filled from the `BATWALK_TELEMETRYDECK_APP_ID` build setting).
/// Without one, the no-op sink stays in place and nothing leaves the device.
enum AnalyticsSetup {
    static func makeSink() -> AnalyticsSink {
        #if canImport(TelemetryDeck)
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "BatwalkTelemetryDeckAppID") as? String,
              !appID.isEmpty, !appID.hasPrefix("$(") else { return NoopAnalytics() }
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
        return TelemetryDeckAnalytics()
        #else
        return NoopAnalytics()
        #endif
    }

    static var isEnabled: Bool {
        #if canImport(TelemetryDeck)
        let appID = Bundle.main.object(forInfoDictionaryKey: "BatwalkTelemetryDeckAppID") as? String ?? ""
        return !appID.isEmpty && !appID.hasPrefix("$(")
        #else
        return false
        #endif
    }
}

#if canImport(TelemetryDeck)
/// Only `AnalyticsEvent` names and the small string properties the game attaches
/// (species, rarity, egg type). The event list itself is the allowlist.
struct TelemetryDeckAnalytics: AnalyticsSink {
    func log(_ event: AnalyticsEvent, properties: [String: String]) {
        TelemetryDeck.signal(event.rawValue, parameters: properties)
    }
}
#endif
