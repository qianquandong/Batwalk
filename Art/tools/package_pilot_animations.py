"""Package approved art without repainting it: fixed crops and nearest scaling.

Run from anywhere with Pillow. Generates 74 frames + 32 portrait assets and QA.
Never trim/recenter individual animation frames: that destroys motion anchors.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Art/gentle-pixel/pilots-v1"
CATALOG = ROOT / "Apps/Shared/Sprites.xcassets"
SIGNATURES = {"mochi": "cartwheel-landing", "sticky": "moving-day", "walker": "power-walk"}
# Generated poses drift across nominal cell boundaries. Put crop boundaries in
# reviewed empty gutters, but keep original 256px anchors (no per-frame recenter).
ROWS = {"mochi": [0, 268, 512, 753, 1000, 1249, 1536],
        "sticky": [0, 269, 519, 774, 1025, 1276, 1536],
        "walker": [0, 276, 503, 764, 1025, 1267, 1536]}
COLS = {"mochi": [[0, 271, 513, 763, 1024], [0, 265, 511, 771, 1024],
                  [0, 256, 512, 768, 1024], [0, 268, 501, 760, 1024],
                  [0, 267, 516, 760, 1024], [0, 270, 498, 788, 1024]],
        "sticky": [[0, 256, 514, 767, 1024], [0, 256, 512, 768, 1024],
                   [0, 265, 517, 772, 1024], [0, 257, 510, 776, 1024],
                   [0, 256, 512, 768, 1024], [0, 242, 527, 787, 1024]],
        "walker": [[0, 259, 509, 764, 1024], [0, 269, 516, 767, 1024],
                   [0, 265, 521, 759, 1024], [0, 257, 502, 765, 1024],
                   [0, 278, 525, 761, 1024], [0, 270, 518, 765, 1024]]}


def write_asset(name, logical):
    target = CATALOG / f"{name}.imageset"
    target.mkdir(exist_ok=True)
    logical.resize((128, 128), Image.Resampling.NEAREST).save(target / "sprite.png", optimize=True)
    (target / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "sprite.png", "idiom": "universal", "scale": "2x"}],
        "info": {"author": "xcode", "version": 1}
    }, indent=2) + "\n")


def main():
    frames_dir = SOURCE / "frames-64px"
    frames_dir.mkdir(exist_ok=True)
    clips = []
    board = Image.new("RGB", (1000, 1060), "#161824")
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default(size=17)
    for column, (species, signature) in enumerate(SIGNATURES.items()):
        sheet_path = SOURCE / f"{species}-sheet-v1.png"
        sheet = Image.open(sheet_path).convert("RGBA")
        assert sheet.size == (1024, 1536), (species, sheet.size)
        assert sheet.getchannel("A").getextrema()[0] == 0, "Source needs true transparency"
        draw.text((26 + column * 328, 16), species.upper(), fill="#efe5d5", font=font)
        actions = ["idle", "sleep", "fly", "pet", "eat", signature]
        for row, action in enumerate(actions):
            names = []
            hashes = []
            for frame in range(6 if species == "walker" and action == signature else 4):
                source_frame = min(frame, 3)
                top, bottom = ROWS[species][row:row + 2]
                left, right = COLS[species][row][source_frame:source_frame + 2]
                crop = sheet.crop((left, top, right, bottom))
                # 32px safety gutter around every original cell; no alpha editing.
                cell = Image.new("RGBA", (320, 320))
                cell.paste(crop, (32 + left - source_frame * 256, 32 + top - row * 256))
                if species == "mochi" and action == "fly":
                    # Replacement strip separates the original overlapping wings.
                    # Same square crop and scale for all four frames, no recentering.
                    strip = Image.open(SOURCE / "mochi-fly-v2.png").convert("RGBA")
                    width = strip.width // 4
                    crop = strip.crop((frame * width, 0, (frame + 1) * width, width))
                    cell = Image.new("RGBA", (320, 320))
                    cell.paste(crop.resize((256, 256), Image.Resampling.NEAREST), (32, 32))
                if species == "walker" and action == signature and frame >= 4:
                    strip = Image.open(SOURCE / "walker-nectar-v1.png").convert("RGBA")
                    width = strip.width // 2
                    crop = strip.crop(((frame - 4) * width, 0, (frame - 3) * width, width))
                    cell = Image.new("RGBA", (320, 320))
                    cell.paste(crop.resize((256, 256), Image.Resampling.NEAREST), (32, 32))
                logical = cell.resize((64, 64), Image.Resampling.NEAREST)
                alpha = logical.getchannel("A")
                bbox = alpha.point(lambda a: 255 if a > 128 else 0).getbbox()
                assert bbox is not None and min(bbox[:2]) > 0 and max(bbox[2:]) < 64, (species, action, frame, bbox)
                name = f"pilot_bat_{species}_{action}_{frame}"
                logical.save(frames_dir / f"{name}.png", optimize=True)
                write_asset(name, logical)
                names.append(name)
                hashes.append(hashlib.sha256(logical.tobytes()).hexdigest())
                # Actual 64px cells, not a flattering enlargement.
                board.paste(logical, (26 + column * 328 + (frame % 4) * 73,
                                      65 + row * 145 + (120 if frame >= 4 else 0)), logical)
            assert len(set(hashes)) > 1, f"Duplicate-only animation: {species}/{action}"
            clips.append({"speciesID": species, "actionID": action, "frames": names,
                          "logicalPixels": 64, "catalogPixels": 128, "sha256": hashes})
            draw.text((26 + column * 328, 134 + row * 145), action, fill="#acb4c7", font=font)
    portrait_paths = sorted((ROOT / "Art/gentle-pixel/portraits-v3/portraits").glob("*.png"))
    assert len(portrait_paths) == 32
    for path in portrait_paths:
        species = path.stem.split("-", 1)[1]
        portrait = Image.open(path).convert("RGBA").resize((64, 64), Image.Resampling.NEAREST)
        write_asset(f"portrait_bat_{species}", portrait)
    manifest = {"version": 1, "normalClips": 18, "normalFrames": 74, "portraitCount": 32,
                "shiny": "runtime hue rotation of the same identity; dedicated palettes pending",
                "sourceCellPixels": 256, "paddedCellPixels": 320, "rowBounds": ROWS, "columnBounds": COLS,
                "processing": "Crop with fixed anchors; nearest-neighbor resize; original alpha preserved.",
                "clips": clips}
    (SOURCE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    board.save(SOURCE / "review-64px.png")
    print(f"Packaged {len(clips)} clips / 74 frames / 32 portraits. All frames fit their 64px canvas.")


if __name__ == "__main__":
    main()
