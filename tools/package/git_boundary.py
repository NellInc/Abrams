#!/usr/bin/env python3
"""Read-only index/history guard. Never prints matching credential contents."""
from __future__ import annotations
import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
# Ordinary Git object limit. Files up to 100 MB need no size hold; only larger
# ones need an LFS/.gitignore decision (and LFS pointers are rejected below).
MAX_BYTES = 100_000_000
# Total expanded bytes one published browser archive may inflate to.
ZIP_EXPANSION_LIMIT = 200_000_000
PRIVATE_PARTS = {'.runtime', '.godot', '.git', 'game', 'genesis', 'reference',
                 'local-art', 'local-audio', 'artifacts', 'capture', 'saves', 'states',
                 '__pycache__', 'builds', '.ssh', '.aws'}
# Never acceptable inside a published asset archive, even below local-art/.
ARCHIVE_PRIVATE_PARTS = PRIVATE_PARTS - {'genesis', 'local-art', 'local-audio'}
BINARY_SUFFIXES = {'.rom', '.smd', '.bin', '.exe', '.com', '.dylib', '.dll', '.so',
                   '.state', '.zip', '.7z', '.rar', '.pyc', '.p12', '.pfx', '.pem', '.key',
                   # inspect_scenarios --extract writes decompressed original resources.
                   '.decoded'}
# The authored player-reference PDFs; manual scans and other PDFs stay local.
PUBLISHED_PDFS = {'docs/player-reference/keyboard-controls.pdf', 'docs/player-reference/field-guide.pdf',
                  'website/dist/assets/guides/field-guide.pdf', 'website/dist/assets/guides/keyboard-controls.pdf'}
