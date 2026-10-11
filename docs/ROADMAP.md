# Roadmap

Milestones follow the PRD launch plan (§5.1). Each milestone ends with something
that runs on a real Apple Watch. The 2026-10-10 review scorecard and what it
changed are in [REVIEW_2026-10-10.md](REVIEW_2026-10-10.md).

## M0 — Foundation ✅

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
- [x] Phone-only pipeline: GitHub Actions archives, cloud-signs and uploads to TestFlight (build 9, 2026-10-06) — see docs/SIGNING.md
- [ ] Create App Group + iCloud container in the portal, re-enable iCloud backup + complication data (`scripts/configure-capabilities.py`)
- [ ] Create the full-unlock IAP in App Store Connect ($2.99)
- [x] Run on a physical Apple Watch; walk 2,000 steps; hatch Mochi (build 9, 2026-10-08)
- [x] Hatch is something the player does: crown / tap to crack the shell, rarity light tease, ≈ 2.4 s reveal, haptic signature per rarity (2026-10-10)
- [ ] Tune the hatch on real hardware (Emotional DoD 1–5), including the Rare / Legendary haptic signatures
- [ ] Verify open-to-visible-bat < ~1 s
- [ ] Verify battery impact over a full day (no GPS, no workout session, hourly background only)
- [x] Decide open questions Q1, Q8, Q12 (+ Q13 trial egg, Q14 pacing) — 2026-10-10

## M2 — Art integration

- [x] Concept board in repo → `Art/concept-board.png`
- [x] Interim sprites cut from the board; Gentle-pixel portraits for all 32 identities
- [x] Watch simulator screenshots in CI (`screenshots` workflow, DemoMode scenarios)
- [x] One-pixel light rim on dark-bodied species so they read on the midnight surface (2026-10-10)
- [ ] **Free roster first:** Cocoa and Long Ear animation sets to match Mochi (the free tier is where first impressions happen)
- [ ] Two-frame sleep / awake for all 20 launch bats, so Day / Dusk / Night is visible on every companion
- [ ] Egg sprites × 5 types × 5 states
- [ ] Artist clean-up pass over the generated portraits (readability at 64 px; 26 / 27 / 30 / 31 rounder, closer to the shape language)
- [ ] Remaining species + real Shiny palettes (hue shift today)
- [ ] Final app icon

## M3 — Alpha (10–20 testers)

- [ ] TestFlight build from this branch (Codemagic `batwalk-testflight`)
- [x] Analytics sink (privacy-respecting, game events only): TelemetryDeck behind `BATWALK_TELEMETRYDECK_APP_ID` — see docs/ANALYTICS.md
- [ ] Set the TelemetryDeck app ID in CI so Alpha can measure the exit criteria
- [x] Watch can purchase (not only restore); free-tier-complete card; locked eggs open the unlock
- [x] Complication shows the companion's portrait + egg ring; Smart Stack relevance at hatch-ready and dusk (needs the App Group)
- [ ] Exit: ≥80% first-hatch completion, no critical save bugs

## M4 — Closed Beta (50–100 users)

- [x] Optional "Bat Awake" dusk notification (Q8)
- [ ] Friendship Lv.2–5 unlock animations
- [ ] Rarity / Friendship / pity tuning from beta data (`Tuning`: shiny 3 %, pity 40, new-species pity 10, Moon Dust 4)
- [ ] Exit: D7 ~25–30%+, Health permission ≥70%, stable battery feedback

## M5 — GA (English, global)

- [ ] App Store assets, privacy nutrition label (Step Count, no tracking; analytics = "App Functionality / Product Interaction, not linked to you" if TelemetryDeck is on)
- [ ] Publish `site/privacy.html` and `site/support.html` (Cloudflare Pages or GitHub Pages) and link them in App Store Connect
- [ ] String Catalog translations (Japanese, Simplified Chinese) — strings are already extracted
- [ ] Exit: crash-free > 99.5%, core KPIs stable

## v1.1 — First content update

- [ ] Flip `BATWALK_CONTENT_WAVE` to 2: the 12 Oddball Bats join the egg pools (Q12)
- [ ] Oddball animation sets; Batpedia "real-life cousin" cards as the launch story

## Post-MVP (explicitly deferred — PRD §7.2)

Habitat economy, evolution, moon-phase / weather events, social, trading, challenges, breeding, GPS, AR, battles, subscriptions, AI, ambient-light detection.
