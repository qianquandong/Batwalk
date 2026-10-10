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

The workflow runs core and app regression tests before archive. It uses secrets
`ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8`, and the configured team
`GB24TMUMQ5`. Run with upload off first to validate a signed archive. Then inspect
embedded entitlements and privacy manifests before enabling upload. The current
PR does not trigger an archive, upload, or merge.

StoreKit adapter tests use a fake backend for deterministic purchase states.
The local `Config/Batwalk.storekit` and real sandbox/TestFlight purchase, pending
approval, refund, reinstall, offline access, and cross-device propagation still
need the checks in [RELEASE_READINESS](RELEASE_READINESS.md).
