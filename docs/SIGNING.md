# Signing & TestFlight (no Mac)

Builds are signed and uploaded by `.github/workflows/testflight.yml` on GitHub's
macOS runners, using an App Store Connect API key (repo secrets `ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_KEY_P8`).

- The archive is **ad-hoc signed** (no development profile → no registered test
  device needed); `-exportArchive` then cloud-signs it with the team's managed
  **Apple Distribution** certificate and App Store profiles, and uploads.
- Build number = workflow run number.
- Start a build: Actions › TestFlight › Run workflow, or push a commit to the
  `testflight` branch (`testflight-archive` = archive only).

## Identifiers

| | ID |
|---|---|
| iPhone app | `com.aimanjack.batwalk` |
| Watch app | `com.aimanjack.batwalk.watchkitapp` |
| Watch widget (complication) | `com.aimanjack.batwalk.watchkitapp.widget` — `…watchkitapp.complication` was rejected by Apple as "not available" |
| App Group | `group.com.aimanjack.batwalk` *(not created yet)* |
| iCloud container | `iCloud.com.aimanjack.batwalk` *(not created yet)* |

## Why iCloud backup and the App Group are switched off for now

An API key can register App IDs and create profiles, but **cannot create an App
Group or an iCloud container**, or attach them to an App ID — Apple answers
`401 Authentication failed`. Until they are created by hand, the build ships
without those entitlements and `SharedConfig.iCloudAndAppGroupEnabled = false`:

- saves stay local on the Watch (no iCloud backup / restore yet)
- the complication shows a static face instead of egg progress
- the iPhone still mirrors the save over WatchConnectivity

## Turning them on (≈10 min, works in a phone browser)

developer.apple.com › Account › **Certificates, Identifiers & Profiles** › Identifiers:

1. **+ › App Groups** → description `Batwalk`, identifier `group.com.aimanjack.batwalk`.
2. **+ › iCloud Containers** → description `Batwalk`, identifier `iCloud.com.aimanjack.batwalk`.
3. Open App ID **com.aimanjack.batwalk** → tick **App Groups** (Configure → pick the group), **iCloud** (CloudKit; Configure → pick the container), **Push Notifications** → Save.
4. Open App ID **com.aimanjack.batwalk.watchkitapp** → same three, plus make sure **HealthKit** is ticked → Save.
5. Open App ID **com.aimanjack.batwalk.watchkitapp.widget** → tick **App Groups** (pick the group) → Save.

Then in code: uncomment the entitlement lines in `project.yml` (and the phone's
`UIBackgroundModes: [remote-notification]`), set
`SharedConfig.iCloudAndAppGroupEnabled = true`, and push to `testflight`.

Before the first public release, deploy the CloudKit schema to Production in the
CloudKit Console.
