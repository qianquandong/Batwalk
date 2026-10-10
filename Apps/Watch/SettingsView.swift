import SwiftUI
import HealthKit
import UserNotifications
import BatwalkCore

/// Settings (board: Watch › 6. Settings): companion, notifications, Health access,
/// restore purchase, version. Health troubleshooting lives here, not in gameplay.
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    let steps: StepService

    @AppStorage(HatchNotifier.enabledKey) private var notificationsOn = true
    @State private var health: HealthStatus = .noData
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmRestore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    #if DEBUG
                    NavigationLink("Animation samples") { PilotAnimationLab() }
                        .font(BatwalkFont.caption)
                    #endif
                    if let companion = store.state.companion {
                        NavigationLink(value: SettingsRoute.bat(companion.speciesID)) {
                            HStack(spacing: BatwalkSpacing.sm) {
                                BatSprite(speciesID: companion.speciesID, shiny: companion.showsShiny, mood: .awake, size: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(companion.displayName).font(BatwalkFont.caption).lineLimit(1)
                                    Text("Lv. \(Friendship.level(forEXP: companion.friendshipEXP))")
                                        .font(BatwalkFont.micro)
                                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                                }
                                Spacer(minLength: 0)
                                chevron
                            }
                            .foregroundStyle(.white)
                            .batwalkGlassCard(padding: 8, radius: 14)
                        }
                        .buttonStyle(PressableStyle())
                    }

                    Toggle(isOn: $notificationsOn) {
                        Label("Notifications", systemImage: "bell.fill")
                            .font(BatwalkFont.caption)
                    }
                    .tint(BatwalkColor.accent)
                    .batwalkGlassCard(padding: 8, radius: 14)

                    if notificationsOn && notificationStatus == .denied {
                        Text("Notifications are blocked in device settings.")
                            .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.warning)
                    }

                    NavigationLink(value: SettingsRoute.health) {
                        HStack(spacing: BatwalkSpacing.sm) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(BatwalkColor.rose)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Health Access").font(BatwalkFont.caption)
                                Text(healthLabel)
                                    .font(BatwalkFont.micro)
                                    .foregroundStyle(healthColor)
                            }
                            Spacer(minLength: 0)
                            chevron
                        }
                        .foregroundStyle(.white)
                        .batwalkGlassCard(padding: 8, radius: 14)
                    }
                    .buttonStyle(PressableStyle())

                    Button {
                        Task { await purchases.restore() }
                    } label: {
                        HStack(spacing: BatwalkSpacing.sm) {
                            Image(systemName: purchases.isUnlocked ? "checkmark.seal.fill" : "arrow.clockwise")
                                .font(.system(size: 13))
                                .foregroundStyle(purchases.isUnlocked ? BatwalkColor.success : BatwalkColor.sage)
                            Text(purchases.isUnlocked ? "Full unlock active" : "Restore Purchase")
                                .font(BatwalkFont.caption)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .batwalkGlassCard(padding: 8, radius: 14)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(purchases.isBusy)
                    if let message = purchases.message {
                        Text(message).font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                    }
                    if let error = purchases.lastError {
                        Text(error).font(BatwalkFont.micro).foregroundStyle(BatwalkColor.warning)
                    }
                    NavigationLink("Privacy & data") { PrivacyView() }.font(BatwalkFont.caption)
                    if let backup = store.availableBackup, backup.collection.count > store.state.collection.count {
                        Button("Restore \(backup.collection.count) backed-up bats") { confirmRestore = true }
                            .font(BatwalkFont.caption)
                    }

                    Text(versionText)
                        .font(BatwalkFont.micro)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .padding(.top, BatwalkSpacing.xs)
                }
                .padding(.horizontal, BatwalkSpacing.xs)
                .batwalkAppear()
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .bat(let id): BatDetailView(speciesID: id)
                case .health: HealthAccessView(steps: steps, status: $health)
                }
            }
            .watchPageBackground()
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
            if on {
                Task {
                    await HatchNotifier.requestPermission()
                    notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                }
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(BatwalkColor.textSecondaryDark)
    }

    private var healthLabel: String {
        health.label
    }

    private var healthColor: Color {
        switch health {
        case .connected: return BatwalkColor.success
        case .notSetUp, .needsAttention: return BatwalkColor.warning
        case .noData: return BatwalkColor.textSecondaryDark
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Batwalk \(version) (\(build))"
    }
}

enum SettingsRoute: Hashable {
    case bat(String)
    case health
}

/// Health Access detail: status, what Batwalk reads, and how to fix access.
struct HealthAccessView: View {
    @Environment(GameStore.self) private var store
    let steps: StepService
    @Binding var status: HealthStatus

    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BatwalkSpacing.sm) {
                Label(status.label,
                      systemImage: status == .connected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(BatwalkFont.headline)
                    .foregroundStyle(status == .connected ? BatwalkColor.success : BatwalkColor.warning)

                Text("Your steps hatch your bat. Batwalk only reads Step Count, and it never leaves your devices.")
                    .font(BatwalkFont.micro)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)

                if status != .connected {
                    Text("An empty result can mean no recorded steps or limited Health access. If you've been walking, check Batwalk's Step Count access in the Health app on your iPhone.")
                        .font(BatwalkFont.micro)
                        .foregroundStyle(.white)
                        .batwalkGlassCard(padding: 8, radius: 14)

                    Button("Check Step Count") {
                        isWorking = true
                        Task { @MainActor in
                            _ = await steps.requestAuthorization()
                            await store.syncSteps(using: steps)
                            status = await Self.currentStatus(steps: steps, state: store.state)
                            isWorking = false
                        }
                    }
                    .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 36))
                    .disabled(isWorking)
                }
            }
            .padding(.horizontal, BatwalkSpacing.xs)
        }
        .navigationTitle("Health")
        .watchPageBackground()
    }

    /// HealthKit hides read denials, so: never asked → Not set up; steps counted
    /// today → Connected; otherwise → Needs attention (with the fix steps).
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
