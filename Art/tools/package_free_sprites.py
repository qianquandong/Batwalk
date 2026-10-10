#!/usr/bin/env python3
"""Package the generated 3x2 sheets into the existing asset naming contract."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MOODS = ("sleeping", "awake", "happy")

for species in ("cocoa", "long-ear"):
    source = ROOT / "Art/generated" / f"{species}-sheet-v1.png"
    sheet = Image.open(source).convert("RGBA")
    assert sheet.size == (1536, 1024), f"Unexpected grid: {source}"
    for row in range(2):
        for column, mood in enumerate(MOODS):
            name = f"bat_{species}_{mood}" + ("_shiny" if row else "")
            destination = ROOT / "Apps/Shared/Sprites.xcassets" / f"{name}.imageset"
            destination.mkdir(parents=True, exist_ok=True)
            image = sheet.crop((column * 512, row * 512, (column + 1) * 512, (row + 1) * 512))
            alpha = image.getchannel("A")
            assert alpha.getpixel((0, 0)) == 0 and alpha.getbbox(), f"Invalid transparency: {name}"
            # Keep every cell's coordinates so normal/shiny and poses don't jump.
            image.resize((256, 256), Image.Resampling.NEAREST).save(destination / f"{name}.png", optimize=True)
            (destination / "Contents.json").write_text(json.dumps({
                "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}],
                "info": {"author": "xcode", "version": 1}}, indent=2) + "\n", encoding="utf-8")
            print(name)
