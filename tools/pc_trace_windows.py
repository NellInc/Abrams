"""Compact SIM RAM window bundles for native text, message and strut events.

Events 26 (SIM text entry), 28 (message assignment) and 29 (strut draw) may
carry only the guest RAM windows their readers dereference instead of a full
640 KiB snapshot. Bundle layout, all little-endian:

    b'AWB1', u16 count (1..8), count x (u32 linear base, u32 length),
    then the windows' bytes concatenated in header order.

Expansion rebuilds an exact 640 KiB image with every window copied to its
absolute base. All other bytes read as zero, so a reader that strays outside
the sent windows fails closed: a font, bitmap or string mismatch becomes
unsupported and the original pixels show through. Windows may overlap (with
SS == DS the stack lies inside DS) only where they carry identical bytes,
which is always true of one snapshot. Nothing here reads or writes the guest.

Frontend event 26 keeps its full snapshot: frontend program identity reads the
DOS SDA, MCB chain and code anchors outside DS.
"""
import json
import struct

RAM_BYTES = 640 * 1024
MAGIC = b'AWB1'
MAX_WINDOWS = 8
WINDOW_EVENTS = (26, 28, 29)
# Manifest event schemas: (text, message, strut). The bundled core bumps all three.
FULL_RAM_SCHEMAS = (2, 1, 1)
WINDOW_BUNDLE_SCHEMAS = (3, 2, 2)
FONT_FIELDS = (0x364E, 0x3662, 0x368A, 0x369E)  # width, height, count, segment


def is_window_bundle(raw):
    """A full snapshot is never a bundle, whatever its first four bytes hold."""
    return len(raw) != RAM_BYTES and bytes(raw[:4]) == MAGIC


def expand_window_bundle(raw):
    """Return the exact 640 KiB image a bundle describes, or raise ValueError."""
    if len(raw) < 6 or bytes(raw[:4]) != MAGIC: raise ValueError('invalid native RAM window bundle')
    count, = struct.unpack_from('<H', raw, 4)
    if not 1 <= count <= MAX_WINDOWS: raise ValueError('unsupported native RAM window count')
    at = 6 + 8 * count
    if at > len(raw): raise ValueError('truncated native RAM window header')
    ram, placed = bytearray(RAM_BYTES), []
    for index in range(count):
        base, length = struct.unpack_from('<II', raw, 6 + 8 * index)
        if not length or base + length > RAM_BYTES:
            raise ValueError('native RAM window outside 640 KiB')
        if at + length > len(raw): raise ValueError('truncated native RAM window bytes')
        data = bytes(raw[at:at + length])
        for prior, size in placed:
            low, high = max(base, prior), min(base + length, prior + size)
            if low < high and ram[low:high] != data[low - base:high - base]:
                raise ValueError('overlapping native RAM windows differ')
        ram[base:base + length] = data
        placed.append((base, length))
        at += length
    if at != len(raw): raise ValueError('native RAM window bundle has trailing bytes')
    # Readers slice text and use it as a hashable cache key; keep bytes.
    return bytes(ram)


def pack_window_bundle(ram, windows):
    """Bundle (base, length) windows of a full snapshot, clipped to 640 KiB.

    Reference encoder for the native header contract and for tests; windows
    that are empty after clipping are omitted.
    """
    if len(ram) != RAM_BYTES: raise ValueError('window bundles are cut from a full 640 KiB snapshot')
    kept = [(base, min(length, RAM_BYTES - base)) for base, length in windows if 0 <= base < RAM_BYTES and length > 0]
    if not 1 <= len(kept) <= MAX_WINDOWS: raise ValueError('unsupported native RAM window count')
    header = MAGIC + struct.pack('<H', len(kept)) + b''.join(struct.pack('<II', *w) for w in kept)
    return header + b''.join(bytes(ram[base:base + length]) for base, length in kept)


def sim_event_windows(event, ram, regs):
    """The windows a native SIM event 26/28/29 bundle must carry.

    DS [ds*16, +64 KiB) and the stack [ss*16+sp, +10) always. Event 26 adds the
    loaded font glyph payload named by DS 0x369E; event 29 adds the strut's
    contiguous four EGA planes plus mask from its DS descriptor.
    """
    ds, stack = regs['ds'] * 16, regs['ss'] * 16 + regs['sp']
    windows = [(ds, 65536), (stack, 10)]
    def word(at): return struct.unpack_from('<H', ram, at)[0] if at + 2 <= len(ram) else 0
    if event == 26 and ds + 0x36A0 <= len(ram):
        width, height, count = (ram[ds + at] for at in FONT_FIELDS[:3])
        segment = word(ds + FONT_FIELDS[3])
        if segment: windows.append((segment * 16, ((width + 7) // 8) * height * count))
    elif event == 29:
        descriptor = word(stack + 4)
        if ds + descriptor + 10 <= len(ram):
            segment, offset, _, width, height = struct.unpack_from('<HHHBB', ram, ds + descriptor)
            windows += [(ds + descriptor, 10), (segment * 16 + offset, 5 * (width // 8) * height)]
    elif event != 28:
        raise ValueError(f'event {event} carries no RAM window bundle')
    return windows


def window_bundle_schemas(manifest):
    """True when a trace manifest declares bundled SIM text/message/strut events,
    False for the full-snapshot schemas; any other combination is a broken build."""
    schemas = tuple(manifest.get(k) for k in ('text_event_schema', 'message_event_schema', 'strut_event_schema'))
    if schemas == WINDOW_BUNDLE_SCHEMAS: return True
    if schemas == FULL_RAM_SCHEMAS: return False
    raise ValueError('Rebuild the local trace core for original text, message and strut events')


def receipt_window_bundles(core_sha256, directory):
    """Bundle mode of the exact trace core a live collector attaches to.

    Reads the build receipt beside the active core, or the one retained with a
    superseded core under previous/<sha256>/. A core without its receipt is
    treated as full-snapshot, so its bundles are refused rather than guessed.
    """
    if not core_sha256: return False
    for path in (directory / 'abrams-trace.json', directory / 'previous' / core_sha256 / 'abrams-trace.json'):
        if path.is_file():
            receipt = json.loads(path.read_text())
            if receipt.get('trace_sha256') == core_sha256: return window_bundle_schemas(receipt)
    return False


def build_window_bundles(info):
    """Bundle mode of a Web core from its build-info.json. A Web build that
    predates bundles records none of the three schemas and sends full RAM."""
    keys = ('text_event_schema', 'message_event_schema', 'strut_event_schema')
    if all(key not in info for key in keys): return False
    return window_bundle_schemas(info)


def event_ram(raw, window_bundles):
    """The 640 KiB image a SIM event 26/28/29 packet describes, in exactly the
    format its trace core declares: a bundle core never sends full RAM for
    these events and a full-snapshot core never sends a bundle."""
    if window_bundles:
        if not is_window_bundle(raw): raise ValueError('native SIM event lacks its RAM window bundle')
        return expand_window_bundle(raw)
    if is_window_bundle(raw): raise ValueError('RAM window bundle from a full-snapshot trace core')
    return raw
