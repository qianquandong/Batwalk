"""Read-only pixel inspection; writes framing metadata, never rewrites artwork."""
import hashlib
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
specs = json.loads((HERE / 'prompts.json').read_text(encoding='utf-8'))['characters']
out = []
for spec in specs:
    key = spec['id']
    source = HERE.parent / 'portraits-v3' / 'portraits' / spec['ref']
    sheet = HERE / f"{key}-{spec['action']}-v1.png"
    split = 636 if key == 'moonwing' else 627
    rects = [[0, 0, 627, split], [627, 0, 627, split], [0, split, 627, 1254-split], [627, split, 627, 1254-split]]

    def inspect(path, rect):
        im = Image.open(path).convert('RGBA')
        x, y, w, h = rect
        pixels = im.load()
        visible = [(i, j) for j in range(h) for i in range(w) if pixels[x+i, y+j][3] > 128]
        bbox = [min(p[0] for p in visible), min(p[1] for p in visible), max(p[0] for p in visible)+1, max(p[1] for p in visible)+1]
        # Use original colored feet for translation only. No shape warping or independent axis scaling.
        def foot(i, j):
            r, g, b, a = pixels[x+i, y+j]
            if j < h * 0.75 or a < 129:
                return False
            if key == 'long-ear':
                return r > g * 1.2 and b > g * 1.1 and r > 50
            if key == 'fruit':
                return r > g * 1.2 and g > b * 1.15
            return b > r * 1.3
        feet = [(i,j) for i,j in visible if foot(i,j)]
        bottom = max(j for _,j in feet)
        band = [(i,j) for i,j in feet if j >= bottom - max(8, round(h*.025))]
        anchor = [(min(i for i,_ in band)+max(i for i,_ in band))/2, bottom+1]
        return {'rect': rect, 'bbox': bbox, 'anchor': anchor}

    sw, sh = Image.open(source).size
    frames = [inspect(sheet, rect) for rect in rects]
    original = inspect(source, [0,0,sw,sh])
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    out.append({'id':key, 'name':spec['name'], 'action':spec['action'], 'title':spec['title'],
                'portrait':'../portraits-v3/portraits/'+spec['ref'], 'sheet':sheet.name,
                'portraitSHA256':digest(source), 'sheetSHA256':digest(sheet),
                'original':original, 'frames':frames,
                'frameDurationsMs':[1000,420,700,650], 'status':'awaiting-user-review'})
result = {'status':'Three concept animation samples only. Not approved or integrated into the app.',
          'framing':'Unmodified original PNGs; renderer clips on transparent gaps and translates frames by foot anchors. Uniform per-character scale only.',
          'characters':out}
(HERE / 'manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps([{'id':x['id'], 'anchors':[f['anchor'] for f in x['frames']]} for x in out]))
