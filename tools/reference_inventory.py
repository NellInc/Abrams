#!/usr/bin/env python3
"""Create a deterministic SHA-256 inventory, or verify without changing baseline."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path


def inventory(root: Path) -> dict:
    if not root.is_dir():
        raise ValueError(f"missing reference directory: {root}")
    paths = sorted(root.rglob("*"), key=lambda p: p.relative_to(root).as_posix())
    if any(p.is_symlink() for p in paths):
        raise ValueError("reference directory must not contain symbolic links")
    files = [{"path": p.relative_to(root).as_posix(), "size": p.stat().st_size,
              "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in paths if p.is_file()]
    return {"schema": 1, "algorithm": "sha256", "files": files}


def serialize(manifest: dict) -> str:
    return json.dumps(manifest, indent=2, sort_keys=True) + "\n"


def verify(root: Path, baseline: Path) -> list[str]:
    expected = json.loads(baseline.read_text())
    if expected.get("schema") != 1 or expected.get("algorithm") != "sha256":
        raise ValueError("unsupported manifest schema or algorithm")
    entries = expected.get("files")
    if not isinstance(entries, list):
        raise ValueError("manifest files must be a list")
    wanted = {}
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {"path", "size", "sha256"}:
            raise ValueError("invalid manifest entry")
        name = entry["path"]
        if (not isinstance(name, str) or not name or Path(name).is_absolute()
                or ".." in Path(name).parts or name in wanted
                or not isinstance(entry["size"], int) or entry["size"] < 0
                or not isinstance(entry["sha256"], str) or len(entry["sha256"]) != 64
                or any(c not in "0123456789abcdef" for c in entry["sha256"])):
            raise ValueError("unsafe or malformed manifest entry")
        wanted[name] = entry
    actual = {entry["path"]: entry for entry in inventory(root)["files"]}
    changes = [f"missing: {name}" for name in sorted(wanted.keys() - actual.keys())]
    changes += [f"unexpected: {name}" for name in sorted(actual.keys() - wanted.keys())]
    changes += [f"changed: {name}" for name in sorted(wanted.keys() & actual.keys())
                if wanted[name] != actual[name]]
    return changes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("GAME"))
    parser.add_argument("--manifest", type=Path, default=Path("reference/reports/game-manifest.json"))
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    try:
        if args.verify:
            changes = verify(args.root, args.manifest)
            print("\n".join(changes) if changes else "Reference inventory verified unchanged")
            return int(bool(changes))
        if args.manifest.resolve().is_relative_to(args.root.resolve()):
            raise ValueError("manifest must be outside reference directory")
        if args.manifest.exists():
            raise ValueError("baseline already exists; use --verify, or choose a new manifest path")
        manifest = inventory(args.root)
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        with args.manifest.open("x") as stream:
            stream.write(serialize(manifest))
        print(f"Inventoried {len(manifest['files'])} files: {args.manifest}")
        return 0
    except (ValueError, OSError) as error:
        parser.exit(2, f"error: {error}\n")

if __name__ == "__main__":
    raise SystemExit(main())
