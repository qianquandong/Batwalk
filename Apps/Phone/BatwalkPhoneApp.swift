import SwiftUI
import SwiftData
import BatwalkCore

/// iPhone companion: a light, editorial collectible app (PRD §2.5). It never
/// gates the core loop and never writes the save — the Watch is the game.
@main
struct BatwalkPhoneApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store: GameStore
    @State private var purchases = PurchaseManager()
    private let container: ModelContainer

    init() {
        let container = Persistence.makeContainer()
        self.container = container
        let store = GameStore(container: container, role: .phone)
        _store = State(initialValue: store)
        if let demo = DemoMode.makeState() {
            store.loadDemo(demo) // screenshot scenario: no sync, no StoreKit
            return
        }
        PhoneSync.shared.onReceiveSave = { data in store.applyMirror(data) }
        PhoneSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(store)
                .environment(purchases)
                .preferredColorScheme(.light)
                .tint(BatwalkColor.purple)
                .task { if !store.isDemo { purchases.start() } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.load() } // pick up CloudKit changes
                }
        }
        .modelContainer(container)
    }
}

enum PhoneTab: Int, Hashable {
    case batpedia, history, stats, unlock
}

struct PhoneRootView: View {
    @State private var tab = PhoneTab(rawValue: DemoMode.page) ?? .batpedia

    var body: some View {
        TabView(selection: $tab) {
            BatpediaView()
                .tabItem { Label("Batpedia", systemImage: "book.closed.fill") }
                .tag(PhoneTab.batpedia)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(PhoneTab.history)
            StatsView(tab: $tab)
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(PhoneTab.stats)
            UnlockView()
                .tabItem { Label("Unlock", systemImage: "sparkles") }
                .tag(PhoneTab.unlock)
        }
    }
}
