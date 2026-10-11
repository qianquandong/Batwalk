"""Package imagegen's new Mochi sheet with fixed anchors and preserved alpha.

This is the same crop/nearest-neighbour asset pipeline as the original pilots.
No repainting, per-frame stretching, background removal or recentering.
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Art/gentle-pixel/launch-actions/mochi-extras-v1.png'
CATALOG = ROOT / 'Apps/Shared/Sprites.xcassets'


def main():
    sheet = Image.open(SOURCE).convert('RGBA')
    w, h = sheet.width / 4, sheet.height / 2
    assert abs(w - h) <= 2, 'Expected square grid cells'
    assert sheet.getchannel('A').getextrema()[0] == 0
    for row, action in enumerate(['thumb-ear-wash', 'wing-eye-mask']):
        for f in range(4):
            crop = sheet.crop(tuple(round(v) for v in (f*w, row*h, (f+1)*w, (row+1)*h)))
            cell = Image.new('RGBA', (320, 320))
            cell.paste(crop.resize((256, 256), Image.Resampling.NEAREST), (32, 32))
            logical = cell.resize((64, 64), Image.Resampling.NEAREST)
            bbox = logical.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
            assert bbox and min(bbox[:2]) > 0 and max(bbox[2:]) < 64, bbox
            target = CATALOG / f'unique_bat_mochi_{action}_{f}.imageset'
            target.mkdir(exist_ok=True)
            logical.resize((128,128), Image.Resampling.NEAREST).save(target / 'sprite.png', optimize=True)
            (target / 'Contents.json').write_text(json.dumps({
                'images': [{'filename':'sprite.png', 'idiom':'universal', 'scale':'2x'}],
                'info': {'author':'xcode', 'version':1}}, indent=2) + '\n')
    print('Mochi: two new gestures / eight frames, existing cartwheel preserved.')


if __name__ == '__main__':
    main()
