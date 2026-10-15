"""Shared guard: does a path lie inside the original-source directories?

Tools that write output use this before any mkdir or write, so generated files
never land beside the original game files. The same check refuses an existing
gate input pinned in tests/gate_fixtures.json: regenerating one in place would
silently change what the gate proves. Standard library only.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_SOURCES = ('GAME', 'GENESIS')
GATE_MANIFEST = 'tests/gate_fixtures.json'


def inside_source(path, root=ROOT, names=ORIGINAL_SOURCES):
    """True if path is, or is under, root/<name> for any name, or an existing pinned gate input.

    Path.resolve() keeps case on case-insensitive APFS/NTFS ('game/x' is GAME/x),
    and os.path.normcase is a no-op on macOS, so check twice: a casefolded first
    component below root (also covers parts that do not exist yet), OR
    os.path.samefile between each existing ancestor and each existing root/<name>
    (covers miscased roots, symlinked source trees and '..').
    """
    path, root = Path(path).resolve(), Path(root).resolve()
    if path != root and path.is_relative_to(root) and path.relative_to(root).parts[0].casefold() in {n.casefold() for n in names}:
        return True
    sources = [root / name for name in names if (root / name).exists()]
    if any(os.path.samefile(a, source) for a in (path, *path.parents) if a.exists() for source in sources):
        return True
    pinned = pinned_evidence(path, root)
    if pinned:
        # Callers report a generic refusal; say which gate input it protects.
        print(f'refusing to write into pinned gate input {pinned}: move it aside, regenerate, '
              f'then re-pin with python3 -m tests.gate_fixtures --write', file=sys.stderr)
        return True
    return False


def pinned_evidence(path, root=ROOT):
    """The existing gate input (tests/gate_fixtures.json, both sets) that path is or lies under, else None.

    A fixture that is absent may be recreated: the gate then reports it changed
    until it is deliberately re-pinned. Case and symlink aliases match as above.
    """
    path, root = Path(path).resolve(), Path(root).resolve()
    try:
        # Builtin open, not Path.open: callers' tests patch Path I/O to prove nothing is written.
        with open(root / GATE_MANIFEST, encoding='utf-8') as handle:
            manifest = json.load(handle)
        names = sorted({*manifest.get('fixtures', {}), *manifest.get('live', {})})
    except (OSError, ValueError, AttributeError, TypeError):
        return None  # The gate itself reports an unreadable manifest.
    relative = path.relative_to(root).parts if path.is_relative_to(root) else None
    for name in names:
        fixture = root / name
        if not fixture.exists():
            continue
        parts = Path(name).parts
        if relative is not None and len(relative) >= len(parts) and \
                [p.casefold() for p in relative[:len(parts)]] == [p.casefold() for p in parts]:
            return name
        if any(os.path.samefile(a, fixture) for a in (path, *path.parents) if a.exists()):
            return name
    return None


def recorded(path, root=ROOT):
    """A receipt-safe spelling of path: repo-relative, else the bare file name.

    Receipts identify inputs by sha256; the path is only a hint, so it must not
    depend on where the checkout lives or leak the user's home directory.
    """
    path, root = Path(path).resolve(), Path(root).resolve()
    return path.relative_to(root).as_posix() if path.is_relative_to(root) else path.name
