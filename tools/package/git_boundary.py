#!/usr/bin/env python3
"""Read-only index/history guard. Never prints matching credential contents."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MAX_BYTES = 50_000_000
PRIVATE_PARTS = {'.runtime', '.godot', '.git', 'game', 'genesis', 'reference',
                 'local-art', 'local-audio', 'artifacts', 'capture', 'saves', 'states',
                 '__pycache__', 'builds', '.ssh', '.aws'}
BINARY_SUFFIXES = {'.rom', '.smd', '.bin', '.exe', '.com', '.dylib', '.dll', '.so',
                   '.state', '.zip', '.7z', '.rar', '.pyc', '.p12', '.pfx', '.pem', '.key'}
SECRET_PATTERNS = [
    re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    re.compile(rb'\bgh[pousr]_[A-Za-z0-9]{36,}\b'),
    re.compile(rb'\bgithub_pat_[A-Za-z0-9_]{70,}\b'),
    re.compile(rb'\bAKIA[0-9A-Z]{16}\b'),
    re.compile(rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}\b'),
]


def limit_text():
    # Read at call time so the reported limit always matches the enforced one.
    return f'{MAX_BYTES // 1_000_000} MB' if MAX_BYTES % 1_000_000 == 0 else f'{MAX_BYTES:,} bytes'


def path_problem(name):
    p = PurePosixPath(name)
    parts = [part.lower() for part in p.parts]
    if ('\\' in name or p.is_absolute() or '..' in parts or str(p) != name
            or any(ord(c) < 32 for c in name)):
        return 'unsafe path'
    if any(part in PRIVATE_PARTS or part.startswith('.env') or part.endswith('.env') for part in parts):
        return 'private directory or environment file'
    if p.suffix.lower() in BINARY_SUFFIXES or p.name.lower() in {'credentials', 'id_rsa', 'id_ed25519'}:
        return 'original/runtime/archive/credential format'
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


def inspect_blob(data, known_hashes):
    if len(data) > MAX_BYTES:
        return f'file exceeds {limit_text()}'
    if hashlib.sha256(data).hexdigest() in known_hashes:
        return 'fingerprinted original game/ROM/content archive'
    if any(pattern.search(data) for pattern in SECRET_PATTERNS):
        return 'credential signature'
    return None


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def check(root, history=False, known_hashes=None):
    known_hashes = known_inputs() if known_hashes is None else known_hashes
    entries = set()
    for record in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if record:
            meta, name = record.split(b'\t', 1)
            mode, oid, stage = meta.decode().split()
            if stage != '0':
                raise ValueError('Resolve conflicted index before boundary validation')
            entries.add((mode, oid, name.decode('utf-8', 'surrogateescape')))
    if history:
        if git(root, 'rev-parse', '--is-shallow-repository').strip() == b'true':
            raise ValueError('Full history required; shallow checkout cannot prove the boundary')
        for commit in git(root, 'rev-list', '--all').splitlines():
            for record in git(root, 'ls-tree', '-r', '-z', commit.decode()).split(b'\0'):
                if record:
                    meta, name = record.split(b'\t', 1)
                    mode, kind, oid = meta.decode().split()
                    entries.add((mode, oid, name.decode('utf-8', 'surrogateescape')))
    failures = set()
    blobs = {}
    for mode, oid, name in entries:
        problem = path_problem(name)
        if problem:
            failures.add((name, problem))
        if mode not in {'100644', '100755'}:
            failures.add((name, 'symlink, submodule or nonregular entry'))
        else:
            blobs.setdefault(oid, set()).add(name)
    if blobs:
        sizes = git_sizes(root, blobs)
        # Stream one bounded blob at a time; never materialize whole history.
        with subprocess.Popen(['git', '-C', str(root), 'cat-file', '--batch'],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE) as process:
            for oid, names in sorted(blobs.items()):
                if sizes[oid] > MAX_BYTES:
                    problem = f'file exceeds {limit_text()}'
                else:
                    process.stdin.write((oid + '\n').encode()); process.stdin.flush()
                    header = process.stdout.readline().split()
                    if len(header) != 3 or header[1] != b'blob':
                        raise ValueError('Git blob unavailable')
                    data = process.stdout.read(int(header[2]))
                    if process.stdout.read(1) != b'\n':
                        raise ValueError('Malformed git blob stream')
                    problem = inspect_blob(data, known_hashes)
                if problem:
                    failures.update((name, problem) for name in names)
            process.stdin.close()
            if process.wait() != 0:
                raise ValueError('Git object inspection failed')
    return sorted(failures)


def git_sizes(root, blobs):
    result = subprocess.run(['git', '-C', str(root), 'cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)'],
                            input='\n'.join(blobs) + '\n', text=True, capture_output=True, check=True)
    sizes = {}
    for line in result.stdout.splitlines():
        oid, kind, size = line.split()
        if kind != 'blob':
            raise ValueError('Git object is not a blob')
        sizes[oid] = int(size)
    return sizes


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
        print('PASS: index' + (' and all reachable history' if args.history else '') + f' boundary ({limit_text()}; known inputs; credential signatures)')
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Boundary check failed: {error}\n')


if __name__ == '__main__':
    main()
