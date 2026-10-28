#!/usr/bin/env python3
"""Build a separately pinned tracing and checkpoint core from reviewed source.

This patches only the local dependency, retaining the unmodified baseline dylib.
No download, game-file write, publication or change to the default core pin.
"""
from __future__ import annotations
import hashlib
import argparse
import sys
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
try:
    from tools.source_guard import inside_source
    from tools.pc_trace_windows import WINDOW_BUNDLE_SCHEMAS
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from source_guard import inside_source
    from pc_trace_windows import WINDOW_BUNDLE_SCHEMAS

ROOT =Path(__file__).resolve().parents[1]
UPSTREAM = '73e03aa145e0549ed4d5a20f8e65532714da33f5'
SOURCE = ROOT / '.runtime/dosbox-pure-source'

# Upstream files the builder rewrites from HEAD. source_bundle imports
# PATCHED_SOURCES, so the corresponding-source archive cannot drift from it.
PATCHES = {
    'src/dbp_serialize.cpp': [
        ('\tar.version = 8;', '\tar.version = 9;'),
        ('ar.version > 8)', 'ar.version > 9)')],
    'src/dos/dos.cpp': [
        ('\t\t.Serialize(dos.internal_output);',
         '\t\t.Serialize(dos.internal_output);\n\n'
         '\t// Version 8 omitted the DOS calendar, although START uses it\n'
         '\t// to seed mission selection. Older states retain the boot date.\n'
         '\t// MODE_ZERO must preserve the initialized calendar.\n'
         '\tif (ar.version >= 9 && ar.mode != DBPArchive::MODE_ZERO)\n'
         '\t{\n'
         '\t\tBit16u year = dos.date.year;\n'
         '\t\tBit8u month = dos.date.month, day = dos.date.day;\n'
         '\t\tar.Serialize(year).Serialize(month).Serialize(day);\n'
         '\t\tif (ar.mode == DBPArchive::MODE_LOAD)\n'
         '\t\t{\n'
         '\t\t\tif (ar.had_error || year < 1980 || month == 0 || month > 12 ||\n'
         '\t\t\t    day == 0 || (day > DOS_DATE_months[month] &&\n'
         '\t\t\t    !(month == 2 && year % 4 == 0 && day == 29)))\n'
         '\t\t\t{ ar.had_error = DBPArchive::ERR_LAYOUT; return; }\n'
         '\t\t\tdos.date.year = year; dos.date.month = month; dos.date.day = day;\n'
         '\t\t}\n'
         '\t}')],
    'src/dos/drives.h': [
        ('class unionDrive : public DOS_Drive {\npublic:',
         'class unionDrive : public DOS_Drive {\npublic:\n\tbool AbramsReloadSave();\n\tbool AbramsFlushSave();')],
    'src/dos/drive_union.cpp': [
        ('DBP_SERIALIZE_SET_POINTER_LIST(PIC_EventHandler, unionDrive, unionDriveImpl::WriteSaveFile);',
         'DBP_SERIALIZE_SET_POINTER_LIST(PIC_EventHandler, unionDrive, unionDriveImpl::WriteSaveFile);\n\n#include "abrams_state_overlay.h"')],
    'src/hardware/vga_draw.cpp': [
        ('static void VGA_VerticalTimer(Bitu /*val*/) {',
         'extern "C" void AbramsTraceScanout(Bit32u page);\n\nstatic void VGA_VerticalTimer(Bitu /*val*/) {'),
        ('\tvga.draw.address = vga.config.real_start;',
         '\tAbramsTraceScanout((Bit32u)vga.config.real_start);\n\tvga.draw.address = vga.config.real_start;')],
    'dosbox_pure_libretro.cpp': [
        ('void GFX_EndUpdate(const Bit16u *changedLines)',
         'extern "C" void AbramsTraceVideoComplete(Bit32u slot);\n'
         'extern "C" void AbramsTraceVideoPresent(Bit32u slot, const Bit8u* pixels, Bit32u width, Bit32u height);\n\n'
         'void GFX_EndUpdate(const Bit16u *changedLines)'),
        ('\tbuffer_active = (buffer_active + 1) % 3;\n',
         '\tAbramsTraceVideoComplete((buffer_active + 1) % 3);\n\tbuffer_active = (buffer_active + 1) % 3;\n'),
        # Event 12 runs host observers, so deliver it at the frame fence: buf is
        # already chosen and the emulation thread has not yet been woken. The
        # pixels and slot match the later software video_cb submission.
        ('\tDBP_ThreadControl(skip_emulate ? TCM_RESUME_FRAME : TCM_NEXT_FRAME);',
         '\tif (!skip_emulate && !dbp_opengl_draw)\n'
         '\t\tAbramsTraceVideoPresent((Bit32u)(&buf - dbp_buffers), (const Bit8u*)buf.video, view_width, view_height);\n\n'
         '\tDBP_ThreadControl(skip_emulate ? TCM_RESUME_FRAME : TCM_NEXT_FRAME);')]
}
EXTRA = {
    'src/hardware/vga_draw.cpp': [
        ('static VGA_Line_Handler VGA_DrawLine;',
         'static VGA_Line_Handler VGA_DrawLine;\n'
         'extern "C" void AbramsTraceRasterLine(Bit32u address, Bit32u row, Bit32u width, Bit32u wrap_mask);\n'
         'static Bit8u* AbramsTraceDrawLine(Bitu address, Bitu line) {\n'
         '\tAbramsTraceRasterLine(address, vga.draw.lines_done, render.src.width, vga.draw.linear_mask);\n'
         '\treturn VGA_DrawLine(address, line);\n}\n', 1),
        ('Bit8u * data=VGA_DrawLine( vga.draw.address, vga.draw.address_line );',
         'Bit8u * data=AbramsTraceDrawLine( vga.draw.address, vga.draw.address_line );', 2),
        ('Bit8u * data=VGA_DrawLine(address, vga.draw.address_line );',
         'Bit8u * data=AbramsTraceDrawLine(address, vga.draw.address_line );', 1)]}
