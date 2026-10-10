import SwiftUI
import BatwalkCore
#if canImport(UIKit)
import UIKit
#endif

/// Legacy asset naming contract (see Art/README.md). Gentle pixel assets use
/// a versioned prefix and resolve before these earlier illustrations.
///   bat_<speciesID>_<mood>[_shiny]   e.g. bat_moonwing_sleeping_shiny
///   egg_<eggType>_<visualState>      e.g. egg_forest_cracked
/// Until real art lands, a vector placeholder is drawn so every screen works.
enum SpriteName {
    static func gentleBat(_ speciesID: String, mood: BatMood, shiny: Bool) -> String {
        "gentle_bat_\(speciesID)_\(mood.rawValue)" + (shiny ? "_shiny" : "")
    }

    static func bat(_ speciesID: String, mood: BatMood, shiny: Bool) -> String {
        "bat_\(speciesID)_\(mood.rawValue)" + (shiny ? "_shiny" : "")
    }

    static func egg(_ type: EggType, state: EggVisualState) -> String {
        "egg_\(type.rawValue)_\(state.rawValue)"
    }
}

/// Resolves which image to show, falling back gracefully while art is incomplete:
/// exact pose → a related pose of the same species → Mochi recoloured for this
/// species (keeps every bat on-style) → nil (vector placeholder).
enum SpriteResolver {
    struct Resolved {
        let name: String
        /// Hue rotation applied when borrowing another species' art or faking Shiny.
        let hueDegrees: Double
        var saturation: Double = 1
        var brightness: Double = 0
    }

    /// Recolour of Mochi for species without art yet, matched to the roster's
    /// visual hooks (PRD §6): (hue°, saturation, brightness).
    private static let borrowedTint: [String: (Double, Double, Double)] = [
        "cocoa": (0, 1.0, -0.12), "long-ear": (20, 0.8, 0.05), "fruit": (-20, 1.2, 0),
        "cave": (190, 0.5, -0.05), "sleepy": (250, 0.7, 0.05), "dust": (0, 0, 0.05),
        "pebble": (0, 0.2, -0.05), "blossom": (-40, 0.9, 0.12), "moss": (70, 0.9, 0),
        "sunset": (-10, 1.4, 0.05), "snow": (180, 0.2, 0.25), "cloud": (0, 0.1, 0.2),
        "golden": (20, 1.6, 0.1), "crystal": (190, 1.3, 0.05), "vampire": (0, 0.3, -0.25),
        "eclipse": (0, 0, -0.3),
    ]

    private static let moodFallbacks: [BatMood: [BatMood]] = [
        .sleeping: [.sleeping, .drowsy, .awake],
        .drowsy: [.drowsy, .sleeping, .awake],
        .awake: [.awake, .happy],
        .happy: [.happy, .awake],
        .eating: [.eating, .happy, .awake],
        .playing: [.playing, .awake],
    ]

    static func bat(_ speciesID: String, mood: BatMood, shiny: Bool) -> Resolved? {
        let moods = moodFallbacks[mood] ?? [mood]
        for m in moods where assetExists(SpriteName.gentleBat(speciesID, mood: m, shiny: shiny)) {
            return Resolved(name: SpriteName.gentleBat(speciesID, mood: m, shiny: shiny), hueDegrees: 0)
        }
        if shiny {
            for m in moods where assetExists(SpriteName.bat(speciesID, mood: m, shiny: true)) {
                return Resolved(name: SpriteName.bat(speciesID, mood: m, shiny: true), hueDegrees: 0)
            }
        }
        let shinyShift: Double = shiny ? 150 : 0
        for m in moods where assetExists(SpriteName.bat(speciesID, mood: m, shiny: false)) {
            return Resolved(name: SpriteName.bat(speciesID, mood: m, shiny: false), hueDegrees: shinyShift)
        }
        // These free companions have distinct silhouettes and palettes rather
        // than borrowing the mascot. Dedicated artist assets still take precedence.
        if speciesID == "cocoa" || speciesID == "long-ear" { return nil }
        let (hue, sat, bright) = borrowedTint[speciesID] ?? (0, 1, 0)
        for m in moods where assetExists(SpriteName.bat("mochi", mood: m, shiny: false)) {
            return Resolved(name: SpriteName.bat("mochi", mood: m, shiny: false),
                            hueDegrees: hue + shinyShift, saturation: sat, brightness: bright)
        }
        return nil
    }

    static func egg(_ type: EggType, state: EggVisualState) -> String? {
        ["gentle_\(SpriteName.egg(type, state: state))",
         "gentle_\(SpriteName.egg(type, state: .calm))",
         SpriteName.egg(type, state: state), "egg_forest_\(state.rawValue)"].first(where: assetExists)
    }
}

func assetExists(_ name: String) -> Bool {
    #if canImport(UIKit)
    return UIImage(named: name) != nil
    #else
    return false
    #endif
}

