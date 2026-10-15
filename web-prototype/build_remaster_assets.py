#!/usr/bin/env python3
"""Stage authored presentation assets for local Godot Web QA.

The visitor's PC game and optional Genesis ROM are never read by this builder.
Only the exact paths and bytes in tools/package/web-publication.json are
eligible. Decodes of original data are derived in the visitor's browser
(web-prototype/derived_art.mjs) and are never packed.

Usage: build_remaster_assets.py [--update-publication]
"""
from pathlib import Path
from contextlib import contextmanager
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.standalone.runtime import ROM_SHA
OUT = ROOT / 'web-prototype/.generated'
PUBLICATION = ROOT / 'tools/package/web-publication.json'
KINDS = {'.png', '.json', '.ttf', '.svg', '.wav'}
# Text members are deflated; PNG/TTF/WAV gain little and stay stored.
DEFLATED = {'.json', '.svg'}
# Git accepts objects up to 100 MB; one part stays near 48 MB so the browser
# holds a bounded archive in memory while it verifies and installs it.
MAX_PART_BYTES = 48_000_000
# Families smaller than this share pooled parts; larger ones own theirs, so a
# change re-publishes only its own family's parts.
FAMILY_POOL_BYTES = 8_000_000
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)
GODOT_FILES = ('index.js', 'index.wasm', 'index.pck', 'index.icon.png',
               'index.audio.worklet.js', 'index.audio.position.worklet.js')
STALE_GODOT_FILES = ('index.html', 'index.service.worker.js', 'index.manifest.json',
                     'index.offline.html', 'index.144x144.png', 'index.180x180.png',
                     'index.512x512.png')
def publication():
    """The reviewed public list; the desktop private allowlist is never used."""
    from tools.package.git_boundary import load_publication
    return load_publication(PUBLICATION.parents[2])


def selected():
    # Only exact reviewed paths and bytes publish. The private desktop kit's
    # allowlist includes original GAME files and decodes; it is not a source.
    reviewed = publication()
    for name, row in sorted(reviewed['files'].items()):
        path = ROOT / name
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f'Missing or linked published Web asset: {name}')
        if path.suffix.lower() not in KINDS:
            raise SystemExit(f'Unsupported published Web asset format: {name}')
        if fingerprint(path)[-1] != row['sha256']:
            raise SystemExit(f'Published Web asset differs from its reviewed entry: {name}. Review the change, '
                             'then run web-prototype/build_remaster_assets.py --update-publication')
        yield path


def asset_set(name, reviewed=None):
    row = (reviewed or publication())['files'].get(name)
    return row['set'] if row else 'common'


def family(name):
    """Stable packing group: set plus the first two path components."""
    parts = name.split('/')
    return '/'.join(parts[:2]) if len(parts) > 2 else parts[0]


def plan_parts(rows):
    """Group (name, set, size) rows into ordered parts that stay stable.

    Each large family owns its parts; small families share one pooled run per
    set. Adding a file only changes parts of its own family (or its pool).
    """
    families = {}
    for name, kind, size in rows:
        families.setdefault((kind, family(name)), []).append((name, size))
    groups = {}
    for (kind, key), members in families.items():
        total = sum(size for _, size in members)
        groups.setdefault((kind, key if total >= FAMILY_POOL_BYTES else '~pool'), []).extend(members)
    plan = []
    for (kind, _), members in sorted(groups.items(), key=lambda item: (item[0][0] != 'common', item[0][1])):
        current, used = [], 22
        for name, size in sorted(members):
            estimated = size + 100 + 2 * len(name.encode())
            if estimated + 22 > MAX_PART_BYTES:
                raise SystemExit(f'One authored asset exceeds a Web part: {name}')
            if current and used + estimated > MAX_PART_BYTES:
                plan.append((kind, current)); current, used = [], 22
            current.append(name); used += estimated
        if current: plan.append((kind, current))
    return plan


