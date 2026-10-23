# Open Questions

Places where the PRD is silent or contradicts itself. Each one has a **current
behaviour** already implemented in `BatwalkCore`, so the game is playable today;
changing a decision usually means editing one value in `Tuning.swift` or `EggType.swift`
and its test.

| # | Question | Current behaviour in code | Where |
|---|---|---|---|
| **Q3** | What happens to steps walked while an egg is ready, or while no egg is chosen? | They are **banked** and applied to the next egg, capped at 6,000 so a multi-day backlog can't chain-hatch several eggs at once. | `Tuning.maxBankedSteps` |
| **Q4** | Friendship EXP numbers. | Level thresholds 0 / 100 / 250 / 500 / 1,000. Duplicate: Common 40, Uncommon 60, Rare 100, Legendary 200. Feed +10. Pet +2, first 10 pets per bat per day. All duplicates grant EXP; no new Moon Dust after 2026-10-23 (Q15). | `Tuning` |
| **Q5** | How often does walking yield fruit? | 1 fruit per 1,500 credited steps; inventory caps at 9 (cap is silent — never a penalty). | `Tuning.stepsPerFruit`, `maxFruit` |
| **Q6** | Rarity odds per egg. | The PRD's global weights (65 / 25 / 8 / 1.5) are renormalised over the rarities present in each egg's pool. So Tiny is always Common; Forest ≈ 72% Common / 28% Uncommon; Moon ≈ 72% Uncommon / 23% Rare / 4% Legendary; Crystal ≈ 72% Uncommon / 23% Rare / 4% Legendary. Within a rarity, species are equally likely — except that after 10 hatches without a new species, the next egg is sealed to one the player hasn't met (new-species pity, Q14). | `HatchEngine`, `GameState.freezeEgg` |
| **Q7** | Is Eclipse Bat ("Special / Moon") obtainable from a special egg? | Not yet — it's in the Moon pool with Galaxy. A special event egg is a post-MVP idea. | `EggType.pool` |
| **Q11** | Wake interaction during the day. | The three pilots play Pet (~1.65 s) or Eat (~2 s), then return to the time-of-day mood; other bats retain the ~2.5 s reaction. No penalty either way. | `HomeView`, `FriendshipPage` |

When a question is answered, update the code + tests, then move the row into the
"Decided" section below with the date.

## Decided

Q1/Q13 below supersede the paid tier and one-time trial from the 2026-10-10 review.

| # | Date | Decision |
|---|---|---|
| Q2 | 2026-10-23 | After the reveal every player chooses any of the five eggs. Dismissing the reveal keeps the choice available. Starter remains the onboarding egg and is also selectable. |
| Q9 | 2026-10-10 | Lv.2–5 permanently display a Heart charm, Forest charm, Star charm, and Best friend crown. In addition, `ActionCatalog` defines a species-specific Lv.2 idle quirk, Lv.3 reaction and Lv.4 signature, plus Legendary Lv.1 hatch/Lv.5 secret actions. Five universal actions are available at Lv.1. Rewards share the existing EXP thresholds. Playback is added as each character's animation art is produced; see `docs/BAT_ACTIONS.md`. |
| Q1 | 2026-10-23 | **Fully free launch.** Every enabled species is available in its designed egg pools. All five egg types are selectable without payment; Shiny and pity apply equally to everyone. Long Ear keeps Tiny / Forest. Oddballs remain wave 2. Supersedes the old three-bat tier. |
| Q8 | 2026-10-10 | "Bat Awake" ships as one **opt-in** local notification at dusk (18:00 local, `Tuning.duskStartHour`), a repeating calendar trigger so it fires at most once a day and costs no background work. Off by default; toggle in Watch Settings. `HatchNotifier.scheduleDuskReminder`. |
| Q12 | 2026-10-23 | The 12 Oddball Bats remain reserved for a **future content update (version unassigned)**. The 1.1 social/free update still ships 20 bats. They stay in `Roster.catalog` (stable IDs, numbers, assets) but are gated by `Roster.enabledWave` / `BATWALK_CONTENT_WAVE`; egg pools only include enabled waves. Release screenshot verification uses `launch_roster=true`. |
| Q13 | 2026-10-23 | **No trial egg.** All five eggs are always available, so the one-time Forest trial and completed-free-roster upsell are retired. Preserve the legacy saved flag without using it to gate anything. |
| Q14 | 2026-10-10 | **Collection pacing.** Shiny chance 0.5% → 3%, with a guaranteed Shiny every 40 hatches and ×3 odds for a species at Lv.5. After 10 hatches with no new species, the next egg seals an unmet species from its pool. Original rule (new income retired by Q15): duplicates of a Lv.5 bat pay **Moon Dust**; 4 dust calls a bat the player hasn't met (within enabled content waves). All numbers in `Tuning`; rules in `GameState.freezeEgg`, `hatch`, `callNewBat`; tests in `EconomyTests`. |
| Q15 | 2026-10-23 | **Simple rewards and longer eggs.** Duplicates give EXP and level the existing bat (Lv.1–5); cumulative XP remains after max level. Stop new Moon Dust income, preserve old balances/redemption. Starter/Tiny 10,000; Forest 21,097; Moon 42,195; Crystal 100,000. Teaching Starter alone remains 2,000. Existing active eggs keep their old target. No new souvenir, story, or invitation systems. |
| Q10 | 2026-10-23 | All players can find Shiny from every egg at the same odds and pity thresholds. Existing sealed eggs keep their original outcomes. |

### Certificate sharing and milestone eggs — decided 2026-10-23

- Certificates preserve unknown historical start dates/steps as unavailable. New receipts freeze both; cloud and paired collection copies redact them.
- A phone-only show-steps preference defaults on but is not automatic transfer consent. A per-card button requests just that receipt while both apps are reachable; it is memory-only.
- One-time teaching egg: 2,000. Pickable Starter/Tiny: 10,000; Forest: 21,097; Moon: 42,195; Crystal: 100,000. Existing active targets remain frozen.
- Shiny ships as a static certificate with the 3% base-odds line. Moon phase is an offline mean-cycle estimate, not a precise astronomical service.

### Weekly and monthly memories — decided 2026-10-23

Weekly recap uses local Monday–Sunday; monthly 1/3/6 hatch milestones reward outfits only. New hatch months are frozen; earned outfits survive backup/history trimming. Phone reminders default off. No streak loss or species gates. See SOCIAL_PROGRESS.md.
