#!/usr/bin/env python3
"""Observe crew footer variants through ordinary START menu input only."""
import hashlib,json
from pathlib import Path
from tools.bootstrap_pc_source import STEPS
from tools.pc_reference_core import PcReferenceCore
from tools.pc_live_state import active_program
from tools.capture_pc_session import INFORMATION_PAGES
ROOT=Path(__file__).resolve().parents[1]

def main():
    out=ROOT/'artifacts/finish-20260928/crew-footer-native';out.mkdir(parents=True,exist_ok=False)
    manifest=json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text())
    core=PcReferenceCore(ROOT/'.runtime/pc-core/source-baseline.dylib',ROOT/'.runtime/pc-core/abrams-ref.zip',out/'saves',expected_sha256=manifest['baseline_sha256'])
    records=[];samples=[]
    def step(frames,keys=()):
        core.run(frames,keys);records.append({'frames':frames,'keys':list(keys),'video_sha256':hashlib.sha256(core.last_video[0]).hexdigest()})
    def press(key):step(10,[key]);step(90)
    try:
        step(240)
        for frames,keys in STEPS[:9]:step(frames,keys)
        press('right');press('right')
        for i,delay in enumerate([0,31,137,601]):
            if delay:step(delay)
            press('return');press('return');step(180)
            image=core.screenshot();raw=image.tobytes();program=active_program(core.conventional_memory())
            prefix=hashlib.sha256(raw[:320*175*3]).hexdigest()
            if image.size!=(320,200) or prefix!=INFORMATION_PAGES['crew'] or not program or program['name']!='START':
                image.save(out/'unexpected.png');raise ValueError('ordinary route did not reach original crew page')
            path=out/f'crew-{i}.png';image.save(path)
            samples.append({'image':path.name,'delay_before_entry':delay,'program':program,'rgb_sha256':hashlib.sha256(raw).hexdigest(),'prefix_sha256':prefix,'footer_sha256':hashlib.sha256(raw[320*175*3:]).hexdigest()})
            press('escape');press('escape')
        report={'mode':'baseline','core_sha256':core.core_sha256,'records':records,'samples':samples,'checks':{'four_original_crew_entries':len(samples)==4,'all_original_prefixes':all(s['prefix_sha256']==INFORMATION_PAGES['crew'] for s in samples)},'scope':__doc__}
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print('CREW_FOOTERS:',len(samples),'ordinary entries;',len({s['footer_sha256'] for s in samples}),'unique footer(s)')
    finally:core.close()
if __name__=='__main__':main()
