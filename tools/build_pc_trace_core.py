#!/usr/bin/env python3
"""Build a separately pinned read-only tracing core from a reviewed source tree.

This patches only the local dependency, retaining the unmodified baseline dylib.
No download, game-file write, publication or change to the default core pin.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = '73e03aa145e0549ed4d5a20f8e65532714da33f5'
SOURCE = ROOT / '.runtime/dosbox-pure-source'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip() != UPSTREAM:
        raise ValueError('unreviewed DOSBox Pure source revision')
    status = subprocess.check_output(['git', '-C', str(SOURCE), 'status', '--porcelain', '--untracked-files=all'], text=True)
    allowed = {' M src/cpu/core_normal.cpp', '?? src/cpu/abrams_trace.h'}
    if any(line not in allowed for line in status.splitlines()):
        raise ValueError('preserve unrecognized dependency changes; source build is not the reviewed input')
    target = SOURCE / 'src/cpu/core_normal.cpp'
    original = subprocess.check_output(['git', '-C', str(SOURCE), 'show', 'HEAD:src/cpu/core_normal.cpp'], text=True)
    changed = original.replace('Bits CPU_Core_Normal_Run(void) {', '#include "abrams_trace.h"\n\nBits CPU_Core_Normal_Run(void) {', 1)
    changed = changed.replace('\twhile (CPU_Cycles-->0) {\n\t\tLOADIP;', '\twhile (CPU_Cycles-->0) {\n\t\tAbramsTraceInstruction();\n\t\tLOADIP;', 1)
    if changed.count('AbramsTraceInstruction();') != 1 or changed.count('#include "abrams_trace.h"') != 1:
        raise ValueError('unexpected normal-core structure')
    if target.read_text() not in (original, changed): raise ValueError('preserve unrecognized dependency edits')
    baseline = ROOT / '.runtime/pc-core/source-baseline.dylib'
    if not baseline.exists(): raise ValueError('build and retain unmodified source-baseline.dylib first')
    header = ROOT / 'tools/pc_core/abrams_trace.h'
    shutil.copyfile(header, target.with_name('abrams_trace.h'))
    target.write_text(changed)
    subprocess.run(['make', '-C', str(SOURCE), '-j4'], check=True)
    output = ROOT / '.runtime/pc-core/abrams-trace.dylib'
    shutil.copyfile(SOURCE / 'dosbox_pure_libretro.dylib', output)
    manifest = {'schema': 1, 'upstream': 'https://github.com/schellingb/dosbox-pure', 'commit': UPSTREAM,
        'source_core_normal_sha256': hashlib.sha256(original.encode()).hexdigest(),
        'patched_core_normal_sha256': sha(target), 'trace_header_sha256': sha(header),
        'baseline_sha256': sha(baseline), 'trace_sha256': sha(output),
        'build': ['make', '-j4'], 'compiler': subprocess.check_output(['c++', '--version'], text=True).splitlines()[0],
        'license': 'GPL-2.0-or-later; upstream LICENSE and notices retained in source checkout',
        'scope': 'local research, normal CPU core only; no guest state writes; parity requires separate tests'}
    output.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__': main()
