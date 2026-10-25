#!/usr/bin/env python3
"""Build deterministic local review kits from an explicit, reviewed allowlist.

No downloads, installers, uploads or licence grants. ZIP bytes are reproducible
from identical allowlisted inputs; this does not claim compiler reproducibility.
"""
from __future__ import annotations
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import re
import sys
import zipfile
try:
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = 'tools/package/allowlist.json'
RECEIPT = 'PACKAGE.json'
BANNED = {'.git', '.godot', '__pycache__', 'artifacts', 'capture', 'saves', 'states', '.ssh', '.aws'}
SOURCE_SUFFIXES = {'.py', '.sh', '.h', '.c', '.gd', '.gdshader', '.gdshaderinc', '.tscn', '.godot', '.md', '.json', '.command', '.txt', '.swift'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git_boundary():
    # Imported on demand: the managed launcher loads this module as a sibling
    # script and never builds kits, and the guard itself imports tools.*.
    try:
        from tools.package import git_boundary as boundary
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        sys.path.insert(0, str(ROOT))
        from tools.package import git_boundary as boundary
    return boundary


def boundary_guard():
    """Return a member check with the Git boundary's fingerprint and credential rules.

    Kits are read from the working tree, which git_boundary never sees, so each
    member is inspected here. Only an original at its pinned private path with
    its pinned hash is exempt; a renamed or relocated copy still fails.
    Working if: a source kit carrying a credential or a fingerprinted original
    fails, and a private kit fails on anything but its pinned inputs.
    """
    boundary = git_boundary()
    known = boundary.known_inputs()
    records = json.loads((boundary.ROOT / 'tools/package/game-inputs.json').read_text())['files']
    from tools.package_setup import CONTENT_SHA
    pinned = {'GAME/' + r['name']: r['sha256'] for r in records} | {'.runtime/pc-core/abrams-ref.zip': CONTENT_SHA}

    def check(name, data, kind):
        if kind == 'private' and pinned.get(name) == digest(data):
            return
        problem = boundary.inspect_blob(data, known, name)
        if problem:
            raise ValueError(f'Boundary violation in {kind} kit member {name}: {problem}')
    return check


def validate_name(name, kind):
    p = PurePosixPath(name)
    if not name or '\\' in name or p.is_absolute() or str(p) != name or '..' in p.parts:
        raise ValueError(f'Unsafe package path: {name}')
    # Exclusions compare case-insensitively (APFS opens 'Godot/Data' as godot/data);
    # exemptions stay exact-case, so a miscased spelling fails closed.
    lower = name.lower()
    parts = [x.lower() for x in p.parts]
    if any(x in BANNED or x.startswith('.env') or x.endswith('.env') for x in parts) or p.suffix.lower() in {'.state', '.pyc', '.log', '.tmp', '.pem', '.key', '.p12', '.pfx'}:
        raise ValueError(f'Forbidden private state: {name}')
    if 'genesis' in parts and not (kind == 'private' and name.startswith(('local-art/genesis/', 'reference/genesis/'))):
        raise ValueError(f'Original ROM directory: {name}')
    if parts[0] == 'local-audio' and not (kind == 'private' and name.startswith(('local-audio/frontend-music-v1/', 'local-audio/suno-score-v1/'))):
        raise ValueError(f'Unreviewed audio working files: {name}')
    if kind == 'source':
        if parts[0] in {'game', 'reference', 'local-art', '.runtime'} or lower.startswith(('godot/assets/', 'godot/data/')):
            raise ValueError(f'Non-source member in source kit: {name}')
        if lower.startswith('godot/tests/fixtures/') and not (name.startswith('godot/tests/fixtures/') and (p.name.endswith('_steps.json') or p.name in {'pc_bearings.json', 'pc_request_sound_oracle.json',
                'pc_reticle_ink.json', 'pc_reticle_target_ink.json'})):
            # The reticle ink fixtures are CPU-model output from the tracked offset table, not original bytes.
            raise ValueError(f'Extracted dialogue fixture: {name}')
        if p.suffix not in SOURCE_SUFFIXES and name != 'LICENSE':
            raise ValueError(f'Unreviewed source format: {name}')


def selected_files(root, kind):
    root = root.resolve()
    manifest = json.loads((root / MANIFEST).read_text())
    if manifest.get('schema') != 1:
        raise ValueError('Unsupported allowlist schema')
    names = list(manifest['source'])
    if kind == 'private':
        names += manifest['private']
    if len(set(names)) != len(names) or RECEIPT in names:
        raise ValueError('Duplicate or reserved allowlist member')
    listings = {}
    for name in names:
        validate_name(name, 'source' if name in manifest['source'] else 'private')
        path = root / name
        if any((root.joinpath(*Path(name).parts[:i])).is_symlink() for i in range(1, len(Path(name).parts) + 1)):
            raise ValueError(f'Symlinks are excluded: {name}')
        if not path.is_file() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f'Missing regular allowlisted file: {name}')
        # Case-insensitive filesystems open miscased entries; require the
        # on-disk spelling so kits carry the paths Linux and Windows expect.
        parent = root
        for part in PurePosixPath(name).parts:
            if parent not in listings:
                listings[parent] = set(os.listdir(parent))
            if part not in listings[parent]:
                raise ValueError(f'Allowlist case differs from disk: {name}')
            parent = parent / part
    return sorted(names)


