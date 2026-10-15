#!/usr/bin/env python3
"""Local macOS app provisioning. Originals and profiles stay outside the app."""
from __future__ import annotations
import argparse
import base64
import hashlib
import io
import json
import os
import re
from pathlib import Path
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import time
from tools.source_guard import inside_source

ROM_SHA = 'ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea'
CONTENT_SHA = 'c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05'
MIN_FREE = 1024 ** 3
# Original-derived presentation data is never shipped in a native app. It is
# reproduced here from the player's verified PC files and Genesis ROM, checked
# against the build's pinned hash, and kept in a content-addressed store.
DERIVED_STORE = 'content/derived'
GENESIS_RECEIPT_SCHEMA = 2
# Set by the portable launcher for its own --invoke child after it has
# verified this exact build's payload, so the child does not hash it twice.
PAYLOAD_VERIFIED_ENV = 'ABRAMS_PAYLOAD_VERIFIED'
IMPORT_MARKER = '.godot/abrams-preflight.json'


def sha(path):
    # Streaming SHA-256 also supports the source kit's Python 3.10 baseline.
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def write_json(path, value):
    # Same-directory exclusive temporary file, followed by atomic replacement.
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.'+path.name, delete=False) as stream:
        json.dump(value, stream, indent=2); stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
        temporary = Path(stream.name)
    temporary.replace(path)


def write_bytes(path, data):
    # Same-directory exclusive temporary file, followed by atomic replacement.
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.'+path.name, delete=False) as stream:
        stream.write(data); stream.flush(); os.fsync(stream.fileno())
        temporary = Path(stream.name)
    temporary.replace(path)


# Name-surrogate reparse tags; the stat module defines them only on Windows.
LINK_REPARSE_TAGS = (getattr(stat, 'IO_REPARSE_TAG_SYMLINK', 0xA000000C),
                     getattr(stat, 'IO_REPARSE_TAG_MOUNT_POINT', 0xA0000003))


def is_link(path):
    """Symlinks, plus Windows junctions (mount-point reparse points).

    Path.is_symlink() is False for an NTFS junction (mklink /J needs no
    administrator rights), so every link guard also checks the reparse tag.
    Other reparse points, such as OneDrive placeholders or deduplicated
    files, are ordinary files and folders, not links.
    """
    path = Path(path)
    if path.is_symlink(): return True
    try: info = os.lstat(path)
    except OSError: return False
    return (bool(getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT)
            and getattr(info, 'st_reparse_tag', 0) in LINK_REPARSE_TAGS)


def regular(path):
    path = Path(path)
    return path.is_file() and not is_link(path)


def managed(home, path):
    """Reject links inside managed storage before reading or creating children."""
    path = Path(path)
    relative = path.relative_to(home)
    for i in range(1, len(relative.parts)+1):
        if is_link(home.joinpath(*relative.parts[:i])):
            raise ValueError('Managed player data cannot contain symlinks or junctions: '+str(path))
    return path


def inside(path, root):
    """Case-, alias- and link-aware containment, never a bare is_relative_to.

    APFS/NTFS keep the spelling given to resolve(), so a miscased path into the
    application must still count as inside it.
    """
    root = Path(root).resolve()
    return Path(path).resolve().is_relative_to(root) or inside_source(path, root.parent, (root.name,))


def rename_directory(source, target, windows=None, attempts=10, sleep=time.sleep):
    """Promote a just-verified directory, retrying transient Windows file locks.

    Real-time antivirus and indexers briefly hold just-written DLLs and data,
    and MoveFileEx then fails with access-denied or sharing-violation.
    """
    windows = os.name == 'nt' if windows is None else windows
    for attempt in range(attempts):
        try:
            return Path(source).rename(target)
        except OSError as error:
            transient = isinstance(error, PermissionError) or getattr(error, 'winerror', None) in (5, 32)
            if not windows or not transient: raise
            if attempt == attempts - 1:
                raise ValueError('Installation files are in use by another program (often antivirus); retry setup. Originals and saves are unchanged.') from error
            sleep(min(0.5, 0.05 * 2 ** attempt))


def app_resources(bundle):
    bundle = Path(bundle).resolve()
    root = bundle / 'Contents/Resources' if bundle.suffix == '.app' else bundle
    manifest = json.loads((root/'RUNTIME.json').read_text())
    if manifest.get('schema') != 1 or manifest.get('originals_included') is not False:
        raise ValueError('Unsupported application manifest')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', str(manifest.get('build_id', ''))):
        raise ValueError('Unsafe application build identifier')
    return root, manifest


