import SwiftUI
import BatwalkCore

// Reusable Batwalk components shared by the Watch and iPhone apps (P5).

// MARK: - Glass card

/// Quiet slate-green surface with a single restrained edge.
struct BatwalkGlassCard: ViewModifier {
    var padding: CGFloat = BatwalkSpacing.md
    var radius: CGFloat = BatwalkRadius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(BatwalkColor.nightCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        BatwalkColor.mist.opacity(0.22),
                        lineWidth: 1)
            )
    }
}

/// Light (iPhone) card: white, rounded, a whisper of shadow.
struct BatwalkLightCard: ViewModifier {
    var padding: CGFloat = BatwalkSpacing.lg
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(BatwalkColor.lightCard)
                    .shadow(color: BatwalkColor.accent.opacity(0.08), radius: 10, y: 4)
            )
    }
}

extension View {
    func batwalkGlassCard(padding: CGFloat = BatwalkSpacing.md, radius: CGFloat = BatwalkRadius.card) -> some View {
        modifier(BatwalkGlassCard(padding: padding, radius: radius))
    }
    func batwalkLightCard(padding: CGFloat = BatwalkSpacing.lg, radius: CGFloat = 20) -> some View {
        modifier(BatwalkLightCard(padding: padding, radius: radius))
    }
}

// MARK: - Buttons

/// Flat mint button with dark text, ≥ 44 pt tall and gentle press feedback.
struct BatwalkPrimaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, minHeight: minHeight)
    }

    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        let minHeight: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(BatwalkFont.headline)
                .foregroundStyle(BatwalkColor.buttonText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .padding(.horizontal, BatwalkSpacing.md)
                .background(Capsule().fill(BatwalkGradient.button))
                .overlay(Capsule().strokeBorder(BatwalkColor.cloud.opacity(0.15), lineWidth: 1))
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(configuration.isPressed ? BatwalkMotion.press : BatwalkMotion.release,
                           value: configuration.isPressed)
        }
    }
}

/// Subtle press feedback for cards and tiles.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(configuration.isPressed ? BatwalkMotion.press : BatwalkMotion.release,
                       value: configuration.isPressed)
    }
}

// MARK: - Progress ring

