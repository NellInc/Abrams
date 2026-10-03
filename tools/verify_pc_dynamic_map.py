#!/usr/bin/env python3
"""Original keyboard-only map route: run it once per core (--mode), then --compare the trace and baseline reports."""
import argparse,hashlib,json
from pathlib import Path
from pc_reference_core import PcReferenceCore
from pc_live_state import SimStateReader,active_program
from pc_render_trace import Collector
ROOT=Path(__file__).resolve().parents[1]
STEPS=[('start',20,[]),('commander-key',3,['f2']),('commander',90,[]),('map-toggle-key',3,['z']),('map-toggle',90,[]),('map-return-key',3,['z']),('map-return',90,[]),('driver-key',3,['f3']),('driver',60,[]),('commander-return-key',3,['f2']),('commander-return',90,[])]
def run(mode,state,out):
 manifest=json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text());pin=manifest[mode+'_sha256'];reader=SimStateReader(ROOT/'GAME/SIM.EXE')
 core=PcReferenceCore(ROOT/'.runtime/pc-core'/('abrams-trace.dylib' if mode=='trace' else 'source-baseline.dylib'),ROOT/'.runtime/pc-core/abrams-ref.zip',out/'saves',expected_sha256=pin)
 collector=Collector(reader);rows=[];packets=[];stages={}
 try:
  core.run(240);core.restore(state,expected_source_sha256=manifest['baseline_sha256']);core.run(1);core.pause_at_frame_end()
  initial=reader.read(core.conventional_memory())
  if mode=='trace':collector.attach(core,initial['load_segment'])
  for stage,count,keys in STEPS:
   for n in range(count):
    core.run(1,keys)
    if collector.error:raise collector.error
    rows.append([keys,hashlib.sha256(core.last_video_ram).hexdigest(),hashlib.sha256(core.last_video[0]).hexdigest()])
    if mode=='trace':
     paired=collector.paired_video(core.last_video);packet=paired.get('dynamic_map',{})
     if packet:
      packets.append({'frame':len(rows)-1,'stage':stage,'mode':packet['mode'],'page':packet['page_offset']})
      name='overview' if packet['mode']==0 else 'local'
      if not (out/(name+'.json')).exists() and paired.get('draw_pass') and paired.get('ui_overlay'):
       core.screenshot().save(out/(name+'.png'))
       fixture={'schema':1,'frame_index':len(rows)-1,'stage':stage,'program':active_program(core.last_video_ram),'presentation':paired}
       (out/(name+'.json')).write_text(json.dumps(fixture,indent=2)+'\n')
   stages[stage]=reader.read(core.last_video_ram)
  result={'mode':mode,'core_sha256':pin,'trace_header_sha256':manifest['trace_header_sha256'],'frames':rows,'stages':stages,'packets':packets,'observer':collector.dynamic_map.report()}
  (out/'report.json').write_text(json.dumps(result,indent=2)+'\n');return result
 finally:
  core.pause_at_frame_end()
  if mode=='trace':collector.detach(core)
  core.close()
def verify(trace_path,baseline_path,manifest_path=ROOT/'.runtime/pc-core/abrams-trace.json'):
 # Parity is only evidence when both runs saw identical guest RAM, video and input on the pinned cores.
 trace=json.loads(Path(trace_path).read_text());baseline=json.loads(Path(baseline_path).read_text())
 manifest=json.loads(Path(manifest_path).read_text()) if Path(manifest_path).is_file() else {}
 observer=trace.get('observer',{})
 checks={'modes_correct':trace.get('mode')=='trace' and baseline.get('mode')=='baseline',
  'all_RAM_video_input_frames_equal':trace.get('frames')==baseline.get('frames') and len(trace.get('frames',[]))==sum(count for _,count,_ in STEPS),
  'all_stage_states_equal':trace.get('stages')==baseline.get('stages') and set(trace.get('stages',{}))=={stage for stage,_,_ in STEPS},
  'core_pins_distinct_and_match_receipt':trace.get('core_sha256')!=baseline.get('core_sha256') and
   trace.get('core_sha256')==manifest.get('trace_sha256') and baseline.get('core_sha256')==manifest.get('baseline_sha256'),
  'new_trace_header':trace.get('trace_header_sha256')==baseline.get('trace_header_sha256')==manifest.get('trace_header_sha256'),
  'both_map_modes_observed':{p['mode'] for p in trace.get('packets',[])}=={0,1},
  'occluded_or_stale_frames_rejected':observer.get('presented',0)>0 and observer.get('frame_mismatch',0)>0}
 return {'checks':checks,'frames':len(trace.get('frames',[])),'observer':observer,
  'trace_sha256':trace.get('core_sha256'),'baseline_sha256':baseline.get('core_sha256'),'trace_header_sha256':trace.get('trace_header_sha256')}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);g=p.add_mutually_exclusive_group(required=True);g.add_argument('--mode',choices=['trace','baseline']);g.add_argument('--compare',nargs=2,type=Path,metavar=('TRACE','BASELINE'))
 p.add_argument('--state',type=Path);p.add_argument('--output',type=Path);p.add_argument('--manifest',type=Path,default=ROOT/'.runtime/pc-core/abrams-trace.json');a=p.parse_args()
 if a.compare:
  r=verify(*a.compare,a.manifest);print(json.dumps(r,indent=2));raise SystemExit(0 if all(r['checks'].values()) else 1)
 if not a.state or not a.output:p.error('--mode needs --state and --output')
 a.output.mkdir(parents=True,exist_ok=False);r=run(a.mode,a.state,a.output);print(json.dumps({'frames':len(r['frames']),'observer':r['observer'],'packet_modes':sorted(set(p['mode'] for p in r['packets']))}))