# Each pattern starts with a literal so the regex engine can skip quickly; the
# leading word boundary is checked separately (see secret_match).
SECRET_PATTERNS = [
    (re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'), False),
    (re.compile(rb'gh[pousr]_[A-Za-z0-9]{36,}\b'), True),
    (re.compile(rb'github_pat_[A-Za-z0-9_]{70,}\b'), True),
    (re.compile(rb'AKIA[0-9A-Z]{16}\b'), True),
    (re.compile(rb'sk-(?:proj-)?[A-Za-z0-9_-]{32,}\b'), True),
]
LFS_POINTER = b'version https://git-lfs.github.com/spec/'
WEB_GENERATED = 'website/dist/play/.generated/'
WEB_ZIPS = {'python-source.zip', 'pyodide/python_stdlib.zip'}
WEB_ASSET_ZIP = re.compile(r'remaster-assets-[0-9]{2}\.zip\Z')
WEB_WASM = WEB_GENERATED + 'godot/index.wasm'
WEB_WASM_SHA256 = 'fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0'
PUBLICATION = 'tools/package/web-publication.json'
# JSON keys that carry decoded original pixels, indices or geometry.
DECODED_KEYS = {'pixels', 'indices_base64', 'packed_indices_base64', 'source_primitives'}


def limit_text():
    # Read at call time so the reported limit always matches the enforced one.
    return f'{MAX_BYTES // 1_000_000} MB' if MAX_BYTES % 1_000_000 == 0 else f'{MAX_BYTES:,} bytes'


def web_zip_kind(name):
    if not name.startswith(WEB_GENERATED):
        return None
    suffix = name[len(WEB_GENERATED):]
    if suffix in WEB_ZIPS:
        return 'source'
    if WEB_ASSET_ZIP.fullmatch(suffix):
        return 'assets'
    return None


_PUBLICATIONS = {}


def load_publication(root=ROOT):
    """The reviewed Web publication list; malformed control data fails closed."""
    path = Path(root) / PUBLICATION
    identity = path.stat()
    key = (str(path), identity.st_mtime_ns, identity.st_size)
    if key in _PUBLICATIONS:
        return _PUBLICATIONS[key]
    data = json.loads(path.read_text())
    if (data.get('schema') != 1 or not isinstance(data.get('files'), dict) or
            not isinstance(data.get('decoded_denylist'), dict) or
            not isinstance(data.get('exceptions'), dict) or
            not isinstance(data.get('historical_publications'), dict)):
        raise ValueError('Unsupported Web publication list')
    for name, row in data['files'].items():
        if (not isinstance(row, dict) or row.get('set') not in {'common', 'genesis'} or
                not re.fullmatch(r'[0-9a-f]{64}', str(row.get('sha256')))):
            raise ValueError(f'Invalid Web publication entry: {name}')
        if row['sha256'] in data['decoded_denylist']:
            raise ValueError(f'Web publication entry is a known original decode: {name}')
    _PUBLICATIONS[key] = data
    return data


def public_asset_member(name, publication=None):
    """True only for an exact reviewed path; contents are checked separately."""
    publication = load_publication() if publication is None else publication
    path = PurePosixPath(name)
    if (any(part.startswith('.env') or part.endswith('.env') for part in path.parts) or
            path.name.lower() in {'credentials', 'id_rsa', 'id_ed25519'} or
            any(part.lower() in ARCHIVE_PRIVATE_PARTS for part in path.parts)):
        return False
    return name in publication['files']


def decoded_payload(data):
    """Name the first decoded-original key in a JSON document, if any."""
    try:
        document = json.loads(data)
    except (UnicodeDecodeError, ValueError):
        return None
    pending = [document]
    while pending:
        value = pending.pop()
        if isinstance(value, dict):
            hit = DECODED_KEYS.intersection(value)
            if hit:
                return sorted(hit)[0]
            pending.extend(value.values())
        elif isinstance(value, list):
            pending.extend(value)
    return None


def path_problem(name):
    p = PurePosixPath(name)
    parts = [part.lower() for part in p.parts]
    if ('\\' in name or p.is_absolute() or '..' in parts or str(p) != name
            or any(ord(c) < 32 for c in name)):
        return 'unsafe path'
    if any(part in PRIVATE_PARTS or part.startswith('.env') or part.endswith('.env') for part in parts):
        return 'private directory or environment file'
    if (p.suffix.lower() in BINARY_SUFFIXES and not web_zip_kind(name)) or p.name.lower() in {'credentials', 'id_rsa', 'id_ed25519'}:
        return 'original/runtime/archive/credential format'
    if p.suffix.lower() == '.pdf' and name not in PUBLISHED_PDFS:
        return 'unreviewed PDF; manual scans stay local'
    if len(parts) == 2 and parts[0] == 'branding' and p.suffix.lower() == '.png':
        return 'local box-art working copy; publish the reviewed copy under docs/images'
    return None


def known_inputs():
    records = json.loads((ROOT / 'tools/package/game-inputs.json').read_text())['files']
    # Reuse the existing canonical ROM pin without importing optional libraries.
    text = (ROOT / 'tools/extract_genesis_samples.py').read_text()
    rom = re.search(r'^ROM_HASH = "([0-9a-f]{64})"$', text, re.MULTILINE)
    if not rom:
        raise ValueError('Canonical Genesis ROM pin missing')
    from tools.package_setup import CONTENT_SHA
    return {r['sha256'] for r in records} | {rom[1], CONTENT_SHA}


def secret_match(data):
    for pattern, word_start in SECRET_PATTERNS:
        at = 0
        while True:
            match = pattern.search(data, at)
            if not match:
                break
            start = match.start()
            # Equivalent to a leading \b: the match begins with a word byte.
            if not word_start or start == 0 or not (data[start - 1:start].isalnum() or data[start - 1:start] == b'_'):
                return True
            at = start + 1
    return False


def lfs_problem(data, known_hashes):
    if not data.startswith(LFS_POINTER) or len(data) > 1024:
        return None
    oid = re.search(rb'^oid sha256:([0-9a-f]{64})$', data, re.MULTILINE)
    if oid and oid[1].decode() in known_hashes:
        return 'Git LFS pointer to a fingerprinted original'
    # The real bytes live outside Git and cannot be inspected here.
    return 'Git LFS pointer; real bytes are not inspectable'


def asset_member_unsafe(name):
    """Asset parts legitimately hold reviewed local-art/ and branding/ paths."""
    problem = path_problem(name) if name else 'unsafe path'
    waivable = problem in {
        'private directory or environment file',
        'local box-art working copy; publish the reviewed copy under docs/images'}
    return bool(problem) and not (waivable and not any(
        part.lower() in ARCHIVE_PRIVATE_PARTS or part.startswith('.env') or part.endswith('.env')
        for part in PurePosixPath(name).parts))


def inspect_public_web_zip(data, kind, known_hashes, publication=None):
    """Inspect published archive members instead of exempting opaque ZIP bytes."""
    if kind == 'assets' and publication is None:
        publication = load_publication()
    try:
        with zipfile.ZipFile(BytesIO(data)) as archive:
            members = archive.infolist()
            if len(members) != len({item.filename for item in members}):
                return 'unsafe browser archive member'
            total = 0
            for item in members:
                name = item.filename.rstrip('/')
                reviewed = kind == 'assets' and public_asset_member(name, publication)
                if (asset_member_unsafe(name) if kind == 'assets' else
                        (path_problem(name) if name else 'unsafe path')):
                    return 'unsafe browser archive member'
                if kind == 'assets' and not reviewed:
                    return 'unreviewed browser asset path'
                if (item.flag_bits & 1 or item.compress_type not in
                        {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED} or
                        stat.S_ISLNK(item.external_attr >> 16)):
                    return 'unsafe browser archive member'
                if item.is_dir():
                    continue
                total += item.file_size
                if item.file_size > MAX_BYTES or total > ZIP_EXPANSION_LIMIT:
                    return 'browser archive expands beyond bound'
                member = archive.read(item)
                if kind == 'assets':
                    digest = hashlib.sha256(member).hexdigest()
                    if digest in publication['decoded_denylist']:
                        return 'browser archive member: decoded original data'
                    if digest != publication['files'][name]['sha256']:
                        return 'browser asset differs from its reviewed publication entry'
                    key = decoded_payload(member) if name.endswith('.json') else None
                    if key and name not in publication['exceptions']:
                        return f'browser archive member: decoded original {key}'
                problem = inspect_blob(member, known_hashes, publication=publication, published=True)
                if problem:
                    return f'browser archive member: {problem}'
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile, NotImplementedError):
        return 'invalid browser archive'
    return None


