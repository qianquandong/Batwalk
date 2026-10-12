import SwiftUI
import BatwalkCore

// Watch-only reusable components (UI_REDESIGN_TASKS P5).

/// Glass stat row: icon · title · value (· chevron).
struct BatwalkStatRow<Icon: View>: View {
    let title: String
    let value: String
    var chevron = false
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: BatwalkSpacing.sm) {
            icon().frame(width: 18, height: 18)
            Text(title).font(BatwalkFont.caption)
            Spacer(minLength: 4)
            Text(value).font(BatwalkFont.rounded(.footnote, weight: .semibold)).monospacedDigit()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
            }
        }
        .foregroundStyle(.white)
        .batwalkGlassCard(padding: 8, radius: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Five small dots under the companion's name: the quiet Watch answer to
/// "how close are we?" without listing a level. Pulses once on a level-up.
struct FriendshipDots: View {
    let level: Int
    var pulse = 0
    var maxLevel = Friendship.maxLevel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swelling = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...maxLevel, id: \.self) { step in
                Circle()
                    .fill(step <= level ? BatwalkColor.rose : BatwalkColor.cloud.opacity(0.22))
                    .frame(width: 4, height: 4)
            }
        }
        .scaleEffect(swelling ? 1.35 : 1)
        .onChange(of: pulse) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { swelling = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) { swelling = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Friendship level \(level) of \(maxLevel)")
    }
}

/// 🍓 Feed (n) — premium even when disabled.
struct FeedButton: View {
    let fruit: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                FruitIcon(size: 16)
                Text("Feed · \(fruit)")
            }
        }
        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
        .disabled(fruit == 0)
        .accessibilityLabel("Feed")
        .accessibilityValue("\(fruit) fruit")
    }
}

/// A fruit that hops up into the bat each time `trigger` changes.
struct FruitToss: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tosses: [UUID] = []

    var body: some View {
        ZStack {
            ForEach(tosses, id: \.self) { _ in
                TossedFruit(still: reduceMotion)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let id = UUID()
            tosses.append(id)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                tosses.removeAll { $0 == id }
            }
        }
        .accessibilityHidden(true)
    }

    private struct TossedFruit: View {
        let still: Bool
        @State private var flown = false

        var body: some View {
            FruitIcon(size: 18)
                .offset(y: flown && !still ? -6 : 40)
                .scaleEffect(flown ? 0.4 : 1)
                .opacity(flown ? 0 : 1)
                .onAppear { withAnimation(.easeIn(duration: 0.45)) { flown = true } }
        }
    }
}

/// Unlocked bat in the collection grid: sprite, glowing border, short name, ♥ if companion.
struct BatCollectionTile: View {
    let bat: OwnedBat
    let isCompanion: Bool
    var isNew = false

    private var shortName: String {
        let name = bat.nickname ?? bat.species?.name ?? bat.speciesID
        return name.hasSuffix(" Bat") ? String(name.dropLast(4)) : name
    }

    var body: some View {
        VStack(spacing: 1) {
            BatSprite(speciesID: bat.speciesID, shiny: bat.showsShiny, mood: .awake, size: 36)
            Text(shortName)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [BatwalkColor.nightCardElevated, BatwalkColor.nightCard],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(BatwalkColor.mist.opacity(0.28), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isCompanion {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(BatwalkColor.rose)
                    .padding(4)
            }
        }
        .unlockReveal(isNew: isNew)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bat.displayName + (isCompanion ? ", companion" : ""))
    }
}

/// Locked tile: dark card, faint silhouette, muted "?".
struct LockedBatTile: View {
    var body: some View {
        ZStack {
            BatSilhouette(size: 34, color: .white.opacity(0.07))
            Text("?")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BatwalkColor.lockedBatBackground))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .accessibilityLabel("Not discovered yet")
    }
}

extension View {
    /// Night background for Watch pages (gradient + still stars; scenery on Home).
    func watchPageBackground(_ time: TimeOfDay = .night, scenery: Bool = false) -> some View {
        background { NightSkyBackground(time: time, scenery: scenery) }
    }
}