PATCHES['src/hardware/vga_memory.cpp'] = [
    ('#include "setup.h"', '#include "setup.h"\n'
     'extern "C" void AbramsTraceVgaRead(Bit32u address);\n'
     'extern "C" void AbramsTraceVgaWrite(Bit32u address, Bit8u value);'),
    ('\t\tvga.latch.d=((Bit32u*)vga.mem.linear)[start];',
     '\t\tvga.latch.d=((Bit32u*)vga.mem.linear)[start];\n\t\tAbramsTraceVgaRead((Bit32u)start);'),
    ('class VGA_UnchainedEGA_Handler : public VGA_UnchainedRead_Handler {\npublic:\n\tvoid writeHandler(PhysPt start, Bit8u val) {',
     'class VGA_UnchainedEGA_Handler : public VGA_UnchainedRead_Handler {\npublic:\n\tvoid writeHandler(PhysPt start, Bit8u val) {\n\t\tAbramsTraceVgaWrite((Bit32u)start, val);')]
PATCHED_SOURCES = frozenset(PATCHES)
# Exact output of an earlier reviewed builder, which may be re-patched in place
# (event 12 previously ran beside video_cb, after the worker had been woken).
SUPERSEDED = {'dosbox_pure_libretro.cpp': {'54683ef39f27e30f8895f541e79ea972ef3cec8e00489025de26f4b806be6fc2'}}
HEADERS = ('src/cpu/abrams_trace.h', 'src/cpu/abrams_vga_ownership.h',
           'src/cpu/abrams_plate_ownership.h', 'src/cpu/abrams_observer_checkpoint.h',
           'src/dos/abrams_state_overlay.h')
# libretro's explicit exports suppress MinGW auto-export. The reviewed observer
# ABI must remain visible, and GCC/pthread stay self-contained. The source
# bundle README repeats this when a receipt predates recorded build commands.
WINDOWS_LDFLAGS = 'LDFLAGS=-shared -static -Wl,--gc-sections -fno-ident -Wl,--export-all-symbols'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def recorded_source(source):
    # Receipts ship in packages; never record an absolute (home) path.
    try: return source.relative_to(ROOT).as_posix()
    except ValueError: return '<source>'


