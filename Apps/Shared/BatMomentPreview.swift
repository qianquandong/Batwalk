import SwiftUI
import BatwalkCore

struct BatMomentSelection: Identifiable {
    let action: BatAction
    var id: String { "\(action.speciesID)/\(action.id)" }
}

/// A visible stage for an unlocked habit: a button lower in a scrolling page
/// must not play an animation on a hero that has already scrolled off screen.
struct BatMomentPreview: View {
    let bat: OwnedBat
    let action: BatAction
    @Environment(\.dismiss) private var dismiss
    @State private var request: BatAnimationRequest

    init(bat: OwnedBat, action: BatAction) {
        self.bat = bat
        self.action = action
        _request = State(initialValue: BatAnimationRequest(actionIDs: [action.id]))
    }

    private var heroSize: CGFloat {
        #if os(watchOS)
        96
        #else
        180
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    BatHeroView(speciesID: bat.speciesID, shiny: bat.showsShiny,
                                mood: action.trigger == .asleep ? .sleeping : .awake,
                                size: heroSize, friendshipEXP: bat.friendshipEXP,
                                animationRequest: request, showsKeepsake: false)
                    Text(action.name).font(BatwalkFont.headline).multilineTextAlignment(.center)
                    Text(action.summary).font(BatwalkFont.caption).multilineTextAlignment(.center)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                    Button("Again") { request = BatAnimationRequest(actionIDs: [action.id]) }
                        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 40))
                }
                .padding()
            }
            .foregroundStyle(BatwalkColor.cloud)
            .background(NightSkyBackground(time: .night, scenery: false))
            .navigationTitle("Little moments")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
