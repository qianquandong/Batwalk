"""Build Apps/Shared/Sprites.xcassets from the concept board.

    python3 Art/tools/build_sprites.py

1. Cuts sprites out of Art/concept-board.png (extract_concept_board.py).
2. Maps them onto the app's asset naming contract (Art/README.md).
3. Tints the strawberry egg per egg type until each egg has real art.
Re-run after replacing the board; real artist sprites should replace these files.
"""
import colorsys, json, os, shutil, subprocess, sys, tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BOARD = os.path.join(ROOT, 'Art', 'concept-board.png')
CATALOG = os.path.join(ROOT, 'Apps', 'Shared', 'Sprites.xcassets')

tmp = tempfile.mkdtemp()
subprocess.run([sys.executable, '-I', os.path.join(ROOT, 'Art', 'tools', 'extract_concept_board.py'), BOARD, tmp],
               check=True, stdout=subprocess.DEVNULL)

assets = {}  # asset name -> PIL image
for f in os.listdir(tmp):
    if f.startswith('bat_'):
        assets[f[:-4]] = Image.open(os.path.join(tmp, f))
# Large portraits (~200 px) are much sharper on the Watch than the 50 px row
# sprites, so they become the hero poses: awake (night home) and happy (reveal, pet).
ptmp = tempfile.mkdtemp()
subprocess.run([sys.executable, '-I', os.path.join(ROOT, 'Art', 'tools', 'extract_portraits.py'), BOARD, ptmp],
               check=True, stdout=subprocess.DEVNULL)
for f in os.listdir(ptmp):
    sp = f[:-4]
    portrait = Image.open(os.path.join(ptmp, f))
    assets[f'bat_{sp}_awake'] = portrait
    assets[f'bat_{sp}_happy'] = portrait
shutil.rmtree(ptmp)
assets['bat_mochi_drowsy'] = Image.open(os.path.join(tmp, 'expr_mochi_0.png'))
assets['bat_strawberry_drowsy'] = Image.open(os.path.join(tmp, 'expr_strawberry_1.png'))
assets['bg_home'] = Image.open(os.path.join(tmp, 'bg_home.png'))

egg_frames = {
    'calm': 'egg_calm', 'shaking': 'egg_shaking', 'cracked': 'egg_cracked',
    'rattling': 'egg_cracked', 'ready': 'egg_cracked',
}
# Hue shift (degrees) applied to the pink shell; green leaves are left alone.
egg_tints = {'starter': 50, 'tiny': -65, 'forest': 0, 'moon': -110, 'crystal': -160}

def tint(im, degrees, sat=1.0):
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.17 < h < 0.45 and s > 0.25:  # leaves / grass
                continue
            h = (h + degrees / 360) % 1
            r2, g2, b2 = colorsys.hsv_to_rgb(h, min(1, s * sat), v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im

for egg, deg in egg_tints.items():
    for state, frame in egg_frames.items():
        base = Image.open(os.path.join(tmp, frame + '.png'))
        assets[f'egg_{egg}_{state}'] = tint(base, deg, 0.8 if egg == 'starter' else 1.0) if deg else base

# Fruit icon: a 16x16 pixel strawberry in the board's palette (the board has no
# clean, isolated fruit to cut out). Interim until the artist's fruit set lands.
FRUIT = [
    "......oo.oo.....",
    ".....oGGoGGo....",
    "....oGgGGGgGo...",
    "...ooGGooGGoo...",
    "..oRRoooooooRo..",
    ".oRRRRRRRRRRRRo.",
    ".oRrRRRyRRRrRRo.",
    "oRRRRyRRRRRRyRRo",
    "oRRrRRRRrRRRRRRo",
    "oRRRRRyRRRRyRrRo",
    ".oRyRRRRRrRRRRo.",
    ".oRRRrRRRRRyRRo.",
    "..oRRRRyRRRRRo..",
    "...oRRRRRRrRo...",
    "....ooRRRRoo....",
    "......oooo......",
]
PAL = {'o': (58, 20, 34, 255), 'G': (96, 170, 72, 255), 'g': (60, 120, 52, 255),
       'R': (232, 72, 92, 255), 'r': (196, 48, 72, 255), 'y': (255, 226, 140, 255)}
fruit = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
for y, row in enumerate(FRUIT):
    for x, c in enumerate(row):
        if c in PAL:
            fruit.putpixel((x, y), PAL[c])
assets['fruit_strawberry'] = fruit

shutil.rmtree(CATALOG, ignore_errors=True)
os.makedirs(CATALOG)
with open(os.path.join(CATALOG, 'Contents.json'), 'w') as fh:
    json.dump({'info': {'author': 'xcode', 'version': 1}}, fh, indent=2)
for name, im in sorted(assets.items()):
    d = os.path.join(CATALOG, name + '.imageset')
    os.makedirs(d)
    im.save(os.path.join(d, name + '.png'))
    with open(os.path.join(d, 'Contents.json'), 'w') as fh:
        json.dump({'images': [{'filename': name + '.png', 'idiom': 'universal'}],
                   'info': {'author': 'xcode', 'version': 1}}, fh, indent=2)
# App icon: Mochi's portrait from the board, square, 1024 px, no transparency.
board = Image.open(BOARD).convert('RGB')
icon = board.crop((19, 368, 219, 568)).resize((1000, 1000), Image.NEAREST)
canvas = Image.new('RGB', (1024, 1024), icon.getpixel((4, 4)))
canvas.paste(icon, (12, 12))
for app in ('Watch', 'Phone'):
    canvas.save(os.path.join(ROOT, 'Apps', app, 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png'))
canvas.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, 'Art', 'icon-placeholder.png'))

shutil.rmtree(tmp)
print(f'{len(assets)} image sets → {os.path.relpath(CATALOG, ROOT)}')
