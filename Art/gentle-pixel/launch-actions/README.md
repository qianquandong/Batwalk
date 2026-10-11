# Gentle pixel · Launch personalities

**20 bats / 64 unique actions / 500 frames**, following the existing
[`BAT_ACTIONS.md`](../../../docs/BAT_ACTIONS.md). 496 frames are new; Mochi's
four-frame cartwheel reuses the original pilot without modification.

- [Interactive review](index.html): same PNGs and timing as the application,
  Watch/iPhone sizes, action filters, pause and single-frame stepping.
- [Manifest](manifest.json): action IDs, names, tiers, triggers, durations, frame
  names and PNG hashes. Generated from the original design and choreography.
- [Runtime / QA](../../../docs/LAUNCH_PERSONALITIES.md).
- [61 editable pixel scenes](../../tools/gentle_pixel/unique_actions.js): extend
  the current engine's palettes, body parts and markings with individual gestures.
- [Mochi source](mochi-extras-v1.png): built-in `image_gen`, preserving its original
  pilot identity. [Prompt and provenance](prompts.json). Fixed cell crops and nearest
  scaling preserve alpha; the original source and pilot are kept intact.

Rebuild from the repository root:

```sh
python3 Art/tools/package_mochi_extras.py  # Pillow; only for the two Mochi gestures
node Art/tools/gentle_pixel/export_unique_actions.js
node Art/tools/gentle_pixel/export_unique_actions.js --check
node --test Art/tools/gentle_pixel/unique_actions.test.js
```

Open `index.html` locally, or serve the repository with
`python3 -m http.server 8767 --bind 127.0.0.1` and visit
`http://127.0.0.1:8767/Art/gentle-pixel/launch-actions/index.html`.
No publishing or external services are required for the review.

The exporter writes `unique_bat_<species>_<action>_<frame>` assets plus the Swift
frame plan. It never overwrites universal or pilot frames. Generated art uses
64×64 logical canvases / 128×128 catalog PNGs with nearest-neighbour sampling.
The existing Shiny hue rotation is retained. Physical Watch testing remains pending.
