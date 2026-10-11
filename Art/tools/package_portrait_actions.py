"""Package approved-portrait action sheets without repainting or deforming art.

One common scale/translation per clip preserves movement and relative pose size.
Approved sample anchors are kept. --check compares decoded pixels (portable PNG
compression), source hashes, manifest and Swift timings; it writes nothing.
"""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "Art/gentle-pixel"
OUT = ART / "launch-actions"
SOURCE = ART / "portrait-actions-v1"
SAMPLES = ART / "portrait-action-samples-v1"
CATALOG = ROOT / "Apps/Shared/Sprites.xcassets"
LEVELS = dict(hatchReveal=1, idleQuirk=2, reaction=3, signature=4, secret=5)
REPAIRS = {
    "cave/find-you-call": "cave-fix",
    "fruit/squabble-squeaks": "fruit-fix",
    "vampire/gorilla-gallop": "vampire-fix",
    "galaxy/star-map-hatch": "galaxy-fix",
    "eclipse/midday-dusk": "eclipse-fix",
}
for species, actions in {
    "dust": ["flap-practice", "drop-start", "almost-landing"],
    "cloud": ["radar-bloom", "gust-surf", "sky-high-snack"],
}.items():
    REPAIRS.update({species + "/" + a: species + "-fix" for a in actions})

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def rel(path):
    return path.relative_to(ROOT).as_posix()

def bounds(image):
    return image.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()

def cuts(image, count, vertical):
    """Find transparent separators near the nominal grid, never cut a subject."""
    alpha = image.getchannel("A").point(lambda a: 255 if a > 16 else 0)
    size = image.width if vertical else image.height
    values = [0]
    for n in range(1, count):
        nominal = round(size * n / count)
        radius = round(size / count * .14)
        candidates = []
        for pos in range(nominal-radius, nominal+radius+1):
            box = (pos, 0, pos+1, image.height) if vertical else (0, pos, image.width, pos+1)
            pixels = alpha.crop(box).histogram()[255]
            candidates.append((pixels, abs(pos-nominal), pos))
        pixels, _, pos = min(candidates)
        if pixels:
            raise ValueError(f"No transparent separator at {n}/{count}: {pixels} pixels")
        values.append(pos)
    return values + [size]

def source_frames(path, columns, rows, row):
    image = Image.open(path).convert("RGBA")
    ys = cuts(image, rows, False)
    locations = [(x, row) for x in range(columns)] if columns == 4 else [(0,0),(1,0),(0,1),(1,1)]
    result = []
    for x,y in locations:
        row_image = image.crop((0, ys[y], image.width, ys[y+1]))
        try:
            xs = cuts(row_image, columns, True)
        except ValueError as error:
            raise ValueError(f"{path.name} row {y}: {error}") from error
        rect = [xs[x], ys[y], xs[x+1]-xs[x], ys[y+1]-ys[y]]
        # Position relative to the nominal cell, independent of shifted cut lines.
        anchor = [(x+.5)*image.width/columns-xs[x], (y+.5)*image.height/rows-ys[y]]
        result.append(dict(rect=rect, anchor=anchor))
    return image, result

def package(image, frames):
    extents = []
    for f in frames:
        x,y,w,h = f["rect"]
        box = bounds(image.crop((x,y,x+w,y+h)))
        if not box: raise ValueError("Empty source cell")
        f["bbox"] = list(box)
        ax,ay = f["anchor"]
        extents.append((box[0]-ax,box[1]-ay,box[2]-ax,box[3]-ay))
    left, top = min(b[0] for b in extents), min(b[1] for b in extents)
    right, bottom = max(b[2] for b in extents), max(b[3] for b in extents)
    scale = min(112/(right-left),112/(bottom-top))
    center = ((left+right)/2,(top+bottom)/2)
    output = []
    for f in frames:
        x,y,w,h = f["rect"]; ax,ay = f["anchor"]
        cell = image.crop((x,y,x+w,y+h))
        cell = cell.resize((max(1,round(w*scale)),max(1,round(h*scale))),Image.Resampling.NEAREST)
        target = Image.new("RGBA",(128,128))
        # Paste without mask: preserves original alpha rather than squaring it.
        target.paste(cell,(round(64-(ax+center[0])*scale),round(64-(ay+center[1])*scale)))
        box = bounds(target)
        assert box and min(box[:2]) >= 5 and max(box[2:]) <= 123, box
        output.append(target)
    return output, dict(scale=scale, center=center, frames=frames)

