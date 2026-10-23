import SwiftUI
import UserNotifications
import BatwalkCore

@MainActor
enum PhoneNotifications {
    static let weeklyKey = "batwalk.phone.weeklyRecap"
    static let challengeKey = "batwalk.phone.challengeReminders"
    private static var generation = 0
    static func refresh(state: GameState, defaults: UserDefaults = .standard) async {
        generation += 1; let revision = generation
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard revision == generation else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("batwalk.phone.") })
        let status = await center.notificationSettings().authorizationStatus
        guard revision == generation, status == .authorized || status == .provisional else { return }
        let plans = PhoneReminderPlan.make(history: state.history, now: .now,
            weekly: defaults.bool(forKey: weeklyKey), challenge: defaults.bool(forKey: challengeKey),
            savedMonthCounts: state.challengeHatchCounts)
        for plan in plans {
            guard revision == generation else { return }
            let identifier = "\(plan.id).\(revision)"
            let content = UNMutableNotificationContent(); content.title = plan.title; content.body = plan.body; content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.date)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
            // A newer refresh removes a request added just as this one was superseded.
            if revision != generation { center.removePendingNotificationRequests(withIdentifiers: [identifier]); return }
        }
    }
}

struct PhoneNotificationSettings: View {
    @Environment(GameStore.self) private var store
    @AppStorage(PhoneNotifications.weeklyKey) private var weekly = false
    @AppStorage(PhoneNotifications.challengeKey) private var challenge = false
    @State private var denied = false
    var body: some View {
        Section("Little reminders") {
            Toggle("Weekly recap", isOn: $weekly)
            Toggle("Challenge reminders", isOn: $challenge)
            Text("Optional, local to this iPhone. Sunday at 9 am, and a few gentle monthly milestones.")
                .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
            if denied { Text("Notifications are off in iPhone Settings.").font(BatwalkFont.caption) }
        }
        .onChange(of: weekly) { _, _ in update() }
        .onChange(of: challenge) { _, _ in update() }
    }
    private func update() {
        guard !store.isDemo else { return }
        Task {
            if weekly || challenge { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
            denied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
            await PhoneNotifications.refresh(state: store.state)
        }
    }
}