/// Placeholder colours per species until the art board's palettes are wired in.
enum SpeciesPalette {
    static func body(_ speciesID: String, shiny: Bool) -> Color {
        let number = Roster.species(speciesID)?.number ?? 1
        let hue = Double((number * 37) % 100) / 100
        return shiny
            ? Color(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.95)
            : Color(hue: hue, saturation: 0.35, brightness: 0.55)
    }
}

struct BatSprite: View {
    let speciesID: String
    var shiny = false
    var mood: BatMood = .awake
    var size: CGFloat = 96

    var body: some View {
        Group {
            if let art = SpriteResolver.bat(speciesID, mood: mood, shiny: shiny) {
                Image(art.name)
                    .interpolation(.none) // crisp pixel art
                    .resizable()
                    .scaledToFit()
                    .hueRotation(.degrees(art.hueDegrees))
                    .saturation(art.saturation)
                    .brightness(art.brightness)
            } else if speciesID == "cocoa" || speciesID == "long-ear" {
                FreeBatArtwork(longEars: speciesID == "long-ear", shiny: shiny, mood: mood)
            } else {
                PlaceholderBat(color: SpeciesPalette.body(speciesID, shiny: shiny), mood: mood)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Roster.species(speciesID)?.name ?? "Bat")
    }
}

/// The character as hero: idle float (2.4 s), ear twitch (6–10 s), happy bounce
/// on `bounceTrigger`. All motion respects Reduce Motion and stops off screen.
struct BatHeroView: View {
    let speciesID: String
    var shiny = false
    var mood: BatMood = .awake
    var size: CGFloat = 110
    var bounceTrigger = 0
    var glow: Color? = nil
    var friendshipEXP = 0

    var body: some View {
        BatSprite(speciesID: speciesID, shiny: shiny, mood: mood, size: size)
            .shadow(color: (glow ?? .clear).opacity(0.5), radius: size * 0.12)
            .earTwitch(mood != .sleeping)
            .happyBounce(trigger: bounceTrigger)
            .idleFloat()
            .overlay(alignment: .bottomTrailing) {
                let level = Friendship.level(forEXP: friendshipEXP)
                if level >= 2 {
                    Image(systemName: level == 5 ? "crown.fill" : level == 4 ? "star.fill" : level == 3 ? "leaf.fill" : "heart.fill")
                        .font(.system(size: max(10, size * 0.13), weight: .bold))
                        .foregroundStyle(level == 5 ? Color.yellow : level == 3 ? Color.green : BatwalkColor.rose)
                        .padding(4)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                        .accessibilityLabel(Friendship.keepsake(forEXP: friendshipEXP) ?? "")
                }
            }
    }
}

/// Small code-native pixel drawings with separate silhouettes for the free roster.
private struct FreeBatArtwork: View {
    let longEars: Bool
    let shiny: Bool
    let mood: BatMood

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 24
            let origin = CGPoint(x: (size.width - unit * 24) / 2, y: (size.height - unit * 24) / 2)
            let outline = Color(red: 0.17, green: 0.12, blue: 0.23)
            let body = longEars ? (shiny ? Color(red: 0.68, green: 0.54, blue: 0.88) : Color(red: 0.92, green: 0.82, blue: 0.62))
                : (shiny ? Color(red: 0.38, green: 0.65, blue: 0.79) : Color(red: 0.47, green: 0.27, blue: 0.20))
            let accent = longEars ? Color(red: 0.45, green: 0.68, blue: 0.61) : Color(red: 0.85, green: 0.59, blue: 0.37)
            func block(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Color) {
                let rect = CGRect(x: origin.x + CGFloat(x) * unit, y: origin.y + CGFloat(y) * unit,
                    width: CGFloat(w) * unit, height: CGFloat(h) * unit)
                context.fill(Path(rect), with: .color(color), style: FillStyle(antialiased: false))
            }
            let tucked = mood == .sleeping || mood == .drowsy
            for left in [true, false] {
                let wing = left ? (tucked ? 6 : 1) : (tucked ? 15 : 17)
                block(wing, 12, tucked ? 3 : 6, 5, outline)
                block(wing + 1, 13, tucked ? 2 : 4, 3, body)
                if !tucked { block(left ? 3 : 18, 11, 3, 1, outline); block(left ? 2 : 19, 17, 2, 1, outline) }
                let ear = left ? 7 : 14
                block(ear, longEars ? 1 : 7, 3, longEars ? 11 : 5, outline)
                block(ear + 1, longEars ? 2 : 8, 1, longEars ? 8 : 3, accent)
            }
            block(8, 10, 8, 11, outline)
            block(7, 12, 10, 7, outline)
            block(8, 12, 8, 7, body)
            block(9, 11, 6, 9, body)
            block(10, 17, 4, 2, accent)
            if tucked {
                block(9, 14, 2, 1, outline); block(13, 14, 2, 1, outline)
            } else {
                block(9, 13, 2, 3, outline); block(13, 13, 2, 3, outline)
                block(9, 13, 1, 1, .white); block(13, 13, 1, 1, .white)
            }
            if mood == .happy || mood == .eating {
                block(8, 16, 1, 1, .pink); block(15, 16, 1, 1, .pink)
            }
            block(11, 16, 2, 1, outline)
        }
        .accessibilityHidden(true)
    }
}

