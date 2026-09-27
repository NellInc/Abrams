"""Read-only original draw collection and EGA scanout/page attribution.

The live path retains bounded history. Guest writes and replacement simulation
are deliberately absent. Video tags follow the core's triple-buffer slots.
"""
from __future__ import annotations
from collections import deque
import ctypes as C
import hashlib
from pathlib import Path
import struct

try:
    from tools.pc_vehicle_math import compose, object_matrix, orientation_mode, primitive_camera_vertices
    from tools.inspect_shapes import inspect_shapes
    from tools.inspect_scenarios import decode_resource
except ModuleNotFoundError:
    from pc_vehicle_math import compose, object_matrix, orientation_mode, primitive_camera_vertices
    from inspect_shapes import inspect_shapes
    from inspect_scenarios import decode_resource

ROOT = Path(__file__).resolve().parents[1]
CALLBACK = C.CFUNCTYPE(None, C.c_uint32, C.POINTER(C.c_uint16), C.c_void_p, C.c_uint32, C.c_uint32)


class Collector:
    def __init__(self, reader, output=None, *, history_limit=3000):
        self.reader, self.output = reader, output
        self.active = None
        self.passes = deque(maxlen=history_limit)
        self.completed_count = 0
        self.pages = {}
        self.drawing_pages = set()
        self.scanout = None
        self.buffers = {}
        self.presented = None
        self.scanout_sequence = 0
        self.current = None
        self.composition_cx = None
        self.error = None
        self.sequence = 0
        self.vertices_checked = 0
        self.shapes = inspect_shapes(decode_resource((ROOT / 'GAME/SHAPE.TBL').read_bytes()))['shapes']
        self.callback = CALLBACK(self.observe)

    def observe(self, event, registers, data, offset, length):
        try:
            raw = C.string_at(data, length)
            if event in (10, 11, 12):
                self.observe_video(event, offset, raw, registers)
                return
            regs = dict(zip(('ax','bx','cx','dx','si','di','bp','sp','cs','ds','es','ss'), registers[:12]))
            def word(at): return struct.unpack_from('<H', raw, at - offset)[0]
            def words(at, n): return list(struct.unpack_from('<' + 'h' * n, raw, at - offset))
            def byte(at): return raw[at - offset]
            if event == 13:
                page = (word(0x35A8) - 0xA000) * 16
                self.pages.pop(page, None)
                self.drawing_pages.add(page)
                if self.scanout and self.scanout['page_offset'] == page:
                    self.scanout['draw_pass'] = None
                    self.scanout['reason'] = 'displayed page redrawn during scanout'
                return
            if event == 9:
                return  # page-register write is observed; scanout latch is authoritative
            if event == 1:
                if self.active is not None: raise ValueError('nested original draw pass')
                self.sequence += 1
                state = self.reader.read(raw)
                if not state or not state['camera']: raise ValueError('draw-start snapshot lacks supported camera')
                state['camera']['sampling'] = 'observed at original drawing callback entry; not a logic-tick claim'
                ds = state['load_segment'] * 16 + 0x19E00
                self.sine = list(struct.unpack_from('<256h', raw, ds + 0x1D9C))
                self.cosine = list(struct.unpack_from('<256h', raw, ds + 0x1E1C))
                self.active = {'sequence': self.sequence, 'camera': state['camera'], 'objects': [],
                    'start_ram_sha256': hashlib.sha256(raw).hexdigest(), 'world': state['world'],
                    'page_offset': (struct.unpack_from('<H', raw, ds + 0x35A8)[0] - 0xA000) * 16,
                    'unsupported': []}
                if self.sequence == 1 and self.output: (self.output / 'first-render.bin').write_bytes(raw)
                self.current = None
                self.composition_cx = None
                return
            if self.active is None: return
            if event == 7:
                # Every root resets context, including sprite-only roots which
                # never execute the matrix-ready hook.
                self.current = None
                self.composition_cx = None
                if raw[0] & 128:
                    self.active['unsupported'].append({'kind': 'sprite_root', 'pointer': regs['bx'],
                        'root': regs['di'], 'command': list(raw)})
            elif event == 8:
                self.active['unsupported'].append({'kind': 'opaque_command', 'command_offset': regs['di'],
                    'pointer': self.current['pointer'] if self.current else None, 'command': list(raw)})
            elif event == 5:
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
            elif event == 6:
                self.active['unsupported'].append({'kind': 'unattributed_polygon'})
            elif event == 4:
                self.passes.append(self.active)
                self.completed_count += 1
                self.pages[self.active['page_offset']] = self.active
                self.drawing_pages.discard(self.active['page_offset'])
                self.active = None
        except Exception as error:
            self.error = error
            self.active = None


    def observe_video(self, event, slot_or_page, raw, registers):
        if event == 10:
            self.scanout_sequence += 1
            page = slot_or_page
            drawing = self.pages.get(page) if page not in self.drawing_pages else None
            self.scanout = {'scanout_sequence': self.scanout_sequence, 'page_offset': page,
                'draw_pass': drawing, 'reason': None if drawing else 'no complete observed pass for scanned page'}
        elif event == 11:
            if slot_or_page not in range(3): raise ValueError('unknown core framebuffer slot')
            self.buffers[slot_or_page] = self.scanout
            self.scanout = None
        elif event == 12:
            if slot_or_page not in range(3): raise ValueError('unknown core framebuffer slot')
            frame = self.buffers.get(slot_or_page)
            width, height = registers[0], registers[1]
            if not 1 <= width <= 2048 or not 1 <= height <= 2048 or len(raw) != width * height * 4:
                raise ValueError('unsupported traced framebuffer dimensions')
            self.presented = {**(frame or {'draw_pass': None, 'reason': 'unobserved framebuffer'}),
                'buffer_slot': slot_or_page, 'video_sha256': hashlib.sha256(raw).hexdigest(),
                'width': width, 'height': height}

    def paired_video(self, video):
        if self.error: raise self.error
        if not self.presented: return {'draw_pass': None, 'reason': 'waiting for observed framebuffer'}
        raw, width, height, pitch = video
        if (width, height, pitch) != (self.presented['width'], self.presented['height'], width * 4):
            raise ValueError('traced and libretro framebuffer dimensions differ')
        if hashlib.sha256(raw).hexdigest() != self.presented['video_sha256']:
            raise ValueError('traced and libretro framebuffer bytes differ')
        return self.presented

    def attach(self, core, load_segment):
        core.pause_at_frame_end()
        core.core.abrams_trace_configure.argtypes = [C.c_uint16, CALLBACK]
        core.core.abrams_trace_configure.restype = None
        core.core.abrams_trace_configure(load_segment, self.callback)

    def detach(self, core):
        core.pause_at_frame_end()
        core.core.abrams_trace_configure(0, self.callback)
