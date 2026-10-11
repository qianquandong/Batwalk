import AppIntents
import Foundation

/// "How far is my egg?" — Siri, Shortcuts and the Action button. Reads the small
/// progress snapshot the app already keeps for the complication; never Health data.
struct EggProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Check my egg"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = ComplicationSnapshot.load()
        let name = snapshot.companionName ?? "Your bat"
        let dialog: IntentDialog
        if snapshot.isEggReady {
            dialog = "Your egg is ready to hatch! Open Batwalk on your Watch."
        } else if let remaining = snapshot.eggStepsRemaining {
            let percent = Int(((snapshot.eggProgress ?? 0) * 100).rounded())
            dialog = "\(remaining.formatted()) steps to go — your egg is \(percent) percent there. \(name) is waiting."
        } else if snapshot.companionName != nil {
            dialog = "No egg right now. Pick your next egg on your Watch and \(name) will keep you company."
        } else {
            dialog = "Open Batwalk on your Apple Watch to start your first egg."
        }
        return .result(dialog: dialog)
    }
}

struct BatwalkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EggProgressIntent(),
            phrases: [
                "How far is my egg in \(.applicationName)",
                "Check my egg in \(.applicationName)",
                "How is my bat in \(.applicationName)",
            ],
            shortTitle: "Check my egg",
            systemImageName: "oval.portrait.fill"
        )
    }
}