def compiler(source):
    # Report the C++ compiler make resolves for this Makefile, not whatever
    # `c++` is first on PATH. A failed query must not abort a finished build
    # before its receipt is written.
    cxx = os.environ.get('CXX', 'c++')
    try:
        database = subprocess.run(['make', '-C', str(source), '-pnq'], capture_output=True, text=True).stdout
        cxx = next((line.split('=', 1)[1].strip() for line in database.splitlines()
                    if line.startswith(('CXX = ', 'CXX := '))), cxx)
        return subprocess.check_output(shlex.split(cxx, posix=sys.platform != 'win32') + ['--version'],
                                       text=True, stderr=subprocess.STDOUT).splitlines()[0]
    except (OSError, subprocess.CalledProcessError, IndexError, ValueError):
        return 'unknown (' + cxx + ')'


def main():
    global SOURCE
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output-dir", type=Path, default=ROOT/".runtime/pc-core")
    args=parser.parse_args()
    if inside_source(args.output_dir, ROOT): parser.error('output must be outside original sources')
    SOURCE=args.source.resolve()
    suffix=".dll" if sys.platform == "win32" else ".dylib" if sys.platform == "darwin" else ".so"
    args.output_dir.mkdir(parents=True,exist_ok=True)
    if subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip() != UPSTREAM:
        raise ValueError('unreviewed DOSBox Pure source revision')
    status = subprocess.check_output(['git', '-C', str(SOURCE), 'status', '--porcelain', '--untracked-files=all'], text=True)
    allowed = ({' M ' + name for name in PATCHED_SOURCES | {'src/cpu/core_normal.cpp'}}
               | {'?? ' + name for name in HEADERS})
    if any(line not in allowed for line in status.splitlines()):
        raise ValueError('preserve unrecognized dependency changes; source build is not the reviewed input')
    target = SOURCE / 'src/cpu/core_normal.cpp'
    original = subprocess.check_output(['git', '-C', str(SOURCE), 'show', 'HEAD:src/cpu/core_normal.cpp'], text=True)
    changed = original.replace('Bits CPU_Core_Normal_Run(void) {', '#include "abrams_trace.h"\n\nBits CPU_Core_Normal_Run(void) {', 1)
    changed = changed.replace('\twhile (CPU_Cycles-->0) {\n\t\tLOADIP;', '\twhile (CPU_Cycles-->0) {\n\t\tAbramsTraceInstruction();\n\t\tLOADIP;', 1)
    if changed.count('AbramsTraceInstruction();') != 1 or changed.count('#include "abrams_trace.h"') != 1:
        raise ValueError('unexpected normal-core structure')
    if target.read_text() not in (original, changed): raise ValueError('preserve unrecognized dependency edits')
    baseline = args.output_dir / ('source-baseline'+suffix)
    if not baseline.exists(): raise ValueError('build and retain unmodified source-baseline.dylib first')
    header = ROOT / 'tools/pc_core/abrams_trace.h'
    shutil.copyfile(header, target.with_name('abrams_trace.h'))
    ownership = ROOT / 'tools/pc_core/abrams_vga_ownership.h'
    shutil.copyfile(ownership, target.with_name(ownership.name))
    plates = ROOT / 'tools/pc_core/abrams_plate_ownership.h'
    shutil.copyfile(plates, target.with_name(plates.name))
    observer = ROOT / 'tools/pc_core/abrams_observer_checkpoint.h'
    shutil.copyfile(observer, target.with_name(observer.name))
    target.write_text(changed, newline='\n')  # keep upstream LF bytes on Windows too
    state_overlay = ROOT / 'tools/pc_core/abrams_state_overlay.h'
    shutil.copyfile(state_overlay, SOURCE / 'src/dos/abrams_state_overlay.h')
    patch_hashes = {}
    for name, replacements in PATCHES.items():
        path = SOURCE / name
        before = subprocess.check_output(['git', '-C', str(SOURCE), 'show', 'HEAD:' + name], text=True)
        after = before
        for old, new in replacements:
            if after.count(old) != 1: raise ValueError('unexpected source anchor: ' + name)
            after = after.replace(old, new, 1)
        previous = after
        for old, new, count in EXTRA.get(name, []):
            if after.count(old) != count: raise ValueError('unexpected ownership source anchor: ' + name)
            after = after.replace(old, new)
        if (path.read_text() not in (before, previous, after)
                and sha(path) not in SUPERSEDED.get(name, ())): raise ValueError('preserve unrecognized edits: ' + name)
        path.write_text(after, newline='\n')
        patch_hashes[name] = {'original': hashlib.sha256(before.encode()).hexdigest(), 'patched': sha(path)}
    build_command=['make', '-C', str(SOURCE), '-j4']
    if sys.platform == 'win32':
        build_command += [WINDOWS_LDFLAGS]
    subprocess.run(build_command, check=True)
    output = args.output_dir / ('abrams-trace'+suffix)
    # Existing local viewers may still map the previous inode. Replace atomically
    # rather than modifying bytes underneath a running process. Every receipt
    # field is computed from the staged core before either file is replaced.
    staged=output.with_suffix('.next')
    staged_manifest=output.with_suffix('.json.next')
    shutil.copyfile(SOURCE / ('dosbox_pure_libretro'+suffix), staged)
    # The header sends SIM events 26/28/29 as AWB1 RAM window bundles
    # (tools/pc_trace_windows.py); the event schemas below declare that.
    manifest = {'schema': 2, 'round_form_event_schema': 1, 'audio_event_schema': 1, 'text_event_schema': WINDOW_BUNDLE_SCHEMAS[0], 'message_event_schema': WINDOW_BUNDLE_SCHEMAS[1], 'strut_event_schema': WINDOW_BUNDLE_SCHEMAS[2], 'driver_overlay_schema': 1, 'state_overlay_schema': 1, 'observer_checkpoint_schema': 1, 'observer_checkpoint_header_sha256': sha(observer), 'state_overlay_header_sha256': sha(state_overlay), 'video_patch_hashes': patch_hashes, 'upstream': 'https://github.com/schellingb/dosbox-pure', 'commit': UPSTREAM,
        'loop_diagnostic_schema': 1, 'ax_fire_context_schema': 1, 'native_save_format_version': 9,
        'source_core_normal_sha256': hashlib.sha256(original.encode()).hexdigest(),
        'patched_core_normal_sha256': sha(target), 'trace_header_sha256': sha(header),
        'ownership_header_sha256': sha(ownership), 'motor_pool_plate_schema': 1, 'frontend_text_schema': 1, 'frontend_scene_schema': 1, 'orientation_schema': 1,
        'plate_ownership_header_sha256': sha(plates),
        'baseline_sha256': sha(baseline), 'trace_sha256': sha(staged),
        'build': [recorded_source(SOURCE) if part == str(SOURCE) else part for part in build_command],
        'compiler': compiler(SOURCE),
        'license': 'GPL-2.0-or-later; upstream LICENSE and notices retained in source checkout',
        'scope': 'local research, normal CPU trace; explicit checkpoint overlay flush/reload ABI 1; ordinary-run parity requires separate tests'}
    staged_manifest.write_text(json.dumps(manifest, indent=2) + '\n')
    # Exact-core checkpoints and player slots stay bound to the core they were
    # saved with. Retain the outgoing core/receipt pair under its own hash so
    # activation is reversible (copy both back) instead of orphaning slots.
    if output.is_file() and sha(output) != manifest['trace_sha256']:
        retained = args.output_dir / 'previous' / sha(output)
        retained.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(output, retained / output.name)
        if output.with_suffix('.json').is_file():
            shutil.copyfile(output.with_suffix('.json'), retained / output.with_suffix('.json').name)
        print('retained previous core: ' + str(retained), file=sys.stderr)
    staged.replace(output)
    staged_manifest.replace(output.with_suffix('.json'))
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__': main()
