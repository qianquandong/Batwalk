#if os(iOS)
import SwiftUI
import BatwalkCore

/// A square card for sharing a bat (iPhone): portrait on the night glade, name,
/// rarity and the "real-life cousin" fact — the natural thing to send a friend.
/// Rendered off screen with `ImageRenderer`; nothing about steps appears on it.
struct BatShareCard: View {
    let bat: OwnedBat
    let species: Species

    var body: some View {
        ZStack {
            NightSkyBackground(time: .night, scenery: true, groundLevel: 0.82)
            VStack(spacing: 14) {
                Text("BATWALK")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                BatSprite(speciesID: species.id, shiny: bat.showsShiny, mood: .happy, size: 210)
                Text(bat.displayName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    RarityChip(rarity: species.rarity)
                    if bat.showsShiny { VariantChip(shiny: true) }
                    if bat.nickname != nil {
                        ChipView(text: species.name, color: BatwalkColor.sage)
                    }
                }
                Text(species.realLifeCousin ?? species.hook)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(BatwalkColor.cloud)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 30)
                Text(bat.hatchCount == 1 ? "Hatched on a walk" : "Met on \(bat.hatchCount) walks")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
            }
            .padding(.vertical, 28)
        }
        .frame(width: 400, height: 400)
    }
}

@MainActor
enum BatShareImage {
    /// A 1200 × 1200 image, or nil when rendering fails (the Share button then hides).
    static func render(bat: OwnedBat, species: Species) -> Image? {
        let renderer = ImageRenderer(content: BatShareCard(bat: bat, species: species))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }
        return Image(uiImage: image)
    }
}
#endif