/// Gradient ring (purple → pink) on a low-opacity track. Fills from its previous
/// value in 0.7 s; optional 1.6 s pulse (off with Reduce Motion).
struct BatwalkProgressRing<Center: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 9
    var pulses = true
    var track: Color = BatwalkColor.accent.opacity(0.22)
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ambient = AmbientMotionReader()
    @State private var shown: Double = 0
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, shown)))
                .stroke(BatwalkGradient.ring(progress: shown),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .scaleEffect(pulsing ? 1.025 : 1)
        .onAppear {
            withAnimation(reduceMotion ? nil : BatwalkMotion.ringFill) { shown = progress }
        }
        .onChange(of: progress) { _, new in
            withAnimation(reduceMotion ? nil : BatwalkMotion.ringFill) { shown = new }
        }
        .task(id: pulses && ambient.allowed) {
            stopMotion { pulsing = false }
            guard pulses && ambient.allowed else { return }
            withAnimation(BatwalkMotion.ringPulse.delay(0.7)) { pulsing = true }
        }
        .onDisappear { stopMotion { pulsing = false } }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Friendship bar

/// Dark track, pink fill, animates old → new in 0.5 s.
struct FriendshipProgressView: View {
    let exp: Int
    var dark = true
    var showsLabel = true

    var body: some View {
        let progress = Friendship.levelProgress(exp: exp)
        let fraction = progress.span.map { Double(progress.current) / Double(max(1, $0)) } ?? 1
        VStack(alignment: .trailing, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(dark ? Color.white.opacity(0.12) : BatwalkColor.lockedBatLight)
                    Capsule()
                        .fill(BatwalkGradient.friendship)
                        .frame(width: max(8, geo.size.width * fraction))
                        .animation(BatwalkMotion.friendshipBar, value: fraction)
                }
            }
            .frame(height: 8)
            if showsLabel {
                Text(progress.span.map { "\(progress.current) / \($0)" } ?? "MAX")
                    .font(BatwalkFont.micro)
                    .monospacedDigit()
                    .foregroundStyle(dark ? BatwalkColor.textSecondaryDark : BatwalkColor.textSecondaryLight)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Friendship")
        .accessibilityValue(progress.span.map { "\(progress.current) of \($0)" } ?? "Max level")
    }
}

// MARK: - Chips

/// Rarity reads in its own colour: symbol and (on light surfaces) the text itself,
/// so Common and Rare never look like the same chip.
struct RarityChip: View {
    let rarity: Rarity
    var dark = true

    var body: some View {
        ChipView(text: rarity.displayName, symbol: rarity.symbol, color: rarity.color,
                 ink: dark ? nil : rarity.inkColor, dark: dark)
    }
}

struct VariantChip: View {
    let shiny: Bool
    var dark = true

    var body: some View {
        ChipView(text: shiny ? "Shiny" : "Normal",
                 symbol: shiny ? "sparkles" : nil,
                 color: shiny ? BatwalkColor.rarityShiny : BatwalkColor.mist,
                 ink: dark ? nil : (shiny ? BatwalkColor.rarityShinyInk : BatwalkColor.textSecondaryLight),
                 dark: dark)
    }
}

struct ChipView: View {
    let text: String
    var symbol: String? = nil
    let color: Color
    /// Text + symbol colour on light surfaces; the pastel `color` stays as the fill.
    var ink: Color? = nil
    var dark = true

    private var foreground: Color {
        if let ink { return ink }
        return dark ? Color.white : BatwalkColor.textPrimaryLight
    }

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                    .foregroundStyle(dark ? color : foreground)
            }
            Text(text).font(BatwalkFont.rounded(.caption2, weight: .semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(dark ? 0.22 : 0.18)))
        .overlay(Capsule().strokeBorder(color.opacity(dark ? 0.45 : 0.35), lineWidth: 1))
    }
}

// MARK: - Icons

