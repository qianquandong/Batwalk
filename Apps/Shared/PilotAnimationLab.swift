import SwiftUI
import BatwalkCore

/// In-memory review only. Reachable through a demo launch argument or Debug Settings.
/// It never asks for Health access or changes collection/fruit/friendship.
struct PilotAnimationLab: View {
    @State private var speciesID = "mochi"
    @State private var mood: BatMood = .awake
    @State private var level = 1
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
                            friendshipEXP: Tuning.default.friendshipThresholds[level - 1],
                            animationRequest: request)
                Picker("Friendship", selection: $level) {
                    ForEach(1...5, id: \.self) { Text("Lv. \($0)").tag($0) }
                }
                HStack {
                    Button("Idle") { request = nil; mood = .awake }
                    Button("Sleep") { request = nil; mood = .sleeping }
                }
                HStack {
                    Button("Fly") { request = BatAnimationRequest([.fly]) }
                    Button("Pet") { request = BatAnimationRequest([.pet]) }
                    Button("Eat") { request = BatAnimationRequest([.feed]) }
                }
                ForEach(PilotAnimationCatalog.playableActions(for: speciesID), id: \.id) { action in
                    Button("Lv. \(action.unlockLevel) · \(action.name)") {
                        request = BatAnimationRequest(actionIDs: [action.id])
                    }
                    .disabled(level < action.unlockLevel)
                }
                Text("Preview only · your save stays as it is")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 8)
        }
        .navigationTitle("Meet the bats")
        .onChange(of: speciesID) { _, _ in request = nil; mood = .awake }
    }
}
