# Approved portrait-derived action sheets

These sheets extend the unchanged portraits-v3 identities to the remaining launch
actions after the three accepted samples. Source files are preserved as generated.

- `generation-log.json`: exact used prompts, source references, sheet layout and tool output filenames.
- `prompts.json`: action plan from the original catalog.
- `repair-prompts.json` and `additional-repair-prompts.json`: targeted corrections.
- `*-fix-sheet-v1.png` supersede the corresponding rows in initial sheets. The packager's
  `REPAIRS` mapping explicitly chooses the corrected version; rejected rows never ship.
- Full shipped provenance, crop rectangles, anchors and SHA256 hashes are in
  [launch-actions/manifest.json](../launch-actions/manifest.json).

All nineteen non-Mochi characters were referenced individually. The three accepted
samples remain in the sibling sample folder. Mochi's existing matching assets remain
in the pilot and launch-action folders. No original portrait was overwritten.
