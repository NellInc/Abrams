#!/usr/bin/env python3
"""Developer ID-sign an assembled Abrams app. Does not submit to Apple.

Use a new build, preserving previous apps for rollback. Credentials and the
private signing key stay in Keychain. All nested native code is signed first.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
ROOT_FOR_IMPORT = Path(__file__).resolve().parents[2]
if str(ROOT_FOR_IMPORT) not in sys.path: sys.path.insert(0, str(ROOT_FOR_IMPORT))
from tools.standalone.build import verify
from tools.standalone.runtime import sha
from tools.source_guard import inside_source

MACH_O = {b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}


def signing_targets(bundle):
    bundle = bundle.resolve()
    if bundle.suffix != '.app' or not (bundle/'Contents/Info.plist').is_file():
        raise ValueError('Expected an assembled .app bundle')
    native = set()
    containers = set()
    for path in bundle.rglob('*'):
        if path.is_symlink():
            if not path.resolve().is_relative_to(bundle):
                raise ValueError('External bundle symlink')
            continue
        if path.is_file():
            with path.open('rb') as stream:
                if stream.read(4) in MACH_O:
                    native.add(path)
        elif path.suffix in ('.framework', '.app'):
            containers.add(path)
    if not native:
        raise ValueError('Bundle contains no native code')
    # Re-seal frameworks/apps after their code and resources are signed. Never
    # use codesign --deep to sign: it cannot express this explicit ownership.
    return sorted(native, key=lambda p: (-len(p.parts), str(p))) + sorted(containers, key=lambda p: (-len(p.parts), str(p))) + [bundle]


def signature_details(path):
    result = subprocess.run(['codesign','--display','--verbose=4',str(path)],
                            check=True,capture_output=True,text=True)
    fields = result.stdout + result.stderr
    authorities = [line.split('=',1)[1] for line in fields.splitlines() if line.startswith('Authority=')]
    team = next((line.split('=',1)[1] for line in fields.splitlines() if line.startswith('TeamIdentifier=')), None)
    timestamp = next((line.split('=',1)[1] for line in fields.splitlines() if line.startswith('Timestamp=')), None)
    return {'developer_id': any(a.startswith('Developer ID Application:') for a in authorities),
            'team_id':team, 'secure_timestamp':timestamp,
            'hardened_runtime':'(runtime)' in fields, 'authorities':authorities}


def refresh_payload(bundle, before, team):
    resources = bundle/'Contents/Resources'
    manifest_path = resources/'RUNTIME.json'
    manifest = json.loads(manifest_path.read_text())
    core = resources/'kit/.runtime/pc-core/abrams-trace.dylib'
    receipt_path = core.with_suffix('.json')
    receipt = json.loads(receipt_path.read_text())
    # Signing changes Mach-O file bytes even though the executable text is
    # unchanged. The core loader pins the shipped bytes; the pre-signing
    # identity is recorded so the checkpoint store can key slots on code
    # identity rather than signed bytes. A repeat signing (e.g. a notarization
    # retry) must keep the first pre-signing identity, not the signed hash.
    receipt.setdefault('unsigned_trace_sha256', receipt['trace_sha256'])
    receipt['trace_sha256'] = sha(core)
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    for row in manifest['files']:
        path = resources/'kit'/row['path']
        row['sha256'] = sha(path)
        row['size'] = path.stat().st_size
    manifest['unsigned_build_id'] = before['build_id']
    manifest['build_id'] = hashlib.sha256(json.dumps({'unsigned_build_id':before['build_id'],
        'files':manifest['files'],'team':team},sort_keys=True).encode()).hexdigest()[:20]
    manifest['signing'] = {'developer_id':True,'team_id':team,'notarization':'pending'}
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')


def sign(bundle, identity, team):
    before = verify(bundle)
    targets = signing_targets(bundle)
    core = bundle/'Contents/Resources/kit/.runtime/pc-core/abrams-trace.dylib'
    original_text = subprocess.check_output(['otool','-s','__TEXT','__text',str(core)])
    for path in targets:
        if path == bundle:
            signed_text = subprocess.check_output(['otool','-s','__TEXT','__text',str(core)])
            if signed_text != original_text:
                raise ValueError('Core executable text changed during signing')
            refresh_payload(bundle,before,team)
        subprocess.run(['codesign','--force','--sign',identity,'--options','runtime',
                        '--timestamp',str(path)],check=True)
        details = signature_details(path)
        if not details['developer_id'] or details['team_id'] != team or not details['secure_timestamp'] or not details['hardened_runtime']:
            raise ValueError('Incomplete Developer ID signature: '+str(path))
    report = verify(bundle)
    report['signing'] = signature_details(bundle)
    report['notarization'] = 'pending, no submission made by this tool'
    report['signed_targets'] = len(targets)
    report['unsigned_build_id'] = before['build_id']
    report['core_executable_text_unchanged'] = True
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--app',type=Path,required=True)
    p.add_argument('--identity',required=True,help='Developer ID Application certificate name or SHA-1')
    p.add_argument('--team',required=True)
    p.add_argument('--report',type=Path,required=True)
    a = p.parse_args()
    if sys.platform != 'darwin':p.error('macOS signing tools are required')
    if a.report.exists():p.error('Use a new report path')
    if inside_source(a.report,a.app.resolve().parent,(a.app.resolve().name,)):p.error('Keep the report outside the sealed bundle')
    result = sign(a.app.resolve(),a.identity,a.team)
    a.report.parent.mkdir(parents=True,exist_ok=True)
    a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__ == '__main__':main()
