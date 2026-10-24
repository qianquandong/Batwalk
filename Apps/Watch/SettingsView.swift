import SwiftUI
import HealthKit
import UserNotifications
import BatwalkCore

/// Infrequent, device-local controls behind the egg page's More button.
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchOnboarding.self) private var onboarding
    let steps: StepService
    var onReplay: (() -> Void)? = nil
    @AppStorage(HatchNotifier.enabledKey) private var notificationsOn = true
    @AppStorage(HatchNotifier.duskEnabledKey) private var duskOn = false
    @State private var health: HealthStatus = .noData
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmRestore = false
    @State private var showGuide = false

    var body: some View {
        NavigationStack {
            List {
                Button { showGuide = true } label: {
                    Label("How to play", systemImage: "questionmark.circle")
                }
                NavigationLink { HealthAccessView(steps: steps, status: $health) } label: {
                    Label("Step access", systemImage: "heart")
                }
                if notificationStatus == .notDetermined {
                    Button("Turn on hatch alerts") {
                        Task { await updateNotificationPermission() }
                    }
                    Text("A gentle tap when an egg is ready.")
                        .font(BatwalkFont.micro)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                } else {
                    Toggle("Hatch alert", isOn: $notificationsOn)
                }
                Toggle("Dusk alert", isOn: $duskOn)
                if (notificationsOn || duskOn) && notificationStatus == .denied {
                    Text("Alerts off in Settings").font(BatwalkFont.micro)
                }
                if store.state.companion != nil {
                    NavigationLink { OutfitPickerView() } label: { Label("Outfit", systemImage: "tshirt") }
                    // Offline fallback for nickname, appearance and Moon Dust.
                    NavigationLink { CollectionPage() } label: {
                        Label("My bats", systemImage: "square.grid.2x2")
                    }
                }
                if let backup = store.availableBackup, backup.collection.count > store.state.collection.count {
                    Button("Restore backup") { confirmRestore = true }
                }
                Label("More on iPhone", systemImage: "iphone")
                    .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
            }
            .navigationTitle("Options")
        }
        .sheet(isPresented: $showGuide) {
            HowToPlayView {
                onboarding.replay(for: store.state)
                onReplay?()
            }
        }
        .task {
            health = await HealthAccessView.currentStatus(steps: steps, state: store.state)
            notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
        .alert("Restore collection?", isPresented: $confirmRestore) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") {
                if let backup = store.availableBackup { try? store.restore(backup) }
            }
        } message: {
            Text("This replaces the collection on this Watch. Bats and friendship are restored; your current egg and step accounting start fresh.")
        }
        .onChange(of: notificationsOn) { _, on in
            if on { Task { await updateNotificationPermission() } }
        }
        .onChange(of: duskOn) { _, on in
            Task {
                if on { await updateNotificationPermission() }
                await HatchNotifier.scheduleDuskReminder(enabled: on, companionName: store.state.companion?.displayName,
                                                         hour: Tuning.default.duskStartHour)
            }
        }
    }

    private func updateNotificationPermission() async {
        await HatchNotifier.requestPermission()
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

struct HealthAccessView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let steps: StepService
    @Binding var status: HealthStatus
    @State private var isWorking = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Label(status.label, systemImage: status == .connected ? "checkmark.circle" : "heart")
                    .font(BatwalkFont.caption)
                Button(isWorking ? "Updating…" : "Update steps") {
                    Task { await update(requestAccess: status == .notSetUp) }
                }
                .buttonStyle(BatwalkPrimaryButtonStyle())
                .disabled(isWorking)
                if status != .connected {
                    Button("How to enable Steps") { showHelp = true }
                        .font(BatwalkFont.caption)
                        .frame(minHeight: 44)
                }
            }.padding(.horizontal, BatwalkSpacing.xs)
        }
        .navigationTitle("Steps")
        .watchPageBackground()
        .sheet(isPresented: $showHelp) { StepPermissionHelpView() }
        .task { await update(requestAccess: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await update(requestAccess: false) } }
        }
    }

    private func update(requestAccess: Bool) async {
        guard !isWorking else { return }
        guard !store.isDemo else {
            status = DemoMode.healthStatus ?? .connected
            return
        }
        isWorking = true
        defer { isWorking = false }
        if requestAccess, !(await steps.requestAuthorization()) {
            status = .needsAttention
            return
        }
        await store.syncSteps(using: steps)
        status = await Self.currentStatus(steps: steps, state: store.state)
    }

    @MainActor
    static func currentStatus(steps: StepService, state: GameState) async -> HealthStatus {
        if let demo = DemoMode.healthStatus { return demo }
        if await steps.authorizationRequestStatus() == .shouldRequest { return .notSetUp }
        switch StepSyncCoordinator.shared.status {
        case .updated(let total, _): return total > 0 ? .connected : .noData
        case .failed: return .needsAttention
        case .idle, .updating: return .noData
        }
    }
}
