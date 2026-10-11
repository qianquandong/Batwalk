# Launch universal poses from approved portraits

**20 bats × 5 actions = 100 clips / 400 frames.** The accepted Mochi pilot provides
20 unchanged frames. The other 19 bats receive 95 clips / 380 new frames for
idle, sleep, fly, pet and eat. Both iPhone and Watch use the same asset catalog.

- [Interactive review](../launch-actions/index.html): originals beside runtime frames,
  one selector to compare the same action across all 20, pause/step, 96 px and dark background.
- `prompts.json`: initial plan. `generation-log.json`: exact final prompts, original
  imagegen output filenames, references, layout and targeted flight corrections.
- `*-universal-v1.png`: original transparent 4-column × 5-row generated sheets.
- `*-fly-fix-v1.png`: 2 × 2 reviewed flight sheets for Cocoa, Fruit, Cave,
  Vampire and Galaxy. These replace only flight rows; rejected rows remain source history.
- `manifest.json`: 100 runtime clips, source/portrait hashes, crop rectangles, anchors,
  one uniform scale per clip, frame names/hashes, duration and ambient rest.
- `strips/`: four packaged frames per clip, exactly as used in the apps.

The approved `portraits-v3` are unchanged. The packager only crops, translates and
uniformly rescales with nearest-neighbor sampling; it never paints, deforms, removes
backgrounds or adjusts alpha. Clear grid gutters are required. The same transform is
used for all four frames of a clip, with safety padding on 128 × 128 / 2× canvases.
Source grid resolution differs between sheets; one clip's scale is never applied to
another source. Mochi's decoded logical pixels are checked against the accepted pilot
manifest (whose hashes cover 64 px raw RGBA, not encoded PNG bytes).

Review corrections: Cocoa unfolds its existing cloak, Fruit carries its pear between
its feet while its two wings flap, Vampire holds the two fruit halves at the two wing
thumbs, Cave flutters its cloak tips without growing rear wings, and Galaxy's wider
flight sheet keeps neighboring wings separate. Dust pet frame 0 reuses the same sheet's
neutral idle frame 0 to avoid an accidental berry; the source rectangle is recorded.

Universals are available at Lv.1. Idle rests 4 s between cycles; sleep rests 3.6 s.
The player retains scene/visibility/Always-On/Reduce Motion gates. This is presentation
only, with no save, economy, capability, signing, TestFlight or release changes.

```sh
python3 -m pip install Pillow==11.3.0
python3 Art/tools/package_portrait_universals.py
python3 Art/tools/package_portrait_universals.py --check
node --test Art/tools/gentle_pixel/universal_actions.test.js
```

Generated art has been reviewed as sheets and in the frame gallery. Actual Watch
playback, energy and final pixel cleanup still need device review before release.
