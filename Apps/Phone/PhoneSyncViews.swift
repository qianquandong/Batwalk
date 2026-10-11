import SwiftUI
import BatwalkCore

struct PhoneSyncStatus: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        TimelineView(.everyMinute) { context in
            let stale = store.lastSyncAt.map { context.date.timeIntervalSince($0) > 900 } ?? true
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: stale ? "clock" : "applewatch")
                VStack(alignment: .leading, spacing: 3) {
                    if let date = store.lastSyncAt {
                        Text("Last updated \(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        if stale { Text("Showing your saved collection. Open Batwalk on your Watch to update.") }
                    } else {
                        Text("Waiting for your Watch")
                        Text("Open Batwalk on your paired Apple Watch to get started.")
                    }
                }
            }
            .font(BatwalkFont.micro)
            .foregroundStyle(BatwalkColor.textSecondaryLight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CompanionChangeControl: View {
    @Environment(GameStore.self) private var store
    let speciesID: String

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 10) {
                if store.companionHandoff.isWaiting {
                    Label("Waiting for Watch", systemImage: "clock")
                        .font(BatwalkFont.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(BatwalkColor.lightTint))
                    Text(waitingText)
                        .font(BatwalkFont.caption)
                        .multilineTextAlignment(.center)
                } else if store.state.companionID == speciesID {
                    Label("On your Watch", systemImage: "checkmark.circle.fill")
                        .font(BatwalkFont.headline)
                        .foregroundStyle(BatwalkColor.accent)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(BatwalkColor.lightTint))
                } else {
                    Button {
                        store.chooseCompanion(speciesID)
                        Haptics.light()
                    } label: { Label("Choose for Watch", systemImage: "applewatch") }
                        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 50))
                    Text("Your Watch will make the change.")
                        .font(BatwalkFont.micro)
                }
                if let error = store.companionRequestError {
                    Text(error).font(BatwalkFont.caption)
                } else if let failure = store.companionHandoff.failure {
                    Text(message(for: failure)).font(BatwalkFont.caption)
                }
            }
            .foregroundStyle(BatwalkColor.textPrimaryLight)
            .multilineTextAlignment(.center)
            .onChange(of: context.date, initial: true) { _, _ in store.refreshHandoff() }
        }
    }

    private var waitingText: String {
        let name = store.companionHandoff.request.flatMap { store.state.collection[$0.speciesID]?.companionTitle } ?? "Your companion"
        return "Keep browsing. We'll confirm when \(name) is on your Watch."
    }

    private func message(for failure: CompanionChangeOutcome) -> String {
        switch failure {
        case .expired: return "This request has expired. Open Batwalk on your Watch, then choose your companion again."
        case .saveChanged: return "Your Watch save has changed. Check your collection and choose again."
        case .notOwned: return "This bat isn't in your Watch collection yet. Open both apps to update."
        case .saveFailed: return "Your Watch couldn't save the change. Open Batwalk on your Watch and try again."
        case .superseded: return "Your companion changed on your Watch. The latest choice is shown here."
        case .applied: return ""
        }
    }
}

struct CurrentCompanionRow: View {
    @Environment(GameStore.self) private var store
    var compact = false

    var body: some View {
        if let bat = store.state.companion {
            HStack(spacing: 12) {
                BatSprite(speciesID: bat.speciesID, shiny: bat.showsShiny, size: compact ? 32 : 48)
                    .accessibilityHidden(true)
                Text("On your Watch: \(bat.companionTitle)")
                    .font(BatwalkFont.caption)
                    .foregroundStyle(BatwalkColor.textPrimaryLight)
                Spacer(minLength: 0)
            }
            .padding(compact ? 8 : 12)
            .background(BatwalkColor.lightTint.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