/// Round body, readable ears, big eyes, clear wings (PRD §3.1) — in vector form.
private struct PlaceholderBat: View {
    let color: Color
    let mood: BatMood

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let wingsOpen = mood == .awake || mood == .playing || mood == .happy
            ZStack {
                // Wings
                HStack(spacing: s * (wingsOpen ? 0.18 : 0.02)) {
                    Ellipse().frame(width: s * 0.38, height: s * 0.26).rotationEffect(.degrees(wingsOpen ? -20 : 30))
                    Ellipse().frame(width: s * 0.38, height: s * 0.26).rotationEffect(.degrees(wingsOpen ? 20 : -30))
                }
                .foregroundStyle(color.opacity(0.75))
                .offset(y: s * 0.05)

                // Ears
                HStack(spacing: s * 0.16) {
                    Triangle().frame(width: s * 0.16, height: s * 0.2)
                    Triangle().frame(width: s * 0.16, height: s * 0.2)
                }
                .foregroundStyle(color)
                .offset(y: -s * 0.24)

                // Body
                Circle().fill(color).frame(width: s * 0.5, height: s * 0.5)

                // Eyes
                HStack(spacing: s * 0.1) {
                    Eye(size: s * 0.1, closed: mood == .sleeping, sleepy: mood == .drowsy)
                    Eye(size: s * 0.1, closed: mood == .sleeping, sleepy: mood == .drowsy)
                }
                .offset(y: -s * 0.03)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct Eye: View {
    let size: CGFloat
    let closed: Bool
    let sleepy: Bool

    var body: some View {
        if closed {
            Capsule().fill(.black.opacity(0.7)).frame(width: size, height: size * 0.18)
        } else {
            ZStack(alignment: .topTrailing) {
                Circle().fill(.black)
                Circle().fill(.white).frame(width: size * 0.35, height: size * 0.35).offset(x: -size * 0.12, y: size * 0.12)
            }
            .frame(width: size, height: sleepy ? size * 0.55 : size)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Egg with progress-driven motion (PRD §3.5): calm → occasional shake →
/// cracks → frequent rattle. Static with Reduce Motion or `animated: false`.
struct EggSprite: View {
    let type: EggType
    let state: EggVisualState
    var size: CGFloat = 96
    var animated = true

    private let ambient = AmbientMotionReader()
    @State private var wiggle = false

    private var wiggleDegrees: Double {
        switch state {
        case .calm: return 0
        case .shaking: return 3
        case .cracked: return 5
        case .rattling, .ready: return 8
        }
    }

    private var wiggleDuration: Double {
        switch state {
        case .calm, .shaking: return 0.9
        case .cracked: return 0.5
        case .rattling, .ready: return 0.25
        }
    }

    private var moves: Bool { animated && ambient.allowed && state != .calm }

    var body: some View {
        Group {
            if let name = SpriteResolver.egg(type, state: state) {
                Image(name).interpolation(.none).resizable().scaledToFit()
            } else {
                PlaceholderEgg(type: type, cracked: state == .cracked || state == .rattling || state == .ready)
            }
        }
        .frame(width: size * 0.8, height: size)
        .rotationEffect(.degrees(moves && wiggle ? wiggleDegrees : (moves ? -wiggleDegrees : 0)), anchor: .bottom)
        // Restarts when the egg changes state (calm → shaking → cracked…) or motion is toggled.
        .task(id: "\(moves)-\(state.rawValue)") {
            stopMotion { wiggle = false }
            guard moves else { return }
            withAnimation(.easeInOut(duration: wiggleDuration).repeatForever(autoreverses: true)) { wiggle = true }
        }
        .onDisappear { stopMotion { wiggle = false } }
        .accessibilityLabel(type.displayName)
    }
}

private struct PlaceholderEgg: View {
    let type: EggType
    let cracked: Bool

    private var tint: Color {
        switch type {
        case .starter: return Color(red: 0.95, green: 0.9, blue: 0.8)
        case .tiny: return Color(red: 0.85, green: 0.8, blue: 0.95)
        case .forest: return Color(red: 0.6, green: 0.8, blue: 0.55)
        case .moon: return Color(red: 0.45, green: 0.5, blue: 0.85)
        case .crystal: return Color(red: 0.6, green: 0.85, blue: 0.95)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Ellipse().fill(tint)
                if cracked {
                    Path { p in
                        let w = geo.size.width, h = geo.size.height
                        p.move(to: CGPoint(x: w * 0.2, y: h * 0.45))
                        p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.55))
                        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.42))
                        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.56))
                        p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.46))
                    }
                    .stroke(.black.opacity(0.55), lineWidth: max(1.5, geo.size.width * 0.03))
                }
            }
        }
    }
}
