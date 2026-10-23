import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy & data").font(.headline)
                Text("Batwalk reads only Step Count from Apple Health to grow your eggs and find fruit. It does not write to Health or read your location, workouts, heart rate, or other Health records.")
                Text("Your game and step accounting stay on your Watch. Your paired iPhone receives a collection mirror through Apple's WatchConnectivity, without step history, totals, active egg progress or certificate walk details. Health-derived save files are excluded from device backup.")
                Text(SharedConfig.appGroupEnabled
                    ? "Your Watch shares a small egg-progress summary with its own watch-face widget."
                    : "Live watch-face progress is not enabled in this build.")
                Text(SharedConfig.cloudBackupEnabled
                    ? "Your bats, nicknames, friendship, fruit inventory, and hatch history can back up to your private iCloud account. Daily steps, step dates, lifetime steps, active egg progress, and banked steps are excluded. After restoring a collection, a new egg starts from new steps."
                    : "Cloud collection backup is not enabled in this build. Keep the app installed to retain your local progress.")
                Text(AnalyticsSetup.isEnabled
                    ? "Batwalk counts anonymous game events (for example \"egg hatched\" or \"bat fed\") through TelemetryDeck so we can tell whether the game is fun. These counts contain no step data, no identifiers and no Health information, and they are never sold."
                    : "There are no ads, tracking SDKs, developer analytics servers, or Batwalk accounts. This version has no purchases.")
                Text("Siri's \"Check my egg\" reads the same small egg-progress summary the watch face uses, on your device only.")
                Text("Walking together is optional and off by default. On iPhone you can separately share this month's hatch count and your all-time hatch count with Apple's Game Center, linked to your Game Center profile. Batwalk displays friends only, but Apple may show these scores publicly in Game Center. No steps, egg distances, birthday, or Health information are submitted to Game Center.")
                Text("Turning sharing off stops future submissions and clears the friends shown in Batwalk; previously shared scores remain in Game Center under Apple's controls. Changing Game Center account turns sharing off. Friends and avatars are kept only in memory, never in game backups or analytics.")
                Text("You can change Step Count access in the Health app and notification access in device settings. Removing Batwalk deletes its local app data; if cloud backup is enabled, manage that separately in your iCloud storage settings. Removing Health access does not erase bats you've already collected.")
                Text("Sharing a birth certificate is your choice. Tap Include my steps and days to request that one walk receipt from your Watch; it stays in memory while you preview the card. Turning Show steps on shared cards off removes steps and days. The default setting never sends Health data by itself. You choose the destination in Apple's share sheet. Collection posters contain no steps.")
                Text("Birthday hats are optional. Only month and day are saved, never your birth year. This preference and the years of earned hats travel with your paired collection and private iCloud backup when enabled. Remove the birthday in iPhone Settings; hats you already earned remain yours.")
                Text("Updated October 23, 2026").font(.caption)
            }
            .font(.footnote)
            .padding()
        }
        .navigationTitle("Privacy")
    }
}
