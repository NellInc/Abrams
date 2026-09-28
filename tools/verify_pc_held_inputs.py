#!/usr/bin/env python3
"""Same-timeline, fresh-process held-key checkpoint continuation diagnostic.

Uses only original keyboard input and read-only guest observations. Each capture
continues uninterrupted after serialization; its exact bytes are then restored in
a fresh native lifetime. No independent cold boot is used as the parity oracle.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.pc_reference_core import PcReferenceCore
from tools.pc_live_state import active_program
from tools.verify_pc_save_states import Client, rewrite
import zipfile

CASES = {
    'fire_release': ([[1, ['space']]], [[1, []]] * 12),
    'movement_fire_hold_release': ([[5, ['up', 'kp6', 'space']]], [[1, ['up', 'kp6', 'space']]] * 3 + [[1, []]] * 9),
    'movement_change': ([[1, ['kp6']]], [[1, ['kp4']]] * 5 + [[1, []]] * 7),
    'shift_digit_release': ([[1, ['shift', '3']]], [[1, []]] * 12),
    'break_pending': ([[1, ['space', 'kp6']], [1, []]], [[1, []]] * 12),
    'fast_forward_release': ([[8, ['up', 'space']]], [[8, []], [1, []], [1, []]]),
}

def sha(raw): return hashlib.sha256(raw).hexdigest()

def observe(core):
    raw, width, height, pitch = core.last_video
    return {'ram': sha(core.conventional_memory()), 'video': sha(raw),
            'frame': core.frame, 'pressed': sorted(core.pressed)}

def phase(args):
    manifest = json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text())
    directory = args.output
    saves = directory / (args.phase + '-saves')
    core = PcReferenceCore(ROOT/'.runtime/pc-core/abrams-trace.dylib',
                           ROOT/'.runtime/pc-core/abrams-ref.zip', saves,
                           expected_sha256=manifest['trace_sha256'])
    try:
        core.run(241)
        if args.phase == 'capture':
            for frames, keys in json.loads((ROOT/'godot/tests/fixtures/pc_boot_steps.json').read_text()):
                core.run(frames, keys)
            for frames, keys in CASES[args.case][0]: core.run(frames, keys)
            core.local_overlay('flush')
            raw = core.serialize_local()
            (directory/'state.bin').write_bytes(raw)
            assert active_program(core.conventional_memory())['name']=='SIM', 'original SIM not reached'
            metadata = {'keys': CASES[args.case][0][-1][1], 'frame': core.frame,
                        'ram_sha256': sha(core.conventional_memory()), 'core': manifest['trace_sha256']}
            (directory/'resume.json').write_text(json.dumps(metadata))
            disk = saves/'abrams-ref.pure.zip'
            (directory/'campaign.zip').write_bytes(disk.read_bytes() if disk.exists() else b'')
        else:
            metadata = json.loads((directory/'resume.json').read_text())
            disk = (directory/'campaign.zip').read_bytes()
            if disk: (saves/'abrams-ref.pure.zip').write_bytes(disk)
            core.local_overlay('reload')
            core.restore_local((directory/'state.bin').read_bytes(), metadata['keys'],
                               metadata['frame'], metadata['ram_sha256'])
        observed = []
        for frames, keys in CASES[args.case][1]:
            core.run(frames, keys)
            observed.append(observe(core))
        (directory/(args.phase+'.json')).write_text(json.dumps(observed, indent=2)+'\n')
    finally: core.close()

def supervisor_matrix(output):
    directory=output/'supervisor';directory.mkdir()
    checks={}
    def record(name, value):
        checks[name]=bool(value)
        assert value, name
    def metadata(slot):
        with zipfile.ZipFile(directory/'saves/states'/f'slot-{slot}.zip') as archive:
            return json.loads(archive.read('resume.json'))
    with (directory/'native.log').open('w') as log:
        client=Client(directory/'saves',log)
        try:
            for frames,keys in json.loads((ROOT/'godot/tests/fixtures/pc_boot_steps.json').read_text()): packet=client.step(frames,keys)
            record('original_sim',packet['program']['name']=='SIM')
            held=client.step(5,['up','space','kp6'])
            saved=client.request('save_state',slot=1)
            record('save_preserves_boundary',saved['success'] and saved['restored']['frame_audit']==held['frame_audit'])
            record('save_preserves_all_held_keys',set(metadata(1)['keys'])=={'up','space','kp6'})
            expected=[client.step(1)['frame_audit'] for _ in range(12)]
            loaded=client.request('load_state',slot=1)
            record('load_preserves_boundary',loaded['success'] and loaded['restored']['frame_audit']==held['frame_audit'])
            actual=[client.step(1)['frame_audit'] for _ in range(12)]
            record('load_released_keys_replay',actual==expected)
            current=client.step(5,['space','kp4'])
            loaded=client.request('load_state',slot=1)
            record('recovery_records_current_keys',set(metadata(0)['keys'])=={'space','kp4'})
            undo=client.request('load_state',slot=0)
            record('undo_preserves_current_controls_boundary',undo['success'] and undo['restored']['frame_audit']==current['frame_audit'])
            # Preserve this held state as the same-timeline reference for both
            # container rejection and native failure after worker replacement.
            saved=client.request('save_state',slot=3)
            record('rollback_reference_saved',saved['success'])
            continuation=[['space','kp4']]*3+[[]]*9
            expected=[client.step(1,keys)['frame_audit'] for keys in continuation]
            states=directory/'saves/states'
            for kind in ['container','native']:
                loaded=client.request('load_state',slot=3)
                record(kind+'_reference_loaded',loaded['success'])
                (states/'slot-2.zip').write_bytes((states/'slot-1.zip').read_bytes())
                def corrupt(files):
                    files['state.bin']=b'invalid-native'
                    if kind=='native':
                        manifest=json.loads(files['manifest.json'])
                        manifest['files']['state.bin']={'size':len(files['state.bin']),'sha256':sha(files['state.bin'])}
                        files['manifest.json']=json.dumps(manifest).encode()
                rewrite(states/'slot-2.zip',corrupt)
                rejected=client.request('load_state',slot=2)
                record(kind+'_rejected',not rejected['success'])
                if kind=='native':
                    record('rollback_restored_held_boundary',rejected['restored']['frame_audit']==saved['restored']['frame_audit'])
                    record('rollback_retained_current_keys',set(metadata(0)['keys'])=={'space','kp4'})
                actual=[client.step(1,keys)['frame_audit'] for keys in continuation]
                record(kind+'_failure_control_continuation',actual==expected)
            client.close();client=Client(directory/'saves',log)
            loaded=client.request('load_state',slot=1)
            record('fresh_supervisor_load',loaded['success'] and loaded['restored']['frame_audit']==held['frame_audit'])
            actual=[client.step(1)['frame_audit'] for _ in range(12)]
            # Re-derive the original neutral reference from the persisted slot
            # without requiring current physical input to match saved keys.
            loaded=client.request('load_state',slot=1)
            replay=[client.step(1)['frame_audit'] for _ in range(12)]
            record('fresh_process_neutral_release_repeatable',actual==replay)
        finally:
            client.close()
            (directory/'report.json').write_text(json.dumps(checks,indent=2)+'\n')
    return checks


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--phase', choices=['capture','restore'])
    parser.add_argument('--case', choices=CASES)
    args=parser.parse_args()
    if args.phase: phase(args); return 0
    args.output.mkdir(parents=True,exist_ok=False)
    checks={}
    supervisor={}
    try:
        for name in CASES:
            directory=args.output/name;directory.mkdir()
            with (directory/'native.log').open('w') as log:
                for operation in ['capture','restore']:
                    subprocess.run([sys.executable,__file__,'--output',str(directory),
                                    '--phase',operation,'--case',name],check=True,stderr=log,stdout=log)
            expected=json.loads((directory/'capture.json').read_text())
            actual=json.loads((directory/'restore.json').read_text())
            checks[name]={'ram': [x['ram'] for x in actual]==[x['ram'] for x in expected],
                          'keys': [x['pressed'] for x in actual]==[x['pressed'] for x in expected],
                          # The first returned native framebuffer is stale after
                          # restore; existing production transport holds it.
                          'fresh_video': [x['video'] for x in actual[1:]]==[x['video'] for x in expected[1:]],
                          'first_ram_divergence':next((i for i,(a,b) in enumerate(zip(actual,expected)) if a['ram']!=b['ram']),None)}
            print(name, json.dumps(checks[name]),flush=True)
        supervisor=supervisor_matrix(args.output)
        print('supervisor',json.dumps(supervisor),flush=True)
    finally:
        (args.output/'report.json').write_text(json.dumps({'checks':checks,
            'supervisor':supervisor,
            'passed':bool(supervisor) and all(supervisor.values()) and len(checks)==len(CASES) and all(c['ram'] and c['keys'] and c['fresh_video'] for c in checks.values()),
            'scope':'Same serialized boundary, uninterrupted versus fresh-process native continuation. Physical key sets change through production host callback. No guest memory mutation.'},indent=2)+'\n')
    return 0 if all(c['ram'] and c['keys'] and c['fresh_video'] for c in checks.values()) else 1

if __name__=='__main__':raise SystemExit(main())
