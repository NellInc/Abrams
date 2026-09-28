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
        result = client.request('save_state',slot=1)
        assert result['success'], result
        saved_audit = held['frame_audit']
        checks['save_has_no_display_advance'] = result['restored']['frame_audit'] == saved_audit and result['restored']['sequence'] == held['sequence']
        held_transition = client.step(1,['kp6'])
        checks['stale_native_frame_is_held'] = held_transition.get('held_frame') is True and held_transition['frame_audit'] == saved_audit
        expected = []
        for index in range(12): expected.append(client.step(1, ['kp6'] if index < 3 else [])['frame_audit'])
        changed = client.step(30)
        result = client.request('load_state',slot=1)
        assert result['success'],result
        checks['load_has_no_display_advance'] = result['restored']['frame_audit'] == saved_audit
        recovery_bytes = (saves/'states/slot-0.zip').read_bytes()
        checks['recovery_saved_current_timeline'] = json.loads(zipfile.ZipFile(io.BytesIO(recovery_bytes)).read('resume.json'))['packet']['frame_audit'] == changed['frame_audit']
        client.step(1,['kp6'])
        actual = [client.step(1,['kp6'] if i < 3 else [])['frame_audit'] for i in range(12)]
        checks['held_then_released_keys_repeat_identically'] = actual == expected
        # A whole new supervisor proves persistence across application restarts.
        client.close(); client = Client(saves,log)
        result = client.request('load_state',slot=1)
        assert result['success'],result
        checks['cross_process_reload'] = result['restored']['frame_audit'] == saved_audit
        client.step(1,['kp6'])
        actual = [client.step(1,['kp6'] if i < 3 else [])['frame_audit'] for i in range(12)]
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
            'scope':'Native RAM and disk persistence; held-frame transition explicitly excluded from fresh-video claims. Trace ownership is reacquired from observed original draws.'},indent=2)+'\n')
    print(json.dumps(checks,indent=2))
    return 0 if all(checks.values()) else 1

if __name__=='__main__': raise SystemExit(main())
