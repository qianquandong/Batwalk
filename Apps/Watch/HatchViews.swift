import SwiftUI
import BatwalkCore

struct HatchPresentation: Identifiable {
    let id = UUID()
    let result: HatchResult
    let egg: EggType
    /// Skip straight to the reveal (demo / screenshots, Moon Dust calls).
    var startRevealed = false
    /// The first reveal introduces the companion before any next-egg choice.
    var isFirstCompanion = false
}

/// Hatch Ready (board: Watch › 5. Hatch Ready), now something the player *does*:
/// turn the Digital Crown or tap the egg to work the shell open. Light leaks out
/// as it cracks; a tick on the wrist at each third. "Hatch Now" stays for anyone
/// who would rather press a button (VoiceOver, AssistiveTouch, Reduce Motion).
struct HatchReadyView: View {
    let egg: ActiveEgg
    var showHint = false
    let onHatch: () -> Void

    private let ambient = AmbientMotionReader()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.batPageVisible) private var pageVisible
    @State private var glowing = false
    /// 0…1: how far the shell has been opened with the crown or taps.
    @State private var crack: Double = 0
    @State private var lastTick = 0
    @State private var hatched = false
    @FocusState private var crownFocused: Bool

    private var motionAllowed: Bool { ambient.allowed && scenePhase == .active && pageVisible }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                if typeSize.isAccessibilitySize {
                    ScrollView {
                        readyContent(stage: 64)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    readyContent(stage: min(112, max(44, geo.size.height - (showHint ? 92 : 54))))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Button(action: hatchNow) {
                    HStack(spacing: 6) {
                        EggIcon(type: egg.type, size: 16)
                        Text("Hatch")
                    }
                }
                .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
                .doubleTapPrimaryAction()
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, BatwalkSpacing.sm)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation($crack, from: 0, through: 1, by: 0.02, sensitivity: .medium,
                              isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crack) { _, value in tick(value) }
        .onAppear { crownFocused = pageVisible }
        .onChange(of: pageVisible) { _, visible in crownFocused = visible }
        .task(id: motionAllowed) {
            stopMotion { glowing = false }
            guard motionAllowed else { return }
            // A short invitation, then a still egg. No repeating glow while
            // the player reads the first-use hint or leaves the Watch idle.
            for _ in 0..<2 {
                withAnimation(.easeInOut(duration: 0.65)) { glowing = true }
                guard (try? await Task.sleep(for: .milliseconds(650))) != nil else { return }
                withAnimation(.easeInOut(duration: 0.65)) { glowing = false }
                guard (try? await Task.sleep(for: .milliseconds(650))) != nil else { return }
            }
        }
        .onDisappear { stopMotion { glowing = false } }
    }

    private func readyContent(stage: CGFloat) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(BatwalkGradient.hatchGlow)
                    .frame(width: stage, height: stage)
                    .scaleEffect((glowing ? 1.08 : 0.94) + crack * 0.1)
                    .opacity(glowing ? 1 : 0.75)
                Circle()
                    .fill(BatwalkColor.moonlight.opacity(0.4 * crack))
                    .frame(width: stage * 0.7, height: stage * 0.7)
                    .blur(radius: 6)
                Button { advance(by: 0.34) } label: {
                    EggSprite(type: egg.type, state: crack >= 0.5 ? .cracked : .ready,
                              size: stage * 0.86, animated: false)
                        .rotationEffect(.degrees(reduceMotion ? 0 : sin(crack * .pi * 6) * 4), anchor: .bottom)
                        .scaleEffect(1 + crack * 0.06)
                        .frame(width: stage, height: stage)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Egg")
                .accessibilityValue("\(Int(crack * 100)) percent open")
                .accessibilityHint("Tap three times, or turn the Digital Crown, to crack it open")
            }
            .frame(height: stage)
            if showHint {
                Text("Tap the egg or turn the Crown.")
                    .font(BatwalkFont.caption)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func advance(by amount: Double) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6)) {
            crack = min(1, crack + amount)
        }
    }

    private func tick(_ value: Double) {
        let third = Int((value * 3).rounded(.down))
        if third > lastTick {
            lastTick = third
            Haptics.crack()
        }
        if value >= 1 { hatchNow() }
    }

    private func hatchNow() {
        guard !hatched else { return }
        hatched = true
        onHatch()
    }
}

/// The hatch: dim → shake (building up) → crack, with light the colour of the
/// rarity leaking through → flash → reveal. ≈ 2.4 s to the bat, then the
/// rarity's haptic signature (PRD §4.7: 2–4 s; §8: Rare/Legendary must feel special).
struct HatchSequenceView: View {
    let presentation: HatchPresentation
    let onDone: () -> Void

    private enum Phase: Int, Comparable {
        case dim, shake, crack, flash, reveal
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var phase: Phase
    @State private var dimmed = false
    @State private var shakeAngle: Double = 0
    @State private var tease: Double = 0
    @State private var flash: Double = 0
    @State private var revealScale: CGFloat
    @State private var revealRequest = BatAnimationRequest([.hatch])

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
    private var teaseColor: Color { record.isShiny ? BatwalkColor.rarityShiny : special ? rarity.color : BatwalkColor.moonlight }
    // A presented cover can resolve its size outside the root's demo override.
    // Apply the capture override at this presentation boundary as well.
    private var revealTypeSize: DynamicTypeSize {
        DemoMode.scenario == "reveal-large-type" ? .accessibility3 : typeSize
    }

