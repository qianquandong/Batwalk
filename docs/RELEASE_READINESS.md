# Batwalk release readiness — updated 2026-10-10

This implementation follows the review order: progress reliability, wrist
experience, rewards/purchases, then release verification. Automated results must
be read from the PR's latest green CI run; an unsigned build is not a device sign-off.

## Implemented

| Stage | Behavior and verification |
|---|---|
| Reliable progress | Copy-on-write game updates publish only after SwiftData commits. Failed writes roll back and remain retryable. Save ID/revision preserves renames and care actions when hatch/step totals tie. Rotating local recovery copies preserve the previous save. Future or unreadable saves do not silently reset. |
| Step accounting | One serial HealthKit statistics batch; failed/incomplete batches do not skip dates. Positive late changes reconcile over seven days; a longer absence resumes from its unprocessed checkpoint. Accounting retains its original time zone across travel; local day/night presentation still follows device time. Daily duplicate reads give no extra rewards. |
| Outcome stability | Species and Shiny result are sealed at egg creation. Legacy eggs seal once during decoding, before StoreKit refresh. Purchases, refunds, and tuning changes cannot reroll an active egg. |
| Data separation | Full Health-derived saves and recovery copies stay local and are excluded from device backup. Private CloudKit contains only a collection allowlist. Collection restoration drops all step progress and establishes today's baseline before granting new steps. StoreKit alone owns paid access. |
| Wrist experience | Progress offers update feedback and Health help. Zero data no longer claims permission denial. Free players start the next Tiny Egg with one reveal action; paid players see actual egg pools. Notification permission follows the first hatch. Widgets have freshness/expiry, privacy-sensitive rendering, and deep links; reloads require visible changes or stale-to-fresh data. |
| Rewards and artwork | Friendship Lv.2–5 earns visible permanent charms/crown, with the next reward shown below Feed. All 20 species have dedicated Gentle pixel sleeping/awake/happy Normal and Shiny art (120 sprites), plus 15 egg states and a strawberry. Matching app icons, midnight-teal/cream/sage interface tokens, flat controls, sparse still scenery and compact Home branding complete the direction. Sources/prompts live in `Art/gentle-pixel`. |
| Purchases | Localized price from StoreKit; unavailable product retry; pending/cancel/success/restore/no-entitlement feedback; foreground entitlement refresh and revoked entitlement handling. Watch restore displays its result. Fake backend tests cover state transitions, not Apple's purchase UI. |
| Release checks | Core plus hosted app regression tests, both simulator builds, a capability-enabled unsigned build, screenshot artifacts, privacy manifest in all three bundles, in-app privacy text, and pre-archive test gates. |

## Added by the 2026-10-10 review (`improve/review-fixes`)

| Area | Behavior and verification |
|---|---|
| Hatch | Crown / tap cracks the egg; rarity light tease; ≈ 2.4 s reveal; haptic signature per rarity; Double Tap on Hatch Now. Verify feel on hardware. |
| Pacing | Shiny 3 % + pity 40 + Lv.5 ×3; new-species pity 10; Moon Dust (1 per Lv.5 duplicate, 4 per call); trial Forest Egg; Long Ear in Tiny. 15 new/updated core tests (101 total, green in Docker). |
| Purchases | Watch paywall (`WatchUnlockView`) from locked eggs, Collection card and Settings. `EntitlementPolicy`: only verified → unlock, only revoked → lock; re-applied after every check and after load/restore. |
| Complication | Portrait + egg ring, cracks from 50 %, last known progress kept when stale, Smart Stack relevance (watchOS 11). Still needs the App Group to show live data. |
| Step sync | Per-day HealthKit fallback when buckets don't match the ledger's time zone; 45-day lookback cap; NaN/absurd totals sanitised; `Tuning.maxDailySteps`. |
| Backup | iPhone publishes its collection mirror over WatchConnectivity; a re-paired Watch restores from it (onboarding button, auto when the save is empty). Cloud backup rewritten only on content change. |
| Analytics | TelemetryDeck sink behind `BATWALK_TELEMETRYDECK_APP_ID` (docs/ANALYTICS.md); privacy text updates itself. |
| Animation | Generated Gentle-pixel frame sets for the 29 non-pilot species (1,216 frames, 6–8 per action, `GeneratedFramePlan`); pilots unchanged. Verify playback cadence and energy on hardware. |
| Platform | Siri "Check my egg" (App Intents), iPhone Dark Mode, share card, String Catalog, strict-concurrency warnings, content waves (Oddballs = v1.1). |
| CI | Core tests on Linux for every PR (1× minutes); macOS builds on `main` / manual; Codemagic for PR Mac checks. |

