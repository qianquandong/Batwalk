# CLAUDE.md — working on Batwalk

Batwalk is an Apple Watch-first cozy pet game. Source of truth for product
decisions: `docs/PRD.md`. Unresolved product questions: `docs/OPEN_QUESTIONS.md`.
The 2026-10-10 review (scores, findings, what changed): `docs/REVIEW_2026-10-10.md`.

## Rules for changes

- **Game rules go in `Packages/BatwalkCore` only**, with a unit test. Apps call
  `GameStore.mutate { ... }` and never re-implement a rule in a view.
- **Balance numbers go in `Tuning.swift`.** Don't hard-code them elsewhere.
- **Only the Watch writes the save.** The iPhone `GameStore` (role `.phone`) is read-only.
- **Never change a species `id` or `EggType` raw value** after shipping — they are save keys and asset names.
  New species go in `Roster.catalog` with a `wave`; pools only include enabled waves.
- **Egg outcomes are sealed at creation** (`GameState.freezeEgg`), pity rules included.
  Nothing after `startEgg` may change what hatches.
- **Launch gameplay is fully free.** `SharedConfig.paidContentEnabled` is false.
  Keep StoreKit plumbing dormant; future purchases are cosmetic only. Payment must
  never change steps, speed, odds, eggs, species access or Friendship.
  The legacy entitlement policy still requires verified transactions and never acts on unknown results.
- Respect the PRD guardrails: no punishment, no pay-to-skip, Step Count only, no AI, no backend.
  Legacy Moon Dust balances remain redeemable; no new dust or trial gate.
- Battery: no GPS, no workout sessions, no polling faster than HealthKit's hourly background delivery.
- Privacy: nothing Health-derived goes to CloudKit, WatchConnectivity backups or analytics.
  Analytics are `AnalyticsEvent` names + small string properties only.

## Commands

```bash
swift test --package-path Packages/BatwalkCore   # rules + tests (works on Linux too)
xcodegen generate                                # regenerate Batwalk.xcodeproj after editing project.yml
```

No Swift toolchain? The core package runs in Docker from any OS:

```bash
docker run --rm -v "$PWD/Packages/BatwalkCore:/work" -w /work swift:5.10-jammy swift test
```

CI (`.github/workflows/ci.yml`) runs the core tests on Linux and then the Watch +
iPhone simulator builds with the hosted app tests on macOS, for every PR.
`codemagic.yaml` holds the screenshot and TestFlight workflows.

## When you resolve an open question

Update the code + test, then move the row in `docs/OPEN_QUESTIONS.md` to "Decided" with the date.
