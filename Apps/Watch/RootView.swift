import SwiftUI
import BatwalkCore

/// Two glanceable pages. Collection and device maintenance are secondary routes;
/// friendship explanations and action browsing live on the phone.
struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let steps: StepService

    @State private var page = DemoMode.page == 1 ? 1 : 0

    var body: some View {
        Group {
        if DemoMode.scenario == "pilot-lab" {
            NavigationStack { PilotAnimationLab() }
        } else if store.recoveryRequired {
            ScrollView {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.title)
                    Text("Save needs attention").font(.headline)
                    Text(store.lastError ?? "Please try opening your save again.").font(.caption)
                    Button("Try again") { store.load() }
                    if let backup = store.availableBackup {
                        Button("Restore \(backup.collection.count) bats") { try? store.restore(backup) }
                    }
                }.padding()
            }
        } else if store.state.hasStarted {
            TabView(selection: $page) {
                HomeView(page: $page).environment(\.batPageVisible, page == 0).tag(0)
                ProgressPage(page: $page, steps: steps).environment(\.batPageVisible, page == 1).tag(1)
            }
            .tabViewStyle(.verticalPage)
        } else {
            OnboardingView(steps: steps)
        }
        }
        .dynamicTypeSize(DemoMode.scenario == "home-large-type" ? .accessibility3 : typeSize)
        .onOpenURL { url in
            guard let route = WatchRoute(url: url) else { return }
            page = route == .progress ? 1 : 0
        }
        .tint(BatwalkColor.cloud)
        .alert("Progress update", isPresented: Binding(
            get: { store.lastError != nil && !store.recoveryRequired },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("OK") { store.clearError() }
        } message: { Text(store.lastError ?? "") }
    }
}

/// First-time flow (PRD §2.2) on the night sky.
struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    let steps: StepService

    @State private var step = 0
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: BatwalkSpacing.sm) {
            Spacer(minLength: 0)
            if step == 0 {
                Text("Something is sleeping in here…")
                    .font(BatwalkFont.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .transition(.opacity)
            } else {
                EggSprite(type: .starter, state: step == 1 ? .calm : .shaking, size: 84)
                    .idleFloat()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                Text("Your steps help it hatch.")
                    .font(BatwalkFont.caption)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            // A replaced or re-paired Watch: the iPhone (or iCloud) still remembers the collection.
            if let backup = store.availableBackup, !backup.collection.isEmpty {
                Button("Restore my \(backup.collection.count) bats") {
                    do { try store.restore(backup) } catch { Haptics.failure() }
                }
                .font(BatwalkFont.micro)
                .disabled(isWorking)
            }
            Button(step < 2 ? "Next" : "Let it hatch") {
                if step < 2 {
                    withAnimation(.easeInOut(duration: 0.6)) { step += 1 }
                } else {
                    begin()
                }
            }
            .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 40))
            .doubleTapPrimaryAction()
            .disabled(isWorking)
        }
        .padding(.horizontal, BatwalkSpacing.sm)
        .watchPageBackground(.night, scenery: step > 0)
    }

    private func begin() {
        isWorking = true
        Task { @MainActor in
            let granted = await steps.requestAuthorization()
            store.analytics.log(.stepPermissionResult, properties: ["completed": granted ? "true" : "false"])
            do { try store.mutate { $0.start(seed: UInt64.random(in: .min ... .max), now: .now) } }
            catch { isWorking = false; return }
            // Credit steps already earned today (PRD §2.2 step 6).
            await store.syncSteps(using: steps)
            store.analytics.log(.onboardingComplete, properties: [:])
            isWorking = false
        }
    }
}
