import SwiftUI
import SwiftData
import BatwalkCore

/// iPhone companion: a light, editorial collectible app (PRD §2.5). It never
/// gates the core loop and never writes the save — the Watch is the game.
/// Follows the system appearance (Light / Dark) since the 2026-10-10 review.
@main
struct BatwalkPhoneApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store: GameStore
    @State private var purchases = PurchaseManager()
    private let container: ModelContainer

    init() {
        Roster.enabledWave = SharedConfig.contentWave
        let container = Persistence.makeContainer()
        self.container = container
        let store = GameStore(container: container, role: .phone)
        store.analytics = AnalyticsSetup.makeSink()
        _store = State(initialValue: store)
        if let demo = DemoMode.makeState() {
            store.loadDemo(demo) // screenshot scenario: no sync, no StoreKit
            return
        }
        PhoneSync.shared.onReceiveSave = { data, date in store.applyMirror(data, updatedAt: date) }
        PhoneSync.shared.onReceiveReceipt = { receipt in store.receiveCompanionReceipt(receipt) }
        PhoneSync.shared.onReceiveSettingsReceipt = { receipt in store.receiveSettingsReceipt(receipt) }
        // The phone keeps its copy of the collection within the Watch's reach.
        PhoneSync.shared.onActivated = { store.publishBackupToWatch() }
        PhoneSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(store)
                .environment(purchases)
                .tint(BatwalkColor.accent)
                .task {
                    if !store.isDemo {
                        if SharedConfig.paidContentEnabled { purchases.start() }
                        await PhoneNotifications.refresh(state: store.state)
                    }
                }
                .onChange(of: store.state.revision) { _, _ in
                    if !store.isDemo { Task { await PhoneNotifications.refresh(state: store.state) } }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.load()
                        store.refreshHandoff()
                        store.publishBackupToWatch()
                        if SharedConfig.paidContentEnabled, !store.isDemo { Task { await purchases.refreshEntitlements() } }
                        if !store.isDemo { Task { await PhoneNotifications.refresh(state: store.state) } }
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
    @State private var settings = ["phone-settings", "phone-unlock"].contains(DemoMode.scenario ?? "")
    @State private var sharePreview = ["phone-certificate", "phone-certificate-shiny", "phone-certificate-birthday", "phone-birthday-settings", "phone-birthday-pending", "phone-poster"].contains(DemoMode.scenario ?? "")
    @Environment(GameStore.self) private var store

    var body: some View {
        TabView(selection: $tab) {
            // Three distinct glyphs: home, a grid of bats, a notebook.
            CompanionView(tab: $tab)
                .environment(\.batPageVisible, tab == .companion)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(PhoneTab.companion)
            BatpediaView()
                .environment(\.batPageVisible, tab == .batpedia)
                .tabItem { Label("Collection", systemImage: "square.grid.2x2") }
                .tag(PhoneTab.batpedia)
            JournalDemoDestination()
                .tabItem { Label("Memories", systemImage: "book.closed") }
                .tag(PhoneTab.journal)
        }
        .sheet(isPresented: $settings) { PhoneSettingsView() }
        .sheet(isPresented: $sharePreview) {
            NavigationStack {
                Group {
                    if ["phone-birthday-settings", "phone-birthday-pending"].contains(DemoMode.scenario ?? "") { BirthdaySettingsView() }
                    else if DemoMode.scenario == "phone-poster" { CollectionPosterView() }
                    else if let record = store.state.history.last { BirthCertificateView(record: record) }
                }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sharePreview = false } } }
            }
        }
    }
}

struct JournalDemoDestination: View {
    var body: some View {
        if DemoMode.scenario == "phone-recap" {
            NavigationStack { WeeklyRecapView() }
        } else if ["phone-challenge", "phone-challenge-gold"].contains(DemoMode.scenario ?? "") {
            NavigationStack { MonthlyChallengeView() }
        } else { HistoryView() }
    }
}
