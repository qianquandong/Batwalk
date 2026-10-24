import SwiftUI
import BatwalkCore

/// A required, recoverable setup screen, outside the quiet companion scene.
struct StepSetupView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    let steps: StepService
    let setup: StepSetupCoordinator
    @State private var showHelp = false

    private var status: StepSetupCoordinator.Status { DemoMode.stepSetupStatus ?? setup.status }
    private var needsHelp: Bool { status == .noSteps || status == .requestFailed || status == .readFailed }

    var body: some View {
        VStack(spacing: 4) {
            ScrollView {
                VStack(spacing: BatwalkSpacing.sm) {
                    if !needsHelp, !typeSize.isAccessibilitySize {
                        EggSprite(type: store.state.egg?.type ?? .starter, state: .calm, size: 44, animated: false)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(BatwalkFont.headline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(BatwalkFont.caption)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if !store.state.hasStarted, let backup = store.availableBackup,
                       !backup.collection.isEmpty {
                        Button("Restore my bats") {
                            do { try store.restore(backup) } catch { Haptics.failure() }
                        }
                        .font(BatwalkFont.caption)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Restore my \(backup.collection.count) bats")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BatwalkSpacing.xs)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Keep recovery controls visible on small Watches and at large
            // text sizes; only the explanation above needs to scroll.
            VStack(spacing: 0) {
                Button(actionTitle) {
                    // Only an unfinished permission flow asks again. Zero or
                    // failed readings retry the query without another prompt.
                    let requestAccess = status == .idle || status == .requestFailed
                    Task { await connect(requestAccess: requestAccess) }
                }
                .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
                .disabled(status == .checking)
                .accessibilityLabel(fullActionTitle)
                if needsHelp {
                    Button { showHelp = true } label: {
                        Text("Help")
                        .font(BatwalkFont.caption)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("How to enable Steps")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, BatwalkSpacing.sm)
        .padding(.bottom, BatwalkSpacing.xs)
        .watchPageBackground()
        .sheet(isPresented: $showHelp) { StepPermissionHelpView() }
        .onChange(of: scenePhase) { _, phase in
            // Returning from Settings rechecks data without reopening a prompt.
            if phase == .active, needsHelp, !setup.isWorking {
                Task { await connect(requestAccess: false) }
            }
        }
    }

    private var actionTitle: String {
        if typeSize.isAccessibilitySize {
            switch status {
            case .idle, .ready: return "Enable"
            case .checking: return "Checking…"
            case .noSteps, .requestFailed, .readFailed: return "Retry"
            }
        }
        return fullActionTitle
    }

    private var fullActionTitle: String {
        switch status {
        case .idle, .ready: return "Enable Steps"
        case .checking: return "Checking…"
        case .noSteps: return "Check again"
        case .requestFailed: return "Try again"
        case .readFailed: return "Retry"
        }
    }

    private var title: String {
        switch status {
        case .idle, .ready: return "Steps hatch bats"
        case .checking: return "Connecting steps"
        case .noSteps: return "Waiting for steps"
        case .requestFailed: return "Finish step setup"
        case .readFailed: return "Let's try again"
        }
    }

    private var message: String {
        switch status {
        case .idle, .ready: return "Your walks help this egg hatch."
        case .checking: return "Reading today's steps…"
        case .noSteps: return "No steps received yet. Walk a little, then check again."
        case .requestFailed: return "Try again or open Help."
        case .readFailed: return "Unlock your Watch, then retry."
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