    var body: some View {
        ZStack {
            NightSkyBackground(time: .night, scenery: false)
            Color.black.opacity(dimmed && phase < .reveal ? 0.3 : 0).ignoresSafeArea()

            if phase < .flash {
                ZStack {
                    // The tease: light in the rarity's colour grows behind the cracks.
                    Circle()
                        .fill(RadialGradient(colors: [teaseColor.opacity(0.9 * tease), .clear],
                                             center: .center, startRadius: 2, endRadius: 70))
                        .frame(width: 150, height: 150)
                        .blur(radius: 4)
                    EggSprite(type: presentation.egg, state: phase >= .crack ? .cracked : .ready,
                              size: 96, animated: false)
                        .rotationEffect(.degrees(shakeAngle), anchor: .bottom)
                        .scaleEffect(phase == .crack ? 1.06 : 1)
                }
            }

            if phase == .reveal {
                reveal.transition(.opacity)
            }

            Color(hex: 0xFFF6D6).opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .dynamicTypeSize(revealTypeSize)
        .task { await run() }
    }

    /// The essential reveal fits first. Accessibility text can scroll above a
    /// pinned Continue button, including shiny and duplicate-reward variants.
    private var reveal: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                if revealTypeSize.isAccessibilitySize {
                    ScrollView { revealDetails(pictureSize: 60) }
                } else {
                    // Reserve space for the name, chips and Continue first. A
                    // scroll view's flexible proposal otherwise hides the labels
                    // behind the pinned button on a 41 mm Watch.
                    revealDetails(pictureSize: min(112, max(36, geometry.size.height - 76)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Button(presentation.isFirstCompanion ? "Say hello" : "Continue", action: onDone)
                    .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
                    .doubleTapPrimaryAction()
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, BatwalkSpacing.sm)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func revealDetails(pictureSize: CGFloat) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [(special ? rarity.color : BatwalkColor.accentSoft).opacity(special ? 0.22 : 0.12), .clear],
                                         center: .center, startRadius: 4, endRadius: 64))
                    .frame(width: pictureSize, height: pictureSize)
                if special { SparkleField(count: 6, color: record.isShiny ? BatwalkColor.rarityShiny : rarity.color, spread: pictureSize * 0.45) }
                BatHeroView(speciesID: record.speciesID, shiny: record.isShiny, mood: .happy, size: pictureSize,
                            animationRequest: revealRequest, showsKeepsake: false)
                    .scaleEffect(revealScale)
            }
            .frame(height: pictureSize)
            if presentation.isFirstCompanion {
                Text("Meet \(species?.name.replacingOccurrences(of: " Bat", with: "") ?? "your new friend")")
                    .font(BatwalkFont.headline)
                    .foregroundStyle(BatwalkColor.cloud)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if record.outcome == .duplicate {
                Label("+\(presentation.result.friendshipGained) XP", systemImage: "heart")
                    .font(BatwalkFont.headline)
                    .foregroundStyle(BatwalkColor.cloud)
            } else {
                Text(record.isShiny ? "A Shiny friend" : "A new friend")
                    .font(BatwalkFont.caption)
                    .foregroundStyle(BatwalkColor.cloud)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Sleeps; false if the cover was dismissed (task cancelled) so the sequence stops.
    private func pause(_ ms: Int) async -> Bool {
        (try? await Task.sleep(for: .milliseconds(ms))) != nil
    }

    @MainActor
    private func run() async {
        if phase == .reveal {
            // Moon Dust calls open straight on the bat; they still deserve the wrist signature.
            if record.source == .moonDust { await Haptics.reveal(rarity: rarity, shiny: record.isShiny) }
            return
        }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .reveal
                revealScale = 1
            }
            await Haptics.reveal(rarity: rarity, shiny: record.isShiny)
            return
        }
        withAnimation(.easeOut(duration: 0.3)) { dimmed = true }
        guard await pause(300) else { return }

        // Shake that builds — the egg is working at it.
        phase = .shake
        for i in 0..<8 {
            let amplitude = 6 + Double(i) * 0.75
            withAnimation(.easeInOut(duration: 0.07)) { shakeAngle = i.isMultiple(of: 2) ? amplitude : -amplitude }
            guard await pause(70) else { return }
        }
        withAnimation(.easeOut(duration: 0.08)) { shakeAngle = 0 }

        // Crack: light leaks out in the rarity's colour before anything is shown.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { phase = .crack }
        Haptics.crack()
        withAnimation(.easeIn(duration: 0.8)) { tease = special ? 1 : 0.45 }
        guard await pause(500) else { return }
        if special { Haptics.light() } // a second knock from inside for Rare and up
        guard await pause(400) else { return }

        withAnimation(.easeIn(duration: 0.15)) { flash = 1 }
        guard await pause(150) else { return }
        phase = .reveal
        withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
        withAnimation(BatwalkMotion.unlock) { revealScale = 1 }
        await Haptics.reveal(rarity: rarity, shiny: record.isShiny)
    }
}