def build(root, output, kind):
    root = root.resolve()
    names = selected_files(root, kind)
    check_source_closure(root, names, include_assets=kind == 'private')
    if kind == 'private':
        verify_private_inputs(root)
    if inside_source(output, root):
        raise ValueError('Output must be outside original source directories')
    if output.resolve() in {(root / n).resolve() for n in names}:
        raise ValueError('Output must not overwrite an input')
    guard = boundary_guard()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation preserves earlier releases; each file is read once for
    # both its hash and ZIP member. Concurrent edits require a subsequent rebuild.
    records = []
    overrides = {'Play.command': 'tools/package/Play.command'} if kind == 'private' else {}
    if any(p not in names for p in overrides.values()):
        raise ValueError('Managed launcher template is missing from allowlist')
    try:
        with output.open('xb') as handle, zipfile.ZipFile(handle, 'w', compression=zipfile.ZIP_STORED) as archive:
            for name in names:
                source_name = overrides.get(name, name)
                data = (root / source_name).read_bytes()
                # The offending member is never written; the partial kit has no receipt.
                guard(name, data, kind)
                mode = 0o755 if name.endswith(('.command', '.sh')) else 0o644
                records.append({'path': name, 'size': len(data), 'sha256': digest(data), 'mode': mode, 'input_path': source_name})
                write_member(archive, name, data, mode)
            receipt = {'schema': 1, 'kind': kind, 'release_ready': False,
                       'rights': 'LOCAL REVIEW ONLY. No publication or redistribution permission established.',
                       'format': 'ZIP_STORED, sorted members, fixed 1980 UTC date, normalized modes',
                       'files': records}
            write_member(archive, RECEIPT, (json.dumps(receipt, indent=2, sort_keys=True) + '\n').encode(), 0o644)
    except Exception:
        # Keep failed output for diagnosis; never overwrite or remove user files.
        raise
    return verify(output, guard)


# Historical comparison inputs are optional to playable/native kits. Their
# specific diagnostic modes still require private baselines and are not claimed
# runnable without them. All other test/runtime resources remain checked.
# Working if: only these five source-qualified diagnostic references may be
# absent; production, inherited test code and explicit loads still fail closed.
OPTIONAL_COMPARISON_INPUTS = {
    ('godot/tests/test_pc_modern_environment_polish.gd', 'tests/finishgrain-before-variant.gdshader'),
    ('godot/tests/test_pc_modern_environment_polish.gd', 'tests/diffusion-before-variant.gdshader'),
    ('godot/tests/test_pc_modern_environment_polish.gd', 'tests/groundlight-first-failed.gdshader'),
    ('godot/tests/test_pc_effect_art.gd', 'tests/particle-material-before.gdshader'),
    ('godot/tests/test_pc_effect_art.gd', 'tests/effects-before.gdshader'),
}


def check_source_closure(root, names, include_assets=False):
    """Reject missing local code imports, including new untracked worker modules."""
    selected = set(names)
    for name in names:
        path = root / name
        if path.suffix == '.gd':
            text = path.read_text()
            for dependency in re.findall(r'(?<![A-Za-z_])(?:pre)?load\(\s*["\']res://([^"\']+)["\']\s*\)', text):
                if dependency.endswith(('.gd', '.gdshader')) and 'godot/' + dependency not in selected:
                    raise ValueError(f'Missing code dependency: {name} -> godot/{dependency}')
            # Inherited scripts compile with the child, so a missing base breaks it.
            extends = re.findall(r'''^[ \t]*extends[ \t]+["']res://([^"']+)["']''', text, re.MULTILINE)
            # Shader templates in strings escape their include delimiters.
            includes = [m[2] for m in re.findall(r'''#include[ \t]+(\\?)(["'])res://([^"'\\\r\n]+)\1\2''', text)]
            for dependency in extends + includes:
                # Formatted template paths are resolved at runtime, as in the resource scan.
                if '%' in dependency or (name, dependency) in OPTIONAL_COMPARISON_INPUTS:
                    continue
                if 'godot/' + dependency not in selected:
                    raise ValueError(f'Missing code dependency: {name} -> godot/{dependency}')
        if path.suffix in {'.gdshader', '.gdshaderinc'}:
            # Every selected include is scanned in turn, so nested includes close too.
            for dependency in re.findall(r'''^[ \t]*#include[ \t]+"res://([^"]+)"''', path.read_text(), re.MULTILINE):
                if 'godot/' + dependency not in selected:
                    raise ValueError(f'Missing code dependency: {name} -> godot/{dependency}')
        if include_assets and path.suffix in {'.gd', '.tscn'}:
            # GDScript shader templates contain singly escaped quote delimiters.
            # Match the delimiter pair, preserving bounded path characters.
            for match in re.finditer(r'''(?<!\\)(\\?)(["'])res://([^"'\\\r\n]+)\1\2''', path.read_text()):
                dependency = match.group(3)
                if (name, dependency) in OPTIONAL_COMPARISON_INPUTS:
                    continue
                if '%' not in dependency and Path(dependency).suffix and 'godot/' + dependency not in selected:
                    raise ValueError(f'Missing resource dependency: {name} -> godot/{dependency}')
        if path.suffix == '.py':
            for node in ast.walk(ast.parse(path.read_text(), filename=name)):
                level = getattr(node, 'level', 0) or 0
                if isinstance(node, ast.Import):
                    modules = [a.name for a in node.names]
                elif isinstance(node, ast.ImportFrom):
                    # Relative imports resolve against the importing file; absolute ones against the repo root.
                    parts = PurePosixPath(name).parent.parts
                    module = '.'.join((*parts[:len(parts) - level + 1], node.module or '') if level else (node.module or '',)).strip('.')
                    modules = [module] * bool(module) + [f'{module}.{a.name}'.strip('.') for a in node.names if a.name != '*']
                else:
                    continue
                for module in modules:
                    stem = module.replace('.', '/')
                    # Bare absolute names also cover tools scripts that import siblings through sys.path.
                    for candidate in (stem + '.py', stem + '/__init__.py', *(('tools/' + stem + '.py',) if not level else ())):
                        if (root / candidate).is_file() and candidate not in selected:
                            raise ValueError(f'Missing code dependency: {name} -> {candidate}')


