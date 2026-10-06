# Art

Approved direction: **polished 2D pixel art**, cute + cozy + slightly mysterious,
never horror (PRD §3). Readability at real Watch size beats detail.

Put the approved concept board here as `concept-board.png`.

## Naming contract (the code looks these up by name)

Image sets go in `Apps/Watch/Assets.xcassets` and `Apps/Phone/Assets.xcassets`.
Until an image exists, the app draws a vector placeholder, so art can land one file at a time.

| What | Asset name | Example |
|---|---|---|
| Bat pose | `bat_<speciesID>_<mood>` | `bat_mochi_sleeping` |
| Shiny bat pose | `bat_<speciesID>_<mood>_shiny` | `bat_moonwing_awake_shiny` |
| Egg | `egg_<eggType>_<state>` | `egg_forest_cracked` |

- `speciesID`: `mochi cocoa long-ear fruit cave sleepy dust pebble strawberry blossom moss sunset snow cloud moonwing golden crystal vampire galaxy eclipse`
- `mood`: `sleeping drowsy awake happy eating playing`
- `eggType`: `starter tiny forest moon crystal`
- `state`: `calm shaking cracked rattling ready`

Animated sheets (idle, fly, pet, eat, happy, hatch reveal — PRD §3.2) will use
`<name>_sheet` with frames laid out horizontally on a fixed logical canvas; the
playback component arrives in milestone M2.

## Deliverable checklist per bat (PRD §3.2, §3.6)

- [ ] Idle · Sleep · Wake/Drowsy · Fly · Pet reaction · Eat · Happy · Hatch reveal
- [ ] Shiny palette (same silhouette)
- [ ] Transparent PNG, consistent canvas, deterministic frame naming
- [ ] Preview exported at real Apple Watch scale
- [ ] Layered source file in `Art/source/` (consider Git LFS)
