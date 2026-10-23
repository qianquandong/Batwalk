import SwiftUI
import BatwalkCore

struct WalkingTogetherView: View {
    @Environment(GameStore.self) private var store
    @Environment(WalkingTogetherCoordinator.self) private var friends

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Little arrivals, together.")
                    .font(.system(.largeTitle, design: .serif))
                Text("A few familiar faces on the same adventure.")
                    .font(BatwalkFont.body).foregroundStyle(BatwalkColor.textSecondaryLight)
                if friends.isSharing {
                    HStack {
                        Text(friends.monthlyEnabled ? "THIS MONTH · UTC" : "ALL YOUR HATCHES")
                            .font(BatwalkFont.micro).tracking(1)
                        Spacer()
                        if friends.status == .loading { ProgressView() }
                        else {
                            Button { Task { await refresh() } } label: {
                                Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                            }.accessibilityLabel("Refresh friends")
                        }
                    }
                    if !friends.rows.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(friends.rows) { row in
                                WalkingFriendView(row: row, showMonth: friends.monthlyEnabled, showTotal: friends.totalEnabled)
                            }
                        }
                    }
                    statusMessage
                } else {
                    Image(systemName: "person.2").font(.system(size: 38)).foregroundStyle(BatwalkColor.accent)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    Text("You choose what to share.").font(BatwalkFont.headline)
                    Text("Share hatch counts to see friends here. Steps always stay out of Game Center.")
                        .font(BatwalkFont.body)
                }
                NavigationLink { WalkingTogetherSettingsView() } label: {
                    Label("Sharing settings", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(BatwalkPrimaryButtonStyle())
                Text("Batwalk shows friends only. Apple may also show shared scores in public Game Center leaderboards. Turning sharing off stops future submissions; it does not remove scores already shared.")
                    .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
            }
            .padding(24).foregroundStyle(BatwalkColor.textPrimaryLight)
        }
        .background(BatwalkColor.lightBackground.ignoresSafeArea())
        .navigationTitle("Walking together")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    @ViewBuilder private var statusMessage: some View {
        switch friends.status {
        case .signIn:
            Button("Sign in to Game Center") { Task { await refresh(interactive: true) } }
                .buttonStyle(BatwalkPrimaryButtonStyle())
        case .friendsPermission:
            Text("Allow Game Center friends access to see friends who have also allowed Batwalk. You can change access in Game Center settings.")
                .font(BatwalkFont.caption)
            Button("Connect friends") { Task { await refresh(interactive: true) } }
                .buttonStyle(BatwalkPrimaryButtonStyle())
        case .failed:
            Text("Friends are taking a moment. Refresh when you're ready.").font(BatwalkFont.caption)
        case .unavailable:
            Text("Game Center is not enabled in this build.").font(BatwalkFont.caption)
        case .ready where friends.rows.isEmpty:
            Text("Friends will appear when they share their hatches.").font(BatwalkFont.caption)
        default: EmptyView()
        }
    }

    private func refresh(interactive: Bool = false) async {
        await friends.refresh(history: store.state.history, total: store.state.lifetimeHatchCount, interactive: interactive)
    }
}

private struct WalkingFriendView: View {
    @Environment(WalkingTogetherCoordinator.self) private var friends
    let row: WalkingFriend
    let showMonth: Bool
    let showTotal: Bool
    @State private var photo: UIImage?

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let photo { Image(uiImage: photo).resizable().scaledToFill() }
                else {
                    Image(systemName: row.isMe ? "heart.fill" : "leaf.fill")
                        .font(.title3).foregroundStyle(BatwalkColor.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(BatwalkColor.lightTint)
                }
            }
            .frame(width: 48, height: 48).clipShape(Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.isMe && row.name != "You" ? "\(row.name) · You" : row.name).font(BatwalkFont.headline)
                if showTotal {
                    Text(row.total.map { "\($0) hatched in all" } ?? "No shared total yet")
                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                }
                if showMonth, row.month == nil {
                    Text("No update this month").font(BatwalkFont.caption)
                        .foregroundStyle(BatwalkColor.textSecondaryLight)
                }
            }
            Spacer(minLength: 4)
            if showMonth {
                Text(row.month.map { String($0) } ?? "—").font(BatwalkFont.title).monospacedDigit()
                    .accessibilityLabel(row.month.map { "\($0) hatches this month" } ?? "Not updated this month")
            }
        }
        .padding(14).frame(minHeight: 76)
        .background(row.isMe ? BatwalkColor.lightTint : BatwalkColor.lightCard, in: RoundedRectangle(cornerRadius: 20))
        .task(id: row.id) { photo = await friends.photo(playerID: row.id) }
    }
}

struct WalkingTogetherSettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(WalkingTogetherCoordinator.self) private var friends

    var body: some View {
        List {
            Section {
                Toggle("Share this month's hatch count", isOn: binding(.month))
                Toggle("Share all-time hatch count", isOn: binding(.total))
            } header: { Text("Walking together") } footer: {
                Text("Off until you choose. Enabling a switch sends that hatch count to Apple's Game Center, linked to your Game Center profile. Scores may be publicly visible in Game Center. No steps, egg distances, birthday, or Health information are submitted.")
            }
            .disabled(!friends.available)
            Section {
                Text("This month's shared count follows the UTC calendar month so every friend uses the same dates. Your personal monthly challenge follows your local calendar.")
                Text("Turning a switch off stops future submissions. Scores already sent remain in Game Center under Apple's controls. Changing Game Center account turns both switches off.")
                Link("Apple Game Center privacy", destination: URL(string: "https://www.apple.com/legal/privacy/data/en/game-center/")!)
            }
            if !friends.available {
                Section { Text("Game Center is not enabled in this build. Your game works offline as usual.") }
            }
            if friends.status == .signIn {
                Section { Text("Sign in to Game Center to enable sharing. Your hatches stay on your devices until you choose a switch again.") }
            }
        }
        .scrollContentBackground(.hidden).background(BatwalkColor.lightBackground)
        .navigationTitle("Sharing").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func binding(_ board: HatchLeaderboard) -> Binding<Bool> {
        Binding(get: { board == .month ? friends.monthlyEnabled : friends.totalEnabled }, set: { enabled in
            Task { await friends.setSharing(board, enabled: enabled,
                history: store.state.history, total: store.state.lifetimeHatchCount) }
        })
    }
}
