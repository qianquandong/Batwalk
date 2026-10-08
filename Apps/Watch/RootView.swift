import SwiftUI
import BatwalkCore

/// HOME · PROGRESS · FRIENDSHIP · BATS · SETTINGS as vertical pages (Digital Crown).
/// Native paging is kept; each page fades/slides its content in (BatwalkAppear).
struct RootView: View {
    @Environment(GameStore.self) private var store
    let steps: StepService

    @State private var page = DemoMode.page

    var body: some View {
        if store.state.hasStarted {
            TabView(selection: $page) {
                HomeView().tag(0)
                ProgressPage(page: $page).tag(1)
                if store.state.companion != nil {
                    FriendshipPage().tag(2)
                    CollectionPage().tag(3)
                }
                SettingsView(steps: steps).tag(4)
            }
            .tabViewStyle(.verticalPage)
        } else {
            OnboardingView(steps: steps)
        }
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
            Button(step < 2 ? "Next" : "Let it hatch") {
                if step < 2 {
                    withAnimation(.easeInOut(duration: 0.6)) { step += 1 }
                } else {
                    begin()
                }
            }
            .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 40))
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
            store.mutate { $0.start(seed: UInt64.random(in: .min ... .max), now: .now) }
            // Credit steps already earned today (PRD §2.2 step 6).
            await store.syncSteps(using: steps)
            store.analytics.log(.onboardingComplete, properties: [:])
            await HatchNotifier.requestPermission()
            isWorking = false
        }
    }
}
