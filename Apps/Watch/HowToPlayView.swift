import SwiftUI

/// Short, replayable help. Reading it never changes the player's egg or save.
struct HowToPlayView: View {
    let onReplay: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BatwalkSpacing.lg) {
                    help("Walk a little", symbol: "figure.walk",
                         message: "Your steps help an egg hatch. Come back anytime; your progress stays.")
                    help("Find your egg", symbol: "arrow.up.arrow.down",
                         message: "Swipe up or turn the Crown from your bat to see your egg and the steps left.")
                    help("Say hello", symbol: "hand.tap",
                         message: "Tap your bat to greet them. Feed shares fruit you earn as you walk.")
                    help("Start another journey", symbol: "sparkles",
                         message: "After hatching, choose another egg when you're ready. There's no rush.")
                    help("Need step help?", symbol: "heart",
                         message: "Open More on the egg page, then Step access. You can also manage alerts there.")
                    Button("Show tips again") {
                        onReplay()
                        dismiss()
                    }
                    .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
                    .accessibilityHint("Show the tips for your current companion or egg. Keeps your progress.")
                }
                .padding(.horizontal, BatwalkSpacing.sm)
                .padding(.vertical, BatwalkSpacing.sm)
            }
            .navigationTitle("How to play")
            .watchPageBackground()
        }
    }

    private func help(_ title: LocalizedStringKey, symbol: String, message: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: BatwalkSpacing.xs) {
            Label(title, systemImage: symbol)
                .font(BatwalkFont.headline)
                .foregroundStyle(BatwalkColor.cloud)
            Text(message)
                .font(BatwalkFont.caption)
                .foregroundStyle(BatwalkColor.textSecondaryDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