/// Small egg icon from the egg sprites.
struct EggIcon: View {
    var type: EggType = .tiny
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let name = SpriteResolver.egg(type, state: .calm) {
                Image(name).interpolation(.none).resizable().scaledToFit()
            } else {
                Image(systemName: "oval.fill").resizable().scaledToFit().foregroundStyle(BatwalkColor.sage)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Pixel strawberry (asset `fruit_strawberry`).
struct FruitIcon: View {
    var size: CGFloat = 16

    var body: some View {
        Group {
            if assetExists("gentle_fruit_strawberry") {
                Image("gentle_fruit_strawberry").interpolation(.none).resizable().scaledToFit()
            } else if assetExists("fruit_strawberry") {
                Image("fruit_strawberry").interpolation(.none).resizable().scaledToFit()
            } else {
                Image(systemName: "leaf.fill").resizable().scaledToFit().foregroundStyle(BatwalkColor.rose)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Bat silhouette (Mochi's outline, tinted) for locked cards and brand marks.
struct BatSilhouette: View {
    var size: CGFloat = 32
    var color: Color = .white.opacity(0.14)

    var body: some View {
        Group {
            if let art = SpriteResolver.bat("mochi", mood: .awake, shiny: false) {
                Image(art.name).renderingMode(.template).interpolation(.none).resizable().scaledToFit()
            } else {
                Image(systemName: "moon.stars.fill").resizable().scaledToFit()
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Night sky

/// A still, sparse pixel glade. Canvas has no animation or background timers.
struct NightSkyBackground: View {
    var time: TimeOfDay = .night
    var scenery = true
    var groundLevel: CGFloat = 0.72

    /// The sky actually changes with the clock: a misty sage noon, a warm grey
    /// dusk, midnight teal at night. Cream text stays readable on all three.
    private var colors: [Color] {
        switch time {
        case .day: return [Color(hex: 0x56756C), Color(hex: 0x25403E)]
        case .dusk: return [Color(hex: 0x5C524C), Color(hex: 0x1E3033)]
        case .night: return [BatwalkColor.indigo, BatwalkColor.deepNight]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                drawStars(in: &context, size: size)
                if scenery {
                    drawTrees(in: &context, size: size)
                    drawGlade(in: &context, size: size)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize) {
        guard time != .day else { return } // no stars at noon
        var rng = SeededGenerator(seed: 7)
        let count = scenery ? 6 : 2
        for i in 0..<count {
            // Right half, below the time and clear of the title / friendship dots on the left.
            let x = (size.width * (0.5 + rng.nextUnit() * 0.45) / 2).rounded(.down) * 2
            let y = (size.height * (0.26 + rng.nextUnit() * 0.30) / 2).rounded(.down) * 2
            let alpha = time == .dusk ? 0.18 : 0.28
            context.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)),
                         with: .color(BatwalkColor.cloud.opacity(alpha)))
            if scenery && i == 0 {
                context.fill(Path(CGRect(x: x - 2, y: y, width: 6, height: 2)),
                             with: .color(BatwalkColor.moonlight.opacity(alpha)))
                context.fill(Path(CGRect(x: x, y: y - 2, width: 2, height: 6)),
                             with: .color(BatwalkColor.moonlight.opacity(alpha)))
            }
        }
    }

    /// Stepped pine silhouettes at both edges — a tall one half off-screen and a
    /// short one beside it — so they read as trees at wrist size while the centre
    /// stays quiet. Still art: no animation timers.
    private func drawTrees(in context: inout GraphicsContext, size: CGSize) {
        let u: CGFloat = 4
        let floor = (size.height * groundLevel / u).rounded(.down) * u
        func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
            context.fill(Path(CGRect(x: (x / u).rounded(.down) * u, y: (y / u).rounded(.down) * u,
                                     width: max(u, (w / u).rounded(.down) * u), height: max(u, h))),
                         with: .color(color), style: FillStyle(antialiased: false))
        }
        /// A pine: tiers that widen towards the ground, then a short trunk.
        func pine(centerX: CGFloat, tiers: Int, color: Color) {
            let tierHeight = u * 3
            let trunk = u * 2
            let top = floor - trunk - CGFloat(tiers) * tierHeight
            for tier in 0..<tiers {
                let width = u * CGFloat(3 + tier * 2)
                block(centerX - width / 2, top + CGFloat(tier) * tierHeight, width, tierHeight, color)
            }
            block(centerX - u, floor - trunk, u * 2, trunk, color)
        }
        let dark = BatwalkColor.deepNight.opacity(time == .day ? 0.30 : 0.55)
        let soft = BatwalkColor.accent.opacity(time == .day ? 0.28 : 0.35)
        pine(centerX: size.width * 0.02, tiers: 7, color: dark)
        pine(centerX: size.width * 0.14, tiers: 4, color: soft)
        pine(centerX: size.width * 0.98, tiers: 6, color: dark)
        pine(centerX: size.width * 0.86, tiers: 3, color: soft)
    }

    private func drawGlade(in context: inout GraphicsContext, size: CGSize) {
        let unit: CGFloat = 4
        for column in 0..<Int((size.width / unit).rounded(.up)) {
            let x = CGFloat(column) * unit
            let arch = sin(Double(x / size.width) * .pi)
            let top = ((size.height * groundLevel - CGFloat(arch) * 10) / unit).rounded(.down) * unit
            context.fill(Path(CGRect(x: x, y: top, width: unit, height: size.height - top)),
                         with: .color(BatwalkColor.accent.opacity(0.20)))
        }
        // Two small stepped leaves frame the character without a busy skyline.
        for side in [CGFloat(0.07), CGFloat(0.90)] {
            let x = (size.width * side / unit).rounded(.down) * unit
            let y = (size.height * (groundLevel - 0.08) / unit).rounded(.down) * unit
            for (dx, dy, width, height) in [(0, 0, 1, 5), (-1, 1, 1, 2), (1, -1, 1, 2), (-2, 0, 1, 1), (2, -2, 1, 1)] {
                context.fill(Path(CGRect(x: x + CGFloat(dx) * unit, y: y + CGFloat(dy) * unit,
                                        width: CGFloat(width) * unit, height: CGFloat(height) * unit)),
                             with: .color(BatwalkColor.accentSoft.opacity(0.25)))
            }
        }
    }
}

// MARK: - Particles (event-driven only)

/// 4 hearts that float up and fade in < 1 s each time `trigger` changes.
struct HeartBurst: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bursts: [Burst] = []

    struct Burst: Identifiable {
        let id = UUID()
        let offsets: [CGFloat]
    }

    var body: some View {
        ZStack {
            ForEach(bursts) { burst in
                ForEach(Array(burst.offsets.enumerated()), id: \.offset) { index, dx in
                    FloatingHeart(dx: dx, delay: Double(index) * 0.06, still: reduceMotion)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let burst = Burst(offsets: [-26, -9, 9, 26].map { $0 + CGFloat.random(in: -4...4) })
            bursts.append(burst)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1000))
                bursts.removeAll { $0.id == burst.id }
            }
        }
        .accessibilityHidden(true)
    }

    private struct FloatingHeart: View {
        let dx: CGFloat
        let delay: Double
        let still: Bool
        @State private var up = false

        var body: some View {
            Image(systemName: "heart.fill")
                .font(.system(size: 9 + abs(dx) / 8, weight: .bold))
                .foregroundStyle(BatwalkColor.rose)
                .offset(x: dx, y: up && !still ? -34 : -8)
                .opacity(up ? 0 : 1)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8).delay(delay)) { up = true }
                }
        }
    }
}

/// A handful of twinkling sparkles around a hero (hatch ready, paywall). 5 views max.
struct SparkleField: View {
    var count = 5
    var color: Color = BatwalkColor.moonlight
    var spread: CGFloat = 52
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ambient = AmbientMotionReader()
    @State private var twinkle = false

    var body: some View {
        ZStack {
            ForEach(0..<min(count, 6), id: \.self) { i in
                let angle = Double(i) / Double(max(1, count)) * 2 * .pi + 0.6
                Image(systemName: "sparkle")
                    .font(.system(size: i % 2 == 0 ? 9 : 6, weight: .bold))
                    .foregroundStyle(color)
                    .offset(x: cos(angle) * spread, y: sin(angle) * spread * 0.8)
                    .opacity(reduceMotion ? 0.8 : (twinkle == (i % 2 == 0) ? 1 : 0.3))
            }
        }
        .task(id: ambient.allowed) {
            stopMotion { twinkle = false }
            guard ambient.allowed else { return }
            withAnimation(BatwalkMotion.hatchGlow) { twinkle = true }
        }
        .onDisappear { stopMotion { twinkle = false } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Empty state

/// "No bats here yet!" card used by Collection / Batpedia / History.
struct BatwalkEmptyState: View {
    var title = "No bats here yet!"
    var message = "Keep walking and hatch your first bat!"

    var body: some View {
        VStack(spacing: BatwalkSpacing.sm) {
            BatSilhouette(size: 54, color: Color.black.opacity(0.45))
            Text(title).font(BatwalkFont.headline).foregroundStyle(.white)
            Text(message).font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryDark)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, BatwalkSpacing.xl)
        .padding(.horizontal, BatwalkSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            NightSkyBackground(time: .night, scenery: true)
                .clipShape(RoundedRectangle(cornerRadius: BatwalkRadius.largeCard, style: .continuous))
        )
    }
}
