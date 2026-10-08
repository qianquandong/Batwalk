import SwiftUI
#if os(watchOS)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Motion system (UI_REDESIGN_TASKS P6). Every repeating or decorative motion
/// checks Reduce Motion; repeating animations stop when their view disappears.
enum BatwalkMotion {
    static let idleFloatDuration = 2.4
    static let idleFloatDistance: CGFloat = 1.5          // ±1.5 pt ≈ 3 px travel
    static let press = Animation.easeOut(duration: 0.1)
    static let release = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let bounce = Animation.spring(response: 0.35, dampingFraction: 0.5)
    static let ringFill = Animation.easeOut(duration: 0.7)
    static let ringPulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) // 1.6 s loop
    static let friendshipBar = Animation.easeOut(duration: 0.5)
    static let hatchGlow = Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true) // 1.8 s loop
    static let unlock = Animation.spring(response: 0.45, dampingFraction: 0.55)
    static let page = Animation.easeInOut(duration: 0.3)
}

// MARK: - Idle float + ear twitch

/// Gentle 2.4 s bob. Off with Reduce Motion; stops when off screen.
struct IdleFloat: ViewModifier {
    var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -BatwalkMotion.idleFloatDistance : BatwalkMotion.idleFloatDistance)
            .onAppear {
                guard enabled, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: BatwalkMotion.idleFloatDuration).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
            .onDisappear {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { up = false }
            }
    }
}

/// Sprites are single images, so the "ear twitch" is a quick ±3° head tilt
/// every 6–10 s. The loop lives in `.task`, which SwiftUI cancels off screen.
struct EarTwitch: ViewModifier {
    var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle), anchor: .bottom)
            .task {
                guard enabled, !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 6...10)))
                    if Task.isCancelled { break }
                    withAnimation(.easeOut(duration: 0.15)) { angle = Bool.random() ? 3 : -3 }
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.easeInOut(duration: 0.2)) { angle = 0 }
                }
            }
    }
}

/// Happy bounce: scale 1 → 1.06 → 1 and lift ~3 pt, 0.35 s spring. Fires when `trigger` changes.
struct HappyBounce: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bumped = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(bumped ? 1.06 : 1)
            .offset(y: bumped ? -3 : 0)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                withAnimation(BatwalkMotion.bounce) { bumped = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(170))
                    withAnimation(BatwalkMotion.bounce) { bumped = false }
                }
            }
    }
}

/// Page / content entrance: fade + 12 pt slide (fade only with Reduce Motion).
struct BatwalkAppear: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown || reduceMotion ? 0 : 12)
            .onAppear {
                guard !shown else { return }
                withAnimation(BatwalkMotion.page.delay(delay)) { shown = true }
            }
    }
}

/// Card / tile unlock: opacity 0 → 1, scale 0.9 → ~1.04 → 1 with a brief glow.
struct UnlockReveal: ViewModifier {
    let isNew: Bool
    var glow: Color = BatwalkColor.purpleGlow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .opacity(!isNew || revealed ? 1 : 0)
            .scaleEffect(!isNew || revealed || reduceMotion ? 1 : 0.9)
            .shadow(color: glow.opacity(glowing ? 0.9 : 0), radius: 8)
            .onAppear {
                guard isNew, !revealed else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.3) : BatwalkMotion.unlock) {
                    revealed = true
                    glowing = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    withAnimation(.easeOut(duration: 0.4)) { glowing = false }
                }
            }
    }
}

/// iPhone grids: cards fade/slide in with ≤ 35 ms stagger (capped so it never drags).
struct StaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .onAppear {
                guard !shown else { return }
                withAnimation(.easeOut(duration: 0.3).delay(Double(min(index, 12)) * 0.035)) { shown = true }
            }
    }
}

extension View {
    func idleFloat(_ enabled: Bool = true) -> some View { modifier(IdleFloat(enabled: enabled)) }
    func earTwitch(_ enabled: Bool = true) -> some View { modifier(EarTwitch(enabled: enabled)) }
    func happyBounce(trigger: Int) -> some View { modifier(HappyBounce(trigger: trigger)) }
    func batwalkAppear(delay: Double = 0) -> some View { modifier(BatwalkAppear(delay: delay)) }
    func unlockReveal(isNew: Bool, glow: Color = BatwalkColor.purpleGlow) -> some View {
        modifier(UnlockReveal(isNew: isNew, glow: glow))
    }
    func staggeredAppear(index: Int) -> some View { modifier(StaggeredAppear(index: index)) }
}

// MARK: - Haptics (P9: meaningful actions only)

enum Haptics {
    /// Feed, pet.
    static func light() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #elseif canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Friendship level up, purchase success.
    static func success() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #elseif canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Egg ready.
    static func notify() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #elseif canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Hatch.
    static func strong() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #elseif canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    static func failure() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
        #elseif canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
