#!/usr/bin/env python3
"""Decode three ending newspapers with the untouched Genesis M68000 routine.

Run with the existing analysis Python (Unicorn); PNG export uses the existing
system Python/Pillow. This is isolated resource execution, never a game-state
edit or proof of having reached an ending during play.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ROM_SHA = 'ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea'
ENTRIES = {'victory': (0x93CE, 0x2A1BA, 0x1A816, 'MOSCOW'),
           'defeat': (0x9402, 0x2CC2C, 0x1AEFC, 'PARIS'),
           'stalemate': (0x9436, 0x2F588, 0x1B5DE, 'STALE')}


def decode(rom):
    from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_PROT_READ, UC_PROT_EXEC
    from unicorn.m68k_const import (UC_CPU_M68K_M68000, UC_M68K_REG_SR,
        UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A7, UC_M68K_REG_PC)
    if hashlib.sha256(rom).hexdigest() != ROM_SHA:
        raise ValueError('unsupported Genesis source')
    m = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
    m.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    m.mem_map(0, 0x80000); m.mem_write(0, rom)
    m.mem_protect(0, 0x80000, UC_PROT_READ | UC_PROT_EXEC)
    m.mem_map(0xFFFF0000, 0x10000)
    result = {}
    for name, (script, tiles, table, source) in ENTRIES.items():
        entry = {'script': script, 'pc_source': source}
        for kind, at in [('tiles', tiles), ('map', table)]:
            m.mem_write(0xFFFF0000, bytes(65536))
            m.reg_write(UC_M68K_REG_SR, 0x2000)
            m.reg_write(UC_M68K_REG_A7, 0xFFFFEF00)
            m.mem_write(0xFFFFEF00, struct.pack('>I', 0x70000))
            m.reg_write(UC_M68K_REG_A0, at + 12)
            m.reg_write(UC_M68K_REG_A1, 0xFFFF0000)
            m.emu_start(0x9AFE, 0x70000, count=2000000)
            if m.reg_read(UC_M68K_REG_PC) != 0x70000:
                raise ValueError('original resource decoder did not return')
            size = m.reg_read(UC_M68K_REG_A1) - 0xFFFF0000
            expected = struct.unpack_from('>H', rom, at + 4)[0] * 32 if kind == 'tiles' else 2000
            if size != expected or not 0 < size < 0xD000:
                raise ValueError('original decoded extent differs from header')
            data = bytes(m.mem_read(0xFFFF0000, size))
            entry[kind] = {'record': at, 'size': size, 'sha256': hashlib.sha256(data).hexdigest(), 'data': data}
        result[name] = entry
    return result


def palette(rom):
    # Command 8 is a BE start/count/CRAM-word list, terminated by FFFF.
    try:
        from tools.extract_genesis_vdp import color_rgb565
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from extract_genesis_vdp import color_rgb565
    colours = [(0, 0, 0)] * 64
    for at in [0x58E8E, 0x58FE6]:
        while True:
            index, = struct.unpack_from('>H', rom, at); at += 2
            if index == 65535: break
            count, = struct.unpack_from('>H', rom, at); at += 2
            if index + count > 64: raise ValueError('palette extent')
            for i in range(count):
                bus, = struct.unpack_from('>H', rom, at); at += 2
                native = (bus >> 1 & 7) | (bus >> 5 & 7) << 3 | (bus >> 9 & 7) << 6
                colours[index + i] = color_rgb565(native)
    return colours


def render(tiles, table, colours):
    from PIL import Image
    if len(table) != 2000 or len(tiles) % 32 or len(colours) != 64:
        raise ValueError('unsupported newspaper geometry')
    im = Image.new('RGB', (320, 200))
    for y in range(25):
        for x in range(40):
            d, = struct.unpack_from('>H', table, (y * 40 + x) * 2)
            index, bank = d & 2047, (d >> 13 & 3) * 16
            if (index + 1) * 32 > len(tiles): raise ValueError('missing tile')
            for ty in range(8):
                for tx in range(8):
                    sx = 7-tx if d & 0x800 else tx
                    sy = 7-ty if d & 0x1000 else ty
                    b = tiles[index*32+sy*4+sx//2]
                    pixel = b >> (4 if sx % 2 == 0 else 0) & 15
                    im.putpixel((x*8+tx, y*8+ty), colours[bank+pixel])
    return im


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--render', action='store_true', help='render a previously decoded output using system Pillow')
    a = p.parse_args()
    try:
        from tools.source_guard import inside_source
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from source_guard import inside_source
    if inside_source(a.output, ROOT, ('GAME','GENESIS')):
        p.error('output must remain outside original source directories')
    rom = (ROOT/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
    if hashlib.sha256(rom).hexdigest() != ROM_SHA: p.error('unsupported ROM')
    if a.render:
        report = json.loads((a.output/'manifest.json').read_text())
        for name, entry in report['entries'].items():
            resources = []
            for kind in ['tiles','map']:
                data = (a.output/entry[kind]['file']).read_bytes()
                if hashlib.sha256(data).hexdigest() != entry[kind]['sha256']: raise ValueError('decoded resource changed')
                resources.append(data)
            image = render(*resources, palette(rom)); path = a.output/(name+'-original.png')
            image.save(path); entry['image'] = path.name
            entry['image_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    else:
        a.output.mkdir(parents=True, exist_ok=False)
        entries = decode(rom)
        for name, entry in entries.items():
            for kind in ['tiles','map']:
                resource = entry[kind]; path = a.output/(name+'-'+kind+'.bin')
                path.write_bytes(resource.pop('data')); resource['file'] = path.name
        report = {'schema':1, 'rom_sha256':ROM_SHA, 'entries':entries,
                  'decoder':'unchanged M68000 9AFE/9B20; read-only ROM; isolated private RAM; bounded return',
                  'palette_commands':[0x58E8E,0x58FE6], 'scope':__doc__}
    (a.output/'manifest.json').write_text(json.dumps(report, indent=2)+'\n')
    print('GENESIS_NEWSPAPERS:', len(report['entries']), 'original resources', 'rendered' if a.render else 'decoded')


if __name__ == '__main__': main()
