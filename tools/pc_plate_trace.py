"""Validate source plates against original SIM loader/driver observations.

This is a bounded content receipt, not a static/dynamic UI replacement mask.
Callback filenames only index a fixed local catalog, never filesystem paths.
"""
from collections import deque
import hashlib
import struct
try:
    from tools.pc_plate_oracle import PLATES
    from tools.inspect_scenarios import decode_resource
except ModuleNotFoundError:
    from pc_plate_oracle import PLATES
    from inspect_scenarios import decode_resource

PLATE_IDS = ('GPS.BIN', 'TC.BIN', 'AA.BIN', 'DRIVER.BIN', 'STATUS.BIN', 'IDENTIFY', 'FRAME')


class PlateLoads:
    def __init__(self, game, history_limit=32):
        self.resources = {}
        for name in PLATES + ('ATBASE.BIN', 'SCENE1.BIN', 'SCENE2.BIN'):
            source = (game / name).read_bytes()
            data = decode_resource(source)
            if len(data) != 32000: raise ValueError('unsupported catalog plate dimensions')
            self.resources[name] = (data, hashlib.sha256(source).hexdigest())
        self.active = None
        self.loads = deque(maxlen=history_limit)
        self.completed = 0
        self.orphan_chunks = 0

    def observe(self, event, raw, result=0):
        if event == 20:
            if self.active is not None: raise ValueError('nested original plate load')
            if not 1 < len(raw) <= 13 or raw[-1] != 0 or any(v < 32 or v > 126 for v in raw[:-1]):
                raise ValueError('unsupported original plate filename')
            name = raw[:-1].decode('ascii').upper()
            self.active = {'name': name, 'data': bytearray(), 'chunks': [], 'page': None}
        elif event == 21:
            if len(raw) < 12: raise ValueError('truncated plate chunk header')
            source_offset, source_segment, count, x, y, page = struct.unpack_from('<6H', raw)
            if count == 0 or count % 160 or len(raw) != count + 12 or x != 0 or y * 160 + count > 32000:
                raise ValueError('unsupported plate chunk geometry')
            if page not in (0xA000, 0xA200): raise ValueError('unsupported plate drawing page')
            if self.active is None:
                # A snapshot attachment may begin part-way through a loader.
                # Never convert a partial/unattributed stream into a receipt.
                self.orphan_chunks += 1
                return
            active = self.active
            if y * 160 != len(active['data']): raise ValueError('noncontiguous original plate chunks')
            if active['page'] is not None and active['page'] != page:
                raise ValueError('plate changed drawing page mid-load')
            active['page'] = page
            data = raw[12:]
            if active['name'] in self.resources:
                expected = self.resources[active['name']][0][y * 160:y * 160 + count]
                if data != expected: raise ValueError('original loader bytes differ from source plate: ' + active['name'])
            active['data'].extend(data)
            active['chunks'].append({'y': y, 'bytes': count, 'source_offset': source_offset,
                                     'source_segment': source_segment})
        elif event == 22:
            if self.active is None: return  # Unobserved load entry remains unverified.
            active, self.active = self.active, None
            known = active['name'] in self.resources
            if result == 1 and len(active['data']) != 32000:
                raise ValueError('successful original plate load is incomplete')
            record = {'name': active['name'], 'result': result, 'bytes': len(active['data']),
                      'page_offset': (active['page'] - 0xA000) * 16 if active['page'] else None,
                      'chunks': active['chunks'], 'decoded_sha256': hashlib.sha256(active['data']).hexdigest(),
                      'verified': result == 1 and known,
                      'source_sha256': self.resources[active['name']][1] if known else None}
            self.loads.append(record)
            self.completed += 1
        else:
            raise ValueError('unsupported original plate observation')

    def report(self):
        return {'completed_count': self.completed, 'loads': list(self.loads),
                'orphan_chunks': self.orphan_chunks, 'incomplete_load': self.active is not None,
                'scope': 'original file-loader bytes at packed-driver entry; no live pixel replacement attribution'}