def update_publication():
    """Re-pin reviewed paths after a human has reviewed their changed bytes."""
    from tools.package.git_boundary import decoded_payload
    data = json.loads(PUBLICATION.read_text())
    changed = []
    for name, row in data['files'].items():
        path = ROOT / name
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f'Missing or linked published Web asset: {name}')
        digest = fingerprint(path)[-1]
        if digest in data['decoded_denylist']:
            raise SystemExit(f'Refusing to publish a known original decode: {name}')
        if path.suffix.lower() == '.json' and decoded_payload(path.read_bytes()) and name not in data['exceptions']:
            raise SystemExit(f'Refusing to publish decoded original data: {name}')
        if digest != row['sha256']:
            row['sha256'] = digest; changed.append(name)
    PUBLICATION.write_text(json.dumps(data, indent=1) + '\n')
    print(f'Re-pinned {len(changed)} reviewed Web asset(s): ' + (', '.join(changed) or 'none'))


def fingerprint(path):
    if path.is_symlink() or not path.is_file():
        raise SystemExit(f'Missing or linked build file: {path}')
    stat = path.stat()
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    after = path.stat()
    identity = (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns)
    if identity != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
        raise SystemExit(f'Build file changed while reading: {path}')
    return (*identity, digest.hexdigest())


