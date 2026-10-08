import SwiftUI
import BatwalkCore
#if canImport(UIKit)
import UIKit
#endif

/// Asset naming contract with the pixel artist (see Art/README.md):
///   bat_<speciesID>_<mood>[_shiny]   e.g. bat_moonwing_sleeping_shiny
///   egg_<eggType>_<visualState>      e.g. egg_forest_cracked
/// Until real art lands, a vector placeholder is drawn so every screen works.
enum SpriteName {
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
        if shiny {
            for m in moods where assetExists(SpriteName.bat(speciesID, mood: m, shiny: true)) {
                return Resolved(name: SpriteName.bat(speciesID, mood: m, shiny: true), hueDegrees: 0)
            }
        }
        let shinyShift: Double = shiny ? 150 : 0
        for m in moods where assetExists(SpriteName.bat(speciesID, mood: m, shiny: false)) {
            return Resolved(name: SpriteName.bat(speciesID, mood: m, shiny: false), hueDegrees: shinyShift)
        }
        let (hue, sat, bright) = borrowedTint[speciesID] ?? (0, 1, 0)
        for m in moods where assetExists(SpriteName.bat("mochi", mood: m, shiny: false)) {
            return Resolved(name: SpriteName.bat("mochi", mood: m, shiny: false),
                            hueDegrees: hue + shinyShift, saturation: sat, brightness: bright)
        }
        return nil
    }

    static func egg(_ type: EggType, state: EggVisualState) -> String? {
        [SpriteName.egg(type, state: state), "egg_forest_\(state.rawValue)"].first(where: assetExists)
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

    var body: some View {
        BatSprite(speciesID: speciesID, shiny: shiny, mood: mood, size: size)
            .shadow(color: (glow ?? .clear).opacity(0.5), radius: size * 0.12)
            .earTwitch(mood != .sleeping)
            .happyBounce(trigger: bounceTrigger)
            .idleFloat()
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    private var moves: Bool { animated && !reduceMotion && state != .calm }

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
        .onAppear {
            guard moves else { return }
            withAnimation(.easeInOut(duration: wiggleDuration).repeatForever(autoreverses: true)) { wiggle = true }
        }
        .onDisappear {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { wiggle = false }
        }
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
