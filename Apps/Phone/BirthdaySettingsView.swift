import SwiftUI
import BatwalkCore

/// Month and day only. A queued request is shown honestly until the Watch confirms it.
struct BirthdaySettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var enabled = false
    @State private var month = 1
    @State private var day = 1
    @State private var loaded = false

    private var draft: MonthDay? { enabled ? MonthDay(month: month, day: day) : nil }
    private var months: [String] {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US")
        return formatter.monthSymbols
    }

    var body: some View {
        Form {
            Section {
                Toggle("Birthday hat", isOn: $enabled)
                if enabled {
                    Picker("Month", selection: $month) {
                        ForEach(1...12, id: \.self) { value in Text(months[value - 1]).tag(value) }
                    }
                    Picker("Day", selection: $day) {
                        ForEach(1...MonthDay.days(in: month), id: \.self) { value in Text("\(value)").tag(value) }
                    }
                }
            } footer: {
                Text("Only month and day are saved, never your birth year. On your birthday your companion wears a tiny party hat, even if no egg hatches. A birthday hatch keeps that year's hat. February 29 is celebrated on February 28 in other years.")
            }
            Section {
                Button(store.settingsHandoff.isWaiting ? "Waiting for Watch…" : "Save on Watch") {
                    store.chooseBirthday(draft)
                }
                .disabled(!store.state.hasStarted || store.settingsHandoff.isWaiting ||
                          (draft == store.state.birthday && store.settingsHandoff.failure == nil && store.settingsRequestError == nil))
                if store.settingsHandoff.isWaiting {
                    Label("Your Watch will confirm this change. Keep both apps open to refresh it.", systemImage: "applewatch")
                } else if let error = store.settingsRequestError {
                    Text(error).foregroundStyle(BatwalkColor.textSecondaryLight)
                } else if let failure = store.settingsHandoff.failure {
                    Text(message(for: failure)).foregroundStyle(BatwalkColor.textSecondaryLight)
                } else if !store.state.hasStarted {
                    Text("Start Batwalk on your paired Watch first, then save your birthday here.")
                } else if draft != store.state.birthday {
                    Text("Unsaved change. Save this choice on your Watch.")
                } else {
                    Text(store.state.birthday == nil ? "No birthday saved." : "Saved on your Watch.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BatwalkColor.lightBackground)
        .navigationTitle("Birthday")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.refreshHandoff()
            guard !loaded else { return }; loaded = true
            let value = store.settingsHandoff.isWaiting ? store.settingsHandoff.request?.birthday : store.state.birthday
            enabled = value != nil
            month = value?.month ?? 1; day = value?.day ?? 1
        }
        .onChange(of: month) { _, value in day = min(day, MonthDay.days(in: value)) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshHandoff() } }
    }

    private func message(for failure: PlayerSettingsOutcome) -> String {
        switch failure {
        case .expired: return "The request expired while your Watch was away. Open both apps and save again."
        case .saveChanged: return "Your Watch collection changed. Open both apps to refresh it, then save again."
        case .superseded: return "A newer birthday choice is already on your Watch. Save again to use this choice."
        case .saveFailed: return "Your Watch could not save the change. Your previous birthday is safe; try again."
        case .applied: return "Saved on your Watch."
        }
    }
}
