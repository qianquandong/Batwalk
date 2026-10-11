import SwiftUI
import BatwalkCore

/// In-memory review only. Reachable through a demo launch argument or Debug Settings.
/// It never asks for Health access or changes collection/fruit/friendship.
struct PilotAnimationLab: View {
    @State private var speciesID = "mochi"
    @State private var mood: BatMood = .awake
    @State private var bestFriends = false
    @State private var request: BatAnimationRequest?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Picker("Companion", selection: $speciesID) {
                    ForEach(PilotAnimationCatalog.speciesIDs, id: \.self) { id in
                        Text(Roster.species(id)?.name ?? id).tag(id)
                    }
                }
                BatHeroView(speciesID: speciesID, mood: mood, size: 100,
                            friendshipEXP: bestFriends ? Tuning.default.friendshipThresholds[3] : 0,
                            animationRequest: request)
                Toggle("Friendship Lv. 4", isOn: $bestFriends)
                    .font(.caption)
                HStack {
                    Button("Idle") { request = nil; mood = .awake }
                    Button("Sleep") { request = nil; mood = .sleeping }
                }
                HStack {
                    Button("Fly") { request = BatAnimationRequest([.fly]) }
                    Button("Pet") { request = BatAnimationRequest([.pet]) }
                    Button("Eat") { request = BatAnimationRequest([.feed]) }
                }
                if let action = PilotAnimationCatalog.signatureAction(for: speciesID) {
                    Button(action.name) { request = BatAnimationRequest([.signature]) }
                        .disabled(!bestFriends)
                }
                Text("Preview only · your save stays as it is")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 8)
        }
        .navigationTitle("Meet the bats")
        .onChange(of: speciesID) { _, _ in request = nil; mood = .awake }
    }
}
