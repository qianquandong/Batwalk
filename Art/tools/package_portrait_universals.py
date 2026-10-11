"""Package launch universal poses from approved-portrait imagegen sheets.

Only cropping, shared per-clip translation and uniform nearest-neighbor scaling;
no painting, deformation or alpha removal. Mochi's accepted pilot stays intact.
"""
import argparse
import hashlib
import json
from PIL import Image
from package_portrait_actions import ROOT, ART, CATALOG, digest, rel, source_frames, package

OUT = ART / 'portrait-universals-v1'
PLAN = {
    'idle': ('待机', [2.4, .18, .18, .24], 4),
    'sleep': ('睡觉', [1.4, .4, .4, .6], 3.6),
    'fly': ('飞行', [.2, .2, .2, .2], 0),
    'pet': ('被摸', [.25, .4, .55, .45], 0),
    'eat': ('吃果子', [.4, .45, .55, .6], 0),
}
FLY_REPAIRS = {'cocoa', 'fruit', 'cave', 'vampire', 'galaxy'}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    checking = parser.parse_args().check
    def write(path, data):
        if checking:
            assert path.exists() and path.read_bytes() == data, 'Stale: ' + rel(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    def write_json(path, obj):
        write(path, (json.dumps(obj, ensure_ascii=False, indent=2)+'\n').encode())
    def write_image(path, im):
        if checking:
            saved = Image.open(path).convert('RGBA')
            assert saved.size == im.size and saved.tobytes() == im.tobytes(), 'Stale pixels: '+rel(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            im.save(path, optimize=True)

    originals = json.loads((ART/'portraits-v3/manifest.json').read_text(encoding='utf-8'))['characters']
    roster = [b for b in originals if b['number'] <= 20]
    ledger = {s['id']: s for s in json.loads((OUT/'generation-log.json').read_text(encoding='utf-8'))['entries']}
    manifest = dict(version=1, catalogPixels=128, artSource='portraits-v3', clips=[])
    pilots = json.loads((ART/'pilots-v1/manifest.json').read_text(encoding='utf-8'))['clips']
    expected = set()
    for bat in roster:
        species = bat['id']
        portrait = ART/'portraits-v3'/bat['portrait']
        assert digest(portrait) == bat['sha256'], 'Approved portrait changed: '+species
        for row, (action, (chinese, seconds, rest)) in enumerate(PLAN.items()):
            pilot = species == 'mochi'
            names = [f"{'pilot' if pilot else 'universal'}_bat_{species}_{action}_{i}" for i in range(4)]
            framing = None
            if pilot:
                source = ART/'pilots-v1'/('mochi-fly-v2.png' if action == 'fly' else 'mochi-sheet-v1.png')
                frames = [Image.open(CATALOG/(n+'.imageset')/'sprite.png').convert('RGBA') for n in names]
                accepted = next(c for c in pilots if c['speciesID'] == 'mochi' and c['actionID'] == action)
                for frame, original_hash in zip(frames, accepted['sha256']):
                    logical = frame.resize((64,64), Image.Resampling.NEAREST)
                    assert hashlib.sha256(logical.tobytes()).hexdigest() == original_hash, 'Mochi pilot pixels changed'
                    assert logical.resize((128,128), Image.Resampling.NEAREST).tobytes() == frame.tobytes()
            else:
                spec = ledger[species+'-fly-fix' if action == 'fly' and species in FLY_REPAIRS else species]
                source = OUT/spec['file']
                sheet, layout = source_frames(source, spec['columns'], spec['rows'], row if spec['rows'] == 5 else 0)
                if species == 'dust' and action == 'pet':
                    # Generated pet frame 0 held a berry. Reuse its neutral idle pose.
                    _, idle = source_frames(source, 4, 5, 0)
                    layout[0] = idle[0]
                frames, framing = package(sheet, layout)
            hashes = []
            for name, frame in zip(names, frames):
                dest = CATALOG/(name+'.imageset')
                if not pilot:
                    expected.add(dest.name)
                    write_image(dest/'sprite.png', frame)
                    write_json(dest/'Contents.json', dict(images=[dict(filename='sprite.png', idiom='universal', scale='2x')], info=dict(author='xcode', version=1)))
                hashes.append(digest(dest/'sprite.png'))
            strip = Image.new('RGBA', (512, 128))
            for i, frame in enumerate(frames): strip.paste(frame, (128*i, 0))
            write_image(OUT/'strips'/f'{species}_{action}.png', strip)
            entry = dict(speciesID=species, actionID=action, chinese=chinese, kind='universal', unlockLevel=1,
                         frames=names, seconds=seconds, restSeconds=rest, sha256=hashes,
                         portrait=rel(portrait), portraitSHA256=digest(portrait),
                         source=rel(source), sourceSHA256=digest(source))
            if framing: entry['framing'] = framing
            if species == 'dust' and action == 'pet': entry['frameOverride'] = 'frame 0 reuses same-sheet idle frame 0'
            manifest['clips'].append(entry)
    obsolete = [p.name for p in CATALOG.glob('universal_bat_*.imageset') if p.name not in expected]
    assert not obsolete, 'Obsolete universal assets: '+str(obsolete)
    write_json(OUT/'manifest.json', manifest)
    ids = ', '.join('"'+b['id']+'"' for b in roster if b['id'] != 'mochi')
    cases = '\n'.join(f'        case .{a}: return Plan(seconds: {s}, rest: {r})' for a, (_,s,r) in PLAN.items())
    swift = ('// Generated by Art/tools/package_portrait_universals.py. Do not edit.\n'
             '// 19 approved portrait identities; Mochi retains its accepted pilot.\n'
             'public enum PortraitUniversalFrames {\n'
             f'    public static let speciesIDs = [{ids}]\n'
             '    public struct Plan: Sendable {\n        public let seconds: [Double]\n        public let rest: Double\n    }\n'
             '    public static func plan(for action: UniversalAction) -> Plan {\n        switch action {\n'
             +cases+'\n        }\n    }\n}\n')
    write(ROOT/'Packages/BatwalkCore/Sources/BatwalkCore/PortraitUniversalFrames.swift', swift.encode())
    print(f"{'Verified' if checking else 'Packaged'} 100 launch universal clips / 400 frames (380 new; 20 preserved Mochi frames)")

if __name__ == '__main__': main()
