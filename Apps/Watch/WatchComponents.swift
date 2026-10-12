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

/// Quiet icon controls with equal footprints and a full 44 pt touch target.
struct WatchPetControlStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(BatwalkColor.cloud)
            .frame(width: 56, height: 44)
            .background {
                Capsule()
                    .fill(BatwalkColor.cloud.opacity(configuration.isPressed ? 0.16 : 0.06))
                    .frame(width: 52, height: 34)
            }
            .contentShape(Capsule())
            .opacity(enabled ? 1 : 0.4)
    }
}

/// One quiet, centered Feed control. Inventory remains available to VoiceOver.
struct FeedButton: View {
    let fruit: Int
    let action: () -> Void

    var body: some View {
        Button("Feed", action: action)
        .buttonStyle(FeedControlStyle())
        .disabled(fruit == 0)
        .accessibilityLabel("Feed")
        .accessibilityValue("\(fruit) fruit")
        .accessibilityHint(fruit == 0 ? "Walk to find fruit" : "Use one fruit")
    }

    private struct FeedControlStyle: ButtonStyle {
        @Environment(\.isEnabled) private var enabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(BatwalkFont.caption)
                .foregroundStyle(BatwalkColor.cloud)
                .padding(.horizontal, 16)
                .frame(minWidth: 88, minHeight: 44)
                .background {
                    Capsule()
                        .fill(BatwalkColor.cloud.opacity(configuration.isPressed ? 0.16 : 0.08))
                        .padding(.vertical, 5)
                }
                .contentShape(Capsule())
                .opacity(enabled ? 1 : 0.4)
        }
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
