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
from tools.pc_render_trace import Collector, prewarm
from tools.pc_trace_windows import build_window_bundles
from tools.pc_session import slim_sample
from tools.pc_audio_events import audio_status
from tools.pc_readiness import ReadinessBark
from tools.pc_crew_voice import CrewBarks, RadioBarks
from tools.inspect_scenarios import decode_resource

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
    def __init__(self, build_info: dict | None = None):
        # SIM event packet format of the Web core that feeds this observer,
        # from its build-info.json; a build that records none sends full RAM.
        self.window_bundles = build_window_bundles(build_info or {})
        self.reader = SimStateReader(ROOT / 'GAME/SIM.EXE')
        self.shape_bytes = decode_resource((ROOT / 'GAME/SHAPE.TBL').read_bytes())
        self.frontend_sources = FrontendSources(ROOT / 'GAME')
        prewarm()  # decode pinned SIM sources before the first mission step
        self.frontend = None
        self.collector = None
        self.mode = None
        self.identity = None
        self.frame = 0
        self.epoch = 0
        self.audio_sequence = 0
        self.audio_pending = []
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
            self.collector = Collector(self.reader, history_limit=2, window_bundles=self.window_bundles)
            self.frontend = None
            self.epoch += 1
            return {'mode': 'sim', 'load_segment': program['load_segment']}
        self.frontend = FrontendText(self.frontend_sources)
        self.collector = None
        return {'mode': 'frontend'}

    def after_frame(self, packet: bytes, receipts: bytes, paired_ram: bytes,
                    current_ram: bytes, video: bytes, width: int, height: int,
                    pitch: int, final: bool = True) -> dict | None:
        """Consume one original frame, mirroring desktop PresentationSession.

        ``paired_ram`` is the snapshot taken immediately before retro_run, at
        the boundary of the framebuffer that call submitted (desktop
        ``last_video_ram``). Program, state and presentation use it.
        ``current_ram`` is read after the frame; like desktop ``step`` it only
        drives audio status. Audio events accumulate until a ``final`` frame,
        which alone builds the packet sample, as desktop ``sample`` does.
        """
        self.frame += 1
        if (len(packet) > MAX_PACKET or len(paired_ram) != 640 * 1024 or
                len(current_ram) != 640 * 1024 or
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
        frame_video = (video, width, height, pitch)
        current = active_program(current_ram)
        verified = (self.mode == 'sim' and self.collector is not None and current and
                    (current['name'], current['psp']) == self.identity and
                    self.reader.locate(current_ram) == current['load_segment'] * 16)
        status = audio_status(current_ram, current if verified else None)
        events = self.collector.audio.drain() if self.collector else []
        bark_view = self.collector.paired_video(frame_video) if verified else {}
        events += self.readiness.advance(self.frame, events, bark_view, status)
        events += self.crew.advance(bark_view, status)
        events += self.radio.advance(bark_view, status)
        for event in events:
            if len(self.audio_pending) >= 4096:
                raise ValueError('browser original-audio event queue overflow')
            self.audio_sequence += 1
            self.audio_pending.append(
                event | {'id': self.audio_sequence, 'frame': self.frame, 'epoch': self.epoch})
        if not final:
            return None
        program = active_program(paired_ram)
        identity = (program['name'], program['psp']) if program else None
        state = None
        if (program and program['name'] == 'SIM' and
                self.reader.locate(paired_ram) == program['load_segment'] * 16):
            state = self.reader.read(paired_ram)
        presentation = {'draw_pass': None,
                        'reason': 'original program has no active observed SIM view'}
        if self.mode == 'sim' and self.collector and identity == self.identity:
            presentation = self.collector.paired_video(frame_video)
        elif self.mode == 'frontend' and self.frontend:
            candidate = self.frontend.paired_video(frame_video, paired_ram)
            source = candidate.get('frontend_program')
            if ((source['name'], source['psp']) if source else None) == identity:
                presentation = candidate
        if state:
            ds = state['load_segment'] * 16 + 0x19E00
            offset, segment = struct.unpack_from('<HH', paired_ram, ds + 0x6D50)
            address = segment * 16 + offset
            if paired_ram[address:address + len(self.shape_bytes)] != self.shape_bytes:
                # SIM can be initializing. Only a completed observed draw
                # turns a resource mismatch into a hard attribution error.
                if presentation.get('draw_pass'):
                    raise ValueError('original SHAPE.TBL differs during observed drawing')
                state = None
        events, self.audio_pending = self.audio_pending, []
        audio = {'schema': 3, 'frame': self.frame, 'epoch': self.epoch,
                 'last_id': self.audio_sequence, 'events': events, **status}
        # Play-only surface, as desktop --slim-samples: undrawn actors never
        # leave the observer.
        return slim_sample({'program': program, 'state': state, 'presentation': presentation,
                            'audio': audio, 'events': count})


def from_json(value: str) -> str:
    request = json.loads(value)
    if request['op'] == 'install':
        install_originals(base64.b64decode(request['archive'], validate=True), request['manifest'])
        return json.dumps({'installed': True})
    raise ValueError('unsupported browser observer operation')
