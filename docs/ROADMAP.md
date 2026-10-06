# Roadmap

Milestones follow the PRD launch plan (§5.1). Each milestone ends with something
that runs on a real Apple Watch.

## M0 — Foundation ✅ (this commit)

- [x] Repo, PRD in Markdown, open questions, decision records
- [x] `BatwalkCore` Swift package: roster, eggs, hatch engine, step ledger, Friendship, fruit, day/dusk/night, save model — with unit tests
- [x] XcodeGen project: Watch app, Watch complication, iPhone companion
- [x] Watch screens wired to real rules: Onboarding, Home, Walk, Care, Bats, hatch reveal, egg picker
- [x] iPhone screens: Batpedia, Large View, History, Unlock / Restore
- [x] HealthKit step sync (foreground + hourly background delivery)
- [x] SwiftData save + CloudKit mirror + WatchConnectivity push
- [x] StoreKit 2 one-time unlock + local `.storekit` config for testing
- [x] CI: core tests + simulator builds
- [x] Vector placeholder bats/eggs + placeholder pixel icon so everything runs before art

## M1 — First playable on wrist (target: Alpha-ready loop)

- [x] Team ID set (AI Man Jack LLC · GB24TMUMQ5)
- [ ] First device build in Xcode (auto-registers IDs + capabilities); create the $1.99 IAP in App Store Connect
- [ ] Run on a physical Apple Watch; walk 2,000 steps; hatch Mochi
- [ ] Tune egg-shake / crack / reveal animations on real hardware (Emotional DoD 1–5)
- [ ] Verify open-to-visible-bat < ~1 s; hatch animation 2–4 s
- [ ] Verify battery impact over a full day (no GPS, no workout session, hourly background only)
- [ ] Decide open questions Q1–Q3

## M2 — Art integration

- [ ] Commission / finalise concept board → `Art/concept-board.png`
- [ ] Mochi, Cocoa, Long Ear full animation sets (free tier first)
- [ ] Egg sprites × 5 types × 5 states
- [ ] Sprite-sheet playback component (frame timing, battery-conscious)
- [ ] Remaining 17 species + Shiny palettes
- [ ] Real app icon

## M3 — Alpha (10–20 testers)

- [ ] TestFlight build
- [ ] Analytics sink (privacy-respecting, game events only)
- [ ] Exit: ≥80% first-hatch completion, no critical save bugs

## M4 — Closed Beta (50–100 users)

- [ ] Optional "Bat Awake" dusk notification (Q8)
- [ ] Friendship Lv.2–5 unlock animations
- [ ] Rarity / Friendship tuning from beta data
- [ ] Exit: D7 ~25–30%+, Health permission ≥70%, stable battery feedback

## M5 — GA (English, global)

- [ ] App Store assets, privacy nutrition label (Step Count, no tracking)
- [ ] Exit: crash-free > 99.5%, core KPIs stable

## Post-MVP (explicitly deferred — PRD §7.2)

Habitat economy, evolution, moon-phase / weather events, social, trading, challenges, breeding, GPS, AR, battles, subscriptions, AI, ambient-light detection.