def verify_private_inputs(root):
    # Never package a modified original or a campaign overlay disguised as content.
    records = json.loads((root / 'tools/package/game-inputs.json').read_text())['files']
    for record in records:
        if digest((root / 'GAME' / record['name']).read_bytes()) != record['sha256']:
            raise ValueError(f"Modified original input: {record['name']}")
    if digest((root / '.runtime/pc-core/abrams-ref.zip').read_bytes()) != 'c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05':
        raise ValueError('Unreviewed content ZIP')
    core = json.loads((root / '.runtime/pc-core/abrams-trace.json').read_text())
    if digest((root / '.runtime/pc-core/abrams-trace.dylib').read_bytes()) != core['trace_sha256']:
        raise ValueError('Core differs from its build receipt')
    headers = {'trace': 'abrams_trace.h', 'ownership': 'abrams_vga_ownership.h',
               'plate_ownership': 'abrams_plate_ownership.h', 'state_overlay': 'abrams_state_overlay.h',
               'observer_checkpoint': 'abrams_observer_checkpoint.h'}
    for key, name in headers.items():
        if digest((root / 'tools/pc_core' / name).read_bytes()) != core.get(key + '_header_sha256'):
            raise ValueError(f'Core build source differs from its receipt: {name}')


def write_member(archive, name, data, mode):
    info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | mode) << 16
    archive.writestr(info, data)


def verify(path, guard=None):
    guard = guard or boundary_guard()
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate archive member')
        receipt = json.loads(archive.read(RECEIPT))
        if receipt.get('schema') != 1 or receipt.get('kind') not in {'source', 'private'} or receipt.get('release_ready') is not False:
            raise ValueError('Invalid local review receipt')
        expected = {r['path'] for r in receipt['files']}
        if len(expected) != len(receipt['files']) or set(names) != expected | {RECEIPT}:
            raise ValueError('Unmanifested archive content')
        embedded = json.loads(archive.read(MANIFEST))
        allowed = set(embedded['source']) | (set(embedded['private']) if receipt['kind'] == 'private' else set())
        if expected != allowed:
            raise ValueError('Archive differs from embedded allowlist')
        if names != sorted(expected) + [RECEIPT]:
            raise ValueError('Archive members are not in canonical order')
        for info in archive.infolist():
            if info.compress_type != zipfile.ZIP_STORED or info.create_system != 3 or not stat.S_ISREG(info.external_attr >> 16):
                raise ValueError(f'Noncanonical member type: {info.filename}')
        for row in receipt['files']:
            name = row['path']
            validate_name(name, 'source' if name in embedded['source'] else receipt['kind'])
            data = archive.read(name)
            info = archive.getinfo(name)
            if len(data) != row['size'] or digest(data) != row['sha256']:
                raise ValueError(f'Archive fingerprint mismatch: {name}')
            guard(name, data, 'source' if name in embedded['source'] else receipt['kind'])
            if info.date_time != (1980, 1, 1, 0, 0, 0) or stat.S_IMODE(info.external_attr >> 16) != row['mode']:
                raise ValueError(f'Archive metadata mismatch: {name}')
    sha = hashlib.sha256()
    with path.open('rb') as handle:
        # Chunked: a private kit is hundreds of megabytes.
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            sha.update(chunk)
    return {'kind': receipt['kind'], 'files': len(expected), 'bytes': path.stat().st_size,
            'sha256': sha.hexdigest(), 'release_ready': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind', choices=['source', 'private'], default='source')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--verify', type=Path)
    args = parser.parse_args()
    if bool(args.output) == bool(args.verify):
        parser.error('Choose exactly one of --output or --verify')
    print(json.dumps(verify(args.verify) if args.verify else build(ROOT, args.output, args.kind), indent=2))


if __name__ == '__main__':
    main()
