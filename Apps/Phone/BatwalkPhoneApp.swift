import SwiftUI
import SwiftData
import BatwalkCore

/// iPhone companion: library and data viewer (PRD §2.5). It never gates the
/// core loop and never writes the save — the Watch is the game.
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
        PhoneSync.shared.onReceiveSave = { data in store.applyMirror(data) }
        PhoneSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(store)
                .environment(purchases)
                .task { purchases.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.load() } // pick up CloudKit changes
                }
        }
        .modelContainer(container)
    }
}

struct PhoneRootView: View {
    var body: some View {
        TabView {
            BatpediaView()
                .tabItem { Label("Batpedia", systemImage: "book.closed.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }
            UnlockView()
                .tabItem { Label("Unlock", systemImage: "sparkles") }
        }
    }
}
