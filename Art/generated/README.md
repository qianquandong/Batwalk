# Free companion sprites

`cocoa-sheet-v1.png` and `long-ear-sheet-v1.png` were generated using the built-in
imagegen tool, with the existing Mochi awake sprite as a style reference. The
second pass removed backdrop/halo alpha while preserving the six poses. The PNG
background has alpha zero, even if a viewer shows nonzero RGB under that alpha.

Each 1536x1024 sheet uses three 512x512 columns (sleeping, awake, happy) and two
rows (Normal, Shiny). The Shiny palettes are authored rather than hue rotations.
`generation-prompts.json` records both complete generation prompts and the
transparency edit prompt. Original mascot and concept-board files were preserved.

Run `python3 Art/tools/package_free_sprites.py` (Pillow) to package the sheets
as twelve 256x256 catalog assets. Cells preserve pose alignment and alpha.
The app's related-pose fallback covers drowsy, eating, and playing; dedicated
animations for those actions remain an art task. Artist approval and small-screen
device review are still required before public release.
