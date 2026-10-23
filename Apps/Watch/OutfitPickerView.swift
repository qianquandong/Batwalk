import SwiftUI
import BatwalkCore

struct OutfitPickerView: View {
    @Environment(GameStore.self) private var store
    var body: some View {
        List {
            if let bat = store.state.companion {
                choice("Latest", .latest, bat: bat)
                choice("No outfit", .none, bat: bat)
                ForEach(store.state.earnedOutfits(for: bat.speciesID)) { outfit in
                    choice("\(outfit.cosmetic.name) · \(outfit.monthKey)", .month(outfit.monthKey), bat: bat)
                }
            }
        }
        .navigationTitle("Outfit")
    }
    private func choice(_ title: String, _ value: OutfitPreference, bat: OwnedBat) -> some View {
        Button {
            do { try store.mutate { try $0.setOutfit(value, for: bat.speciesID) } }
            catch { Haptics.failure() }
        } label: {
            HStack {
                Text(title)
                Spacer()
                if (store.state.outfitPreferences?[bat.speciesID] ?? .latest) == value { Image(systemName: "checkmark") }
            }
        }.font(BatwalkFont.caption)
    }
}