Verified on Codemagic (`batwalk-verify`, build 6acaec5b, 2026-10-11, Xcode 26.3):
core tests, Watch + iPhone simulator builds, the hosted app tests (incl. all
1,216 generated frames), iPhone and Watch screenshots and the capability-enabled
build — green after one fix (`RelevantContext.date(from:to:)` for watchOS 11).

## Required before release

- [ ] Register and verify App Group/CloudKit capability IDs and provisioning profiles; turn on each feature with the generated configuration. Developer portal was signed out during this task.
- [ ] Prove live widget sharing and tap destinations on signed Watch hardware; test all four families, Smart Stack rectangular presentation, redaction, and stale data.
- [ ] Deploy/inspect the collection-only CloudKit schema; restore on another signed Watch. Reopening the original local store must preserve v1 saves.
- [ ] Test on minimum supported watchOS 10/iOS 17 and current OS, smallest and largest screens, large text, VoiceOver, Reduce Motion, Always On, and Low Power Mode. Simulator captures cover a representative device, not this matrix.
- [ ] On actual paired devices, revoke/regrant Health access, cross midnight/DST, travel across time zones, add late iPhone steps, stay offline, and resume after 14+ days. Record expected daily totals and exactly-once game rewards. HealthKit cannot reveal read-denial directly.
- [ ] Measure battery and wakeups on a representative older Watch and current model over comparable 8–24 hour periods. Record foreground idle, background, widget use, Always On, and Low Power behavior; do not infer energy use from simulator timing. Verify haptic intensity on wrist.
- [ ] Complete local StoreKit configuration and sandbox/TestFlight purchase, restore, pending approval, unverified/error, refund/revocation, reinstall, offline verified access, and phone-to-Watch propagation. Fake tests do not substitute for these.
- [ ] Approve the 32 independent Gentle pixel identities at real Watch size. Three pilot bats have 18 clips / 74 frames; the other 29 use static portraits. Complete remaining animation sheets, pixel cleanup, dedicated v3 Shiny palettes and layered sources. Check the [pilot review matrix](PILOT_ANIMATIONS.md) on actual Watch hardware; generated frame packaging and Linux core tests do not verify watchOS playback or energy use.
- [ ] Publish an accessible privacy-policy URL and support contact; align App Store privacy labels with actual enabled capabilities and any future analytics. The bundled privacy text is available, but a public policy/support destination has not been supplied.
- [ ] Inspect a signed archive's three privacy manifests/entitlements, then upload to TestFlight and verify install/upgrade from an existing build. A green unsigned CI run alone does not prove App Store readiness.

## Known limits and deliberate scope

The recent reconciliation window is seven days; arbitrarily old Health edits
outside retained daily checkpoints are not retroactive rewards. Absences are
different: unprocessed days after the last checkpoint are queried in a single
batch. A long-range query has a timeout and remains retryable.

The full hatch history remains append-only. WatchConnectivity uses application
context for small saves and a protected temporary file above 50 KB. Old revisions
from either channel are ignored on the phone. Large-history file delivery still
requires a paired-device test before promising unlimited history.
No background workout session, GPS, faster polling, backend, or random-reward
monetization has been introduced. Existing price, rarity odds, and EXP thresholds
are unchanged.

References: [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy),
[Health and health research review rules](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research),
[Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api),
[WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity).
