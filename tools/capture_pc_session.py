#!/usr/bin/env python3
"""Cold-boot/quit/reentry trace and unmodified-core comparison, local only.

Runs the original menus, briefings and mission in their own disk overlay. It
does not restore RAM without its filesystem, author menu rules or write RAM.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path
try:
    from tools.pc_reference_core import PcReferenceCore
    from tools.pc_live_state import SimStateReader, active_program
    from tools.pc_session import PresentationSession
    from tools.inspect_scenarios import decode_resource
    from tools.pc_render_trace import Collector
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_reference_core import PcReferenceCore
    from pc_live_state import SimStateReader, active_program
    from pc_session import PresentationSession
    from inspect_scenarios import decode_resource
    from pc_render_trace import Collector
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]


def no_sim_geometry(s):
    """No SIM state; only START may carry its own pixel-paired START/ANIM scenery."""
    draw=(s.get('presentation') or {}).get('draw_pass')
    return s.get('state') is None and (not draw or
        (s.get('program') or {}).get('name')=='START' and draw.get('frontend_scene')=='START/ANIM')


def ui_fully_original(presentation):
    # An incomplete native UI mask is reported as ui_overlay None.
    return (presentation.get('ui_overlay') or {}).get('ui_pixels')==64000

# Exact first 175 rows: the original leaves variable menu residue in row 175.
# This row and all later pixels remain untouched by presentation replacement.
INFORMATION_HEIGHT = 175
INFORMATION_PAGES = {
    'crew':'ea3537272108eef43162fb682f854fe51fee92ad26eed41e24a413e06a84e4c8',
    'ax':'7bade03c6160c7ffde9c1bba75f848c1f24a3ddf5d6e958cf3983ccc2d8836b5',
    'heat':'c96c35c736bea17133812caf4103ee1f59c5e21e76680fa131cb2eb3e7b55816',
    'sabot':'6eaa9f227c3002c35b0b5cdecb18d8b0bed82c3e80edb3309a3e40fbe1ee9a76',
    'coax':'ef61948e2b478e785fd5d0282b79b07d277f348a163a0ecad8ca8870e58c66ec',
    'cannon':'e91b9cf3a1e51e999b74fa6e1fc74115deceb96ba647ed01527a4c83d36d7c01',
    'smoke':'a12eaba06e9e7186efe795bab66ce88cfb9ce20302b283dc58530375630e961e'}


def information_steps():
    try:
        from tools.bootstrap_pc_source import STEPS
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from bootstrap_pc_source import STEPS
    route=[{'label':f'boot-{i:02d}','frames':n,'keys':keys} for i,(n,keys) in enumerate(STEPS[:9])]
    actions=[('campaign-select','right'),('information-select','right'),('information-menu','return'),
             ('crew','return'),('crew-close','escape'),('ammo-select','down'),('ammo-menu','return'),
             ('ax','return'),('ax-close','escape'),('heat-select','down'),('heat','return'),
             ('heat-close','escape'),('sabot-select','down'),('sabot','return'),('sabot-close','escape'),
             ('ammo-close','escape'),('armament-select','down'),('armament-menu','return'),
             ('coax','return'),('coax-close','escape'),('cannon-select','down'),('cannon','return'),
             ('cannon-close','escape'),('smoke-select','down'),('smoke','return'),('smoke-close','escape'),
             ('armament-close','escape'),('information-close','escape')]
    for label,key in actions:
        route.extend([{'label':label+'-press','frames':10,'keys':[key]},
                      {'label':label,'frames':90,'keys':[]}])
        if label in INFORMATION_PAGES: route.append({'label':label+'-wait','frames':180,'keys':[]})
    return route


def steps(motor_pool_controls=False, motor_pool_allocations=False):
    fixture = ROOT / 'godot/tests/fixtures'
    boot = json.loads((fixture / 'pc_boot_steps.json').read_text())
    route=([{'label': 'ready', 'frames': 1, 'keys': []}] +
            [{'label': f'boot-{i:02d}', 'frames': n, 'keys': keys} for i,(n,keys) in enumerate(boot)] +
            json.loads((fixture / 'pc_reentry_steps.json').read_text()))
    if motor_pool_controls or motor_pool_allocations:
        index=next(i for i,s in enumerate(route) if s['label']=='boot-23')
        extra=[]
        controls=[('select-governor','up'),('toggle-governor','right'),('select-begin','down')]
        if motor_pool_allocations:
            controls=[('arming-governor','up'),('arming-ax','up'),('arming-ax-increase','right'),
                      ('arming-sabot','up'),('arming-sabot-decrease','left'),('arming-heat','up'),
                      ('arming-heat-increase','right'),('arming-sabot-return','down'),
                      ('arming-ax-return','down'),('arming-governor-return','down'),('arming-begin','down')]
        for name,key in controls:
            extra.extend([{'label':name+'-press','frames':3,'keys':[key]},
                          {'label':name,'frames':30,'keys':[]}])
        route[index:index]=extra
    return route


def scenario_steps(session=None):
    """Visit every original scenario, all stations, pause/mute and quit/debrief.

    Menu pulses use the independently observed 10/90-frame cadence. Shorter
    three-frame repeats can be missed while START redraws its model backdrop.
    This is an input trace, not a reimplementation of any menu or mission rule.
    """
    fixture = ROOT / 'godot/tests/fixtures'
    boot = json.loads((fixture / 'pc_boot_steps.json').read_text())
    end = json.loads((fixture / 'pc_reentry_steps.json').read_text())[:11]
    route = [{'label':'ready','frames':1,'keys':[]}]
    route += [{'label':f'boot-{i:02d}','frames':n,'keys':keys} for i,(n,keys) in enumerate(boot[:12])]
    def pulse(label,key):
        return [{'label':label+'-press','frames':10,'keys':[key]},
                {'label':label,'frames':90,'keys':[]}]
    yield from route
    for scenario in range(8):
        route=[]
        prefix=f'scenario-{scenario}'
        if scenario:
            route += pulse(prefix+'-menu','return')
            for i in range(3): route += pulse(prefix+f'-select-up-{i}','up')
            # START resets the selected mission after returning from END.
            for choice in range(scenario): route += pulse(prefix+f'-next-{choice}','return')
            for i in range(3): route += pulse(prefix+f'-select-down-{i}','down')
        route += [{'label':prefix+f'-entry-{i:02d}','frames':n,'keys':keys}
                  for i,(n,keys) in enumerate(boot[12:])]
        for station,key in [('commander','f2'),('cupola','f3'),('driver','f4'),('gunner','f1')]:
            route += pulse(prefix+'-'+station,key)
        for name,key in [('sound-off','f5'),('sound-on','f5'),('pause','escape'),('resume','space'),
                         ('cannon','space'),('coax','m'),('smoke','s')]:
            route += pulse(prefix+'-'+name,key)
        route += [{'label':prefix+'-'+step['label'],'frames':step['frames'],'keys':step['keys']}
                  for step in end]
        yield from route
        # END has a variable number of original review pages after combat.
        # Advance by ordinary Space input until the original returns to START.
        # This diagnostic never synthesizes an outcome or overwrites guest RAM.
        yield {'label':prefix+'-menu-wait','frames':600,'keys':[]}
        for page in range(6):
            if session is None or (session.sample()['program'] or {}).get('name')=='START':break
            yield {'label':prefix+f'-review-{page}-press','frames':10,'keys':['space']}
            yield {'label':prefix+f'-review-{page}','frames':600,'keys':[]}
        yield {'label':prefix+'-main-menu','frames':300,'keys':[]}


def combat_loss_steps(session):
    """Let original enemies destroy the stationary tank, then revisit a mission.

    The live executable decides the outcome. No quit key, memory mutation or
    mission-state restore can substitute for the observed SIM-to-END transition.
    """
    fixture = ROOT / 'godot/tests/fixtures'
    boot = json.loads((fixture/'pc_boot_steps.json').read_text())
    yield {'label':'ready','frames':1,'keys':[]}
    for i,(frames,keys) in enumerate(boot):
        yield {'label':f'boot-{i:02d}','frames':frames,'keys':keys}
    if (session.sample()['program'] or {}).get('name')!='SIM':
        raise ValueError('combat-loss route did not enter original SIM')
    for i in range(300):
        yield {'label':f'combat-{i:03d}','frames':60,'keys':[]}
        if (session.sample()['program'] or {}).get('name')!='SIM':break
    if (session.sample()['program'] or {}).get('name')!='END':
        raise ValueError('original tank loss did not reach END within 18000 frames')
    yield {'label':'combat-debrief','frames':600,'keys':[]}
    for i in range(8):
        if (session.sample()['program'] or {}).get('name')=='START':break
        yield {'label':f'combat-review-{i}-press','frames':10,'keys':['space']}
        yield {'label':f'combat-review-{i}','frames':600,'keys':[]}
    yield {'label':'combat-main-menu','frames':300,'keys':[]}
    if (session.sample()['program'] or {}).get('name')!='START':
        raise ValueError('combat debrief did not return to the original menu')
    yield from json.loads((fixture/'pc_reentry_steps.json').read_text())[12:]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode', choices=['trace','baseline'], required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--compare', type=Path, help='other capture report, compared after this run')
    p.add_argument('--boot-state', type=Path, help='shared neutral START snapshot for byte-exact comparison')
    p.add_argument('--capture-ui', action='store_true', help='save paired original UI/plate masks at stage boundaries')
    p.add_argument('--motor-pool-controls', action='store_true', help='exercise the original governor menu with ordinary arrow keys')
    p.add_argument('--motor-pool-allocations', action='store_true', help='exercise all original ammunition fields with ordinary arrow keys')
    p.add_argument('--information', action='store_true', help='capture all seven original M1-Info pages and return to the main menu')
    p.add_argument('--all-scenarios', action='store_true', help='ordinary-input entry, four stations, weapons, pause/mute and quit/debrief for all eight scenarios')
    p.add_argument('--combat-loss', action='store_true', help='wait for original enemy fire to end the mission, debrief and reenter')
    args = p.parse_args()
    if args.combat_loss and (args.all_scenarios or args.information or args.motor_pool_controls or args.motor_pool_allocations):
        p.error('combat-loss is a separate route')
    if args.all_scenarios and (args.information or args.motor_pool_controls or args.motor_pool_allocations):
        p.error('all-scenarios is a separate route')
    if args.information and (args.motor_pool_controls or args.motor_pool_allocations):
        p.error('information and motor-pool routes are separate')
    other = json.loads(args.compare.read_text()) if args.compare else None
    if inside_source(args.output, ROOT):
        p.error('output must be outside original source directories')
    args.output.mkdir(parents=True,exist_ok=False)
    manifest = json.loads((ROOT / '.runtime/pc-core/abrams-trace.json').read_text())
    library = 'abrams-trace.dylib' if args.mode == 'trace' else 'source-baseline.dylib'
    core = PcReferenceCore(ROOT / '.runtime/pc-core' / library, ROOT / '.runtime/pc-core/abrams-ref.zip',
                           args.output / 'saves', expected_sha256=manifest[args.mode+'_sha256'])
    collectors = []
    def factory(*args, **kwargs):
        collector = Collector(*args, **kwargs)
        collectors.append(collector)
        return collector
    session = PresentationSession(core,SimStateReader(ROOT/'GAME/SIM.EXE'),
                                  decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes()),trace=args.mode=='trace',
                                  collector_factory=factory)
    records, samples, ui_presentations, presentations = [], [], [], []
    damage_exit_frames = []
    try:
        core.run(240)  # Same original startup boundary as the live host.
        if args.boot_state:
            core.restore(args.boot_state,expected_source_sha256=manifest['baseline_sha256'])
            core.run(1)  # Native framebuffer priming after snapshot restore.
            program = active_program(core.conventional_memory())
            if not program or program['name'] != 'START': raise ValueError('comparison requires a neutral START snapshot')
        route=combat_loss_steps(session) if args.combat_loss else scenario_steps(session) if args.all_scenarios else information_steps() if args.information else steps(args.motor_pool_controls,args.motor_pool_allocations)
        for step in route:
            for _ in range(step['frames']):
                session.step(1,step['keys'])
                records.append({'frame':core.frame, 'keys':step['keys'],
                    'ram_sha256':hashlib.sha256(core.last_video_ram).hexdigest(),
                    'video_sha256':hashlib.sha256(core.last_video[0]).hexdigest()})
                if args.combat_loss:
                    program=active_program(core.last_video_ram)
                    if program and program['name']=='SIM':
                        base=session.reader.locate(core.last_video_ram)
                        # Original 699e sets this after armour damage; 2031
                        # tests it before 1956(1). Observation only, not a cue.
                        if base==program['load_segment']*16 and core.last_video_ram[base+0x19e00+0xcca]:
                            damage_exit_frames.append(core.frame)
            sample = session.sample()
            sample["audio"] = session.drain_audio()
            filename = step['label']+'.png'
            core.screenshot().save(args.output/filename)
            if args.information and step['label'] in INFORMATION_PAGES:
                (args.output/(step['label']+'.bin')).write_bytes(core.last_video_ram)
            samples.append(step | sample | {'frame':core.frame, 'image':filename})
            view=sample['presentation']
            if args.capture_ui and (view.get('plate_overlay') or {}).get('mask_png'):
                index=len(presentations)
                presentations.append(view)
                mask=step['label']+'-ui.png'
                plate=step['label']+'-plates.png'
                (args.output/mask).write_bytes(base64.b64decode(view['ui_overlay']['mask_png'],validate=True))
                (args.output/plate).write_bytes(base64.b64decode(view['plate_overlay']['mask_png'],validate=True))
                ui_presentations.append({'stage':step['label'],'frame_index':index,
                    'image':filename,'mask':mask,'plate_mask':plate})
        by_name = {sample['label']:sample for sample in samples}
        programs = [entry['program']['name'] if entry['program'] else None for entry in session.transitions]
        if args.combat_loss:
            combat=[s for s in samples if s['label'].startswith('combat-')]
            checks={
                'original_damage_exit_flag_observed':bool(damage_exit_frames),
                'no_quit_command':all('q' not in r['keys'] for r in records),
                'stationary_combat_no_inputs':all(not s['keys'] for s in combat if s['label'][7:].isdigit()),
                'combat_debrief_is_END':by_name['combat-debrief']['program']['name']=='END',
                'combat_returns_to_START':by_name['combat-main-menu']['program']['name']=='START',
                'original_loss_and_reentry_lifecycle':programs==['START','BRIEF','SIM','END','START','BRIEF','SIM'],
                'second_mission_initialized':bool(by_name['second-mission']['state']) and by_name['second-mission']['state']['scenario_resource_index']==6,
            }
            if args.mode=='trace':
                checks['second_mission_fresh_render_epoch']=by_name['second-mission']['render_epoch']==2
                checks['second_mission_paired']=bool(by_name['second-mission']['presentation'].get('draw_pass'))
                checks['no_stale_SIM_presentation_in_debrief']=all(s['state'] is None and s['presentation'].get('draw_pass') is None
                    for s in combat if s['program'] and s['program']['name']=='END')
        elif args.all_scenarios:
            visited=[]
            checks={}
            for index in range(8):
                prefix=f'scenario-{index}'
                gunner=by_name[prefix+'-gunner']
                state=gunner['state'] or {}
                visited.append(state.get('scenario_resource_index'))
                for station in ('commander','cupola','driver','gunner'):
                    at=by_name[prefix+'-'+station]
                    checks[prefix+'-'+station]=bool(at['state']) and at['state']['station']==station
                    if args.mode=='trace':
                        checks[prefix+'-'+station+'-paired']=bool(at['presentation'].get('draw_pass'))
                if args.mode=='trace':
                    checks[prefix+'-mute']=not by_name[prefix+'-sound-off']['audio']['enabled']
                    checks[prefix+'-unmute']=bool(by_name[prefix+'-sound-on']['audio']['enabled'])
                    checks[prefix+'-pause']=not by_name[prefix+'-pause']['audio']['enabled']
                    checks[prefix+'-resume']=bool(by_name[prefix+'-resume']['audio']['enabled'])
                checks[prefix+'-debrief']=by_name[prefix+'-debrief']['program']['name']=='END'
                checks[prefix+'-menu']=by_name[prefix+'-main-menu']['program']['name']=='START'
            checks['eight_distinct_original_scenarios']=set(visited)==set(range(8))
            checks['eight_original_mission_lifecycles']=programs==['START']+['BRIEF','SIM','END','START']*8
        elif args.information:
            checks={'START_owns_information': programs==['START'],
                    'no_SIM_state_or_geometry':all(no_sim_geometry(s) for s in samples)}
            for name,pin in INFORMATION_PAGES.items():
                from PIL import Image
                picture=Image.open(args.output/(name+'.png')).convert('RGB')
                checks['original_page_'+name]=hashlib.sha256(picture.crop((0,0,320,INFORMATION_HEIGHT)).tobytes()).hexdigest()==pin
                checks['stable_page_'+name]=(args.output/(name+'.png')).read_bytes()==(args.output/(name+'-wait.png')).read_bytes()
        else:
            checks = {
                'program_lifecycle': programs == ['START','BRIEF','SIM','END','START','BRIEF','SIM'],
                'debrief_is_original_END': by_name['debrief']['program']['name']=='END',
                'menus_have_no_SIM_state_or_geometry': all(
                    no_sim_geometry(s) for s in samples if not s['program'] or s['program']['name']!='SIM'),
                'second_mission_initialized': bool(by_name['second-mission']['state']) and
                    by_name['second-mission']['state']['scenario_resource_index']==6,
            }
            if args.mode == 'trace':
                checks['fresh_second_render_epoch'] = by_name['second-mission']['render_epoch']==2
                checks['second_mission_paired'] = bool(by_name['second-mission']['presentation'].get('draw_pass'))
                checks['quit_dialog_fully_original'] = ui_fully_original(by_name['quit-dialog']['presentation'])
        report = {'mode':args.mode,'core_sha256':core.core_sha256,'source_commit':manifest['commit'],
            'initial_unrecorded_frames':240,'records':records,'samples':samples,
            'boot_state_sha256':hashlib.sha256(args.boot_state.read_bytes()).hexdigest() if args.boot_state else None,
            'restore_priming_frames':1 if args.boot_state else 0,
            'transitions':session.transitions,'checks':checks,
            'plate_epochs':[c.plates.report() for c in collectors],
            'ui_presentations':ui_presentations,'presentations':presentations,
            'scope':('all eight original scenario entries, station and weapon inputs, pause/mute and quit/debrief; victory/campaign outcomes are separate' if args.all_scenarios else 'all seven original M1-Info pages; page recognition excludes preserved row 175 and lower border' if args.information else 'bounded original cold-boot, quit and reentry; compare full paired RAM/video/input records separately')}
        if args.combat_loss:
            report.update(damage_exit_frames=damage_exit_frames,
                scope='ordinary boot, original stationary-tank combat loss, debrief, menu and second mission; no live RAM writes or mid-mission restoration')
        if args.compare:
            mismatches = [i for i,(a,b) in enumerate(zip(records,other['records'])) if a!=b]
            comparable = lambda r: [{k:s[k] for k in ('label','frame','keys','program','state')} for s in r['samples']]
            checks['equal_frame_count'] = len(records)==len(other['records'])
            checks['all_RAM_video_and_inputs_identical'] = not mismatches
            checks['all_stage_states_identical'] = comparable(report)==comparable(other)
            checks['program_boundaries_identical'] = report['transitions']==other['transitions']
            if args.combat_loss:checks['damage_exit_frames_identical']=damage_exit_frames==other.get('damage_exit_frames')
            report['comparison'] = {'path':str(args.compare),'core_sha256':other['core_sha256'],
                                    'mismatch_count':len(mismatches),'first_mismatches':mismatches[:20]}
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'mode':args.mode,'frames':len(records),'stages':len(samples),'checks':checks},indent=2))
        if not all(checks.values()): raise SystemExit(1)
    finally:
        session.close()
        core.close()


if __name__ == '__main__': main()