def inspect_blob(data, known_hashes, name=None, publication=None, published=False, reviewed_history=False,
                 superseded=False):
    """Inspect one blob; `published` adds the Git/Pages decoded-original rules.

    Private kits legitimately carry decodes, so callers outside Git pass
    neither flag. `superseded` marks an asset part that only history holds:
    exact membership is an index rule for what will be published, so a part
    reviewed under an earlier list is checked for decodes, unsafe paths,
    originals and credentials, never against today's entries.
    `reviewed_history` marks an already-published archive listed under
    historical_publications: it is still scanned for originals and
    credentials, but is exempt from the decoded-original rules.
    """
    if len(data) > MAX_BYTES:
        return f'file exceeds {limit_text()}'
    digest = hashlib.sha256(data).hexdigest() if data else None
    # An original zero-byte marker is indistinguishable from harmless empty
    # Python package markers; it carries no original game content.
    if digest in known_hashes:
        return 'fingerprinted original game/ROM/content archive'
    problem = lfs_problem(data, known_hashes)
    if problem:
        return problem
    if name and PurePosixPath(name).name == '.gitattributes' and re.search(rb'filter\s*=\s*lfs\b', data):
        return 'Git LFS attribute; real bytes would bypass inspection'
    if published and digest and not reviewed_history:
        publication = load_publication() if publication is None else publication
        if digest in publication['decoded_denylist']:
            return 'decoded original data'
    kind = web_zip_kind(name) if name else None
    if kind == 'assets' and reviewed_history:
        return historical_archive_problem(data, known_hashes)
    if kind == 'assets' and superseded:
        return historical_archive_problem(data, known_hashes, publication or load_publication())
    if kind:
        return inspect_public_web_zip(data, kind, known_hashes, publication)
    # This exact pinned Godot 4.7.2 binary includes a false-positive key
    # header sequence. New engine bytes must be reviewed rather than bypassed.
    if name == WEB_WASM and digest == WEB_WASM_SHA256:
        return None
    if secret_match(data):
        return 'credential signature'
    return None


