#!/usr/bin/env python3
"""Slice Gentle pixel sources into fixed-grid nearest-neighbor renditions."""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Art/gentle-pixel"
CATALOG = ROOT / "Apps/Shared/Sprites.xcassets"
MOODS = ("sleeping", "awake", "happy")
ROSTER = "mochi cocoa long-ear fruit cave sleepy dust pebble strawberry blossom moss sunset snow cloud moonwing golden crystal vampire galaxy eclipse".split()


def write_asset(name, cell):
    alpha = cell.getchannel("A")
    assert alpha.getbbox(), f"Empty sprite: {name}"
    # Some exports contain one alpha unit of rounding noise in a clear margin.
    assert alpha.getpixel((0, 0)) <= 2, f"Opaque backdrop: {name}"
    # These are fixed-canvas renditions, not per-pose bounding-box crops.
    # A 64 px logical canvas keeps all UI sizes on the same coarse pixel grid.
    logical = cell.resize((64, 64), Image.Resampling.NEAREST)
    image = logical.resize((256, 256), Image.Resampling.NEAREST)
    destination = CATALOG / f"{name}.imageset"
    destination.mkdir(parents=True, exist_ok=True)
    image.save(destination / f"{name}.png", optimize=True)
    (destination / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1}}, indent=2) + "\n", encoding="utf-8")


def cell_at(sheet, column, row, columns, rows):
    width, height = sheet.size
    return sheet.crop((round(column * width / columns), round(row * height / rows),
                       round((column + 1) * width / columns), round((row + 1) * height / rows)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    count = 0
    for species in ROSTER:
        path = SOURCE / f"{species}-sheet-v2.png"
        if not path.exists():
            assert not args.require_complete, f"Missing sheet: {species}"
            continue
        sheet = Image.open(path).convert("RGBA")
        assert sheet.size == (1536, 1024), f"Unexpected sheet dimensions: {species}"
        for row in range(2):
            for column, mood in enumerate(MOODS):
                name = f"gentle_bat_{species}_{mood}" + ("_shiny" if row else "")
                write_asset(name, cell_at(sheet, column, row, 3, 2))
                count += 1
    icon_path = SOURCE / "egg-icons-v2.png"
    if icon_path.exists():
        icons = Image.open(icon_path).convert("RGBA")
        names = [f"gentle_egg_{egg}_{state}" for egg in ("starter", "tiny", "forest", "moon", "crystal")
                 for state in ("calm", "cracked", "ready")] + ["gentle_fruit_strawberry"]
        for index, name in enumerate(names):
            write_asset(name, cell_at(icons, index % 4, index // 4, 4, 4))
            count += 1
    else:
        assert not args.require_complete, "Missing egg/icon sheet"
    app_icon_path = SOURCE / "app-icon-v2.png"
    if app_icon_path.exists():
        app_icon = Image.open(app_icon_path).convert("RGB")
        app_icon = app_icon.resize((64, 64), Image.Resampling.NEAREST).resize((1024, 1024), Image.Resampling.NEAREST)
        for platform in ("Watch", "Phone"):
            destination = ROOT / f"Apps/{platform}/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
            app_icon.save(destination, optimize=True)
    else:
        assert not args.require_complete, "Missing application icon"
    print(f"Packaged {count} Gentle pixel assets")


if __name__ == "__main__":
    main()
