import SwiftUI
import BatwalkCore

// Batwalk design tokens. Values come from the approved UI boards
// (Art/ui-boards/watch-ui-spec.png › Component Tokens, overview.png › Design System).
// Screens use these semantic names — never raw hex values.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum BatwalkColor {
    // Night surfaces (Watch + dark heroes)
    static let deepNight = Color(hex: 0x0B1020)
    static let indigo = Color(hex: 0x1A1F3D)
    static let nightSurface = Color(hex: 0x1E2130)
    static let nightCard = Color(hex: 0x2A2F45)
    static let nightCardElevated = Color(hex: 0x353B57)

    // Brand
    static let purple = Color(hex: 0x8B5CF6)
    static let purpleGlow = Color(hex: 0x9F7BFF)
    static let pinkAccent = Color(hex: 0xF472B6)
    static let ringPink = Color(hex: 0xFF6BCC)
    static let moonlight = Color(hex: 0xFDE68A)
    static let softLavender = Color(hex: 0xCDB4FF)
    static let mist = Color(hex: 0x8BA0D9)
    static let cloud = Color(hex: 0xF3EBFF)

    // Text
    static let textPrimaryDark = Color.white
    static let textSecondaryDark = Color(hex: 0xB9B3D9)
    static let textPrimaryLight = Color(hex: 0x1B1640)
    static let textSecondaryLight = Color(hex: 0x6E6894)

    // Light (iPhone) surfaces
    static let lightBackground = Color(hex: 0xF7F3FF)
    static let lightCard = Color.white
    static let lightTint = Color(hex: 0xEFE7FF)

    // Locked bats
    static let lockedBatBackground = Color(hex: 0x161A30)
    static let lockedBatLight = Color(hex: 0xECE6FA)

    // Status
    static let success = Color(hex: 0x5ED3A6)
    static let warning = Color(hex: 0xF5B83D)

    // Rarity
    static let rarityCommon = Color(hex: 0xA79BC9)
    static let rarityUncommon = Color(hex: 0x5ED3A6)
    static let rarityRare = Color(hex: 0x5B8CFF)
    static let rarityLegendary = Color(hex: 0xF5B83D)
    static let rarityShiny = Color(hex: 0xFFD86B)
}

enum BatwalkGradient {
    /// Main interactive gradient: purple → pink.
    static let primary = LinearGradient(
        colors: [BatwalkColor.purple, BatwalkColor.pinkAccent],
        startPoint: .leading, endPoint: .trailing)

    /// Buttons: mostly purple with a pink edge, as on the boards.
    static let button = LinearGradient(
        colors: [Color(hex: 0x7C4DF0), Color(hex: 0xB062E8)],
        startPoint: .leading, endPoint: .trailing)

    static let friendship = LinearGradient(
        colors: [Color(hex: 0xFF5FA2), BatwalkColor.pinkAccent],
        startPoint: .leading, endPoint: .trailing)

    static let hatchGlow = RadialGradient(
        colors: [BatwalkColor.moonlight.opacity(0.85), BatwalkColor.pinkAccent.opacity(0.25), .clear],
        center: .center, startRadius: 2, endRadius: 90)

    static let nightBackground = LinearGradient(
        colors: [BatwalkColor.indigo, BatwalkColor.deepNight],
        startPoint: .top, endPoint: .bottom)

    /// Progress ring stroke; the ring rotates it so it starts at 12 o'clock.
    static func ring(progress: Double) -> AngularGradient {
        AngularGradient(
            colors: [BatwalkColor.purpleGlow, BatwalkColor.ringPink],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * max(0.02, min(1, progress))))
    }

    /// Soft lavender used behind bat art on the light iPhone UI.
    static let lightArt = LinearGradient(
        colors: [Color(hex: 0xF3ECFF), Color(hex: 0xE4D8FF)],
        startPoint: .top, endPoint: .bottom)
}

/// 8 pt layout grid.
enum BatwalkSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum BatwalkRadius {
    static let chip: CGFloat = 10
    static let tile: CGFloat = 14
    static let card: CGFloat = 16
    static let largeCard: CGFloat = 24
}

/// SF Rounded throughout, on top of Dynamic Type styles.
enum BatwalkFont {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
    static let title = rounded(.title2, weight: .bold)
    static let headline = rounded(.headline, weight: .semibold)
    static let body = rounded(.body)
    static let caption = rounded(.caption, weight: .medium)
    static let micro = rounded(.caption2, weight: .medium)
}

/// Rarity presentation (chips, glows, reveal strength).
extension Rarity {
    var color: Color {
        switch self {
        case .common: return BatwalkColor.rarityCommon
        case .uncommon: return BatwalkColor.rarityUncommon
        case .rare: return BatwalkColor.rarityRare
        case .legendary: return BatwalkColor.rarityLegendary
        }
    }

    var symbol: String {
        switch self {
        case .common: return "circle.fill"
        case .uncommon: return "leaf.fill"
        case .rare: return "star.fill"
        case .legendary: return "crown.fill"
        }
    }

    /// Rare and Legendary reveals get the stronger glow + extra haptic.
    var isSpecial: Bool { self >= .rare }
}
