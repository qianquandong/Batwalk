import SwiftUI
import SwiftData
import WatchKit
import UserNotifications
import BatwalkCore

@main
struct BatwalkWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store: GameStore
    @State private var purchases = PurchaseManager()
    private let container: ModelContainer
    private let steps = StepService()

    init() {
        let container = Persistence.makeContainer()
        self.container = container
        let store = GameStore(container: container, role: .watch)
        _store = State(initialValue: store)
        if let demo = DemoMode.makeState() {
            store.loadDemo(demo) // screenshot scenario: no HealthKit, no sync
            return
        }
        // iPhone → Watch requests (e.g. "Set as Companion"); the Watch stays the only writer.
        PhoneSync.shared.onReceiveCommand = { command in
            if let id = command[PhoneSync.setCompanionKey], store.state.collection[id] != nil {
                do { try store.mutate { try $0.setCompanion(id) } } catch { return }
                store.analytics.log(.companionChanged, properties: ["species": id, "source": "phone"])
            }
        }
        PhoneSync.shared.activate()
        // Registered at launch, not in a view's .task: a HealthKit background wake
        // may never render the UI, so the observer must exist without it.
        let steps = self.steps
        steps.startObserving {
            await Self.backgroundSync(store: store, steps: steps)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(steps: steps)
                .environment(store)
                .environment(purchases)
                .task {
                    if !store.isDemo { purchases.start() }
                }
                // View-level onChange: reliably tracks @Observable reads (Scene-level may not).
                .onChange(of: purchases.hasCheckedEntitlements) { _, checked in
                    if checked { try? store.mutate { $0.setUnlocked(purchases.isUnlocked) } }
                }
                .onChange(of: purchases.isUnlocked) { _, unlocked in
                    guard purchases.hasCheckedEntitlements else { return }
                    try? store.mutate { $0.setUnlocked(unlocked) }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await purchases.refreshEntitlements(); await Self.foregroundSync(store: store, steps: steps) }
        }
    }

    @MainActor
    private static func foregroundSync(store: GameStore, steps: StepService) async {
        guard !store.isDemo else { return }
        store.load() // pick up a CloudKit restore if one arrived (also while still on onboarding)
        guard store.state.hasStarted else { return }
        await store.syncSteps(using: steps) // plays the egg-ready haptic (PRD §2.2)
        if let save = try? JSONEncoder().encode(store.state) { PhoneSync.shared.push(save: save) }
    }

    @MainActor
    private static func backgroundSync(store: GameStore, steps: StepService) async {
        guard store.state.hasStarted else { return }
        let update = await store.syncSteps(using: steps)
        if update.eggBecameReady {
            await HatchNotifier.postHatchReady(companionName: store.state.companion?.displayName)
        }
    }
}

/// Only lightweight notifications (PRD locked decision): Hatch Ready.
/// "Bat Awake" at dusk is on the roadmap (docs/ROADMAP.md).
enum HatchNotifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static let enabledKey = "batwalk.notifications"

    static func postHatchReady(companionName: String?) async {
        guard UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ready to hatch!"
        content.body = companionName.map { "\($0) is curious what's inside your egg." } ?? "Something is wiggling in your egg."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "hatch-ready", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
