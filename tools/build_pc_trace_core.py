#!/usr/bin/env python3
"""Build a separately pinned tracing and checkpoint core from reviewed source.

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
    allowed = {' M src/cpu/core_normal.cpp', '?? src/cpu/abrams_trace.h',
               ' M dosbox_pure_libretro.cpp', ' M src/hardware/vga_draw.cpp',
               ' M src/hardware/vga_memory.cpp', '?? src/cpu/abrams_vga_ownership.h',
               '?? src/cpu/abrams_plate_ownership.h', '?? src/cpu/abrams_observer_checkpoint.h', ' M src/dos/drives.h',
               ' M src/dos/drive_union.cpp', '?? src/dos/abrams_state_overlay.h'}
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
    ownership = ROOT / 'tools/pc_core/abrams_vga_ownership.h'
    shutil.copyfile(ownership, target.with_name(ownership.name))
    plates = ROOT / 'tools/pc_core/abrams_plate_ownership.h'
    shutil.copyfile(plates, target.with_name(plates.name))
    observer = ROOT / 'tools/pc_core/abrams_observer_checkpoint.h'
    shutil.copyfile(observer, target.with_name(observer.name))
    target.write_text(changed)
    state_overlay = ROOT / 'tools/pc_core/abrams_state_overlay.h'
    shutil.copyfile(state_overlay, SOURCE / 'src/dos/abrams_state_overlay.h')
    patches = {
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
            ('\telse\n\t\tvideo_cb(buf.video, view_width, view_height, view_width * 4);',
             '\telse {\n\t\tAbramsTraceVideoPresent((Bit32u)(&buf - dbp_buffers), (const Bit8u*)buf.video, view_width, view_height);\n'
             '\t\tvideo_cb(buf.video, view_width, view_height, view_width * 4);\n\t}')]
    }
    patch_hashes = {}
    extra = {
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
    patches['src/hardware/vga_memory.cpp'] = [
        ('#include "setup.h"', '#include "setup.h"\n'
         'extern "C" void AbramsTraceVgaRead(Bit32u address);\n'
         'extern "C" void AbramsTraceVgaWrite(Bit32u address, Bit8u value);'),
        ('\t\tvga.latch.d=((Bit32u*)vga.mem.linear)[start];',
         '\t\tvga.latch.d=((Bit32u*)vga.mem.linear)[start];\n\t\tAbramsTraceVgaRead((Bit32u)start);'),
        ('class VGA_UnchainedEGA_Handler : public VGA_UnchainedRead_Handler {\npublic:\n\tvoid writeHandler(PhysPt start, Bit8u val) {',
         'class VGA_UnchainedEGA_Handler : public VGA_UnchainedRead_Handler {\npublic:\n\tvoid writeHandler(PhysPt start, Bit8u val) {\n\t\tAbramsTraceVgaWrite((Bit32u)start, val);')]
    for name, replacements in patches.items():
        path = SOURCE / name
        before = subprocess.check_output(['git', '-C', str(SOURCE), 'show', 'HEAD:' + name], text=True)
        after = before
        for old, new in replacements:
            if after.count(old) != 1: raise ValueError('unexpected source anchor: ' + name)
            after = after.replace(old, new, 1)
        previous = after
        for old, new, count in extra.get(name, []):
            if after.count(old) != count: raise ValueError('unexpected ownership source anchor: ' + name)
            after = after.replace(old, new)
        if path.read_text() not in (before, previous, after): raise ValueError('preserve unrecognized edits: ' + name)
        path.write_text(after)
        patch_hashes[name] = {'original': hashlib.sha256(before.encode()).hexdigest(), 'patched': sha(path)}
    subprocess.run(['make', '-C', str(SOURCE), '-j4'], check=True)
    output = ROOT / '.runtime/pc-core/abrams-trace.dylib'
    # Existing local viewers may still map the previous inode. Replace atomically
    # rather than modifying bytes underneath a running process.
    staged=output.with_suffix('.next')
    shutil.copyfile(SOURCE / 'dosbox_pure_libretro.dylib', staged)
    staged.replace(output)
    manifest = {'schema': 2, 'audio_event_schema': 1, 'text_event_schema': 2, 'message_event_schema': 1, 'strut_event_schema': 1, 'driver_overlay_schema': 1, 'state_overlay_schema': 1, 'observer_checkpoint_schema': 1, 'observer_checkpoint_header_sha256': sha(observer), 'state_overlay_header_sha256': sha(state_overlay), 'video_patch_hashes': patch_hashes, 'upstream': 'https://github.com/schellingb/dosbox-pure', 'commit': UPSTREAM,
        'source_core_normal_sha256': hashlib.sha256(original.encode()).hexdigest(),
        'patched_core_normal_sha256': sha(target), 'trace_header_sha256': sha(header),
        'ownership_header_sha256': sha(ownership), 'motor_pool_plate_schema': 1, 'frontend_text_schema': 1, 'orientation_schema': 1,
        'plate_ownership_header_sha256': sha(plates),
        'baseline_sha256': sha(baseline), 'trace_sha256': sha(output),
        'build': ['make', '-j4'], 'compiler': subprocess.check_output(['c++', '--version'], text=True).splitlines()[0],
        'license': 'GPL-2.0-or-later; upstream LICENSE and notices retained in source checkout',
        'scope': 'local research, normal CPU trace; explicit checkpoint overlay flush/reload ABI 1; ordinary-run parity requires separate tests'}
    output.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__': main()
