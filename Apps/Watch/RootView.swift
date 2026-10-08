import SwiftUI
import BatwalkCore

/// HOME · WALK · CARE · BATS (PRD §2.4), as vertical pages scrolled with the Digital Crown.
struct RootView: View {
    @Environment(GameStore.self) private var store
    let steps: StepService

    @State private var page = DemoMode.page

    var body: some View {
        if store.state.hasStarted {
            TabView(selection: $page) {
                HomeView().tag(0)
                WalkView().tag(1)
                if store.state.companion != nil {
                    CareView().tag(2)
                    BatsView().tag(3)
                }
            }
            .tabViewStyle(.verticalPage)
        } else {
            OnboardingView(steps: steps)
        }
    }
}

/// First-time flow (PRD §2.2).
struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    let steps: StepService

    @State private var page = 0
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            switch page {
            case 0:
                Text("Something is sleeping in here…")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            default:
                EggSprite(type: .starter, state: page == 1 ? .calm : .shaking, size: 80)
                    .transition(.scale.combined(with: .opacity))
                Text("Your steps help it hatch.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            Button(page < 2 ? "Next" : "Let it hatch") {
                if page < 2 {
                    withAnimation(.easeInOut(duration: 0.6)) { page += 1 }
                } else {
                    begin()
                }
            }
            .disabled(isWorking)
        }
        .padding(.horizontal, 4)
        .background(Color.black.ignoresSafeArea())
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
