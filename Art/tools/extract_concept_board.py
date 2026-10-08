"""Cut sprites out of the Batwalk concept board.
usage: extract.py board.png outdir"""
import sys, os
from collections import deque
from PIL import Image
import numpy as np

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
img = Image.open(src).convert('RGB')
A = np.asarray(img).astype(int)
H, W, _ = A.shape

def segments(y0, y1, x0, x1, bgthr=60, mingap=4, minw=18):
    region = A[y0:y1, x0:x1]
    bg = np.median(np.concatenate([region[0], region[-1]]), axis=0)
    d = np.abs(region - bg).sum(axis=2)
    cols = (d > bgthr).sum(axis=0) > 0
    segs, start, gap = [], None, 0
    for x, on in enumerate(cols):
        if on:
            if start is None: start = x
            gap = 0; end = x
        elif start is not None:
            gap += 1
            if gap > mingap:
                if end - start + 1 >= minw: segs.append((x0 + start, x0 + end + 1))
                start = None
    if start is not None and end - start + 1 >= minw: segs.append((x0 + start, x0 + end + 1))
    return segs

def cutout(x0, y0, x1, y1, tol=26, pad=3, keep_main=True):
    x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)
    region = A[y0:y1, x0:x1]
    h, w, _ = region.shape
    border = np.concatenate([region[0], region[-1], region[:, 0], region[:, -1]])
    bg = np.median(border, axis=0)
    near = np.abs(region - bg).sum(axis=2) <= tol
    mask_bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not mask_bg[y, x]: mask_bg[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not mask_bg[y, x]: mask_bg[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not mask_bg[ny, nx]:
                mask_bg[ny, nx] = True; q.append((ny, nx))
    fg = ~mask_bg
    if keep_main:
        # drop foreground islands touching the left/right edge that aren't the main one
        lab = np.zeros((h, w), int); comps = []
        for sy in range(h):
            for sx in range(w):
                if fg[sy, sx] and not lab[sy, sx]:
                    cid = len(comps) + 1; pts = []; dq = deque([(sy, sx)]); lab[sy, sx] = cid
                    while dq:
                        y, x = dq.popleft(); pts.append((y, x))
                        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
                            ny, nx = y + dy, x + dx
                            if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not lab[ny, nx]:
                                lab[ny, nx] = cid; dq.append((ny, nx))
                    comps.append(pts)
        if comps:
            main = max(range(len(comps)), key=lambda i: len(comps[i]))
            for i, pts in enumerate(comps):
                xs = [p[1] for p in pts]
                ys = [p[0] for p in pts]
                bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
                thin_line = min(bw, bh) <= 3 and max(bw, bh) >= 8
                if i != main and (min(xs) <= 1 or max(xs) >= w - 2 or len(pts) < 4 or thin_line):
                    for y, x in pts: fg[y, x] = False
    rgba = np.dstack([region, np.where(fg, 255, 0)]).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im

def square(im, size=None):
    s = size or max(im.size) + 4
    canvas = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    canvas.paste(im, ((s - im.width) // 2, s - im.height - 2), im)
    return canvas

species = ['mochi', 'strawberry', 'moonwing', 'galaxy']
panels = [(5, 382), (390, 766), (774, 1150), (1158, 1531)]
row_moods = ['awake', 'sleeping', 'playing', 'happy', 'eating']   # Idle, Sleep, Fly, Pet, Eat
report = []
def label_windows(px0, px1):
    words = segments(664, 684, px0, px1, mingap=5, minw=6)
    centers = [(a + b) / 2 for a, b in words][:5]
    edges = [px0] + [int((centers[i] + centers[i + 1]) / 2) for i in range(len(centers) - 1)] + [px1]
    return list(zip(edges[:-1], edges[1:]))

for sp, (px0, px1) in zip(species, panels):
    segs = label_windows(px0, px1)
    report.append(f'{sp} row: {segs}')
    segs = [(max(a, px0 + 6), min(b, px1 - 6)) for a, b in segs]
    for mood, (sx0, sx1) in zip(row_moods, segs):
        sprite = square(cutout(sx0, 600, sx1, 662, pad=0), 80)
        sprite.save(f'{out}/bat_{sp}_{mood}.png')
    esegs = [s for s in segments(700, 760, px0, px1, mingap=8) if s[0] > px0 + 110]  # skip "Expressions" label
    report.append(f'{sp} expr: {esegs}')
    for i, (sx0, sx1) in enumerate(esegs):
        square(cutout(sx0, 700, sx1, 760), 72).save(f'{out}/expr_{sp}_{i}.png')

# Egg hatching sequence (strawberry egg)
egg_panels = [(18, 124), (130, 236), (241, 347), (353, 459), (465, 571)]
report.append(f'egg panels: {egg_panels}')
names = ['calm', 'shaking', 'cracked', 'reveal', 'hatched']
for name, (ex0, ex1) in zip(names, egg_panels):
    # inside each framed panel, trim the frame then cut the egg
    inner = cutout(ex0 + 5, 840, ex1 - 5, 951, tol=34, pad=0)
    square(inner, 112).save(f'{out}/egg_{name}.png')
img.crop((476, 20, 732, 234)).save(f'{out}/bg_home.png')
print('\n'.join(report))
