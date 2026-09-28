#!/usr/bin/env python3
"""Extract the two original destroyed-tank plates through the Genesis decoder.

This runs read-only ROM instructions in isolated RAM. It does not alter a live
core or claim the scenes were reached during ordinary play.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
from tools.extract_genesis_newspapers import ROM_SHA, render

ROOT = Path(__file__).resolve().parents[1]
SCENES = {'scene1': (0x937E, 9, 21, 0x58E42), 'scene2': (0x93A0, 10, 22, 0x58E68)}


def record(rom, base, index):
    at = base
    for _ in range(index):
        length = struct.unpack_from('>I', rom, at)[0]
        at = (at + 4 + length + 1) & ~1
        if at + 12 > len(rom): raise ValueError('resource chain outside ROM')
    return at


def decode(rom):
    if hashlib.sha256(rom).hexdigest() != ROM_SHA: raise ValueError('unsupported ROM')
    from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_PROT_READ, UC_PROT_EXEC
    from unicorn.m68k_const import (UC_CPU_M68K_M68000, UC_M68K_REG_SR,
        UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A7, UC_M68K_REG_PC)
    if hashlib.sha256(rom).hexdigest() != ROM_SHA: raise ValueError('unsupported ROM')
    machine = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
    machine.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    machine.mem_map(0, 0x80000); machine.mem_write(0, rom)
    machine.mem_protect(0, 0x80000, UC_PROT_READ | UC_PROT_EXEC)
    machine.mem_map(0xFFFF0000, 0x10000)
    entries = {}
    for name, (script, tiles, table, palette) in SCENES.items():
        entry = {'script': script, 'palette_command': palette, 'resources': {}}
        resources = [('tiles', 0x1DFDE, tiles), ('map', 0x18628, table)]
        if name == 'scene2': resources.append(('smoke_map', 0x18628, 23))
        for kind, base, index in resources:
            at = record(rom, base, index)
            machine.mem_write(0xFFFF0000, bytes(65536))
            machine.reg_write(UC_M68K_REG_SR, 0x2000)
            machine.reg_write(UC_M68K_REG_A7, 0xFFFFEF00)
            machine.mem_write(0xFFFFEF00, struct.pack('>I', 0x70000))
            machine.reg_write(UC_M68K_REG_A0, at + 12)
            machine.reg_write(UC_M68K_REG_A1, 0xFFFF0000)
            machine.emu_start(0x9AFE, 0x70000, count=2000000)
            if machine.reg_read(UC_M68K_REG_PC) != 0x70000: raise ValueError('decoder did not return')
            size = machine.reg_read(UC_M68K_REG_A1) - 0xFFFF0000
            width, height = struct.unpack_from('>2H', rom, at + 4)
            expected = width * 32 if kind == 'tiles' else width * height * 2
            if size != expected or not 0 < size < 0xD000: raise ValueError('decoded extent differs')
            data = bytes(machine.mem_read(0xFFFF0000, size))
            entry['resources'][kind] = {'chain_index': index, 'record': at, 'size': size,
                                       'sha256': hashlib.sha256(data).hexdigest(), 'dimensions': [width, height], 'data': data}
        entries[name] = entry
    return entries


def colours(rom, at):
    from tools.extract_genesis_vdp import color_rgb565
    palette = [(0, 0, 0)] * 64
    while True:
        index = struct.unpack_from('>H', rom, at)[0]; at += 2
        if index == 65535: break
        count = struct.unpack_from('>H', rom, at)[0]; at += 2
        if index + count > 64: raise ValueError('palette extent')
        for i in range(count):
            bus = struct.unpack_from('>H', rom, at)[0]; at += 2
            native = (bus >> 1 & 7) | (bus >> 5 & 7) << 3 | (bus >> 9 & 7) << 6
            palette[index + i] = color_rgb565(native)
    return palette


def composite_smoke(image, tiles, table, palette):
    # Script1 writes map23 on the other plane at x20,y2. The shared map
    # handler adds two top-border tiles; the 320x200 plate crop removes them.
    if len(table) != 4 * 16 * 2: raise ValueError('unsupported smoke geometry')
    for y in range(16):
        for x in range(4):
            descriptor = struct.unpack_from('>H', table, (y * 4 + x) * 2)[0]
            index, bank = descriptor & 2047, (descriptor >> 13 & 3) * 16
            if (index + 1) * 32 > len(tiles): raise ValueError('smoke tile outside bank')
            for ty in range(8):
                for tx in range(8):
                    sx = 7-tx if descriptor & 0x800 else tx
                    sy = 7-ty if descriptor & 0x1000 else ty
                    byte = tiles[index*32+sy*4+sx//2]
                    pixel = byte >> (4 if sx % 2 == 0 else 0) & 15
                    if pixel: image.putpixel((160+x*8+tx, 16+y*8+ty), palette[bank+pixel])
    return image


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--render', action='store_true')
    args = p.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT/name).resolve()) for name in ['GAME','GENESIS']):
        p.error('output must stay outside original input directories')
    rom = (ROOT / 'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
    if hashlib.sha256(rom).hexdigest() != ROM_SHA: raise ValueError('unsupported ROM')
    if args.render:
        manifest = json.loads((args.output / 'manifest.json').read_text())
        for name, entry in manifest['entries'].items():
            data = []
            for kind in ['tiles', 'map']:
                resource = entry['resources'][kind]
                value = (args.output / resource['file']).read_bytes()
                if hashlib.sha256(value).hexdigest() != resource['sha256']: raise ValueError('changed decoded resource')
                data.append(value)
            palette = colours(rom, entry['palette_command'])
            image = render(*data, palette)
            if name == 'scene2':
                resource = entry['resources']['smoke_map']
                smoke = (args.output / resource['file']).read_bytes()
                if hashlib.sha256(smoke).hexdigest() != resource['sha256']: raise ValueError('changed smoke map')
                image = composite_smoke(image, data[0], smoke, palette)
                entry['overlay'] = {'map': 23, 'rect': [160, 16, 32, 128], 'transparent_index': 0}
            path = args.output / (name + '-original.png'); image.save(path)
            entry['image'] = path.name; entry['image_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    else:
        args.output.mkdir(parents=True, exist_ok=False)
        entries = decode(rom)
        for name, entry in entries.items():
            for kind, resource in entry['resources'].items():
                path = args.output / (name + '-' + kind + '.bin')
                path.write_bytes(resource.pop('data')); resource['file'] = path.name
        manifest = {'schema': 1, 'rom_sha256': ROM_SHA, 'entries': entries,
                    'source_sequence': 'DA50 selects script0; DA5E selects script1 through9354; original waits unchanged',
                    'scope': __doc__}
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('GENESIS_AFTERMATH:', len(manifest['entries']), 'rendered' if args.render else 'decoded')


if __name__ == '__main__': main()
