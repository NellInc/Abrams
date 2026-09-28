#!/usr/bin/env python3
"""Bind three static illustrations only to complete, fingerprinted PC plates."""
import hashlib
import json
from pathlib import Path
from PIL import Image
from tools.inspect_scenarios import decode_resource
from tools.extract_pc_ui import screen_pixels
from tools.build_pc_graphics_catalog import PALETTE as SIM_PALETTE
from tools.build_pc_intro_catalog import PALETTE as START_PALETTE

ROOT = Path(__file__).resolve().parents[1]
OUT = 'local-art/pc-splash-aftermath-v1'
ART = {'publisher': 'local-art/pc-splash-aftermath-v1/publisher-v1.png',
       'scene1': 'local-art/genesis/remastered/aftermath-v1/scene1-v1.png',
       'scene2': 'local-art/genesis/remastered/aftermath-v1/scene2-v1.png'}


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def build(root=ROOT):
    pins = {r['name']: r['sha256'] for r in json.loads((root/'tools/package/game-inputs.json').read_text())['files']}
    genesis = json.loads((root/'local-art/genesis/source/aftermath-v1/manifest.json').read_text())
    capture_path = root/'artifacts/pc-intro-trace-01/report.json'
    capture = json.loads(capture_path.read_text())
    if not capture['checks'].get('all_records_identical'): raise ValueError('publisher needs compared original trace')
    out = root/OUT; (out/'source').mkdir(parents=True, exist_ok=True)
    entries = []
    for key, source, program, palette in [('publisher','US','START',START_PALETTE), ('scene1','SCENE1.BIN','SIM',SIM_PALETTE), ('scene2','SCENE2.BIN','SIM',SIM_PALETTE)]:
        if sha(root/'GAME'/source) != pins[source]: raise ValueError('changed original '+source)
        image = Image.new('RGB',(320,200))
        image.putdata([palette[n] for n in screen_pixels(decode_resource((root/'GAME'/source).read_bytes()))])
        expected_path = out/'source'/(source.lower().replace('.','-')+'-original.png'); image.save(expected_path)
        rgb_sha = hashlib.sha256(image.tobytes()).hexdigest()
        art_path = root/ART[key]
        with Image.open(art_path) as art: size = list(art.size)
        entry = {'name':key, 'program':program, 'source':source, 'source_sha256':pins[source],
                 'rgb_sha256':rgb_sha, 'expected_path':str(expected_path.relative_to(root)),
                 'asset':{'path':ART[key], 'sha256':sha(art_path), 'size':size},
                 'rect':[0,0,320,200], 'source_rect':[0,0,*size]}
        if key == 'publisher':
            matches = [i for i,r in enumerate(capture['records']) if r.get('rgb_sha256')==rgb_sha and r.get('program',{}).get('name')=='START']
            if not matches: raise ValueError('publisher not found in original compared capture')
            entry.update({'rect':[12,56,297,77], 'source_rect':[73,170,1840,449],
                          'trace_frames':[min(matches),max(matches)], 'trace_report_sha256':sha(capture_path),
                          'native':'PC publisher identity retained',
                          'donor_basis':'PC-specific A Dynamix Production. Genesis boot capture shows SEGA instead, so preserve PC publisher identity; no ROM-wide absence assertion.'})
        else:
            record = genesis['entries'][key]
            native = root/'local-art/genesis/source/aftermath-v1'/record['image']
            if sha(native) != record['image_sha256']: raise ValueError('changed native donor')
            entry['native_asset']={'path':str(native.relative_to(root)), 'sha256':sha(native), 'size':[320,200]}
            entry['donor_basis']='Genesis source scripts937E/93A0, original read-only decoder9AFE, tile banks9/10 and maps21/22 with map23 smoke overlay in scene2'
        entries.append(entry)
    report={'schema':1, 'entries':entries, 'scope':__doc__,
            'ownership':'All 64000 PC source pixels and program identity must match. No timers, input, core writes, gameplay or APC/HEAT changes.'}
    path=out/'catalog.json';path.write_text(json.dumps(report,indent=2)+'\n')
    print('SPLASH_AFTERMATH:',sha(path),len(entries),'complete-frame bindings')
    return report


if __name__=='__main__': build()