def historical_archive_problem(data, known_hashes, publication=None):
    """Originals, credentials and bounds for an archive only history holds.

    With `publication`, a superseded part must also be free of unsafe paths
    and decoded original data; only historical_publications skip that.
    """
    try:
        with zipfile.ZipFile(BytesIO(data)) as archive:
            total = 0
            for item in archive.infolist():
                name = item.filename.rstrip('/')
                if publication is not None and asset_member_unsafe(name):
                    return 'unsafe browser archive member'
                if item.is_dir():
                    continue
                total += item.file_size
                if item.file_size > MAX_BYTES or total > ZIP_EXPANSION_LIMIT:
                    return 'browser archive expands beyond bound'
                member = archive.read(item)
                if publication is not None:
                    if hashlib.sha256(member).hexdigest() in publication['decoded_denylist']:
                        return 'browser archive member: decoded original data'
                    # Retiring an exception later means recording the superseded
                    # parts that relied on it under historical_publications.
                    key = decoded_payload(member) if name.endswith('.json') else None
                    if key and name not in publication['exceptions']:
                        return f'browser archive member: decoded original {key}'
                problem = inspect_blob(member, known_hashes)
                if problem:
                    return f'browser archive member: {problem}'
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile, NotImplementedError):
        return 'invalid browser archive'
    return None


def git(root, *args, input=None):
    command=['git', '-C', str(root), *args]
    if input is None:
        return subprocess.check_output(command)
    # Bulk Git commands can fill stdout while consuming the inventory.
    # Keep the complete response without bidirectional pipe back-pressure.
    with tempfile.TemporaryFile() as output:
        subprocess.run(command,input=input,stdout=output,stderr=subprocess.PIPE,check=True)
        output.seek(0)
        return output.read()


def name_class(name):
    """Every way inspect_blob depends on the name; equal classes share a verdict."""
    kind = web_zip_kind(name)
    return (kind, name == WEB_WASM, PurePosixPath(name).name == '.gitattributes')


def lfs_attributes(root, names):
    """Paths whose effective Git attributes route them through Git LFS."""
    if not names:
        return set()
    result=git(root,'check-attr','--cached','-z','--stdin','filter',
               input='\0'.join(sorted(names)).encode()+b'\0')
    fields = result.split(b'\0')
    return {fields[i].decode('utf-8', 'surrogateescape') for i in range(0, len(fields) - 2, 3)
            if fields[i + 2] == b'lfs'}


