"""Read-only original draw collection and EGA scanout/page attribution.

The live path retains bounded history. Guest writes and replacement simulation
are deliberately absent. Video tags follow the core's triple-buffer slots.
"""
from __future__ import annotations
from collections import deque
import base64
import ctypes as C
import hashlib
import io
from pathlib import Path
import struct
from PIL import Image

try:
    from tools.pc_vehicle_math import compose, object_matrix, orientation_mode, primitive_camera_vertices
    from tools.inspect_shapes import inspect_shapes
    from tools.inspect_scenarios import decode_resource
    from tools.pc_materials import read_materials
    from tools.pc_bitmaps import decode_bitmaps, read_ega_bitmap, verify_loaded_effects
    from tools.pc_audio_events import AudioEvents
    from tools.pc_text_trace import TextRuns
    from tools.pc_plate_trace import PlateLoads, PLATE_IDS
except ModuleNotFoundError:
    from pc_vehicle_math import compose, object_matrix, orientation_mode, primitive_camera_vertices
    from inspect_shapes import inspect_shapes
    from inspect_scenarios import decode_resource
    from pc_materials import read_materials
    from pc_bitmaps import decode_bitmaps, read_ega_bitmap, verify_loaded_effects
    from pc_audio_events import AudioEvents
    from pc_text_trace import TextRuns
    from pc_plate_trace import PlateLoads, PLATE_IDS

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
        self.ui_mask_slot = None
        self.plate_mask_slot = None
        self.scanout_ui_bits = b''
        self.buffers = {}
        self.presented = None
        self.scanout_sequence = 0
        self.current = None
        self.composition_cx = None
        self.palette_rgb = None
        self.backgrounds = {}
        self.background_page = None
        self.error = None
        self.sequence = 0
        self.audio = AudioEvents()
        self.text = TextRuns(ROOT / "GAME")
        self.plates = PlateLoads(ROOT / 'GAME')
        self.vertices_checked = 0
        self.effects = decode_bitmaps(decode_resource((ROOT / 'GAME/EFFECTS.BMP').read_bytes()))
        self.effect_pixels_checked = 0
        self.shapes = inspect_shapes(decode_resource((ROOT / 'GAME/SHAPE.TBL').read_bytes()))['shapes']
        self.callback = CALLBACK(self.observe)

    def observe(self, event, registers, data, offset, length):
        try:
            raw = C.string_at(data, length)
            if event == 25:
                self.audio.observe(raw, text_sequence=self.text.sequence)
                return
            if event in (10, 11, 12, 19, 24):
                self.observe_video(event, offset, raw, registers)
                return
            regs = dict(zip(('ax','bx','cx','dx','si','di','bp','sp','cs','ds','es','ss'), registers[:12]))
            if event == 26:
                self.text.begin(raw, regs)
                return
            if event == 27:
                self.text.finish(raw)
                return
            if event in (20, 21, 22):
                self.plates.observe(event, raw, regs['ax'])
                return
            if event == 23: raise ValueError(f'unsupported native plate observation: {offset}')
            def word(at): return struct.unpack_from('<H', raw, at - offset)[0]
            def words(at, n): return list(struct.unpack_from('<' + 'h' * n, raw, at - offset))
            def byte(at): return raw[at - offset]
            if event == 14:
                if len(raw) != 64: raise ValueError('unsupported palette snapshot')
                self.palette_rgb = [list(raw[i:i + 3]) for i in range(0, 64, 4)]
                return
            if event == 13:
                page = (word(0x35A8) - 0xA000) * 16
                self.pages.pop(page, None)
                self.drawing_pages.add(page)
                self.background_page = page
                self.backgrounds[page] = None
                if self.scanout and self.scanout['page_offset'] == page:
                    self.scanout['draw_pass'] = None
                    self.scanout['reason'] = 'displayed page redrawn during scanout'
                return
            if event == 15:
                upper, lower = struct.unpack('<HH', raw)
                self.backgrounds[self.background_page] = {'kind': 'horizon',
                    'line': [[regs['si'], regs['di']], [regs['bx'], regs['cx']]],
                    'colors': [upper & 255, lower & 255]}
                return
            if event == 16:
                self.backgrounds[self.background_page] = {'kind': 'solid', 'color': regs['dx'] & 255}
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
                self.active['materials'] = read_materials(raw, ds)
                self.active['palette_rgb'] = self.palette_rgb
                self.active['background'] = self.backgrounds.get(self.active['page_offset'])
                if self.sequence == 1:
                    loaded = verify_loaded_effects(raw, ds, self.effects)
                    self.effect_pixels_checked = sum(p['width'] * p['height'] for p in loaded)
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
                    obj = next(o for name in ('static', 'dynamic') for o in self.active['world'][name]
                               if o['pointer'] == regs['bx'])
                    self.current = {'kind': 'sprite', 'pointer': regs['bx'], 'root': regs['di'],
                        'shape_index': obj['shape_index'], 'bitmap_index': raw[1], 'sprite_status': 'pending',
                        'dynamic_instance': any(o['pointer'] == regs['bx'] for o in self.active['world']['dynamic']),
                        'polygons': []}
                    self.active['objects'].append(self.current)
            elif event == 17:
                if not self.current or self.current.get('kind') != 'sprite':
                    self.active['unsupported'].append({'kind': 'unattributed_bitmap'})
                    return
                ds, stack = regs['ds'] * 16, regs['ss'] * 16 + regs['bp']
                index, x, y = struct.unpack_from('<Hhh', raw, stack + 6)
                if index != self.current['bitmap_index'] or index >= len(self.effects):
                    raise ValueError('original bitmap selection differs from root')
                source = self.effects[index]
                bitmap = read_ega_bitmap(raw, ds, regs['bx'])
                if any(bitmap[k] != source[k] for k in ('width', 'height', 'pixels')):
                    raise ValueError('observed bitmap differs from source resource')
                if bitmap['opaque'] != [p != 0 for p in source['pixels']]:
                    raise ValueError('observed bitmap transparency differs from source resource')
                if raw[ds + 0x359F] != 15:
                    self.current['sprite_status'] = 'unsupported-plane-mask'
                    self.active['unsupported'].append({'kind': 'bitmap_plane_mask', 'value': raw[ds + 0x359F]})
                    return
                clip = list(struct.unpack_from('<4h', raw, ds + 0x3593))
                # The driver's clip storage is left/right/top/bottom.
                self.current['sprite'] = bitmap | {'index': index, 'origin': [x, y],
                    'clip': [clip[0], clip[2], clip[1], clip[3]]}
                self.current['sprite_status'] = 'observed'
            elif event == 18:
                if self.current and self.current.get('kind') == 'sprite' and self.current['sprite_status'] == 'pending':
                    self.current['sprite_status'] = 'rejected-before-blit'
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
            elif event == 3 and self.current and self.current.get('kind') != 'sprite':
                self.current['primitive_ids'].append(regs['si'])
            elif event == 6 and self.current and self.current.get('kind') != 'sprite':
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
                    'fill_mode': byte(0x359C),
                    'camera_vertices': vertices,
                    'pixels': list(map(list, zip(words(0x1A29, count), words(0x1A49, count))))})
            elif event == 6:
                self.active['unsupported'].append({'kind': 'unattributed_polygon'})
            elif event == 4:
                for obj in self.active.get('objects', []):
                    if obj.get('sprite_status') == 'pending':
                        self.active['unsupported'].append({'kind': 'incomplete_sprite', 'pointer': obj['pointer']})
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
            self.ui_mask_slot = None
            self.plate_mask_slot = None
            self.scanout_ui_bits = b''
            self.scanout_sequence += 1
            page = slot_or_page
            drawing = self.pages.get(page) if page not in self.drawing_pages else None
            self.scanout = {'scanout_sequence': self.scanout_sequence, 'page_offset': page,
                '_text_candidates': self.text.scanout(page),
                'draw_pass': drawing, 'reason': None if drawing else 'no complete observed pass for scanned page',
                'palette_rgb': [list(raw[i:i + 3]) for i in range(0, 64, 4)] if len(raw) == 64 else None}
        elif event == 19:
            if slot_or_page not in range(3): raise ValueError('unknown core framebuffer slot')
            if raw and len(raw) != 320 * 200: raise ValueError('unsupported UI mask dimensions')
            if any(v not in (0, 255) for v in raw): raise ValueError('invalid UI provenance mask')
            self.ui_mask_slot = slot_or_page
            self.scanout_ui_bits = raw
            if self.scanout:
                self.scanout['ui_overlay'] = None
                if raw:
                    png = io.BytesIO()
                    Image.frombytes('L', (320, 200), raw).save(png, format='PNG')
                    self.scanout['ui_overlay'] = {'width': 320, 'height': 200,
                        'mask_png': base64.b64encode(png.getvalue()).decode('ascii'),
                        'mask_sha256': hashlib.sha256(raw).hexdigest(), 'ui_pixels': raw.count(255),
                        'basis': 'EGA bit provenance sampled at original scanline time'}
        elif event == 24:
            if slot_or_page not in range(3): raise ValueError('unknown core framebuffer slot')
            if raw and len(raw) != 64000: raise ValueError('unsupported plate mask dimensions')
            if any(value > len(PLATE_IDS) for value in raw): raise ValueError('invalid plate provenance mask')
            if raw and (self.ui_mask_slot != slot_or_page or len(self.scanout_ui_bits) != 64000):
                raise ValueError('plate mask lacks paired UI provenance')
            if any(plate and ui != 255 for plate, ui in zip(raw,self.scanout_ui_bits)):
                raise ValueError('plate mask covers original world pixels')
            self.plate_mask_slot = slot_or_page
            if self.scanout:
                self.scanout['plate_overlay'] = None
                if raw:
                    png = io.BytesIO()
                    Image.frombytes('L', (320,200), raw).save(png, format='PNG')
                    self.scanout['plate_overlay'] = {'width':320, 'height':200,
                        'mask_png':base64.b64encode(png.getvalue()).decode('ascii'),
                        'mask_sha256':hashlib.sha256(raw).hexdigest(),
                        'plates':{str(i+1):{'source':name,'pixels':raw.count(i+1),
                            'source_sha256':self.plates.resources[name][1]} for i,name in enumerate(PLATE_IDS)},
                        'basis':'all four EGA bits retain the same source plate and original coordinate at scanout'}
        elif event == 11:
            if slot_or_page not in range(3): raise ValueError('unknown core framebuffer slot')
            if self.ui_mask_slot is not None and self.ui_mask_slot != slot_or_page:
                raise ValueError('UI mask and completed framebuffer slots differ')
            if self.plate_mask_slot is not None and self.plate_mask_slot != slot_or_page:
                raise ValueError('plate mask and completed framebuffer slots differ')
            self.buffers[slot_or_page] = self.scanout
            self.scanout = None
            self.ui_mask_slot = None
            self.plate_mask_slot = None
            self.scanout_ui_bits = b''
        elif event == 12:
            if slot_or_page not in range(3): raise ValueError('unknown core framebuffer slot')
            frame = self.buffers.get(slot_or_page)
            width, height = registers[0], registers[1]
            if not 1 <= width <= 2048 or not 1 <= height <= 2048 or len(raw) != width * height * 4:
                raise ValueError('unsupported traced framebuffer dimensions')
            visible = self.text.present((frame or {}).get('_text_candidates', ()), raw, width, height,
                                        (frame or {}).get('palette_rgb'))
            metadata = {k:v for k,v in (frame or {}).items() if k != '_text_candidates'}
            self.presented = {**(metadata or {'draw_pass': None, 'reason': 'unobserved framebuffer'}),
                'text_runs': visible,
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
        # A zero load segment only disables instruction hooks. VGA callbacks
        # must also be removed before this Python callback can be released.
        core.core.abrams_trace_configure(0, CALLBACK())
