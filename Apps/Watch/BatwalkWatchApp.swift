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
        Roster.enabledWave = SharedConfig.contentWave
        let container = Persistence.makeContainer()
        self.container = container
        let store = GameStore(container: container, role: .watch)
        store.analytics = AnalyticsSetup.makeSink()
        _store = State(initialValue: store)
        if let demo = DemoMode.makeState() {
            store.loadDemo(demo) // screenshot scenario: no HealthKit, no sync
            return
        }
        // iPhone → Watch requests ("Choose for Watch"); the Watch stays the only writer.
        PhoneSync.shared.onReceiveRequest = { request in
            let receipt = store.applyCompanionRequest(request)
            PhoneSync.shared.reply(receipt, save: try? JSONEncoder().encode(store.state))
        }
        // The paired iPhone's mirror of the collection — a replacement Watch can restore from it.
        PhoneSync.shared.onReceivePhoneBackup = { backup in store.offerPhoneBackup(backup) }
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
                // Every entitlement check re-applies, so a save loaded or restored since
                // the last check still picks up the verified result.
                .onChange(of: purchases.entitlementVersion) { _, _ in applyEntitlement() }
                .onChange(of: store.state.saveID) { _, _ in applyEntitlement() }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .background { store.endCompanionVisit() }
                    guard phase == .active, !store.isDemo else { return }
                    Task {
                        // Refresh on first presentation and after returning from
                        // Settings. Step recovery must not wait for StoreKit.
                        await Self.foregroundSync(store: store, steps: steps)
                        await purchases.refreshEntitlements()
                        applyEntitlement()
                    }
                }
        }
        .modelContainer(container)
    }

    /// Only a verified entitlement unlocks and only an explicit revocation re-locks;
    /// an unknown result never changes the save (2026-10-10 review, finding 3b).
    private func applyEntitlement() {
        guard purchases.hasCheckedEntitlements, !store.isDemo, !store.recoveryRequired,
              let unlocked = EntitlementPolicy.unlockedValue(for: purchases.entitlement),
              unlocked != store.state.isUnlocked else { return }
        do { try store.mutate { $0.setUnlocked(unlocked) } } catch { return }
        store.analytics.log(unlocked ? .purchaseUnlock : .restorePurchase,
                            properties: ["state": unlocked ? "active" : "revoked", "device": "watch"])
    }

    @MainActor
    private static func foregroundSync(store: GameStore, steps: StepService) async {
        guard !store.isDemo else { return }
        store.load() // pick up a CloudKit restore if one arrived (also while still on onboarding)
        guard store.state.hasStarted else { return }
        await store.syncSteps(using: steps) // plays the egg-ready haptic (PRD §2.2)
        if let save = try? JSONEncoder().encode(store.state) { PhoneSync.shared.push(save: save) }
        // Keep the dusk note's companion name current.
        await HatchNotifier.scheduleDuskReminder(
            enabled: UserDefaults.standard.bool(forKey: HatchNotifier.duskEnabledKey),
            companionName: store.state.companion?.displayName, hour: Tuning.default.duskStartHour)
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

/// Only lightweight notifications (PRD locked decision): Ready to hatch, and the
/// optional Bat Awake note at dusk (Q8, decided 2026-10-10 — opt-in, once a day).
enum HatchNotifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static let enabledKey = "batwalk.notifications"
    static let duskEnabledKey = "batwalk.duskNotifications"
    private static let duskIdentifier = "bat-awake"

    static func postHatchReady(companionName: String?) async {
        guard UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ready to hatch!"
        content.body = companionName.map { "\($0) is curious what's inside your egg." } ?? "Something is wiggling in your egg."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "hatch-ready", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Replaces the pending dusk note (or removes it). A repeating calendar trigger
    /// fires at most once a day and costs no background work.
    static func scheduleDuskReminder(enabled: Bool, companionName: String?, hour: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [duskIdentifier])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = companionName.map { "\($0) is waking up" } ?? "Your bat is waking up"
        content.body = "Dusk on the wrist. Say hello and see what it gets up to tonight."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: duskIdentifier, content: content, trigger: trigger))
    }
}