def main():
    check = argparse.ArgumentParser()
    check.add_argument("--check", action="store_true")
    checking = check.parse_args().check
    def write(path, data):
        if checking:
            if not path.exists() or path.read_bytes() != data:
                raise ValueError("Stale: " + rel(path))
        else:
            path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)
    def write_json(path, obj):
        write(path,(json.dumps(obj,ensure_ascii=False,indent=2)+"\n").encode())
    def write_image(path, im):
        if checking:
            existing = Image.open(path).convert("RGBA")
            assert existing.size == im.size and existing.tobytes() == im.tobytes(), "Stale pixels: "+rel(path)
        else:
            path.parent.mkdir(parents=True,exist_ok=True); im.save(path,optimize=True)
    design = (ROOT/"Packages/BatwalkCore/Sources/BatwalkCore/BatActions.swift").read_text(encoding="utf-8").split("// MARK: Oddball")[0]
    cn = dict(re.findall(r"`([^`]+)` \| ([^|]+) \|",(ROOT/"docs/BAT_ACTIONS.md").read_text(encoding="utf-8")))
    actions = re.findall(r'act\("([^"]+)", "([^"]+)", "([^"]+)", \.(\w+), \.(\w+),\s*"([^"]+)"',design)
    assert len(actions)==64 and len(set(a[0] for a in actions))==20
    specs = {s["id"]:s for s in json.loads((SOURCE/"prompts.json").read_text(encoding="utf-8"))["characters"]}
    sample_list = json.loads((SAMPLES/"manifest.json").read_text(encoding="utf-8"))["characters"]
    samples = {s["id"]+"/"+s["action"]:s for s in sample_list}
    ledger = {s["id"]:s for s in json.loads((SOURCE/"generation-log.json").read_text(encoding="utf-8"))["entries"]}
    manifest = dict(version=2,catalogPixels=128,artSource="portraits-v3",clips=[])
    swift, expected = [], set()
    for species,action,name,tier,trigger,summary in actions:
        key=species+"/"+action
        number = list(dict.fromkeys(a[0] for a in actions)).index(species)+1
        portrait=ART/"portraits-v3/portraits"/f"{number:02}-{species}.png"
        old = action=="cartwheel-landing"
        prefix="pilot_bat_" if old else "unique_bat_"
        names=[f"{prefix}{species}_{action}_{f}" for f in range(4)]
        seconds=[.65,.4,.65,.7]
        source = None; framing = None
        if species=="mochi":
            seconds=[.25,.24,.24,1.2] if old else [.4,.5,.5,.4] if action=="thumb-ear-wash" else [.3,.45,.6,.4]
            source=ART/("pilots-v1/mochi-sheet-v1.png" if old else "launch-actions/mochi-extras-v1.png")
            # Preserve already packaged approved pilot/extra pixels exactly.
            frames=[Image.open(CATALOG/(n+".imageset")/"sprite.png").convert("RGBA") for n in names]
        else:
            if key in samples:
                s=samples[key]; source=SAMPLES/s["sheet"]
                assert digest(portrait)==s["portraitSHA256"] and digest(source)==s["sheetSHA256"]
                sheet=Image.open(source).convert("RGBA"); framing=s["frames"]
                frames,framing=package(sheet,framing)
                seconds=[t/1000 for t in s["frameDurationsMs"]]
            else:
                id=REPAIRS.get(key,species); spec=ledger[id]
                source=SOURCE/spec["file"]
                row=spec["actions"].index(action) if spec["columns"]==4 else 0
                sheet,layout=source_frames(source,spec["columns"],spec["rows"],row)
                frames,framing=package(sheet,layout)
        hashes=[]
        for n,im in zip(names,frames):
            dest=CATALOG/(n+".imageset"); expected.add(dest.name)
            if species!="mochi":
                write_image(dest/"sprite.png",im)
                write_json(dest/"Contents.json",dict(images=[dict(filename="sprite.png",idiom="universal",scale="2x")],info=dict(author="xcode",version=1)))
            hashes.append(digest(dest/"sprite.png"))
        strip=Image.new("RGBA",(512,128))
        for f,im in enumerate(frames): strip.paste(im,(128*f,0))
        write_image(OUT/"strips"/f"{species}_{action}.png",strip)
        if not old: swift.append(f'        "{key}": [{", ".join(str(t) for t in seconds)}],')
        entry=dict(speciesID=species,actionID=action,name=name,chinese=cn.get(action,name).strip(),tier=tier,trigger=trigger,summary=summary,unlockLevel=LEVELS[tier],frames=names,seconds=seconds,sha256=hashes,portrait=rel(portrait),portraitSHA256=digest(portrait))
        if source and source.exists(): entry.update(source=rel(source),sourceSHA256=digest(source))
        if framing: entry["framing"]=framing
        manifest["clips"].append(entry)
    # Only obsolete unique frames in this exact asset catalog are removable.
    obsolete=[p for p in CATALOG.glob("unique_bat_*.imageset") if p.name not in expected]
    if obsolete:
        raise ValueError("Obsolete unique asset directories (remove explicitly): "+", ".join(p.name for p in obsolete[:8]))
    write_json(OUT/"manifest.json",manifest)
    write(ROOT/"Packages/BatwalkCore/Sources/BatwalkCore/LaunchActionFrames.swift",
          ("// Generated by Art/tools/package_portrait_actions.py. Do not edit.\n"
           "// Approved portraits; 63 clips plus the original Mochi cartwheel.\n"
           "public enum LaunchActionFrames {\n    public static let seconds: [String: [Double]] = [\n"+
           "\n".join(swift)+"\n    ]\n}\n").encode())
    print(f"{'Verified' if checking else 'Packaged'} 20 portrait identities / 64 actions / 256 frames")

if __name__=="__main__":
    main()
