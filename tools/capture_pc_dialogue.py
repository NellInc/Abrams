#!/usr/bin/env python3
"""Bounded original dialogue discovery, read-only and with baseline-comparable input.

Queued RAM text is research evidence only, never passed to the live presentation.
Ordinary radio-key pulses probe the original retrieval path. Stop at SIM exit;
the RAM-only mission snapshot does not establish disk-dependent outcome parity.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
try:
    from tools.pc_reference_core import PcReferenceCore
    from tools.pc_live_state import SimStateReader, active_program
    from tools.pc_session import PresentationSession
    from tools.pc_render_trace import Collector
    from tools.inspect_scenarios import decode_resource
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_reference_core import PcReferenceCore
    from pc_live_state import SimStateReader, active_program
    from pc_session import PresentationSession
    from pc_render_trace import Collector
    from inspect_scenarios import decode_resource
    from source_guard import inside_source

ROOT=Path(__file__).resolve().parents[1]


def queued_dialogue(ram,load):
    ds=(load+0x19E0)*16
    def string(pointer):
        if not pointer: return None
        end=ram.find(b'\0',ds+pointer,min(ds+65536,ds+pointer+256))
        return ram[ds+pointer:end].decode('cp437') if end>=0 else None
    def word(at): return struct.unpack_from('<H',ram,ds+at)[0]
    return {'crew':string(word(0x094C)),'secondary':string(word(0x646A)),
            'speaker':ram[ds+0x6464],'radio':string(word(0x094E)),
            'radio_open':bool(ram[ds+0x0950]),'crew_countdown':word(0x6470)}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode',choices=['trace','baseline'],required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--state',type=Path,required=True)
    p.add_argument('--capture-ui',action='store_true',help='save paired original masks/presentations with newly visible dialogue')
    p.add_argument('--capture-window',type=int,nargs=2,metavar=('FIRST','LAST'),
                   help='also save every paired frame in this inclusive route-index window')
    route=p.add_mutually_exclusive_group()
    route.add_argument('--radio',action='store_true',help='original Escort driving, radio retrieval, mute and reopen route')
    route.add_argument('--warnings',action='store_true',help='original smoke exhaustion, mute and re-warning route')
    p.add_argument('--frames',type=int,default=12000);a=p.parse_args()
    if not 1<=a.frames<=18000:p.error('frames must be 1..18000')
    if a.capture_window and not (a.capture_ui and 0<=a.capture_window[0]<=a.capture_window[1]<a.frames):
        p.error('capture-window requires capture-ui and 0 <= FIRST <= LAST < frames')
    if inside_source(a.output,ROOT,('GAME','GENESIS')):
        p.error('output must be outside original sources')
    a.output.mkdir(parents=True,exist_ok=False)
    manifest=json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text())
    lib='abrams-trace.dylib' if a.mode=='trace' else 'source-baseline.dylib'
    core=PcReferenceCore(ROOT/'.runtime/pc-core'/lib,ROOT/'.runtime/pc-core/abrams-ref.zip',
                         a.output/'saves',expected_sha256=manifest[a.mode+'_sha256'])
    reader=SimStateReader(ROOT/'GAME/SIM.EXE')
    collectors=[]
    def factory(*args,**kwargs):
        collector=Collector(*args,**kwargs);collectors.append(collector);return collector
    session=PresentationSession(core,reader,decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes()),trace=a.mode=='trace',collector_factory=factory)
    records=[];changes=[];audio=[];seen=set();prior=None;final=None;ui_presentations=[]
    route_keys=[]
    if a.warnings or a.radio:
        fixture='pc_warning_steps.json' if a.warnings else 'pc_radio_steps.json'
        for count,keys in json.loads((ROOT/'godot/tests/fixtures'/fixture).read_text()):
            route_keys.extend([keys]*count)
    try:
        core.run(240);core.restore(a.state,expected_source_sha256=manifest['baseline_sha256']);core.run(1)
        if not reader.read(core.conventional_memory()):raise ValueError('missing original SIM')
        for i in range(min(a.frames,len(route_keys)) if route_keys else a.frames):
            keys=route_keys[i] if route_keys else (['r'] if i>=600 and (i-600)%1200<3 else [])
            session.step(1,keys)
            audio.extend(e|{'frame_index':i} for e in session.drain_audio()['events'])
            sample=session.sample();ram=core.last_video_ram;program=sample['program']
            queue=queued_dialogue(ram,program['load_segment']) if sample['state'] else None
            view=sample['presentation'];runs=view.get('text_runs',[])
            record={'index':i,'keys':keys,'program':program,
                    'ram_sha256':hashlib.sha256(ram).hexdigest(),
                    'video_sha256':hashlib.sha256(core.last_video[0]).hexdigest(),'queued':queue}
            records.append(record)
            signature=sorted((r['kind'],r['text'],r['rect'],r['speaker'],r.get('message_ref',{}).get('id')) for r in runs)
            queued_signature={k:v for k,v in (queue or {}).items() if k!='crew_countdown'}
            current=[signature,queued_signature]
            if current!=prior:
                item={'frame_index':i,'visible':runs,'messages':view.get('messages',[]),'queued':queue,'scanout_sequence':view.get('scanout_sequence')}
                new=[(r['kind'],r['text'],tuple(r['rect'])) for r in runs if r['kind']!='weapon_status']
                unseen=set(new)-seen
                if unseen:
                    filename=f'text-{i:05d}.png';core.screenshot().save(a.output/filename);item['image']=filename
                    mask=(view.get('ui_overlay') or {}).get('mask_png')
                    if a.capture_ui and mask:
                        maskname=f'text-{i:05d}-mask.png'
                        (a.output/maskname).write_bytes(base64.b64decode(mask,validate=True))
                        ui_presentations.append({'stage':f'dialogue-{i:05d}','frame_index':i,
                                                 'image':filename,'mask':maskname,'presentation':view})
                    if any(r['kind']=='crew_secondary' for r in runs):
                        (a.output/f'text-{i:05d}.bin').write_bytes(ram)
                    seen.update(unseen)
                changes.append(item);prior=current
                if new:print(json.dumps({'frame':i,'visible':new}),flush=True)
            if a.capture_window and a.capture_window[0]<=i<=a.capture_window[1]:
                filename=f'text-{i:05d}.png';core.screenshot().save(a.output/filename)
                mask=(view.get('ui_overlay') or {}).get('mask_png')
                if mask and not any(e['frame_index']==i for e in ui_presentations):
                    maskname=f'text-{i:05d}-mask.png'
                    (a.output/maskname).write_bytes(base64.b64decode(mask,validate=True))
                    ui_presentations.append({'stage':f'dialogue-{i:05d}','frame_index':i,
                                             'image':filename,'mask':maskname,'presentation':view})
            if not program or program['name']!='SIM':break
            if i%1200==1199:print(json.dumps({'frame':i,'queued':queue}),flush=True)
        final=session.sample()
        core.screenshot().save(a.output/'last-frame.png')
        report={'mode':a.mode,'core_sha256':core.core_sha256,'frames':records,'changes':changes,
                'profile':'radio-retrieval' if a.radio else ('smoke-warnings' if a.warnings else 'incoming-damage'),
                'audio_events':audio,'final_state':final['state'],'final_program':final['program'],
                'state_sha256':hashlib.sha256(a.state.read_bytes()).hexdigest(),
                'state_core_sha256':manifest['baseline_sha256'],
                'capture_window':a.capture_window,
                'text_epochs':[c.text.report() for c in collectors],
                'message_epochs':[{'counts':dict(c.text.messages.counts),'assignments':list(c.text.messages.history)} for c in collectors],
                'ui_presentations':ui_presentations,'scope':__doc__}
        (a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'frames':len(records),'changes':len(changes),'unique_visible_runs':len(seen),
                          'final_program':final['program']}),flush=True)
    finally:
        session.close();core.close()


if __name__=='__main__':main()
