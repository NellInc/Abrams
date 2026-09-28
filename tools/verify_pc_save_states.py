#!/usr/bin/env python3
"""Native end-to-end checkpoint checks using original keyboard routes only."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def sha(raw): return hashlib.sha256(raw).hexdigest()

class Client:
    def __init__(self, directory, log):
        self.process = subprocess.Popen([sys.executable,str(ROOT/'tools/pc_bridge_host.py'),
            '--backend','trace','--saves',str(directory),'--frame-audit'],
            stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=log,text=True)
        self.counter = 0
        self.ready = self.read()
    def read(self):
        line = self.process.stdout.readline()
        if not line: raise RuntimeError('host exited without response')
        value = json.loads(line)
        if value['type'] == 'error': raise RuntimeError(value['message'])
        return value
    def request(self, op, **kwargs):
        self.counter += 1
        self.process.stdin.write(json.dumps({'op':op,'id':self.counter,**kwargs})+'\n')
        self.process.stdin.flush()
        value = self.read()
        assert value['id'] == self.counter
        return value
    def step(self, frames, keys=()): return self.request('step',frames=frames,keys=list(keys))
    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write('{"op":"quit"}\n'); self.process.stdin.flush()
        assert self.process.wait() == 0
        self.process.stdin.close(); self.process.stdout.close()

def rewrite(path, transform):
    with zipfile.ZipFile(path) as z: files = {n:z.read(n) for n in z.namelist()}
    transform(files)
    with zipfile.ZipFile(path,'w') as z:
        for name, raw in files.items(): z.writestr(name, raw)

def provenance(packet):
    presentation = packet.get('presentation') or {}
    return {name: (presentation.get(name) or {}).get('mask_sha256')
            for name in ('ui_overlay', 'plate_overlay', 'driver_overlay')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    saves = args.output/'saves'; saves.mkdir()
    sources = {str(p.relative_to(ROOT)):sha(p.read_bytes()) for d in ('GAME','GENESIS') for p in (ROOT/d).rglob('*') if p.is_file()}
    checks = {}
    log = (args.output/'native.log').open('w')
    client = Client(saves,log)
    try:
        checks['protocol4_preserved'] = client.ready['protocol'] == 4 and len(client.ready['slots']) == 6
        missing = client.request('load_state',slot=5)
        checks['empty_slot_nonfatal'] = missing['success'] is False and client.step(1)['type'] == 'sample'
        # The extra frame above is outside the deterministic input route.
        client.close(); client = Client(saves,log)
        for frames,keys in json.loads((ROOT/'godot/tests/fixtures/pc_boot_steps.json').read_text()): last = client.step(frames,keys)
        checks['original_sim_reached'] = last['program']['name'] == 'SIM'
        held = client.step(5,['kp6'])
        saved_provenance = provenance(held)
        checks['checkpoint_has_observed_cockpit'] = bool(saved_provenance['plate_overlay']) and any(
            p['pixels'] > 0 for p in held['presentation']['plate_overlay']['plates'].values())
        # An independent, uninterrupted native run is the reference, rather
        # than comparing two equally broken post-save observers.
        baseline = Client(args.output/'uninterrupted-saves', log)
        try:
            for frames, keys in json.loads((ROOT/'godot/tests/fixtures/pc_boot_steps.json').read_text()): baseline.step(frames, keys)
            baseline_held = baseline.step(5, ['kp6'])
            baseline.step(1, ['kp6'])
            uninterrupted = [baseline.step(1, ['kp6'] if i < 3 else []) for i in range(12)]
        finally:
            baseline.close()
        result = client.request('save_state',slot=1)
        assert result['success'], result
        saved_audit = held['frame_audit']
        checks['save_has_no_display_advance'] = result['restored']['frame_audit'] == saved_audit and result['restored']['sequence'] == held['sequence']
        held_transition = client.step(1,['kp6'])
        checks['stale_native_frame_is_held'] = held_transition.get('held_frame') is True and held_transition['frame_audit'] == saved_audit
        observed = [client.step(1, ['kp6'] if i < 3 else []) for i in range(12)]
        (args.output/'observer-continuation.json').write_text(json.dumps({
            'saved_boundary': held['frame_audit'], 'independent_boundary': baseline_held['frame_audit'],
            'uninterrupted': [{'native':p['frame_audit'],'provenance':provenance(p)} for p in uninterrupted],
            'after_save': [{'native':p['frame_audit'],'provenance':provenance(p)} for p in observed]},indent=2)+'\n')
        expected = [p['frame_audit'] for p in observed]
        # Independent cold boots already differ in RAM at the saved boundary
        # before any save; same-state native parity is checked separately.
        checks['save_video_matches_uninterrupted'] = [p['frame_audit']['video_sha256'] for p in observed] == [p['frame_audit']['video_sha256'] for p in uninterrupted]
        expected_provenance = [provenance(p) for p in uninterrupted]
        checks['save_provenance_matches_uninterrupted'] = [provenance(p) for p in observed] == expected_provenance
        checks['save_provenance_not_stale_packet'] = all(not p.get('held_frame') for p in observed)
        changed = client.step(30)
        result = client.request('load_state',slot=1)
        assert result['success'],result
        checks['load_has_no_display_advance'] = result['restored']['frame_audit'] == saved_audit
        recovery_bytes = (saves/'states/slot-0.zip').read_bytes()
        checks['recovery_saved_current_timeline'] = json.loads(zipfile.ZipFile(io.BytesIO(recovery_bytes)).read('resume.json'))['packet']['frame_audit'] == changed['frame_audit']
        client.step(1,['kp6'])
        replay = [client.step(1,['kp6'] if i < 3 else []) for i in range(12)]
        actual = [p['frame_audit'] for p in replay]
        checks['load_provenance_matches_uninterrupted'] = [provenance(p) for p in replay] == expected_provenance
        checks['held_then_released_keys_repeat_identically'] = actual == expected
        # Same native checkpoint with no observer is an exact-timeline control:
        # observer restoration must not change native input/RAM/video semantics.
        (saves/'states/slot-3.zip').write_bytes((saves/'states/slot-1.zip').read_bytes())
        def legacy_observer(files):
            files.pop('observer.bin')
            manifest=json.loads(files['manifest.json']); manifest['files'].pop('observer.bin')
            files['manifest.json']=json.dumps(manifest).encode()
        rewrite(saves/'states/slot-3.zip', legacy_observer)
        result=client.request('load_state',slot=3)
        assert result['success'],result
        client.step(1,['kp6'])
        no_observer=[client.step(1,['kp6'] if i<3 else [])['frame_audit'] for i in range(12)]
        checks['observer_restore_native_parity'] = no_observer == expected
        # A whole new supervisor proves persistence across application restarts.
        client.close(); client = Client(saves,log)
        result = client.request('load_state',slot=1)
        assert result['success'],result
        checks['cross_process_reload'] = result['restored']['frame_audit'] == saved_audit
        client.step(1,['kp6'])
        replay = [client.step(1,['kp6'] if i < 3 else []) for i in range(12)]
        actual = [p['frame_audit'] for p in replay]
        checks['cross_process_provenance_matches_uninterrupted'] = [provenance(p) for p in replay] == expected_provenance
        checks['cross_process_native_continuation'] = actual == expected
        original = (saves/'states/slot-1.zip').read_bytes()
        (saves/'states/slot-2.zip').write_bytes(original)
        rewrite(saves/'states/slot-2.zip', lambda files: files.update({'state.bin':b'corrupt'}))
        result = client.request('load_state',slot=2)
        checks['corruption_rejected_session_playable'] = not result['success'] and client.step(2)['type'] == 'sample'
        (saves/'states/slot-2.zip').write_bytes(original)
        def incompatible(files):
            manifest=json.loads(files['manifest.json']);manifest['compatibility']['core_sha256']='0'*64
            files['manifest.json']=json.dumps(manifest).encode()
        rewrite(saves/'states/slot-2.zip',incompatible)
        result=client.request('load_state',slot=2)
        checks['incompatible_rejected_session_playable'] = not result['success'] and client.step(2)['type']=='sample'
        # Valid container, deliberately invalid native bytes exercises rollback
        # after the disk has been replaced and the former worker has closed.
        (saves/'states/slot-2.zip').write_bytes(original)
        def invalid_native(files):
            files['state.bin']=b'invalid-native'
            manifest=json.loads(files['manifest.json']);manifest['files']['state.bin']={'size':len(files['state.bin']),'sha256':sha(files['state.bin'])}
            files['manifest.json']=json.dumps(manifest).encode()
        rewrite(saves/'states/slot-2.zip',invalid_native)
        result=client.request('load_state',slot=2)
        checks['native_rejection_rolls_back_playable'] = not result['success'] and bool(result.get('restored')) and client.step(2)['type']=='sample'
        client.close(); client = None
        # A campaign is authored and saved by the original START/SIM/END flow.
        campaign = args.output/'campaign'; campaign.mkdir()
        (campaign/'other-game.pure.zip').write_bytes(b'other-user-save')
        client=Client(campaign,log)
        for frames,keys in json.loads((ROOT/'godot/tests/fixtures/pc_campaign_steps.json').read_text())['new']: last=client.step(frames,keys)
        result=client.request('save_state',slot=1)
        assert result['success'],result
        with zipfile.ZipFile(campaign/'states/slot-1.zip') as z: disk=z.read('campaign.zip')
        with zipfile.ZipFile(io.BytesIO(disk)) as z:
            disk_members={name:sha(z.read(name)) for name in z.namelist()}
        checks['original_campaign_data_in_checkpoint'] = any(name.upper()!='SHELL' for name in disk_members)
        (args.output/'campaign-members.json').write_text(json.dumps(disk_members,indent=2)+'\n')
        client.close();client=None
        # Change the on-disk save between sessions, then restore its prior bytes.
        with zipfile.ZipFile(campaign/'abrams-ref.pure.zip','w') as z: z.writestr('SENTINEL.TXT',b'newer overlay')
        client=Client(campaign,log)
        result=client.request('load_state',slot=1)
        assert result['success'],result
        checks['campaign_overlay_restored_exactly']=(campaign/'abrams-ref.pure.zip').read_bytes()==disk
        checks['other_user_saves_untouched']=(campaign/'other-game.pure.zip').read_bytes()==b'other-user-save'
        with zipfile.ZipFile(campaign/'states/slot-0.zip') as z:
            with zipfile.ZipFile(io.BytesIO(z.read('campaign.zip'))) as overlay:
                checks['recovery_preserves_newer_disk']=overlay.read('SENTINEL.TXT')==b'newer overlay'
        checks['campaign_restore_playable']=client.step(30)['type']=='sample'
        client.close();client=None
        checks['original_sources_unchanged']=all(sha((ROOT/name).read_bytes())==digest for name,digest in sources.items())
    finally:
        if client: client.close()
        log.close()
        (args.output/'report.json').write_text(json.dumps({'checks':checks,'passed':all(checks.values()),
            'scope':'Native RAM/disk persistence and host-only EGA provenance continuation against an uninterrupted run; held-frame transition excluded from fresh-video claims.'},indent=2)+'\n')
    print(json.dumps(checks,indent=2))
    return 0 if all(checks.values()) else 1

if __name__=='__main__': raise SystemExit(main())
