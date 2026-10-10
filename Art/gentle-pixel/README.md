# Gentle pixel — selected 2026-10-10

The owner selected **C · Gentle pixel** to replace the previous visual direction.
This is the active reference for Watch and iPhone presentation.

- Coarse, warm, friendly pixel silhouettes; fixed 64 px logical canvases and
  nearest-neighbor rendering at every displayed size.
- Midnight teal Watch surfaces, cream text, sage buttons and restrained peach
  Friendship accents. The iPhone uses warm cream and sage surfaces.
- Flat cards/buttons, sparse static pixel plants/stars, compact Home branding.
  Keep native Dynamic Type, accessible labels and Reduce Motion behavior.
- All 20 roster IDs have sleeping, awake and happy sprites in both Normal and
  Shiny palettes: **120 dedicated images**, plus 15 egg states and a strawberry.
- Long Ear has a taller ear silhouette; Sleepy has a cap; thematic bats keep
  their sprout, flower, crescent, crystal, cape or star marks. Shiny assets resolve
  directly without tinting another species.

`*-sheet-v2.png` sources are 3 columns (sleeping / awake / happy) × 2 rows
(Normal / Shiny). `egg-icons-v2.png` is a row-major 4×4 grid: three states
(calm / cracked / ready) for each of Starter, Tiny, Forest, Moon, Crystal, then
the strawberry. `app-icon-v2.png` supplies both app icons.

Generated with the built-in imagegen tool; complete prompts are preserved in
[`generation-prompts.json`](generation-prompts.json). Package with:

```sh
python3 Art/tools/package_gentle_sprites.py --require-complete
```

The packager preserves fixed cell coordinates and alpha, creates 64 px logical
renditions and 256 px catalog images, and exports opaque 1024 px app icons. Asset
names start with `gentle_`, so the earlier catalog remains available for recovery.
The legacy board builder reapplies this pack afterward.

These are static pose assets. Drowsy, eating and playing currently use related
poses plus native motion. Dedicated animation frames and layered artist source
remain separate production work. Final approval should include actual Watch
scale, small-screen/accessibility checks and the simulator screenshots in the PR.
