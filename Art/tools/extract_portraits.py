"""Cut the four large portraits out of the board. usage: portraits.py board.png outdir [T]"""
import sys, os
from collections import deque
from PIL import Image
import numpy as np
src, out = sys.argv[1], sys.argv[2]
T = int(sys.argv[3]) if len(sys.argv) > 3 else 60
os.makedirs(out, exist_ok=True)
A = np.asarray(Image.open(src).convert('RGB')).astype(int)
boxes = {
    'mochi': (18, 372, 226, 572),
    'strawberry': (396, 372, 604, 572),
    'moonwing': (786, 366, 1041, 584),
    'galaxy': (1158, 366, 1433, 594),
}
for name, (x0, y0, x1, y1) in boxes.items():
    R = A[y0:y1, x0:x1]
    h, w, _ = R.shape
    dark = R.max(axis=2) < T
    bg = np.zeros((h, w), bool)
    q = deque((y, x) for y in range(h) for x in (0, w - 1)) 
    q.extend((y, x) for x in range(w) for y in (0, h - 1))
    for y, x in list(q): bg[y, x] = dark[y, x]
    q = deque(p for p in q if bg[p])
    while q:
        y, x = q.popleft()
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and dark[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True; q.append((ny, nx))
    # restore a 1px dark outline around the figure so it reads on any background
    fg = ~bg
    grown = fg.copy()
    grown[1:, :] |= fg[:-1, :]; grown[:-1, :] |= fg[1:, :]; grown[:, 1:] |= fg[:, :-1]; grown[:, :-1] |= fg[:, 1:]
    alpha = np.where(fg, 255, np.where(grown, 255, 0))
    rgb = np.where(fg[..., None], R, np.where(grown[..., None], np.minimum(R, 30), R))
    im = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), 'RGBA')
    im = im.crop(im.getbbox())
    s = max(im.size) + 8
    canvas = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    canvas.paste(im, ((s - im.width) // 2, (s - im.height) // 2), im)
    canvas.save(f'{out}/{name}.png')
    print(name, canvas.size)