@contextmanager
def generated_lock(out, exclusive=True):
    """Cooperating writers/readers hold one stable lock inode; never unlink it."""
    import fcntl  # These pinned local Web build tools run on POSIX hosts.
    if out.is_symlink() or (out.exists() and not out.is_dir()):
        raise SystemExit('Refusing a linked or non-directory generated target')
    out.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(out / '.abrams-build.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(descriptor, (fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH) | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit('Generated build is in use by another builder or packager')
        yield
    finally:
        os.close(descriptor)


def output_identity(out, include_godot=False):
    if out.is_symlink() or (out / 'godot').is_symlink():
        raise SystemExit('Refusing a linked generated target')
    names = {'remaster-assets.json', 'genesis-input.json', 'remaster-assets.zip'}
    names.update(p.name for p in out.glob('remaster-assets-*.zip')
                 if re.fullmatch(r'remaster-assets-\d{2}\.zip', p.name))
    if include_godot:
        names.update('godot/' + name for name in GODOT_FILES + STALE_GODOT_FILES)
    return {name: fingerprint(out / name) if (out / name).exists() or (out / name).is_symlink() else None
            for name in sorted(names)}


def install_outputs(inputs, out, expected, include_godot=False):
    """Recover handled failures, preserving unrelated generated files.

    Call under generated_lock. This is a guarded multi-file promotion, not
    atomic visibility or power-loss durability. An incomplete recovery retains
    its journal and backup. Working if: failed promotion restores old bytes,
    concurrent target edits are refused, and foreign generated files stay exact.
    """
    allowed = {'remaster-assets.json', 'genesis-input.json'}
    if include_godot: allowed.update('godot/' + name for name in GODOT_FILES)
    if not inputs or any(name not in allowed and not re.fullmatch(r'remaster-assets-\d{2}\.zip', name) for name in inputs):
        raise SystemExit('Unsafe generated output name')
    temporary = Path(tempfile.mkdtemp(prefix='.abrams-promotion-', dir=out))
    candidate, backup = temporary / 'candidate', temporary / 'previous'
    moved, installed, rows = [], [], {}
    retain = False
    try:
        for name, source in inputs.items():
            before = fingerprint(source)
            destination = candidate / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            if fingerprint(source) != before or fingerprint(destination)[-1] != before[-1]:
                raise SystemExit(f'Generated candidate changed during copying: {name}')
            rows[name] = {'bytes': before[2], 'sha256': before[-1]}
        if output_identity(out, include_godot) != expected:
            raise SystemExit('Generated target changed during building; previous build retained')
        # Persist recovery information before the first target mutation.
        journal = {'managed_before': expected, 'candidate': rows,
                   'moved': moved, 'installed': installed}
        def record():
            (temporary / 'recovery.json').write_text(json.dumps(journal, indent=2) + '\n')
        record()
        try:
            for name, identity in expected.items():
                if identity is not None:
                    saved = backup / name
                    saved.parent.mkdir(parents=True, exist_ok=True)
                    (out / name).replace(saved)
                    moved.append(name); record()
            for name in inputs:
                destination = out / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                (candidate / name).replace(destination)
                installed.append(name); record()
        except BaseException as error:
            failures = []
            for name in reversed(installed):
                try:
                    path = out / name
                    if path.exists() and fingerprint(path)[-1] != rows[name]['sha256']:
                        raise RuntimeError('Installed output changed during recovery')
                    path.unlink(missing_ok=True)
                except BaseException as failure: failures.append(f'{name}: {failure}')
            for name in reversed(moved):
                try:
                    if (out / name).exists() or (out / name).is_symlink():
                        raise RuntimeError('Recovery destination is occupied')
                    (backup / name).replace(out / name)
                except BaseException as failure: failures.append(f'{name}: {failure}')
            if failures:
                retain = True
                raise RuntimeError(f'Generated replacement failed; recovery retained at {temporary}: {failures}') from error
            raise
    finally:
        if not retain: shutil.rmtree(temporary)
    return rows


def stage_assets(out):
    out.mkdir(parents=True, exist_ok=True)
    control = PUBLICATION
    control_identity = fingerprint(control)
    paths = list(selected())
    if not 1 <= len(paths) <= 10000:
        raise SystemExit('Authored asset inventory is empty or exceeds its consumer limit')
    identities = {path: fingerprint(path) for path in paths}
    reviewed = publication()
    by_name = {}
    for path in paths:
        name = path.relative_to(ROOT).as_posix()
        if not re.fullmatch(r'[A-Za-z0-9_./-]+', name) or any(p in ('', '.', '..') for p in name.split('/')) or name.startswith(('GAME/', 'GENESIS/')):
            raise SystemExit(f'Unsafe authored asset path: {name}')
        by_name[name] = path
    plan = plan_parts([(name, asset_set(name, reviewed), identities[path][2]) for name, path in by_name.items()])
    if len(plan) > 100:
        raise SystemExit('Too many authored asset parts')
    # Entry-aligned ZIP parts load one at a time in the browser. Fixed entry
    # metadata makes unchanged inputs rebuild to byte-identical parts.
    parts = []
    manifest = []
    for index, (kind, names) in enumerate(plan):
        archive = out / f'remaster-assets-{index:02d}.zip'
        with zipfile.ZipFile(archive, 'w', allowZip64=False) as bundle:
            for name in names:
                path = by_name[name]
                raw = path.read_bytes()
                if fingerprint(path) != identities[path] or hashlib.sha256(raw).hexdigest() != identities[path][-1]:
                    raise SystemExit(f'Authored asset changed during building: {name}')
                entry = zipfile.ZipInfo(name, date_time=ZIP_EPOCH)
                entry.create_system = 3
                entry.external_attr = 0o644 << 16
                entry.compress_type = zipfile.ZIP_DEFLATED if path.suffix.lower() in DEFLATED else zipfile.ZIP_STORED
                bundle.writestr(entry, raw, compresslevel=9 if entry.compress_type == zipfile.ZIP_DEFLATED else None)
                manifest.append({'path': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), 'set': kind})
        if not 22 <= archive.stat().st_size <= MAX_PART_BYTES:
            raise SystemExit('Completed authored asset part exceeds its Web limit')
        parts.append({'name': archive.name, 'bytes': archive.stat().st_size,
                      'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'set': kind})
    if fingerprint(control) != control_identity or list(selected()) != paths or any(fingerprint(p) != identities[p] for p in paths):
        raise SystemExit('Authored inventory changed during building; previous build retained')
    (out / 'remaster-assets.json').write_text(json.dumps({
        'schema': 3, 'parts': parts,
        'files': manifest}, separators=(',', ':')) + '\n')
    (out / 'genesis-input.json').write_text(json.dumps({
        'sha256': ROM_SHA, 'bytes': 524288}, separators=(',', ':')) + '\n')
    print(f'Staged {len(manifest)} authored files in {len(parts)} parts '
          f'({sum(part["bytes"] for part in parts)} bytes); no original PC game files')
    return {name: out / name for name in ['remaster-assets.json', 'genesis-input.json'] + [p['name'] for p in parts]}


def main(argv=()):
    if list(argv) == ['--update-publication']:
        update_publication()
        return
    if argv:
        raise SystemExit('usage: build_remaster_assets.py [--update-publication]')
    with generated_lock(OUT):
        expected = output_identity(OUT)
        with tempfile.TemporaryDirectory(prefix='.abrams-assets-', dir=OUT) as workspace:
            inputs = stage_assets(Path(workspace))
            install_outputs(inputs, OUT, expected)


if __name__ == '__main__':
    main(sys.argv[1:])