def check(root, history=False, known_hashes=None, publication=None):
    known_hashes = known_inputs() if known_hashes is None else known_hashes
    publication = load_publication(root if (Path(root) / PUBLICATION).is_file() else ROOT) if publication is None else publication
    entries = set()
    for record in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if record:
            meta, name = record.split(b'\t', 1)
            mode, oid, stage = meta.decode().split()
            if stage != '0':
                raise ValueError('Resolve conflicted index before boundary validation')
            entries.add((mode, oid, name.decode('utf-8', 'surrogateescape')))
    index_oids = {oid for _, oid, _ in entries}
    failures = {(name, 'Git LFS attribute; real bytes would bypass inspection')
                for name in lfs_attributes(root, {name for _, _, name in entries})}
    if history:
        if git(root, 'rev-parse', '--is-shallow-repository').strip() == b'true':
            raise ValueError('Full history required; shallow checkout cannot prove the boundary')
        for commit in git(root, 'rev-list', '--all').splitlines():
            for record in git(root, 'ls-tree', '-r', '-z', commit.decode()).split(b'\0'):
                if record:
                    meta, name = record.split(b'\t', 1)
                    mode, kind, oid = meta.decode().split()
                    entries.add((mode, oid, name.decode('utf-8', 'surrogateescape')))
    blobs = {}
    for mode, oid, name in entries:
        problem = path_problem(name)
        if problem:
            failures.add((name, problem))
        if mode not in {'100644', '100755'}:
            failures.add((name, 'symlink, submodule or nonregular entry'))
        else:
            blobs.setdefault(oid, set()).add(name)
    # Reviewed, already-published archives stay inspectable for secrets and
    # originals, but only history (never the index) may carry them. Any other
    # part history alone holds was superseded by a later reviewed build.
    historical = {oid for oid in publication['historical_publications'] if oid not in index_oids}
    if blobs:
        sizes = git_sizes(root, blobs)
        # Stream one bounded blob at a time; never materialize whole history.
        with subprocess.Popen(['git', '-C', str(root), 'cat-file', '--batch'],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE) as process:
            for oid, names in sorted(blobs.items()):
                if sizes[oid] > MAX_BYTES:
                    problem, data = f'file exceeds {limit_text()}', None
                else:
                    process.stdin.write((oid + '\n').encode()); process.stdin.flush()
                    header = process.stdout.readline().split()
                    if len(header) != 3 or header[1] != b'blob':
                        raise ValueError('Git blob unavailable')
                    data = process.stdout.read(int(header[2]))
                    if process.stdout.read(1) != b'\n':
                        raise ValueError('Malformed git blob stream')
                    problem = None
                # One inspection per (blob, name class), not per historical name.
                verdicts = {}
                for name in names:
                    key = name_class(name)
                    if key not in verdicts:
                        verdicts[key] = problem or inspect_blob(
                            data, known_hashes, name, publication, published=True,
                            reviewed_history=oid in historical, superseded=oid not in index_oids)
                    if verdicts[key]:
                        failures.add((name, verdicts[key]))
            process.stdin.close()
            if process.wait() != 0:
                raise ValueError('Git object inspection failed')
    return sorted(failures)


def git_sizes(root, blobs):
    result=git(root,'cat-file','--batch-check=%(objectname) %(objecttype) %(objectsize)',
               input=('\n'.join(blobs)+'\n').encode()).decode()
    sizes = {}
    for line in result.splitlines():
        oid, kind, size = line.split()
        if kind != 'blob':
            raise ValueError('Git object is not a blob')
        sizes[oid] = int(size)
    return sizes


def generated_growth(root):
    """Bytes of new Web-bundle blobs in local commits that no remote has yet."""
    listing = subprocess.run(['git', '-C', str(root), 'rev-list', '--objects', 'HEAD', '--not', '--remotes'],
                             capture_output=True, text=True, check=True).stdout
    oids = {line.split(' ', 1)[0] for line in listing.splitlines()
            if ' ' in line and line.split(' ', 1)[1].startswith(WEB_GENERATED)}
    if not oids:
        return 0
    # The listing also names trees under the prefix; count only blobs.
    result=git(root,'cat-file','--batch-check=%(objecttype) %(objectsize)',
               input=('\n'.join(sorted(oids))+'\n').encode()).decode()
    return sum(int(size) for kind, size in (line.split() for line in result.splitlines()) if kind == 'blob')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true', help='also scan all reachable local refs; requires full history')
    args = parser.parse_args()
    try:
        failures = check(ROOT, history=args.history)
        for name, reason in failures:
            print(f'{name!r}: {reason}')
        if failures:
            raise SystemExit(1)
        if args.history:
            growth = generated_growth(ROOT)
            if growth > 100_000_000:
                # Advisory: every bundle rebuild stays in history permanently.
                print(f'WARNING: unpushed commits add {growth / 1e6:.0f} MB of generated Web bundle blobs', file=sys.stderr)
        print('PASS: index' + (' and all reachable history' if args.history else '') + f' boundary ({limit_text()}; known inputs; Web publication list; credential signatures)')
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Boundary check failed: {error}\n')


if __name__ == '__main__':
    main()
