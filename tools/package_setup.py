#!/usr/bin/env python3
"""Copy fingerprinted user-supplied PC originals and recreate the pinned local ZIP.

No game download. Original input is read-only. Existing targets are never changed.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CONTENT_SHA = 'c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05'
CONFIG = '[dosbox]\nmachine=ega\nmemsize=16\n[cpu]\ncore=normal\ncputype=386\ncycles=fixed 3000\n[autoexec]\n@echo off\nc:\nABRAMS.COM EGA\n'


def prepare(source, destination, records):
    if source.resolve() == (destination / 'GAME').resolve():
        raise ValueError('Use a separate original source directory')
    target = destination / 'GAME'
    archive = destination / '.runtime/pc-core/abrams-ref.zip'
    if not archive.resolve().is_relative_to(destination.resolve()):
        raise ValueError('Runtime destination must remain inside the kit')
    if target.exists() or archive.exists():
        raise ValueError('GAME or content ZIP already exists; existing files are preserved')
    payload = {}
    for record in records:
        name = record['name']
        if Path(name).name != name or name in {'.', '..'}:
            raise ValueError('Unsafe original filename')
        path = source / name
        if path.is_symlink():
            raise ValueError('Original inputs must be regular files')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != record['sha256']:
            raise ValueError(f'Unsupported or modified original: {name}')
        payload[name] = data
    target.mkdir(parents=True, exist_ok=False)
    archive.parent.mkdir(parents=True, exist_ok=True)
    for name, data in payload.items():
        (target / name).write_bytes(data)
    with archive.open('xb') as handle, zipfile.ZipFile(handle, 'w', compression=zipfile.ZIP_STORED) as out:
        for name, data in [*payload.items(), ('dosbox.conf', CONFIG.encode())]:
            info = zipfile.ZipInfo(name, (2026, 9, 26, 22, 55, 24))
            info.create_system = 3
            info.external_attr = 0o600 << 16
            out.writestr(info, data)
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual != CONTENT_SHA:
        raise ValueError('ZIP reconstruction did not match the pinned input; do not launch')
    return actual


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True, help='directory of separately supplied original PC files')
    parser.add_argument('--destination', type=Path, required=True, help='source-kit directory with no existing GAME or content ZIP')
    args = parser.parse_args()
    records = json.loads((ROOT / 'tools/package/game-inputs.json').read_text())['files']
    print(prepare(args.game, args.destination, records))


if __name__ == '__main__':
    main()
