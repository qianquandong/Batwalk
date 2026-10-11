# Gentle pixel — selected 2026-10-10

The owner selected **C · Gentle pixel** to replace the previous visual direction.
This is the active reference for Watch and iPhone presentation.

## Character direction: 32 independent identities

The owner's follow-up clarified that C specifies the rendering language and cozy
tone. Each bat needs an independently designed theme, face, body construction,
resting expression and personality. Changing the mascot's color or stretching its
body is insufficient. The original action catalog supplies character cues.

[`portraits-v3/roster.png`](portraits-v3/roster.png) presents all 32 new original
portrait concepts. Individual transparent originals, full generation prompts,
stable IDs and action references are in [`portraits-v3/`](portraits-v3/).
This library includes the 12 Oddball IDs from PR #2. Chinese labels are working
art labels and do not rename the stored species IDs.

All 32 portraits are now packaged for runtime display. Mochi, Sticky and Walker
have [18 animated clips / 74 frames](pilots-v1/README.md) with a 64 px logical
canvas. The launch 20 now have all [100 universal clips / 400 frames](portrait-universals-v1/README.md).
The ten remaining non-pilot wave-two bats keep approved portrait stills.
Launch bats #1–20 now also have [all 64 unique actions](launch-actions/README.md).
Generated art still needs
on-device approval and pixel cleanup; new Shiny palettes currently use hue rotation.

## Current runtime presentation and pose assets

- Coarse, warm, friendly pixel silhouettes; fixed 64 px logical canvases and
  nearest-neighbor rendering at every displayed size.
- Midnight teal Watch surfaces, cream text, sage buttons and restrained peach
  Friendship accents. The iPhone uses warm cream and sage surfaces.
- Flat cards/buttons, sparse static pixel plants/stars, compact Home branding.
  Keep native Dynamic Type, accessible labels and Reduce Motion behavior.
- Three pilot identities retain their original idle/sleep/fly/pet/eat/signature frames.
  The other 19 launch bats use `portrait-universals-v1`; ten wave-two bats use portrait stills.
  Launch unique actions use `launch-actions`.
  Their source sheets are in `portrait-actions-v1`, with the three accepted samples in `portrait-action-samples-v1`.
- The earlier 20-species pose pack (120 Normal/Shiny images) is retained as a
  historical fallback, alongside the 15 egg states and strawberry still in use.

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

The older pose sheets are historical fallbacks. Active animation sets and their
editable source are documented above. Final approval should include actual Watch
scale, small-screen/accessibility checks and the simulator screenshots in the PR.
