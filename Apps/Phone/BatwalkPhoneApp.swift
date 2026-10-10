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
        PhoneSync.shared.onReceiveSave = { data, date in store.applyMirror(data, updatedAt: date) }
        PhoneSync.shared.onReceiveReceipt = { receipt in store.receiveCompanionReceipt(receipt) }
        PhoneSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(store)
                .environment(purchases)
                .preferredColorScheme(.light)
                .tint(BatwalkColor.accent)
                .task { if !store.isDemo { purchases.start() } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.load()
                        store.refreshHandoff()
                        if !store.isDemo { Task { await purchases.refreshEntitlements() } }
                    }
                }
        }
        .modelContainer(container)
    }
}

enum PhoneTab: Int, Hashable {
    case companion, batpedia, journal
}

struct PhoneRootView: View {
    @State private var tab = PhoneTab(rawValue: DemoMode.page) ?? .companion
    @State private var settings = DemoMode.scenario == "phone-unlock"

    var body: some View {
        TabView(selection: $tab) {
            CompanionView(tab: $tab)
                .environment(\.batPageVisible, tab == .companion)
                .tabItem { Label("Companion", systemImage: "house") }
                .tag(PhoneTab.companion)
            BatpediaView()
                .environment(\.batPageVisible, tab == .batpedia)
                .tabItem { Label("Batpedia", systemImage: "book.closed.fill") }
                .tag(PhoneTab.batpedia)
            HistoryView()
                .tabItem { Label("Journal", systemImage: "text.book.closed") }
                .tag(PhoneTab.journal)
        }
        .sheet(isPresented: $settings) { PhoneSettingsView() }
    }
}
