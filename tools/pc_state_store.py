"""Bounded, fingerprinted local checkpoints. No pickle or archive extraction."""
from __future__ import annotations
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import struct
import sys
import tempfile
import time
import zipfile

MAX_STATE = 128 * 1024 * 1024
MAX_DISK = 64 * 1024 * 1024
MAX_RESUME = 32 * 1024 * 1024
OPTIONAL_LIMITS = {'observer.bin': 2 * 1024 * 1024}
LIMITS = {'state.bin': MAX_STATE, 'resume.json': MAX_RESUME, 'campaign.zip': MAX_DISK}

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def sync_parent(path):
    # Windows' CRT cannot open directories for fsync. The temporary file is
    # still flushed before same-directory replacement on every platform.
    if os.name == 'nt': return
    directory = os.open(path, os.O_RDONLY)
    try: os.fsync(directory)
    finally: os.close(directory)

def atomic_write(path, raw):
    path = Path(path)
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        sync_parent(path.parent)
    finally:
        if os.path.exists(name): os.unlink(name)


def read_bounded(path, limit):
    with Path(path).open('rb') as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit: raise ValueError('checkpoint file exceeds size limit')
    return raw


def validate_disk(raw):
    if not raw: return
    if len(raw) > MAX_DISK: raise ValueError('campaign overlay exceeds size limit')
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        infos = archive.infolist()
        if len(infos) > 4096 or sum(i.file_size for i in infos) > MAX_DISK:
            raise ValueError('campaign overlay expands beyond size limit')
        names = [i.filename for i in infos]
        if len(names) != len(set(names)): raise ValueError('duplicate campaign member')
        for item in infos:
            name = item.filename.replace('\\', '/')
            if name.startswith('/') or '..' in name.split('/') or ':' in name or item.flag_bits & 1:
                raise ValueError('unsafe campaign archive member')
        if archive.testzip() is not None: raise ValueError('campaign overlay CRC mismatch')


class StateStore:
    def __init__(self, saves, core, content, backend):
        self.root = Path(saves).resolve() / 'states'
        if self.root.is_symlink(): raise ValueError('state directory must not be a symlink')
        self.root.mkdir(parents=True, exist_ok=True)
        self.compatibility = {'schema': 1, 'backend': backend,
            'core_sha256': sha(Path(core).read_bytes()), 'content_sha256': sha(Path(content).read_bytes()),
            'platform': sys.platform, 'machine': platform.machine(),
            'byteorder': sys.byteorder, 'pointer_bits': struct.calcsize('P') * 8,
            'options': 'abrams-ega-normal-386-3000-v1'}
        self.disk = Path(saves).resolve() / (Path(content).stem + '.pure.zip')
        if self.disk.is_symlink(): raise ValueError('campaign overlay must not be a symlink')

    def path(self, slot):
        if type(slot) is not int or not 0 <= slot <= 5: raise ValueError('slot must be 0 to 5')
        path = self.root / f'slot-{slot}.zip'
        if path.is_symlink(): raise ValueError('slot must not be a symlink')
        return path

    def read(self, slot):
        path = self.path(slot)
        if not path.exists(): raise ValueError(f'Slot {slot} is empty')
        raw = read_bounded(path, sum(LIMITS.values()) + sum(OPTIONAL_LIMITS.values()) + 65536)
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            infos = archive.infolist()
            names = {i.filename for i in infos}
            if (len(infos) != len(names) or not {*LIMITS, 'manifest.json'} <= names
                    or names - {*LIMITS, *OPTIONAL_LIMITS, 'manifest.json'}):
                raise ValueError('invalid checkpoint members')
            for item in infos:
                if item.file_size > ((LIMITS | OPTIONAL_LIMITS).get(item.filename, 65536)) or item.flag_bits & 1:
                    raise ValueError('checkpoint member exceeds limit or is encrypted')
            manifest = json.loads(archive.read('manifest.json'))
            if not isinstance(manifest, dict): raise ValueError('invalid checkpoint manifest')
            if manifest.get('compatibility') != self.compatibility:
                raise ValueError('Checkpoint belongs to a different core, game, or platform')
            files = {name: archive.read(name) for name in (LIMITS | OPTIONAL_LIMITS) if name in names}
        if not files['state.bin']: raise ValueError('empty native checkpoint')
        if manifest.get('files') != {name: {'size': len(data), 'sha256': sha(data)} for name, data in files.items()}:
            raise ValueError('Checkpoint integrity check failed')
        resume = json.loads(files['resume.json'])
        if (not isinstance(resume, dict) or type(resume.get('frame')) is not int or resume['frame'] < 0
                or type(resume.get('sequence')) is not int or resume['sequence'] < 0
                or not isinstance(resume.get('keys'), list) or len(resume['keys']) > 16
                or not isinstance(resume.get('packet'), dict)
                or not isinstance(resume.get('ram_sha256'), str)
                or len(resume['ram_sha256']) != 64
                or any(c not in '0123456789abcdef' for c in resume['ram_sha256'])
                or any(not isinstance(k, str) for k in resume['keys'])
                or len(set(resume['keys'])) != len(resume['keys'])):
            raise ValueError('invalid checkpoint resume metadata')
        validate_disk(files['campaign.zip'])
        return manifest, files

    def write(self, slot, capture):
        files = {name: read_bounded(Path(capture) / name, limit) for name, limit in LIMITS.items()}
        files.update({name: read_bounded(Path(capture) / name, limit)
                      for name, limit in OPTIONAL_LIMITS.items() if (Path(capture) / name).exists()})
        validate_disk(files['campaign.zip'])
        resume = json.loads(files['resume.json'])
        packet = resume['packet']
        program = packet.get('program') or {}
        manifest = {'compatibility': self.compatibility, 'saved_at': time.strftime('%Y-%m-%d %H:%M:%S', time.localtime()),
                    'program': program.get('name', 'Original game'), 'sequence': resume['sequence'],
                    'files': {name: {'size': len(data), 'sha256': sha(data)} for name, data in files.items()}}
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('manifest.json', json.dumps(manifest))
            for name, raw in files.items(): archive.writestr(name, raw)
        target = self.path(slot)
        if target.exists(): atomic_write(target.with_suffix('.previous.zip'), read_bounded(target, sum(LIMITS.values()) + sum(OPTIONAL_LIMITS.values()) + 65536))
        atomic_write(target, buffer.getvalue())
        self.read(slot)

    def slots(self):
        result = []
        for slot in range(6):
            row = {'slot': slot, 'exists': False, 'valid': False,
                   'label': 'Before last load' if slot == 0 else f'Slot {slot}'}
            try:
                row['exists'] = (self.root / f'slot-{slot}.zip').exists()
                if row['exists']:
                    manifest, _ = self.read(slot)
                    row.update(valid=True, saved_at=manifest['saved_at'], program=manifest['program'])
            except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error: row['message'] = str(error)
            result.append(row)
        return result

    def install_disk(self, raw):
        validate_disk(raw)
        if self.disk.is_symlink(): raise ValueError('campaign overlay must not be a symlink')
        if raw: atomic_write(self.disk, raw)
        elif self.disk.exists(): self.disk.unlink()
