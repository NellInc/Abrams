"""Original-program lifecycle for the read-only tandem presentation bridge.

No menu or mission rules are authored here. Every frame is still executed by
the original. Program changes discard derived geometry before a new attachment.
"""
import struct
try:
    from tools.pc_live_state import active_program
    from tools.pc_render_trace import Collector
except ModuleNotFoundError:
    from pc_live_state import active_program
    from pc_render_trace import Collector


class PresentationSession:
    def __init__(self, core, reader, shape_bytes, *, trace=True, collector_factory=Collector):
        self.core, self.reader, self.shape_bytes = core, reader, shape_bytes
        self.trace, self.collector_factory = trace, collector_factory
        self.program = None
        self.collector = None
        self.epoch = 0
        self.transitions = []

    @staticmethod
    def identity(program):
        return (program['name'],program['psp']) if program else None

    def before_frame(self):
        ram = self.core.conventional_memory()
        program = active_program(ram)
        if self.identity(program) != self.identity(self.program):
            self.close()
            self.program = program
            self.transitions.append({'frame': self.core.frame, 'program': program})
        if (self.trace and self.collector is None and program and program['name'] == 'SIM'
                and self.reader.locate(ram) == program['load_segment']*16):
            self.collector = self.collector_factory(self.reader, history_limit=2)
            self.collector.attach(self.core, program['load_segment'])
            self.epoch += 1

    def step(self, frames, keys=()):
        for _ in range(frames):
            self.before_frame()
            self.core.run(1, keys)
            if self.collector and self.collector.error: raise self.collector.error

    def sample(self):
        ram = self.core.last_video_ram
        program = active_program(ram)
        state = None
        if program and program['name'] == 'SIM' and self.reader.locate(ram) == program['load_segment']*16:
            state = self.reader.read(ram)
        presentation = {'draw_pass': None, 'reason': 'original program has no active observed SIM view'}
        if self.collector and self.identity(program) == self.identity(self.program):
            presentation = self.collector.paired_video(self.core.last_video)
        if state:
            ds = state['load_segment']*16 + 0x19E00
            offset, segment = struct.unpack_from('<HH',ram,ds+0x6D50)
            address = segment*16+offset
            if ram[address:address+len(self.shape_bytes)] != self.shape_bytes:
                # SIM can be initializing. Only a completed observed draw
                # turns a resource mismatch into a hard attribution error.
                if presentation.get('draw_pass'): raise ValueError('original SHAPE.TBL differs during observed drawing')
                state = None
        return {'program': program, 'state': state, 'presentation': presentation,
                'render_epoch': self.epoch}

    def close(self):
        if self.collector:
            self.collector.detach(self.core)
            self.collector = None
