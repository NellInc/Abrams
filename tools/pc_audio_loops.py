"""Original sound-channel loop ownership, without reimplementing movement.

Program-counter intervals come from the pinned sound tables and original bytecode
interpreter. An occupied channel outside these loops never becomes engine audio.
"""
import struct

# backend: channel-table, named (channel, program start, exclusive end, idle period)
LAYOUTS = {
    0: (0x0F76, {'engine': (3, 0x0BD4, 0x0BFC, 0x4584),
                 'turret': (2, 0x0C20, 0x0C84, 0x2134)}),
    1: (0x1110, {'engine': (0, 0x0628, 0x0650, 0x9140),
                 'turret': (1, 0x0650, 0x06CC, 0x6F54)}),
}


def read_loops(ram, load, backend):
    if backend not in LAYOUTS: return {}
    table, layout = LAYOUTS[backend]
    sound = load + 0x18B50
    result = {}
    for name, (channel, begin, end, idle) in layout.items():
        ticks, pc, period, delta, effective, amplitude = struct.unpack_from('<6H', ram, sound+table+channel*48)
        # Dispatcher sets ticks=1 before the interpreter initializes a sequence.
        # Its zeroed amplitude keeps that not-yet-sounding channel silent.
        active = bool(ticks and begin <= pc < end and period and amplitude)
        result[name] = {'active': active, 'channel':channel, 'ticks':ticks, 'program':pc,
                        'period':period, 'amplitude':amplitude, 'idle_period':idle,
                        'amplitude_reference':3 if backend == 0 else 30000}
    return result
