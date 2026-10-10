# Art

Current direction: **C · Gentle pixel**, selected by the owner on 2026-10-10.
Coarse readable pixel characters, midnight teal, cream, sage and a sparse glade.
Readability at real Watch size beats detail. See [the active specification](gentle-pixel/README.md).

All 20 species now have dedicated sleeping/awake/happy Normal and Shiny assets,
alongside matching eggs, fruit and app icons. Sources and generation prompts are
in [`gentle-pixel/`](gentle-pixel/README.md). Run
`python3 Art/tools/package_gentle_sprites.py --require-complete` to package them.
The `gentle_` catalog resolves before earlier art; other moods use related new
poses. Dedicated animation sheets remain artist production work.

### Earlier art (retained as a fallback)

[`concept-board.png`](concept-board.png) and the previous UI boards are historical
references; they do not define the current visual style.

`python3 Art/tools/build_sprites.py` regenerates the earlier board catalog, then
reapplies the current Gentle pixel pack:

- **Mochi, Strawberry, Moonwing, Galaxy**: awake · sleeping · playing (fly) · happy (pet) · eating; Mochi/Strawberry also drowsy
- **Eggs**: calm · shaking · cracked, recoloured per egg type (starter cream, tiny lavender, forest pink, moon indigo, crystal cyan)
- **Large portraits** (~200 px) of the same four bats are used for the awake and happy poses — the sharpest art on the board
- **Home background** (the cave) and the **app icon** (Mochi portrait)

[`generated/`](generated/README.md) retains the previous Cocoa and Long Ear
sources. Recoloured mascot fallbacks are retained for missing future assets,
but the shipped 20-species roster resolves dedicated Gentle pixel art first.

## Naming contract (the code looks these up by name)

Shared image sets go in `Apps/Shared/Sprites.xcassets`.
Until an image exists, the app draws a vector placeholder, so art can land one file at a time.

| What | Asset name | Example |
|---|---|---|
| Current bat pose | `gentle_bat_<speciesID>_<mood>[_shiny]` | `gentle_bat_mochi_awake` |
| Current egg | `gentle_egg_<eggType>_<pose>` | `gentle_egg_forest_cracked` |
| Bat pose | `bat_<speciesID>_<mood>` | `bat_mochi_sleeping` |
| Shiny bat pose | `bat_<speciesID>_<mood>_shiny` | `bat_moonwing_awake_shiny` |
| Egg | `egg_<eggType>_<state>` | `egg_forest_cracked` |

- `speciesID`: `mochi cocoa long-ear fruit cave sleepy dust pebble strawberry blossom moss sunset snow cloud moonwing golden crystal vampire galaxy eclipse`
  `bumblebee sticky marshmallow honk ember nectar tube-nose polka wrinkle walker fox ghost` (Oddball Bats, PRD §6.3 — art brief and real-life references in that table)
- `mood`: `sleeping drowsy awake happy eating playing`
- `eggType`: `starter tiny forest moon crystal`
- `state`: `calm shaking cracked rattling ready`

### Unique actions

Every bat also has 3 unique actions (Legendaries have 5), unlocked by Friendship.
The art brief for each one, with the real behaviour it comes from, is in
[`docs/BAT_ACTIONS.md`](../docs/BAT_ACTIONS.md). Sheet name:
`bat_<speciesID>_<actionID>_sheet`, e.g. `bat_marshmallow_fig-yellow_sheet`.
Until a sheet exists, the game plays the universal action instead.

Animated sheets (idle, fly, pet, eat, happy, hatch reveal — PRD §3.2) will use
`<name>_sheet` with frames laid out horizontally on a fixed logical canvas; the
playback component arrives in milestone M2.

## Deliverable checklist per bat (PRD §3.2, §3.6)

- [ ] Idle · Sleep · Wake/Drowsy · Fly · Pet reaction · Eat · Happy · Hatch reveal
- [ ] 3 unique actions (Legendary: 5) from `docs/BAT_ACTIONS.md`
- [ ] Shiny palette (same silhouette)
- [ ] Transparent PNG, consistent canvas, deterministic frame naming
- [ ] Preview exported at real Apple Watch scale
- [ ] Layered source file in `Art/source/` (consider Git LFS)
