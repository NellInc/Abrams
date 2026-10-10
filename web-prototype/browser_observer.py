"""Browser-side reuse of the desktop PC source observers under Pyodide.

All file inputs are the visitor's manifest-verified originals, staged only in
the tab's virtual filesystem. Native callback receipts are matched before a
SIM presentation is returned to the JavaScript renderer.
"""
from __future__ import annotations

import base64
import ctypes as C
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile

from tools.pc_frontend_text import FrontendText, FrontendSources
from tools.pc_live_state import SimStateReader, active_program
from tools.pc_render_trace import Collector
from tools.pc_audio_events import audio_status
from tools.pc_readiness import ReadinessBark
from tools.pc_crew_voice import CrewBarks, RadioBarks

ROOT = Path('/repo')
MAX_PACKET = 64 * 1024 * 1024


def install_originals(archive: bytes, manifest: dict) -> None:
    """Mount only the already verified PC catalog, never arbitrary ZIP paths."""
    target = ROOT / 'GAME'
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(archive)) as source:
        for row in manifest['files']:
            name = row['name']
            if '/' in name or '\\' in name or name in ('', '.', '..'):
                raise ValueError('unsafe original catalog name')
            raw = source.read(name)
            if len(raw) > 16 * 1024 * 1024 or hashlib.sha256(raw).hexdigest() != row['sha256']:
                raise ValueError('original game file differs from manifest')
            (target / name).write_bytes(raw)


class BrowserObserver:
    def __init__(self):
        self.reader = SimStateReader(ROOT / 'GAME/SIM.EXE')
        self.frontend_sources = FrontendSources(ROOT / 'GAME')
        self.frontend = None
        self.collector = None
        self.mode = None
        self.identity = None
        self.frame = 0
        self.epoch = 0
        self.audio_sequence = 0
        self.readiness = ReadinessBark()
        self.crew = CrewBarks()
        self.radio = RadioBarks()

    def before_frame(self, ram: bytes) -> dict:
        program = active_program(ram)
        identity = (program['name'], program['psp']) if program else None
        if identity != self.identity:
            self.identity = identity
            self.collector = None
            self.frontend = None
            self.mode = None
            self.readiness.pending = None
            self.crew.last_message = 0
            self.radio.last_message = 0
        wanted = 'sim' if (program and program['name'] == 'SIM' and
                           self.reader.locate(ram) == program['load_segment'] * 16) else 'frontend'
        if wanted == self.mode:
            return {'mode': 'unchanged'}
        self.mode = wanted
        if wanted == 'sim':
            self.collector = Collector(self.reader, history_limit=2)
            self.frontend = None
            self.epoch += 1
            return {'mode': 'sim', 'load_segment': program['load_segment']}
        self.frontend = FrontendText(self.frontend_sources)
        self.collector = None
        return {'mode': 'frontend'}

    def after_frame(self, packet: bytes, receipts: bytes, ram: bytes,
                    video: bytes, width: int, height: int, pitch: int) -> dict:
        self.frame += 1
        if (len(packet) > MAX_PACKET or len(ram) != 640 * 1024 or
                (width, height, pitch) != (320, 200, 1280) or len(video) != pitch * height):
            raise ValueError('invalid paired browser frame')
        expected = []
        at = 0
        while at < len(receipts):
            if at + 8 > len(receipts):
                raise ValueError('truncated native claim receipt')
            page, plate = struct.unpack_from('<II', receipts, at)
            at += 8
            mask = b''
            if plate:
                if at + 8000 > len(receipts):
                    raise ValueError('truncated native strut receipt')
                mask = receipts[at:at + 8000]
                at += 8000
            expected.append((page, plate, mask))

        def claim_strut(page, plate, mask, length):
            if not expected or expected.pop(0) != (page, plate, C.string_at(mask, length)):
                raise ValueError('native strut claim differs from desktop source proof')
            return True

        def claim_motor_pool(page):
            if not expected or expected.pop(0) != (page, 0, b''):
                raise ValueError('native motor-pool claim differs from desktop source proof')
            return True

        if self.mode == 'sim':
            if self.collector is None:
                raise ValueError('SIM observer was not attached')
            self.collector.claim_strut = claim_strut
            self.collector.claim_motor_pool = claim_motor_pool
            observer = self.collector
        elif self.mode == 'frontend':
            if self.frontend is None or expected:
                raise ValueError('invalid frontend observer or claim receipt')
            observer = self.frontend
        else:
            raise ValueError('browser observer was not armed')
        cursor = count = 0
        while cursor < len(packet):
            if len(packet) - cursor < 36:
                raise ValueError('truncated native event header')
            event, offset, length = struct.unpack_from('<III', packet, cursor)
            regs = struct.unpack_from('<12H', packet, cursor + 12)
            cursor += 36
            if length > len(packet) - cursor:
                raise ValueError('truncated native event payload')
            observer.observe_packet(event, regs, packet[cursor:cursor + length], offset)
            if observer.error:
                raise observer.error
            cursor += length
            count += 1
        if expected:
            raise ValueError('native claim lacks desktop source proof')
        program = active_program(ram)
        state = None
        presentation = {'draw_pass': None, 'reason': 'no paired original presentation'}
        if self.mode == 'sim' and program and program['name'] == 'SIM' and self.collector:
            state = self.reader.read(ram)
            presentation = self.collector.paired_video((video, width, height, pitch))
        elif self.mode == 'frontend' and self.frontend:
            presentation = self.frontend.paired_video((video, width, height, pitch), ram)
        verified = (self.mode == 'sim' and program and
                    (program['name'], program['psp']) == self.identity and
                    self.reader.locate(ram) == program['load_segment'] * 16)
        status = audio_status(ram, program if verified else None)
        events = self.collector.audio.drain() if self.collector else []
        events += self.readiness.advance(self.frame, events, presentation, status)
        events += self.crew.advance(presentation, status)
        events += self.radio.advance(presentation, status)
        if len(events) > 4096:
            raise ValueError('browser original-audio event queue overflow')
        for event in events:
            self.audio_sequence += 1
            event.update(id=self.audio_sequence, frame=self.frame, epoch=self.epoch)
        audio = {'schema': 3, 'frame': self.frame, 'epoch': self.epoch,
                 'last_id': self.audio_sequence, 'events': events, **status}
        return {'program': program, 'state': state, 'presentation': presentation,
                'audio': audio, 'events': count}


def from_json(value: str) -> str:
    request = json.loads(value)
    if request['op'] == 'install':
        install_originals(base64.b64decode(request['archive'], validate=True), request['manifest'])
        return json.dumps({'installed': True})
    raise ValueError('unsupported browser observer operation')
