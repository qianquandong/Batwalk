import SwiftUI

/// Purchase explanations and checkout live in the iPhone companion.
struct WatchUnlockView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone").font(.largeTitle)
            Text("More on iPhone").font(BatwalkFont.headline)
            Text("Batwalk → Settings → Full collection")
                .font(BatwalkFont.caption).multilineTextAlignment(.center)
            Button("Done") { dismiss() }.buttonStyle(BatwalkPrimaryButtonStyle())
        }
        .padding(.horizontal, BatwalkSpacing.sm)
        .foregroundStyle(BatwalkColor.cloud)
        .watchPageBackground()
    }
}
