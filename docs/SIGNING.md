# Signing and capability setup

Default builds keep live widgets and cloud collection backup off. These are
independent capabilities; neither requires changing game rules or the local save URL.
GitHub's App Store Connect key can sign/export builds but does not replace portal
setup for App Groups and iCloud containers. The portal session inspected during
this change was signed out, so registration is still unverified.

## Identifiers

| Target | Identifier |
|---|---|
| iPhone | `com.aimanjack.batwalk` |
| Watch | `com.aimanjack.batwalk.watchkitapp` |
| Widget | `com.aimanjack.batwalk.watchkitapp.widget` |
| App Group | `group.com.aimanjack.batwalk` |
| Private CloudKit container | `iCloud.com.aimanjack.batwalk` |
| Non-consumable purchase | `com.aimanjack.batwalk.fullunlock` |

## Live watch-face progress

In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list),
create the App Group and attach it to the Watch app and widget App IDs. Refresh
provisioning profiles. The phone does not use the Watch's App Group container.

For a local device build:

```sh
python3 scripts/configure-capabilities.py --app-group
xcodegen generate --spec project.capabilities.json
```

For the TestFlight workflow, set repository Actions variable
`BATWALK_APP_GROUP_ENABLED` to exactly `true` after registration. This controls
both entitlements and runtime flags; do not edit `SharedConfig` independently.

Verify on a signed Watch: change eggs, pet/rename, change companion, allow a
snapshot to expire, and tap each widget family. Each should open Batwalk at the
appropriate page. A generic unsigned simulator build cannot prove App Group access.

## Cloud collection backup

Create the iCloud container, attach it with CloudKit to the Watch and phone App
IDs, and enable their push notification capability. Refresh profiles.

```sh
python3 scripts/configure-capabilities.py --cloud-backup
xcodegen generate --spec project.capabilities.json
```

Use both flags to enable both features. In GitHub Actions set
`BATWALK_CLOUD_BACKUP_ENABLED=true` after registering the container. The generated
overlay enables the matching CloudKit/push entitlements and phone background mode.

Only `CollectionBackupRecord` is cloud enabled. The existing `SaveRecord` stays
local at its original store URL. Never move it into a cloud configuration: it
contains Health-derived step accounting. The backup allowlist excludes the step
ledger, its dates/time zone, lifetime totals, banked steps, current egg progress,
fruit progress, pet-day log, and purchase entitlement. A collection restore begins
with a new step baseline; a new install does not recreate Health progress.

Initialize and inspect the Development schema on devices, then deploy it to
Production in CloudKit Console before public/TestFlight recovery validation.
Confirm records contain only the collection allowlist. Verify restoration on a
second signed Watch using the same iCloud account, including after a multi-day
absence. The phone must never become a game-save writer.

## Archive and TestFlight

### Codemagic

Run `batwalk-testflight` manually on the intended commit. It uses the existing
Batwalk App Store Connect record `6819895282` and team `GB24TMUMQ5`, and includes
the iPhone app, Watch app and Watch widget. It has no automatic trigger. The
unsigned CI fallback remains a separate workflow and cannot publish builds.

Connect an explicitly authorized App Store Connect integration named
`Batwalk TestFlight` in the Codemagic personal account. Codemagic injects its key
identifier, issuer ID and private key (which can be an `@file:` reference). Keep the private key out of Git, build
artifacts and logs. Apple team API keys apply across the team's apps; their
permissions cannot be restricted to this repository by the workflow name.

The preflight reads the latest TestFlight build number from Apple and increments
it, failing if Apple access is unavailable. Run only one publishing build at a
time to avoid two runs choosing the same number. Core tests, release checks and
hosted app tests must pass before archive. Optional App Groups and CloudKit stay
off until their portal registration and device behavior have been verified.

The archive is initially ad hoc signed, following the existing successful GitHub
upload method. Before upload, the release check verifies all three embedded
bundles, matching versions, device platforms, companion linkage, privacy
manifests and Watch HealthKit entitlements. Xcode then uses cloud-managed
distribution signing during export with `Config/ExportOptions.plist` and uploads
to App Store Connect. The temporary private-key file is removed on script exit.
An archive check alone does not establish a valid distribution signature.

After upload, confirm Apple processing has finished and the build is available
to the intended internal tester in TestFlight. Upload success alone is not proof
of installability. This workflow does not submit an App Store release, request
external beta review, invite testers or expire existing builds.

### Existing GitHub workflow

`.github/workflows/testflight.yml` uses `ASC_KEY_ID`, `ASC_ISSUER_ID` and
`ASC_KEY_P8`. Its older run-number counter must be reconciled with Apple's latest
build before returning to GitHub for uploads after Codemagic. With upload off it
only validates an ad hoc archive; distribution signing happens during export.

StoreKit adapter tests use a fake backend for deterministic purchase states.
The local `Config/Batwalk.storekit` and real sandbox/TestFlight purchase, pending
approval, refund, reinstall, offline access, and cross-device propagation still
need the checks in [RELEASE_READINESS](RELEASE_READINESS.md).
