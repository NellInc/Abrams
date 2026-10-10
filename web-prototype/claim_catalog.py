#!/usr/bin/env python3
"""Build a per-user, source-derived Web claim catalog from verified PC files.

The binary is transient browser memory. It must never be checked in or served:
it contains decoded original bitmap and plate pixels. The original-file
manifest is checked before this is called by the browser runtime.
"""
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.inspect_scenarios import decode_resource
from tools.pc_bitmaps import decode_bitmaps
from tools.pc_plate_trace import PlateLoads


def build(game: Path) -> bytes:
    plates = PlateLoads(game)
    bitmaps = decode_bitmaps(decode_resource((game / 'STRUTS.BMP').read_bytes()))
    if not 1 <= len(bitmaps) <= 256:
        raise ValueError('unsupported original strut catalog')
    result = bytearray(struct.pack('<4sHH', b'ABCL', 1, len(bitmaps)))
    for name in ('GPS.BIN', 'TC.BIN', 'AA.BIN', 'DRIVER.BIN', 'ATBASE.BIN'):
        result.extend(c for byte in plates.resources[name][0] for c in (byte >> 4, byte & 15))
    for bitmap in bitmaps:
        result.extend(struct.pack('<HH', bitmap['width'], bitmap['height']))
        result.extend(bitmap['pixels'])
    if len(result) > 1024 * 1024:
        raise ValueError('original strut catalog exceeds Web bound')
    return bytes(result)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: claim_catalog.py ORIGINAL_GAME_DIRECTORY')
    sys.stdout.buffer.write(build(Path(sys.argv[1])))
