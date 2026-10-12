import SwiftUI
import HealthKit
import UserNotifications
import BatwalkCore

/// Infrequent, device-local controls behind the egg page's More button.
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    let steps: StepService
    @AppStorage(HatchNotifier.enabledKey) private var notificationsOn = true
    @AppStorage(HatchNotifier.duskEnabledKey) private var duskOn = false
    @State private var health: HealthStatus = .noData
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmRestore = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink { HealthAccessView(steps: steps, status: $health) } label: {
                    Label("Step access", systemImage: "heart")
                }
                Toggle("Hatch alert", isOn: $notificationsOn)
                Toggle("Dusk alert", isOn: $duskOn)
                if (notificationsOn || duskOn) && notificationStatus == .denied {
                    Text("Alerts off in Settings").font(BatwalkFont.micro)
                }
                if store.state.companion != nil {
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
    let steps: StepService
    @Binding var status: HealthStatus
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Label(status.label, systemImage: status == .connected ? "checkmark.circle" : "heart")
                    .font(BatwalkFont.caption)
                Button(isWorking ? "Updating…" : "Update steps") {
                    isWorking = true
                    Task { @MainActor in
                        _ = await steps.requestAuthorization()
                        await store.syncSteps(using: steps)
                        status = await Self.currentStatus(steps: steps, state: store.state)
                        isWorking = false
                    }
                }
                .buttonStyle(BatwalkPrimaryButtonStyle())
                .disabled(isWorking)
                Label("Help on iPhone", systemImage: "iphone")
                    .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
            }.padding(.horizontal, BatwalkSpacing.xs)
        }
        .navigationTitle("Steps")
        .watchPageBackground()
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