def profile_home(bundle, requested=None):
    selected = requested or os.environ.get('ABRAMS_DATA_HOME')
    if selected:
        home = Path(selected).expanduser()
    elif sys.platform == 'win32':
        base = os.environ.get('LOCALAPPDATA')
        home = (Path(base) if base else Path.home()/'AppData/Local')/'Abrams'
    elif sys.platform == 'darwin':
        home = Path.home()/'Library/Application Support/Abrams'
    else:
        base = os.environ.get('XDG_DATA_HOME')
        home = (Path(base) if base else Path.home()/'.local/share')/'abrams'
    if not home.is_absolute() or inside(home, bundle):
        raise ValueError('Player data must use an absolute directory outside the application')
    return home.resolve()


def source_records(resources, expected_sha=None):
    raw = (resources/'kit/tools/package/game-inputs.json').read_bytes()
    if expected_sha is not None and hashlib.sha256(raw).hexdigest() != expected_sha:
        raise ValueError('Verified original input manifest changed during installation')
    rows = json.loads(raw)['files']
    names = [row['name'] for row in rows]
    if not names or len(set(names)) != len(names) or any(not name or name in {'.','..'} or Path(name).name != name or '\\' in name for name in names):
        raise ValueError('Unsafe original input manifest')
    return rows


def validate_content(resources, content, records=None):
    for row in source_records(resources) if records is None else records:
        path = content/'GAME'/row['name']
        managed(content, path)
        if not regular(path) or sha(path) != row['sha256']:
            raise ValueError('Imported PC game files in the player data folder are missing or changed. They and your saves were kept for diagnosis. Restore the profile from a backup, or use a fresh data home (ABRAMS_DATA_HOME or --data-home).')
    archive = content/'.runtime/pc-core/abrams-ref.zip'
    managed(content, archive)
    if not regular(archive) or sha(archive) != CONTENT_SHA:
        raise ValueError('Imported PC content is incomplete or changed; existing saves have been preserved.')


def _png(image):
    stream = io.BytesIO(); image.save(stream, format='PNG'); return stream.getvalue()


# Recipes whose bytes depend on the platform's PNG encoder. Only these may be
# unavailable on a machine; pure-Python outputs must always reproduce exactly.
ENCODED_RECIPES = frozenset({'pc-plates', 'pc-bitmap', 'genesis-plate'})


def genesis_decompress(rom, at, limit=0xD000):
    """Pure-Python port of the ROM's own resource decoder at 9AFE/9B20.

    Chunks are a little-endian length plus one block: a little-endian output
    count, 16 common bytes, the long back-reference width and an LSB-first
    bit stream of 16-bit little-endian words. Checked byte for byte against
    the unchanged M68000 routine under Unicorn for every newspaper and
    aftermath resource and both complete resource chains. Cases the original
    would wrap (zero lengths, overruns, forward references) are refused.
    """
    out = bytearray()
    def byte(index):
        if not 0 <= index < len(rom): raise ValueError('Genesis resource outside the ROM')
        return rom[index]
    while True:
        length = byte(at) | byte(at+1) << 8
        if not length: return bytes(out)
        if length & 0x8000: raise ValueError('Unsupported Genesis resource chunk')
        block, at = at+2, at+2+length
        remaining = byte(block) | byte(block+1) << 8
        common = [byte(block+2+i) for i in range(16)]
        width = byte(block+0x12)
        if not remaining or width > 8: raise ValueError('Unsupported Genesis resource block')
        cursor, bits, held = block+0x13, 0, 0
        def take(count):
            nonlocal cursor, bits, held
            while held < count:
                bits |= (byte(cursor) | byte(cursor+1) << 8) << held; cursor += 2; held += 16
            value = bits & (1 << count) - 1; bits >>= count; held -= count
            return value
        while remaining > 0:
            token = take(2)
            if token & 1:
                out.append(common[take(4) ^ 15] if token & 2 else take(8)); remaining -= 1
            else:
                size = take(6)
                if size < 3: size = take((7, 8, 14)[size])
                if not size: raise ValueError('Unsupported Genesis zero-length run')
                remaining -= size
                if token & 2:
                    offset = take(8) | (take(width) << 8 if width else 0)
                    start = len(out) - offset
                    if not 0 < offset < 0x8000 or start < 0: raise ValueError('Genesis back-reference outside its output')
                    for index in range(size): out.append(out[start+index])
                else:
                    out.extend(bytes([common[take(4) ^ 15] if take(1) else take(8)]) * size)
            if len(out) > limit: raise ValueError('Genesis resource exceeds its decoded bound')
        if remaining: raise ValueError('Genesis block overran its declared size')


