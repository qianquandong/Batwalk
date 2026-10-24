import SwiftUI
import BatwalkCore

/// Two glanceable pages. Collection and device maintenance are secondary routes;
/// friendship explanations and action browsing live on the phone.
struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let steps: StepService

    @State private var page = DemoMode.page == 1 ? 1 : 0
    @State private var stepSetup = StepSetupCoordinator()
    @State private var onboarding = DemoMode.makeWatchOnboarding()
    @State private var tutorialPrepared = false

    var body: some View {
        Group {
        if !tutorialPrepared {
            Color.clear.watchPageBackground()
        } else if DemoMode.scenario == "pilot-lab" {
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
        } else if DemoMode.stepSetupStatus != nil ||
                    (store.state.hasStarted && !store.isDemo && StepSetupCoordinator.needsSetup(for: store.state)) {
            StepSetupView(steps: steps, setup: stepSetup)
        } else if store.state.hasStarted {
            TabView(selection: $page) {
                HomeView(page: $page).environment(\.batPageVisible, page == 0).tag(0)
                ProgressPage(page: $page, steps: steps).environment(\.batPageVisible, page == 1).tag(1)
            }
            .tabViewStyle(.verticalPage)
        } else {
            OnboardingView(steps: steps, setup: stepSetup)
        }
        }
        .environment(onboarding)
        .dynamicTypeSize(DemoMode.scenario?.hasSuffix("large-type") == true ? .accessibility3 : typeSize)
        .onAppear {
            if !store.recoveryRequired { onboarding.prepare(for: store.state) }
            tutorialPrepared = true
        }
        .onChange(of: store.state) { _, state in
            if !store.recoveryRequired { onboarding.reconcile(with: state) }
        }
        .onChange(of: store.recoveryRequired) { _, required in
            if !required { onboarding.prepare(for: store.state) }
        }
        .onChange(of: page) { _, value in
            if value == 1 { onboarding.didViewEgg() }
        }
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
    @Environment(WatchOnboarding.self) private var onboarding
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let steps: StepService
    let setup: StepSetupCoordinator

    var body: some View {
        if onboarding.introductionSeen {
            StepSetupView(steps: steps, setup: setup)
        } else {
        VStack(spacing: BatwalkSpacing.xs) {
            ScrollView {
                VStack(spacing: BatwalkSpacing.sm) {
                    Text("Something is sleeping in here…")
                        .font(BatwalkFont.headline)
                        .multilineTextAlignment(.center)
                    EggSprite(type: .starter, state: .calm, size: typeSize.isAccessibilitySize ? 48 : 68)
                        .idleFloat()
                        .accessibilityHidden(true)
                    Text("A little friend is waiting.")
                        .font(BatwalkFont.caption)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            // A replaced or re-paired Watch: the iPhone (or iCloud) still remembers the collection.
            if let backup = store.availableBackup, !backup.collection.isEmpty {
                Button("Restore my \(backup.collection.count) bats") {
                    do { try store.restore(backup) } catch { Haptics.failure() }
                }
                .font(BatwalkFont.caption)
                .frame(minHeight: 44)
            }
            Button("Meet them") {
                withAnimation(reduceMotion ? nil : BatwalkMotion.page) { onboarding.finishIntroduction() }
            }
            .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
            .doubleTapPrimaryAction()
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, BatwalkSpacing.sm)
        .foregroundStyle(BatwalkColor.cloud)
        .watchPageBackground(.night)
        }
    }
}
