#!/usr/bin/env python3
"""Capture actual original render passes with a separately pinned tracing core.

The native callback observes guest registers/RAM in-place and only copies data
out. The host never writes guest memory. Baseline mode checks the same source
build without hooks; both modes retain full-RAM/framebuffer hashes per frame.
"""
from __future__ import annotations
import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path
import struct

try:
    from tools.pc_reference_core import PcReferenceCore, CORE_SHA256
    from tools.pc_live_state import SimStateReader
    from tools.pc_vehicle_math import compose, object_matrix, orientation_mode, primitive_camera_vertices
    from tools.inspect_shapes import inspect_shapes
    from tools.inspect_scenarios import decode_resource
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore, CORE_SHA256
    from pc_live_state import SimStateReader
    from pc_vehicle_math import compose, object_matrix, orientation_mode, primitive_camera_vertices
    from inspect_shapes import inspect_shapes
    from inspect_scenarios import decode_resource

ROOT = Path(__file__).resolve().parents[1]
CALLBACK = C.CFUNCTYPE(None, C.c_uint32, C.POINTER(C.c_uint16), C.c_void_p, C.c_uint32, C.c_uint32)


class Collector:
    def __init__(self, reader, output):
        self.reader, self.output = reader, output
        self.active = None
        self.passes = []
        self.error = None
        self.sequence = 0
        self.vertices_checked = 0
        self.shapes = inspect_shapes(decode_resource((ROOT / 'GAME/SHAPE.TBL').read_bytes()))['shapes']
        self.callback = CALLBACK(self.observe)

    def observe(self, event, registers, data, offset, length):
        try:
            raw = C.string_at(data, length)
            regs = dict(zip(('ax','bx','cx','dx','si','di','bp','sp','cs','ds','es','ss'), registers[:12]))
            def word(at): return struct.unpack_from('<H', raw, at - offset)[0]
            def words(at, n): return list(struct.unpack_from('<' + 'h' * n, raw, at - offset))
            def byte(at): return raw[at - offset]
            if event == 1:
                self.sequence += 1
                state = self.reader.read(raw)
                if not state or not state['camera']: raise ValueError('draw-start snapshot lacks supported camera')
                state['camera']['sampling'] = 'observed at original drawing callback entry; not a logic-tick claim'
                ds = state['load_segment'] * 16 + 0x19E00
                self.sine = list(struct.unpack_from('<256h', raw, ds + 0x1D9C))
                self.cosine = list(struct.unpack_from('<256h', raw, ds + 0x1E1C))
                self.active = {'sequence': self.sequence, 'camera': state['camera'], 'objects': [],
                    'start_ram_sha256': hashlib.sha256(raw).hexdigest(), 'world': state['world']}
                if self.sequence == 1: (self.output / 'first-render.bin').write_bytes(raw)
                self.current = None
                self.composition_cx = None
                return
            if self.active is None: return
            if event == 5:
                self.composition_cx = regs['cx']
            elif event == 2:
                pointer = word(0x12CC)
                obj = next(o for name in ('static','dynamic') for o in self.active['world'][name] if o['pointer'] == pointer)
                matrix = words(word(0x1CDA), 9)
                self.current = {'pointer': pointer, 'shape_index': obj['shape_index'], 'root': regs['di'],
                    'dynamic_instance': any(o['pointer'] == pointer for o in self.active['world']['dynamic']),
                    'static_path': byte(0x1CDF), 'matrix_mode': byte(0x1CDE), 'matrix': matrix,
                    'view_origin': words(0x1426, 3), 'world_delta': words(0x142C, 3),
                    'packed_shift': byte(0x1425), 'composition_cx': self.composition_cx,
                    'primitive_ids': [], 'polygons': []}
                if not self.current['static_path']:
                    basis = object_matrix(obj['orientation_u8'], self.sine, self.cosine)
                    expected, mode = compose(basis, orientation_mode(obj['orientation_u8']),
                        self.active['camera']['matrix_q14_columns'], self.active['camera']['matrix_mode'], self.composition_cx)
                    if (expected, mode) != (matrix, self.current['matrix_mode']):
                        raise ValueError(f'actual live original composition mismatch for {pointer:#x}')
                self.active['objects'].append(self.current)
                self.composition_cx = None
            elif event == 3 and self.current:
                self.current['primitive_ids'].append(regs['si'])
            elif event == 6 and self.current:
                count = word(0x1A69)
                if not 0 <= count <= 16: raise ValueError('unsupported polygon buffer length')
                shape = self.shapes[self.current['shape_index']]
                primitive_id = self.current['primitive_ids'][-1] if self.current['primitive_ids'] else None
                primitive = next(p for p in shape['primitives'] if p['offset'] == primitive_id)
                vertices = primitive_camera_vertices(shape, primitive, self.current)
                for encoded, expected in zip(primitive['encoded_indices'], vertices):
                    index = (encoded & 127) * 2
                    actual = [words(at + index, 1)[0] for at in (0x1519, 0x1619, 0x1719)]
                    if actual != expected: raise ValueError(f'original vertex differs for shape {shape["index"]}, ref {encoded}: {actual} != {expected}')
                    self.vertices_checked += 1
                self.current['polygons'].append({'primitive': self.current['primitive_ids'][-1] if self.current['primitive_ids'] else None,
                    'colors': [byte(0x359E), byte(0x359D)],
                    'camera_vertices': vertices,
                    'pixels': list(map(list, zip(words(0x1A29, count), words(0x1A49, count))))})
            elif event == 4:
                self.passes.append(self.active)
                self.active = None
        except Exception as error:
            self.error = error
            self.active = None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['trace','baseline','reference'], default='trace')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--frames', type=int, default=180)
    parser.add_argument('--state', type=Path, default=ROOT / 'reference/pc-live/mission-entry/reference.state')
    parser.add_argument('--state-core-sha256', default=CORE_SHA256)
    args = parser.parse_args()
    if not 1 <= args.frames <= 3000: parser.error('frames must be 1..3000')
    if args.output.resolve().is_relative_to((ROOT / 'GAME').resolve()): parser.error('output must be outside original GAME')
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((ROOT / '.runtime/pc-core/abrams-trace.json').read_text())
    if args.mode == 'reference':
        library, pin = ROOT / '.runtime/pc-core/dosbox_pure_libretro.dylib', CORE_SHA256
    else:
        library = ROOT / '.runtime/pc-core' / ('abrams-trace.dylib' if args.mode == 'trace' else 'source-baseline.dylib')
        pin = manifest[args.mode + '_sha256']
    reader = SimStateReader(ROOT / 'GAME/SIM.EXE')
    collector = Collector(reader, args.output)
    core = PcReferenceCore(library, ROOT / '.runtime/pc-core/abrams-ref.zip', args.output / 'saves', expected_sha256=pin)
    frames = []
    try:
        core.run(240)
        core.restore(args.state, expected_source_sha256=args.state_core_sha256)
        core.run(1)
        core.pause_at_frame_end()
        state = reader.read(core.conventional_memory())
        if state is None: raise ValueError('restored state lacks the fingerprinted original SIM')
        if args.mode == 'trace':
            core.core.abrams_trace_configure.argtypes = [C.c_uint16, CALLBACK]
            core.core.abrams_trace_configure.restype = None
            core.core.abrams_trace_configure(state['load_segment'], collector.callback)
        for i in range(args.frames):
            keys = ['c'] if i < 3 else ['kp6'] if 30 <= i < 90 else []
            core.run(1, keys)
            if collector.error: raise collector.error
            frames.append({'index': i, 'keys': keys, 'ram_sha256': hashlib.sha256(core.last_video_ram).hexdigest(),
                'video_sha256': hashlib.sha256(core.last_video[0]).hexdigest()})
        core.screenshot().save(args.output / 'last-frame.png')
        result = {'mode': args.mode, 'core_sha256': pin, 'source_commit': manifest['commit'], 'frames': frames,
            'state_sha256': hashlib.sha256(args.state.read_bytes()).hexdigest(),
            'state_core_sha256': args.state_core_sha256, 'trace_header_sha256': manifest['trace_header_sha256'],
            'original_vertices_checked': collector.vertices_checked,
            'render_passes': collector.passes, 'incomplete_pass_at_stop': collector.active is not None,
            'scope': 'actual original normal-core instruction hooks; no guest writes; compare baseline/reference hashes separately'}
        (args.output / 'report.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({'mode': args.mode, 'frames': len(frames), 'render_passes': len(collector.passes),
            'dynamic_contexts': sum(o['dynamic_instance'] for p in collector.passes for o in p['objects'])}))
    finally:
        core.pause_at_frame_end()
        if args.mode == 'trace': core.core.abrams_trace_configure(0, collector.callback)
        core.close()


if __name__ == '__main__': main()
