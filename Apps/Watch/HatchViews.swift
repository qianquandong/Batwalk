import SwiftUI
import BatwalkCore

struct HatchPresentation: Identifiable {
    let id = UUID()
    let result: HatchResult
    let egg: EggType
    /// Skip straight to the reveal (demo / screenshots).
    var startRevealed = false
}

/// Hatch Ready (board: Watch › 5. Hatch Ready): warm glow, a few sparkles,
/// floating egg, one big "Hatch Now".
struct HatchReadyView: View {
    let egg: ActiveEgg
    let onHatch: () -> Void

    private let ambient = AmbientMotionReader()
    @State private var glowing = false

    var body: some View {
        GeometryReader { geo in
            let stage = geo.size.height * 0.46
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(BatwalkGradient.hatchGlow)
                        .frame(width: stage * 1.02, height: stage * 1.02)
                        .scaleEffect(glowing ? 1.08 : 0.94)
                        .opacity(glowing ? 1 : 0.75)
                    SparkleField(count: 5, spread: stage * 0.5)
                    EggSprite(type: egg.type, state: .ready, size: stage * 0.86, animated: false)
                        .idleFloat()
                }
                .frame(height: stage)
                Text("Your egg is ready!")
                    .font(BatwalkFont.headline)
                    .foregroundStyle(.white)
                Text("A new friend is waiting to hatch.")
                    .font(BatwalkFont.micro)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Button(action: onHatch) {
                    HStack(spacing: 6) {
                        EggIcon(type: egg.type, size: 16)
                        Text("Hatch Now")
                    }
                }
                .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 40))
            }
            .padding(.horizontal, BatwalkSpacing.sm)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: ambient.allowed) {
            stopMotion { glowing = false }
            guard ambient.allowed else { return }
            withAnimation(BatwalkMotion.hatchGlow) { glowing = true }
        }
        .onDisappear { stopMotion { glowing = false } }
    }
}

/// The hatch: dim → shake → crack → white/gold flash → reveal (≈ 2 s to reveal).
/// Rare / Legendary / Shiny get a stronger glow and one extra haptic.
struct HatchSequenceView: View {
    let presentation: HatchPresentation
    let onDone: () -> Void

    private enum Phase: Int, Comparable {
        case dim, shake, crack, flash, reveal
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase
    @State private var dimmed = false
    @State private var shakeAngle: Double = 0
    @State private var flash: Double = 0
    @State private var revealScale: CGFloat

    init(presentation: HatchPresentation, onDone: @escaping () -> Void) {
        self.presentation = presentation
        self.onDone = onDone
        _phase = State(initialValue: presentation.startRevealed ? .reveal : .dim)
        _revealScale = State(initialValue: presentation.startRevealed ? 1 : 0.2)
    }

    private var record: HatchRecord { presentation.result.record }
    private var species: Species? { Roster.species(record.speciesID) }
    private var rarity: Rarity { species?.rarity ?? .common }
    private var special: Bool { rarity.isSpecial || record.isShiny }

    var body: some View {
        ZStack {
            NightSkyBackground(time: .night, scenery: false)
            Color.black.opacity(dimmed && phase < .reveal ? 0.3 : 0).ignoresSafeArea()

            if phase < .flash {
                EggSprite(type: presentation.egg, state: phase >= .crack ? .cracked : .ready,
                          size: 96, animated: false)
                    .rotationEffect(.degrees(shakeAngle), anchor: .bottom)
                    .scaleEffect(phase == .crack ? 1.06 : 1)
            }

            if phase == .reveal {
                reveal.transition(.opacity)
            }

            Color(hex: 0xFFF6D6).opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .task { await run() }
    }

    private var reveal: some View {
        ScrollView {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [(special ? rarity.color : BatwalkColor.purpleGlow).opacity(special ? 0.75 : 0.45), .clear],
                                             center: .center, startRadius: 4, endRadius: 64))
                        .frame(width: 110, height: 110)
                    if special { SparkleField(count: 6, color: record.isShiny ? BatwalkColor.rarityShiny : rarity.color, spread: 50) }
                    BatSprite(speciesID: record.speciesID, shiny: record.isShiny, mood: .happy, size: 84)
                        .scaleEffect(revealScale)
                }
                .frame(height: 92)
                Text(species?.name ?? "New bat")
                    .font(BatwalkFont.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    RarityChip(rarity: rarity)
                    if record.isShiny { VariantChip(shiny: true) }
                }
                Text(subtitle)
                    .font(BatwalkFont.micro)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                    .multilineTextAlignment(.center)
                Button("Start next egg", action: onDone)
                    .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 36))
                    .padding(.top, 4)
            }
            .padding(.horizontal, BatwalkSpacing.sm)
        }
    }

    private var subtitle: String {
        switch record.outcome {
        case .newSpecies: return record.isShiny ? "A Shiny new friend!" : "A new friend!"
        case .newShiny: return "A Shiny one!"
        case .duplicate: return "Old friend! +\(presentation.result.friendshipGained) Friendship"
        }
    }

    /// Sleeps; false if the cover was dismissed (task cancelled) so the sequence stops.
    private func pause(_ ms: Int) async -> Bool {
        (try? await Task.sleep(for: .milliseconds(ms))) != nil
    }

    @MainActor
    private func run() async {
        guard phase != .reveal else { return }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .reveal
                revealScale = 1
            }
            Haptics.strong()
            return
        }
        withAnimation(.easeOut(duration: 0.25)) { dimmed = true }
        guard await pause(250) else { return }

        phase = .shake
        for i in 0..<6 {
            withAnimation(.easeInOut(duration: 0.06)) { shakeAngle = i.isMultiple(of: 2) ? 9 : -9 }
            guard await pause(65) else { return }
        }
        withAnimation(.easeOut(duration: 0.08)) { shakeAngle = 0 }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { phase = .crack }
        Haptics.light()
        guard await pause(450) else { return }

        withAnimation(.easeIn(duration: 0.12)) { flash = 1 }
        guard await pause(130) else { return }
        phase = .reveal
        Haptics.strong()
        withAnimation(.easeOut(duration: 0.4)) { flash = 0 }
        withAnimation(BatwalkMotion.unlock) { revealScale = 1 }

        if special {
            guard await pause(400) else { return }
            Haptics.success()
        }
    }
}
