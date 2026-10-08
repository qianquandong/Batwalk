import SwiftUI
import HealthKit
import BatwalkCore

/// Settings (board: Watch › 6. Settings): companion, notifications, Health access,
/// restore purchase, version. Health troubleshooting lives here, not in gameplay.
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    let steps: StepService

    @AppStorage(HatchNotifier.enabledKey) private var notificationsOn = true
    @State private var health: HealthStatus = .connected

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
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
                    .tint(BatwalkColor.purple)
                    .batwalkGlassCard(padding: 8, radius: 14)

                    NavigationLink(value: SettingsRoute.health) {
                        HStack(spacing: BatwalkSpacing.sm) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(BatwalkColor.pinkAccent)
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
                                .foregroundStyle(purchases.isUnlocked ? BatwalkColor.success : BatwalkColor.softLavender)
                            Text(purchases.isUnlocked ? "Full unlock active" : "Restore Purchase")
                                .font(BatwalkFont.caption)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .batwalkGlassCard(padding: 8, radius: 14)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(purchases.isBusy)

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
        .task { health = await HealthAccessView.currentStatus(steps: steps, state: store.state) }
        .onChange(of: notificationsOn) { _, on in
            if on { Task { await HatchNotifier.requestPermission() } }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(BatwalkColor.textSecondaryDark)
    }

    private var healthLabel: String {
        switch health {
        case .connected: return "Connected"
        case .notSetUp: return "Not set up"
        case .needsAttention: return "Needs attention"
        }
    }

    private var healthColor: Color {
        switch health {
        case .connected: return BatwalkColor.success
        case .notSetUp, .needsAttention: return BatwalkColor.warning
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
                Label(status == .connected ? "Connected" : status == .notSetUp ? "Not set up" : "Needs attention",
                      systemImage: status == .connected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(BatwalkFont.headline)
                    .foregroundStyle(status == .connected ? BatwalkColor.success : BatwalkColor.warning)

                Text("Your steps hatch your bat. Batwalk only reads Step Count, and it never leaves your devices.")
                    .font(BatwalkFont.micro)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)

                if status != .connected {
                    Text("No steps have arrived today. If you've been walking, open Health on your iPhone › Sharing › Apps › Batwalk and turn on Steps.")
                        .font(BatwalkFont.micro)
                        .foregroundStyle(.white)
                        .batwalkGlassCard(padding: 8, radius: 14)

                    Button("Allow Step Count") {
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
        // Today's total, not lifetime: if Steps access is later turned off in Health,
        // the status must stop saying "Connected".
        let today = state.ledger.dayKey == DayKey.make(.now) ? state.ledger.lastDailyTotal : 0
        return today > 0 ? .connected : .needsAttention
    }
}