def cram_rgb(packed):
    """Packed 9-bit CRAM to RGB, as tools.extract_genesis_vdp.color_rgb565.

    Kept here without that module's Pillow import, so the stdlib-only source
    kit can derive palettes; a test pins the two against each other.
    """
    r, g, b = [(packed >> shift & 7) * 2 for shift in (0, 3, 6)]
    pixel = r << 12 | (r >> 3) << 11 | g << 7 | (g >> 2) << 5 | b << 1 | b >> 3
    return ((pixel >> 11 & 31) * 255 // 31,
            (pixel >> 5 & 63) * 255 // 63, (pixel & 31) * 255 // 31)


class DerivationInputs:
    """Verified originals for one derivation pass; decodes are memoised."""
    def __init__(self, game=None, rom=None):
        self.game, self.rom, self.memo = game, rom, {}

    def _cached(self, key, compute):
        if key not in self.memo: self.memo[key] = compute()
        return self.memo[key]

    def original(self, name):
        if self.game is None: raise ValueError('PC originals are unavailable for this derivation')
        if not name or Path(name).name != name or name in {'.', '..'}: raise ValueError('Unsafe original name: '+str(name))
        path = self.game/name
        if not regular(path): raise ValueError('Missing original: '+name)
        return self._cached(('raw', name), path.read_bytes)

    def resource(self, name):
        from tools.inspect_scenarios import decode_resource
        return self._cached(('resource', name), lambda: decode_resource(self.original(name)))

    def bitmaps(self, name):
        from tools.pc_bitmaps import decode_bitmaps
        return self._cached(('bitmaps', name), lambda: decode_bitmaps(self.resource(name)))

    def screen(self, name):
        # Same high-nibble-first 320x200 plate layout as tools/extract_pc_ui.py,
        # without importing that research tool's live-state dependencies.
        def pixels():
            data = self.resource(name)
            if len(data) != 32000: raise ValueError('Unsupported packed 320x200 plate: '+name)
            return [colour for value in data for colour in (value >> 4, value & 15)]
        return self._cached(('screen', name), pixels)

    def effects(self):
        if self.rom is None: raise ValueError('The Genesis ROM is unavailable for this derivation')
        from tools.extract_genesis_effects import decode_effects
        return self._cached('effects', lambda: decode_effects(self.rom))

    def palette(self, segments):
        """Genesis CRAM words read from the ROM, converted as the capture core does."""
        if self.rom is None: raise ValueError('The Genesis ROM is unavailable for this derivation')
        colours = []
        for offset, count in segments:
            if offset < 0 or offset % 2 or count < 1 or offset + count * 2 > len(self.rom): raise ValueError('Unsafe Genesis palette segment')
            for at in range(offset, offset + count * 2, 2):
                word, = struct.unpack_from('>H', self.rom, at)
                # ROM 0000BBB0GGG0RRR0 to the core's packed 9-bit R|G<<3|B<<6 CRAM.
                colours.append(list(cram_rgb((word >> 1 & 7) | (word >> 5 & 7) << 3 | (word >> 9 & 7) << 6)))
        return colours

    def palette_commands(self, commands):
        """Genesis palette command 8 lists (start, count, CRAM words; FFFF ends)."""
        if self.rom is None: raise ValueError('The Genesis ROM is unavailable for this derivation')
        colours = [(0, 0, 0)] * 64
        for at in commands:
            while True:
                if at < 0 or at % 2 or at + 2 > len(self.rom): raise ValueError('Unsafe Genesis palette command')
                index, = struct.unpack_from('>H', self.rom, at); at += 2
                if index == 0xFFFF: break
                if at + 2 > len(self.rom): raise ValueError('Unsafe Genesis palette command')
                count, = struct.unpack_from('>H', self.rom, at); at += 2
                if index + count > 64 or at + count * 2 > len(self.rom): raise ValueError('Unsafe Genesis palette command')
                for i in range(count):
                    word, = struct.unpack_from('>H', self.rom, at); at += 2
                    colours[index + i] = cram_rgb((word >> 1 & 7) | (word >> 5 & 7) << 3 | (word >> 9 & 7) << 6)
        return colours

    def genesis_resource(self, record, kind):
        """One decoded tile bank or map, sized exactly as its record header says."""
        if self.rom is None: raise ValueError('The Genesis ROM is unavailable for this derivation')
        def decode():
            if record < 0 or record + 12 > len(self.rom): raise ValueError('Unsafe Genesis resource record')
            width, height = struct.unpack_from('>2H', self.rom, record + 4)
            data = genesis_decompress(self.rom, record + 12)
            expected = width * 32 if kind == 'tiles' else width * height * 2
            if len(data) != expected or not 0 < len(data) < 0xD000: raise ValueError('Decoded Genesis extent differs from its header')
            return data
        return self._cached(('genesis', record, kind), decode)


def _derived_value(spec, inputs):
    kind = spec['kind']
    if kind == 'pc-bitmaps': return inputs.bitmaps(spec['source'])
    if kind == 'pc-resource-base64': return base64.b64encode(inputs.resource(spec['source'])).decode()
    if kind == 'pc-bitmap-base64':
        return base64.b64encode(bytes(inputs.bitmaps(spec['source'])[spec['index']]['pixels'])).decode()
    if kind == 'genesis-effect': return inputs.effects()[spec['index']][spec['field']]
    if kind == 'genesis-palette': return inputs.palette(spec['segments'])
    raise ValueError('Unsupported derived value: '+str(kind))


def derive(recipe, inputs):
    """Reproduce one original-derived file exactly; the caller checks its pin."""
    kind = recipe['kind']
    if kind == 'json':
        value = json.loads(json.dumps(recipe['template']))
        for fill in recipe['fills']:
            at = value
            for key in fill['at'][:-1]: at = at[key]
            if at[fill['at'][-1]] is not None: raise ValueError('Derived JSON template is not empty at '+str(fill['at']))
            at[fill['at'][-1]] = _derived_value(fill['value'], inputs)
        return (json.dumps(value, indent=2)+'\n').encode()
    if kind == 'pc-shape-registry':
        # The Modern catalogue's per-shape SHAPE.TBL structure, from the same
        # pure decode the asset builder pins; it refuses any other SHAPE.TBL.
        if recipe.get('source') != 'SHAPE.TBL': raise ValueError('Unsupported shape registry source')
        from tools.build_pc_modern_assets import source_registry, registry_bytes
        return registry_bytes(source_registry(inputs.original('SHAPE.TBL')))
    if kind == 'gimp-palette':
        colours = inputs.palette(recipe['segments'])
        return ('GIMP Palette\nName: '+recipe['name']+'\nColumns: 16\n#\n'+'\n'.join(
            f'{r:3} {g:3} {b:3}\tIndex {i}' for i, (r, g, b) in enumerate(colours))+'\n').encode()
    if kind == 'genesis-plate':
        # The same tile renderer and smoke overlay that produced the pinned
        # plates; only the original M68000 decode is replaced by its port.
        from tools.extract_genesis_newspapers import render
        colours = inputs.palette_commands(recipe['palette_commands'])
        tiles = inputs.genesis_resource(recipe['tiles'], 'tiles')
        image = render(tiles, inputs.genesis_resource(recipe['map'], 'map'), colours)
        if recipe.get('overlay') is not None:
            from tools.extract_genesis_aftermath import composite_smoke
            image = composite_smoke(image, tiles, inputs.genesis_resource(recipe['overlay'], 'map'), colours)
        return _png(image)
    from PIL import Image
    palette = [tuple(colour) for colour in recipe['palette']]
    if kind == 'pc-plates':
        image = Image.new('RGB', (320, 200*len(recipe['sources'])))
        for index, name in enumerate(recipe['sources']):
            plate = Image.new('RGB', (320, 200)); plate.putdata([palette[c] for c in inputs.screen(name)])
            image.paste(plate, (0, index*200))
        return _png(image)
    if kind == 'pc-bitmap':
        found = [item for item in inputs.bitmaps(recipe['source']) if item['index'] == recipe['index']]
        if len(found) != 1: raise ValueError('Original bitmap is missing: '+recipe['source'])
        item = found[0]
        image = Image.new('RGBA', (item['width'], item['height']))
        image.putdata([palette[c]+(255 if c else 0,) for c in item['pixels']])
        return _png(image)
    raise ValueError('Unsupported derivation: '+str(kind))


def derived_rows(manifest, origin):
    rows = manifest.get('derived', [])
    names = set()
    for row in rows:
        name = row['path']; relative = Path(name)
        if not name or relative.as_posix() != name or '\\' in name or ':' in name or relative.is_absolute() or '..' in relative.parts or name in names:
            raise ValueError('Unsafe derived file manifest')
        if (not re.fullmatch(r'[0-9a-f]{64}', str(row.get('sha256', ''))) or row.get('origin') not in ('pc', 'genesis')
                or not isinstance(row.get('recipe'), dict)):
            raise ValueError('Unsafe derived file manifest')
        names.add(name)
    return [row for row in rows if row['origin'] == origin]


def stored(home, digest):
    return managed(home, home/DERIVED_STORE/digest)


def derive_into_store(home, rows, inputs):
    """Write each reproducible file to the store; report the ones that differ.

    A file that cannot be reproduced exactly (for example under a different
    image encoder) is left out, so its presentation falls back to the original
    PC pixels instead of showing unverified data.
    """
    store = managed(home, home/DERIVED_STORE)
    store.mkdir(parents=True, exist_ok=True)
    written, unavailable = {}, []
    for row in rows:
        path = stored(home, row['sha256'])
        if regular(path) and sha(path) == row['sha256']:
            written[row['path']] = row['sha256']; continue
        try:
            data = derive(row['recipe'], inputs)
        except Exception as error:  # A decoder failure only disables this one presentation file.
            unavailable.append(row['path']+': '+type(error).__name__+': '+str(error)); continue
        if hashlib.sha256(data).hexdigest() != row['sha256']:
            unavailable.append(row['path']+': reproduced bytes differ from the pinned file'); continue
        write_bytes(path, data)
        written[row['path']] = row['sha256']
    return written, unavailable


def derive_pc(home, rows, game):
    """Derive PC presentation data and keep a diagnostic receipt of the result."""
    written, unavailable = derive_into_store(home, rows, DerivationInputs(game=game))
    write_json(managed(home, home/'content/pc-derived.json'), {'schema': 1, 'files': written, 'unavailable': unavailable})
    return written, unavailable


def derived_unavailable(home):
    """Diagnostics only: derived files this machine could not reproduce exactly."""
    found = []
    for name in ('pc-derived.json', 'genesis.json'):
        try:
            path = managed(home, home/'content'/name)
            data = json.loads(path.read_text()) if regular(path) else {}
        except (ValueError, OSError):
            continue
        if isinstance(data, dict) and isinstance(data.get('unavailable'), list):
            found.extend(str(entry) for entry in data['unavailable'])
    return found


def genesis_state(home, manifest):
    """Return (enabled, problem). The receipt lists the files really derived.

    Genesis is enabled only by verified ROM-derived bytes: every pinned row
    must be in the receipt at its pinned hash and re-hash from the store. An
    encoder-dependent PNG may instead be listed as unavailable, but pure-Python
    rows never may, so a hand-written receipt cannot unlock Genesis content.
    """
    receipt = managed(home, home/'content/genesis.json')
    if not receipt.exists(): return False, ''
    if not regular(receipt): raise ValueError('Genesis receipt must be a regular file')
    data = json.loads(receipt.read_text())
    if data == {'schema': 1, 'rom_sha256': ROM_SHA}:
        return False, 'This version derives its Genesis presentation from the ROM itself. Add the Genesis ROM again to enable it.'
    if (not isinstance(data, dict) or set(data) != {'schema', 'rom_sha256', 'files', 'unavailable'}
            or data['schema'] != GENESIS_RECEIPT_SCHEMA or data['rom_sha256'] != ROM_SHA
            or not isinstance(data['files'], dict) or not isinstance(data['unavailable'], list)):
        raise ValueError('Unsupported Genesis import receipt')
    for digest in data['files'].values():
        if not re.fullmatch(r'[0-9a-f]{64}', str(digest)): raise ValueError('Unsupported Genesis import receipt')
        path = stored(home, digest)
        if not regular(path) or sha(path) != digest:
            return False, 'Imported Genesis data is missing or changed. Add the Genesis ROM again.'
    rows = derived_rows(manifest, 'genesis')
    unavailable = {str(entry).split(': ', 1)[0] for entry in data['unavailable']}
    verified = [row for row in rows if data['files'].get(row['path']) == row['sha256']]
    # A newer build may pin Genesis data that this receipt never derived.
    if not verified or any(row not in verified and (row['recipe']['kind'] not in ENCODED_RECIPES or row['path'] not in unavailable)
                           for row in rows):
        return False, 'This version needs Genesis data that was not imported yet. Add the Genesis ROM again.'
    return True, ''


def genesis_enabled(home, manifest):
    return genesis_state(home, manifest)[0]


def status(bundle, home):
    resources, manifest = app_resources(bundle)
    content = managed(home, home/'content'/CONTENT_SHA)
    installed = False
    problem = ''
    if content.exists():
        try: validate_content(resources, content); installed = True
        except (ValueError, OSError) as error: problem = str(error)
    enabled, genesis_problem = genesis_state(home, manifest)
    return {'pc_installed': installed, 'genesis_enabled': enabled,
            'problem': problem or (genesis_problem if installed else ''),
            'derived_unavailable': derived_unavailable(home),
            'data_home': str(home), 'build_id': manifest['build_id']}


def import_games(bundle, home, game=None, genesis=None):
    resources, manifest = app_resources(bundle)
    # Validate optional input before committing either import.
    # The verified bytes are the ones derived from, never a later re-read.
    rom = Path(genesis).read_bytes() if genesis and regular(genesis) else None
    if genesis and (rom is None or hashlib.sha256(rom).hexdigest() != ROM_SHA):
        raise ValueError('Unsupported Genesis ROM. Select the original raw ROM revision documented in the README; no data was replaced.')
    target = managed(home, home/'content'/CONTENT_SHA)
    if game:
        game = Path(game)
        rows = source_records(resources)
        if not game.is_dir() or is_link(game): raise ValueError('Choose an extracted PC game folder')
        if inside(home, game): raise ValueError('Choose a player data folder outside the original game folder. Originals are unchanged.')
        # Validate everything before creating any destination. DOS filenames are
        # case-insensitive, but case collisions are ambiguous and rejected.
        candidates = {}
        for path in game.iterdir(): candidates.setdefault(path.name.upper(), []).append(path)
        for row in rows:
            paths = candidates.get(row['name'].upper(), [])
            if len(paths) != 1 or not regular(paths[0]) or sha(paths[0]) != row['sha256']:
                raise ValueError('Unsupported or missing PC file: '+row['name']+'. Originals and existing saves are unchanged.')
        if target.exists(): validate_content(resources, target)
        else:
            home.mkdir(parents=True, exist_ok=True)
            if shutil.disk_usage(home).free < MIN_FREE: raise ValueError('At least 1 GiB of free disk space is required')
            target.parent.mkdir(parents=True, exist_ok=True)
            staging = Path(tempfile.mkdtemp(prefix='.import-', dir=target.parent))
            # Reuse the existing pinned-content reconstruction; the normalized
            # input staging preserves every byte and never changes source files.
            normalized = staging/'input'; normalized.mkdir()
            for row in rows: shutil.copyfile(candidates[row['name'].upper()][0], normalized/row['name'])
            sys.path.insert(0, str(resources/'kit'))
            from tools.package_setup import prepare
            prepared = staging/'prepared'
            prepare(normalized, prepared, rows)
            validate_content(resources, prepared)
            rename_directory(prepared, target)
            # Retain small staging inputs rather than deleting files automatically.
    elif not target.exists():
        raise ValueError('Choose the original PC game folder first. Genesis alone cannot run the PC simulation.')
    validate_content(resources, target)
    sys.path.insert(0, str(resources/'kit'))
    # PC-derived files come from the verified imported copy, never the source folder.
    derive_pc(home, derived_rows(manifest, 'pc'), target/'GAME')
    if genesis:
        # The ROM itself is never copied. Only pinned derivations are kept, and
        # the receipt lists exactly the files that were really reproduced.
        files, unavailable = derive_into_store(home, derived_rows(manifest, 'genesis'),
            DerivationInputs(game=target/'GAME', rom=rom))
        write_json(home/'content/genesis.json', {'schema': GENESIS_RECEIPT_SCHEMA, 'rom_sha256': ROM_SHA,
                                                 'files': files, 'unavailable': unavailable})
    return status(bundle, home)


def payload_names(manifest):
    names = set()
    for row in manifest['files']:
        name = row['path']; relative = Path(name)
        if not name or relative.as_posix() != name or '\\' in name or ':' in name or relative.is_absolute() or '..' in relative.parts or name in names:
            raise ValueError('Unsafe application payload manifest')
        names.add(name)
    return names


def valid_payload(resources, manifest):
    payload_names(manifest)
    for row in manifest['files']:
        name = row['path']; relative = Path(name)
        path = resources/'kit'/name
        if any(is_link(resources/'kit'/Path(*relative.parts[:i])) for i in range(1,len(relative.parts)+1)):
            raise ValueError('Application payload contains an unexpected symlink')
        if not regular(path) or sha(path) != row['sha256']:
            raise ValueError('Application payload is missing or changed: '+name)


def sync_derived(resources, home, manifest, target):
    """Place pinned derived files at the paths the presentation already reads.

    Older profiles derive missing PC files lazily from the verified installed
    originals; Genesis files exist only after a ROM import. A file that is not
    available is simply absent, so the original PC pixels show through.
    """
    names = payload_names(manifest)
    pc = derived_rows(manifest, 'pc')
    rows = pc + (derived_rows(manifest, 'genesis') if genesis_enabled(home, manifest) else [])
    if any(row['path'] in names for row in rows): raise ValueError('Derived file collides with the application payload')
    missing = [row for row in pc if not (regular(stored(home, row['sha256'])) and sha(stored(home, row['sha256'])) == row['sha256'])]
    if missing:
        sys.path.insert(0, str(resources/'kit'))
        derive_pc(home, pc, target/'GAME')
    for row in rows:
        source = stored(home, row['sha256'])
        if not regular(source) or sha(source) != row['sha256']: continue
        destination = managed(home, target/row['path'])
        if regular(destination) and sha(destination) == row['sha256']: continue
        if destination.exists() and not regular(destination): raise ValueError('Derived installation path is not a regular file: '+row['path'])
        destination.parent.mkdir(parents=True, exist_ok=True)
        write_bytes(destination, source.read_bytes())


def prepare_install(bundle, home):
    resources, manifest = app_resources(bundle)
    payload_names(manifest)
    target = managed(home, home/'versions'/manifest['build_id'])
    fresh = not target.exists() and not is_link(target)
    # An accepted version is fully re-hashed below; that copy is what runs, and
    # macOS also seals the bundle. Only a new copy needs the application hashed,
    # unless this build's own portable launcher just verified it.
    if fresh and os.environ.get(PAYLOAD_VERIFIED_ENV) != manifest['build_id']:
        valid_payload(resources, manifest)
    expected_sha = next((row['sha256'] for row in manifest['files']
                         if row['path'] == 'tools/package/game-inputs.json'), None)
    if expected_sha is None: raise ValueError('Verified original input manifest is missing from the application payload')
    # Bind the expected original records to reviewed bytes, never a later read
    # of an application file that can change while copying.
    records = source_records(resources, expected_sha)
    content = managed(home, home/'content'/CONTENT_SHA)
    # The accepted version's own GAME copy is checked by validate_install.
    if fresh: validate_content(resources, content, records)
    home.mkdir(parents=True, exist_ok=True)
    if is_link(target): raise ValueError('Versioned installation cannot be a symlink or junction')
    if not target.exists():
        if shutil.disk_usage(home).free < MIN_FREE: raise ValueError('At least 1 GiB of free disk space is required')
        target.parent.mkdir(parents=True, exist_ok=True)
        staging = Path(tempfile.mkdtemp(prefix='.install-', dir=target.parent))
        try:
            for row in manifest['files']:
                destination = staging/row['path']; destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(resources/'kit'/row['path'], destination)
                destination.chmod(row['mode'])
            shutil.copytree(content/'GAME', staging/'GAME')
            shutil.copyfile(content/'.runtime/pc-core/abrams-ref.zip', staging/'.runtime/pc-core/abrams-ref.zip')
            write_json(staging/'INSTALL.json', {'schema':1,'build_id':manifest['build_id']})
            validate_install(resources, home, staging, manifest, records, candidate=True)
            rename_directory(staging, target)
        finally:
            # This unique unfinished directory contains only attempted copies.
            # Never remove an accepted version, original source or player state.
            # A transient lock on cleanup must not hide the real failure.
            if staging.exists(): shutil.rmtree(staging, ignore_errors=True)
    else:
        # The candidate was verified immediately before promotion.
        validate_install(resources, home, target, manifest, records)
    sync_derived(resources, home, manifest, target)
    return target


def validate_install(resources, home, target, manifest, records, candidate=False):
    # Reuse the same checks on an unfinished candidate and an accepted version.
    # Working if: a failed copy never poisons the version ID, while existing
    # changed versions remain untouched for diagnosis.
    for row in manifest['files']:
        path = managed(home, target/row['path'])
        if not regular(path) or sha(path) != row['sha256']:
            if candidate:
                raise ValueError('New installation copy failed verification: '+row['path']+'. Existing originals, installations and saves are unchanged; retry from the verified application.')
            raise ValueError('Versioned installation changed: '+row['path']+'. Keep it for recovery and use a fresh data home.')
    try:
        validate_content(resources, target, records)
    except (ValueError, OSError) as error:
        if candidate:
            raise ValueError('New installation original-content copy failed verification. Existing originals and saves are unchanged; retry from the verified application.') from error
        raise


def renderer_preflight(arguments, env, log_path):
    """Accept clean diagnostics as well as exit status, retaining the full log.

    Working if: zero-exit parse errors never launch gameplay, clean commands
    ignore historical failures, and owned preflight commands have a deadline.
    """
    with log_path.open('ab') as log:
        start = log.tell()
        try:
            result = subprocess.run(arguments, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=300)
        except subprocess.TimeoutExpired as error:
            raise subprocess.SubprocessError(f'Renderer preflight timed out after 300 seconds. Details: {log_path}') from error
    pattern = re.compile(br'(?:SCRIPT ERROR|Parse Error|SHADER ERROR|ERROR:)', re.I)
    tail = b''
    diagnostic = b''
    with log_path.open('rb') as log:
        log.seek(start)
        for chunk in iter(lambda: log.read(8192), b''):
            text = tail[-128:] + chunk
            match = pattern.search(text)
            if match and not diagnostic: diagnostic = text[match.start():].split(b'\n',1)[0][:512]
            tail = (tail + chunk)[-2048:]
    if result.returncode or diagnostic:
        detail = (diagnostic or tail).decode('utf-8', errors='replace').strip()
        raise subprocess.SubprocessError(f'Renderer preflight failed (exit {result.returncode}). Details: {log_path}'+('\n'+detail if detail else ''))


def renderer_import(godot, project, build_id, env, log_path, extra=(), preflight=None):
    """Run the editor import once per verified build, then only on change.

    The marker lives in the import cache itself, so deleting .godot repeats the
    import. --check-only still runs on every launch.
    """
    marker = Path(project)/IMPORT_MARKER
    if regular(marker) and not is_link(marker.parent) and marker.read_text() == build_id+'\n': return False
    (preflight or renderer_preflight)([str(godot),'--headless',*extra,'--path',str(project),'--editor','--import'], env, log_path)
    if is_link(marker.parent): raise ValueError('Renderer import cache cannot be a symlink or junction')
    marker.parent.mkdir(exist_ok=True)
    write_bytes(marker, (build_id+'\n').encode())
    return True


def launch(bundle, home, extra):
    forbidden = {'--saves','--output','--trace','--reference','--pc-only','--graphics'}
    if any(arg.split('=')[0] in forbidden for arg in extra):
        raise ValueError('The application owns content, presentation and save paths; use its importer/settings.')
    resources, manifest = app_resources(bundle)
    install = prepare_install(bundle, home)
    portable = Path(bundle).suffix != '.app'
    godot = Path(bundle)/('renderer/AbramsRenderer.exe' if sys.platform == 'win32' else 'renderer/AbramsRenderer') if portable else Path(bundle)/'Contents/Helpers/AbramsRenderer.app/Contents/MacOS/AbramsRenderer'
    runtime = resources/'runtime/AbramsRuntime'/('AbramsRuntime.exe' if sys.platform == 'win32' else 'AbramsRuntime')
    for path in [godot,runtime]:
        if not regular(path) or not os.access(path,os.X_OK): raise ValueError('Bundled runtime is unavailable')
    managed(home, home/'saves').mkdir(exist_ok=True); managed(home, home/'logs').mkdir(exist_ok=True)
    env = dict(os.environ, ABRAMS_PYTHON=str(runtime), PYTHONDONTWRITEBYTECODE='1')
    # Ignore developer-machine overrides and package-manager Python search paths.
    for key in ['PYTHONHOME','PYTHONPATH','GODOT_BIN',PAYLOAD_VERIFIED_ENV]:
        env.pop(key,None)
    application_log = managed(home, home/'logs/application.log')
    renderer_import(godot, install/'godot', manifest['build_id'], env, application_log)
    renderer_preflight([str(godot),'--headless','--path',str(install/'godot'),'--script','res://scripts/pc_bridge_viewer.gd','--check-only'], env, application_log)
    # Explicit game mute also avoids opening an OS audio device before startup.
    engine_args=[str(godot)]
    if '--no-audio' in extra: engine_args.extend(['--audio-driver','Dummy'])
    args=engine_args+['--path',str(install/'godot'),'--script','res://scripts/pc_bridge_viewer.gd','--','--boot','--play','--saves',str(home/'saves'),'--output',str(home/'logs')]
    if not genesis_enabled(home, manifest): args.append('--pc-only')
    args.extend(extra)
    if portable:
        # Game console output goes to the profile log, not the bounded setup pipes;
        # a failure reports the exit code and this session's last log lines.
        game_log = managed(home, home/'logs/game.log')
        with game_log.open('ab') as log:
            log.write(b'\n== game session ==\n'); log.flush(); start = log.tell()
            code = subprocess.call(args, env=env, stdout=log, stderr=subprocess.STDOUT)
        if code:
            with game_log.open('rb') as log:
                log.seek(max(start, log.seek(0, 2)-1000)); tail = log.read().decode('utf-8', 'replace').strip()
            print(json.dumps({'error': f'The game exited with code {code}. Details: {game_log}'+('\n'+tail if tail else '')}), file=sys.stderr)
        return code
    os.execve(godot,args,env)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle',type=Path,required=True)
    p.add_argument('--data-home')
    p.add_argument('--status',action='store_true')
    p.add_argument('--game',type=Path)
    p.add_argument('--genesis',type=Path)
    p.add_argument('--prepare',action='store_true')
    p.add_argument('--play',action='store_true')
    args,extra=p.parse_known_args()
    try:
        home=profile_home(args.bundle,args.data_home)
        if args.game or args.genesis: import_games(args.bundle,home,args.game,args.genesis)
        if args.prepare: print(json.dumps({'installation':str(prepare_install(args.bundle,home))}))
        elif args.play: return launch(args.bundle,home,extra)
        else:
            if extra: raise ValueError('Unknown setup arguments')
            print(json.dumps(status(args.bundle,home)))
    except (ValueError,OSError,KeyError,subprocess.SubprocessError,json.JSONDecodeError) as error:
        print(json.dumps({'error':str(error)}),file=sys.stderr);return 1
    return 0

if __name__=='__main__':raise SystemExit(main())
