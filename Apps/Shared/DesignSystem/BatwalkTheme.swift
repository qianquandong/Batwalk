import SwiftUI
import BatwalkCore

// Gentle pixel direction: midnight teal, cream, sage, and restrained peach.
// See Art/gentle-pixel/README.md for the current visual reference.
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
    static let deepNight = Color(hex: 0x0C181B)
    static let indigo = Color(hex: 0x1C2E32)
    static let nightSurface = Color(hex: 0x1F3033)
    static let nightCard = Color(hex: 0x2C3E40)
    static let nightCardElevated = Color(hex: 0x374B49)

    // Brand
    static let accent = Color(hex: 0x547465)
    static let accentSoft = Color(hex: 0xB7C9AC)
    static let rose = Color(hex: 0xDDAE9D)
    static let ringMint = Color(hex: 0xCBD6AB)
    static let moonlight = Color(hex: 0xEFE2B6)
    static let sage = Color(hex: 0xCED7BF)
    static let mist = Color(hex: 0x89A7A0)
    static let cloud = Color(hex: 0xF4F0E2)
    static let buttonText = Color(hex: 0x182C25)

    // Text
    static let textPrimaryDark = cloud
    static let textSecondaryDark = Color(hex: 0xB2C0B8)
    static let textPrimaryLight = Color(hex: 0x202C28)
    static let textSecondaryLight = Color(hex: 0x66766B)

    // Light (iPhone) surfaces
    static let lightBackground = Color(hex: 0xF4F1E8)
    static let lightCard = Color(hex: 0xFFFCF4)
    static let lightTint = Color(hex: 0xE5E9DB)

    // Locked bats
    static let lockedBatBackground = Color(hex: 0x122125)
    static let lockedBatLight = Color(hex: 0xE1E5D8)

    // Status
    static let success = Color(hex: 0xAFC9A5)
    static let warning = Color(hex: 0xE3BA7A)

    // Rarity
    static let rarityCommon = Color(hex: 0xADBBAC)
    static let rarityUncommon = Color(hex: 0xB3C697)
    static let rarityRare = Color(hex: 0xA7BECF)
    static let rarityLegendary = Color(hex: 0xDEC48B)
    static let rarityShiny = Color(hex: 0xF0DCA6)
}

enum BatwalkGradient {
    /// Muted sage accents for the light companion app.
    static let primary = LinearGradient(
        colors: [BatwalkColor.accent, BatwalkColor.mist],
        startPoint: .leading, endPoint: .trailing)

    /// Cream-mint buttons remain readable on both night and light surfaces.
    static let button = LinearGradient(
        colors: [BatwalkColor.accentSoft, BatwalkColor.accentSoft],
        startPoint: .leading, endPoint: .trailing)

    static let friendship = LinearGradient(
        colors: [BatwalkColor.rose, BatwalkColor.rose],
        startPoint: .leading, endPoint: .trailing)

    static let hatchGlow = RadialGradient(
        colors: [BatwalkColor.moonlight.opacity(0.25), BatwalkColor.accentSoft.opacity(0.08), .clear],
        center: .center, startRadius: 2, endRadius: 90)

    static let nightBackground = LinearGradient(
        colors: [BatwalkColor.indigo, BatwalkColor.deepNight],
        startPoint: .top, endPoint: .bottom)

    /// Progress ring stroke; the ring rotates it so it starts at 12 o'clock.
    static func ring(progress: Double) -> AngularGradient {
        AngularGradient(
            colors: [BatwalkColor.accentSoft, BatwalkColor.ringMint],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * max(0.02, min(1, progress))))
    }

    /// Warm cream backdrop for the pixel characters.
    static let lightArt = LinearGradient(
        colors: [BatwalkColor.lightTint, BatwalkColor.lightBackground],
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
