"""Read-only original sound boundary and bounded, once-only delivery.

The original 9107 dispatcher is the authority, not input keys or ammo deltas.
Unknown requests stay in diagnostics without acquiring invented meanings.
"""
from collections import deque
import struct
try:
    from tools.pc_audio_loops import read_loops
except ModuleNotFoundError:
    from pc_audio_loops import read_loops

# Return IPs immediately after verified near calls to 0000:9107.
SAMPLES = {
    (11, 0x3C97): ('radio', None), (11, 0x3CDB): ('radio', None),
    (1, 0x33C4): ('cannon', 'on_the_way'),
    (2, 0x32FA): ('machinegun', None),
    (3, 0x7C07): ('smoke', 'smoke'),
    (6, 0x6B25): ('impact', None), (8, 0x6B25): ('impact', None),
    (6, 0x74E5): ('impact', None), (8, 0x74E5): ('impact', None),
    (6, 0x7547): ('impact', None), (8, 0x7547): ('impact', None),
}
for _return in (0x15E4, 0x15FF, 0x1640, 0x814D, 0x81CF, 0x81F3):
    SAMPLES[(14, _return)] = ('switch', None)


class AudioEvents:
    def __init__(self, limit=4096):
        self.limit = limit
        self.pending = deque()

    def observe(self, raw, *, text_sequence=None):
        if len(raw) != 12: raise ValueError('invalid native audio boundary')
        ip, caller, value, backend, gate, reload_state = struct.unpack('<6H', raw)
        if ip not in (0x9107, 0x8DA3, 0x35EE, 0x91D6):
            raise ValueError('unsupported original audio boundary')
        if len(self.pending) >= self.limit: raise ValueError('original audio event queue overflow')
        event = {'ip': ip, 'return_ip': caller, 'value': value, 'backend': backend,
                 'enabled': gate == 1 and backend in (0, 1)}
        if ip == 0x9107:
            event['kind'] = 'sound'
            sample, voice = SAMPLES.get((value, caller), (None, None))
            event.update(sample=sample, voice=voice)
        elif ip == 0x8DA3:
            event.update(kind='gate', enabled=value == 1 and backend in (0, 1))
        elif ip == 0x35EE:
            if reload_state != 2: raise ValueError('reload completion outside original loading state')
            # The separate readiness gate needs a newer, actually visible READY
            # draw. This original boundary alone remains silent.
            event['kind'] = 'reload_complete'
            if text_sequence is not None: event['text_sequence'] = text_sequence
        else:
            event['kind'] = 'engine_parameter'
        self.pending.append(event)

    def drain(self):
        events = list(self.pending)
        self.pending.clear()
        return events


def audio_status(ram, program):
    if not program or program['name'] != 'SIM': return {'active': False, 'enabled': False, 'loops': {}}
    load = program['load_segment'] * 16
    backend = ram[load + 0x19E00 + 0x35AC]
    gate = ram[load + 0x18B50 + 0x0F48]
    return {'active': True, 'enabled': backend in (0, 1) and gate == 1, 'backend': backend,
            'loops': read_loops(ram, load, backend)}
