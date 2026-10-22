import SwiftUI
import BatwalkCore

/// A required, recoverable setup screen, outside the quiet companion scene.
struct StepSetupView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let steps: StepService
    let setup: StepSetupCoordinator
    @State private var showHelp = false

    private var status: StepSetupCoordinator.Status { DemoMode.stepSetupStatus ?? setup.status }
    private var needsHelp: Bool { status == .noSteps || status == .requestFailed || status == .readFailed }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                EggSprite(type: store.state.egg?.type ?? .starter, state: .calm, size: needsHelp ? 54 : 70)
                    .accessibilityHidden(true)
                Text(title)
                    .font(BatwalkFont.headline)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(BatwalkFont.caption)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(status == .checking ? "Checking…" : needsHelp ? "Check again" : "Enable Steps") {
                    Task { await connect(requestAccess: true) }
                }
                .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
                .disabled(setup.isWorking)
                if needsHelp {
                    Button("How to enable") { showHelp = true }
                        .font(BatwalkFont.caption)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, BatwalkSpacing.sm)
            .padding(.vertical, 6)
        }
        .watchPageBackground()
        .sheet(isPresented: $showHelp) { StepPermissionHelpView() }
        .onChange(of: scenePhase) { _, phase in
            // Returning from Settings rechecks data without reopening a prompt.
            if phase == .active, needsHelp, !setup.isWorking {
                Task { await connect(requestAccess: false) }
            }
        }
    }

    private var title: String {
        switch status {
        case .idle, .ready: return "Steps hatch your bat"
        case .checking: return "Connecting steps"
        case .noSteps: return "Waiting for steps"
        case .requestFailed: return "Finish step setup"
        case .readFailed: return "Let's try again"
        }
    }

    private var message: String {
        switch status {
        case .idle, .ready: return "Turn on Steps in the next screen to begin."
        case .checking: return "Reading today's steps…"
        case .noSteps: return "No steps received yet. Turn on Steps, walk a few steps, then check again."
        case .requestFailed: return "Step setup didn't finish. Try again, or check Watch Settings."
        case .readFailed: return "Couldn't read steps. Unlock your Watch and try again."
        }
    }

    private func connect(requestAccess: Bool) async {
        if requestAccess {
            await setup.connect(store: store, reader: steps, requestAuthorization: {
                await steps.requestAuthorization()
            })
        } else {
            await setup.connect(store: store, reader: steps)
        }
    }
}

struct StepPermissionHelpView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("On your Watch")
                        .font(BatwalkFont.headline)
                    Text("Settings → Health → Apps → Batwalk")
                    Text("Turn on Steps, then return here. If you've already allowed Steps, walk a few steps and check again.")
                    Text("Batwalk only reads steps. It never writes to Health.")
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                }
                .font(BatwalkFont.caption)
                .padding(.horizontal, BatwalkSpacing.sm)
            }
            .navigationTitle("Enable Steps")
            .watchPageBackground()
        }
    }
}
