import SwiftUI
import BatwalkCore

struct HistoryView: View {
    @Environment(GameStore.self) private var store
    @State private var showFriends = DemoMode.scenario == "phone-friends"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PhoneHeader(title: "Little memories")
                    Text("Every hello has a place here.")
                        .font(BatwalkFont.body).foregroundStyle(BatwalkColor.textSecondaryLight)
                    PhoneSyncStatus()
                    JournalCommunitySection()
                    NavigationLink { WalkingTogetherView() } label: {
                        Label("Walking together", systemImage: "person.2")
                            .font(BatwalkFont.headline).frame(minHeight: 44)
                    }
                    HStack {
                        Text("\(store.state.collection.count) friends")
                        Spacer()
                        Text("\(store.state.history.count) little meetings")
                    }
                    .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                    .padding(.vertical, 12)
                    if store.state.history.isEmpty {
                        PhoneEmptyState()
                    } else {
                        Text("RECENT MEETINGS").font(BatwalkFont.micro).tracking(2)
                            .foregroundStyle(BatwalkColor.textSecondaryLight)
                        LazyVStack(spacing: 12) {
                            ForEach(Array(store.state.history.reversed().enumerated()), id: \.offset) { _, record in
                                NavigationLink { BirthCertificateView(record: record) } label: {
                                    HatchHistoryRow(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showFriends) { WalkingTogetherView() }
        }
    }
}
