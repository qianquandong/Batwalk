# Analytics (PRD §4.5–4.6, roadmap M3)

Batwalk counts **anonymous game events only** — never step totals, dates, Health
data or identifiers — through [TelemetryDeck](https://telemetrydeck.com), which
stores no personal data and needs no consent banner. The event list in
`Packages/BatwalkCore/Sources/BatwalkCore/Analytics.swift` is the allowlist.

| Event | Properties |
|---|---|
| `onboarding_complete` | — |
| `step_permission_result` | `completed` |
| `first_hatch`, `bat_collected` | `species`, `rarity`, `shiny`, `egg` (or `source: moon-dust`) |
| `egg_complete` | `egg` |
| `duplicate_friendship` | `species`, `moonDust` |
| `companion_changed` | `species`, `source` |
| `feed_bat` | `species` |
| `purchase_unlock`, `restore_purchase` | `state`, `device` |

## Turning it on

Analytics are **off** in every build until an app ID is set. The sink is chosen
once at launch (`AnalyticsSetup.makeSink()`): no ID → `NoopAnalytics`.

1. Create an app at dashboard.telemetrydeck.com and copy its App ID.
2. Set the build setting `BATWALK_TELEMETRYDECK_APP_ID` — in `Config/Local.xcconfig`
   for local builds, or as a Codemagic / GitHub variable passed to `xcodebuild`
   for TestFlight. `project.yml` copies it into both apps' Info.plist as
   `BatwalkTelemetryDeckAppID`.
3. Update the App Store privacy label: *Product Interaction — used for Analytics —
   not linked to the user*. `Apps/Shared/PrivacyView.swift` already describes this
   in-app when the ID is present.

## Alpha exit criteria these events answer

- ≥ 80 % first-hatch completion: `onboarding_complete` → `first_hatch`.
- Step permission ≥ 75 %: `step_permission_result`.
- Hatch cadence 1–2 / day: `egg_complete` per user per day.
- Paid conversion: `purchase_unlock` with `state=active`.
