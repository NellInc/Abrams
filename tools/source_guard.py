"""Shared guard: does a path lie inside the original-source directories?

Tools that write output use this before any mkdir or write, so generated files
never land beside the original game files. Standard library only.
"""
from __future__ import annotations
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_SOURCES = ('GAME', 'GENESIS')


def inside_source(path, root=ROOT, names=ORIGINAL_SOURCES):
    """True if path is, or is under, root/<name> for any name.

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
    return any(os.path.samefile(a, source) for a in (path, *path.parents) if a.exists() for source in sources)
