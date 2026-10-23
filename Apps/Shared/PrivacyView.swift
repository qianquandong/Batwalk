import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy & data").font(.headline)
                Text("Batwalk reads only Step Count from Apple Health to grow your eggs and find fruit. It does not write to Health or read your location, workouts, heart rate, or other Health records.")
                Text("Your game and step accounting stay on your Watch. Your paired iPhone receives an offline mirror through Apple's WatchConnectivity. Health-derived save files are excluded from device backup.")
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
                Text("You can change Step Count access in the Health app and notification access in device settings. Removing Batwalk deletes its local app data; if cloud backup is enabled, manage that separately in your iCloud storage settings. Removing Health access does not erase bats you've already collected.")
                Text("Updated October 23, 2026").font(.caption)
            }
            .font(.footnote)
            .padding()
        }
        .navigationTitle("Privacy")
    }
}
