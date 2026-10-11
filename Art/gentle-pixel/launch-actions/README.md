# Launch portrait actions

**20 bats / 64 unique actions / 256 frames**, following [BAT_ACTIONS.md](../../../docs/BAT_ACTIONS.md).
The approved [portraits-v3](../portraits-v3/roster.png) define each character.
The three accepted samples retain their source pixels and anchors. Mochi keeps its matching original clips.

- [Interactive review](index.html): original portrait beside the exact runtime PNGs, action selection, 96 px preview, light/dark backgrounds, pause and frame stepping.
- [Manifest](manifest.json): source and portrait SHA256, crop rectangles, anchors, shared scale, frame names, timings and PNG hashes.
- [Source sheets and exact prompts](../portrait-actions-v1/): original generated sheets plus targeted corrections.
- [Accepted samples](../portrait-action-samples-v1/): Long Ear / Fruit / Moonwing.
- [Runtime rules](../../../docs/LAUNCH_PERSONALITIES.md): friendship gates, triggers, low-frequency ambient playback, accessibility and preview UI.

```sh
python3 -m pip install Pillow==11.3.0
python3 Art/tools/package_portrait_actions.py
python3 Art/tools/package_portrait_actions.py --check
node --test Art/tools/gentle_pixel/unique_actions.test.js
```

The packager only crops, translates and uniformly scales; it does not draw, recolor,
remove backgrounds, deform poses or replace the original portraits. Each clip shares
one scale. Transparent gutters are detected near the grid boundaries to avoid cutting
ears or wings; source positions and alpha are preserved. PNGs are 128 × 128 at 2×.

The previous code-drawn unique pack was discarded. Historical generated universal
assets are no longer selected by the runtime. Non-pilot universal actions use approved
portrait stills until matching poses are available. This preview is not a Watch simulator.

Generation and source-pixel checks do not replace human review at real device size.
No TestFlight upload, release or merge is part of this work.
