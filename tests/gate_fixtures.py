"""Pinned local inputs read by the Godot checks in tools/validate.sh.

The gate replays retained captures under the gitignored artifacts/ tree. Those
captures are evidence, not test output: if one is cleared, regenerated or edited,
the gate must say so before any Godot check runs, instead of failing for an
unrelated-looking reason or passing against different evidence.

    python3 -m tests.gate_fixtures --verify [--live]  # validate.sh runs these first
    python3 -m tests.gate_fixtures --write [--live]   # after deliberately replacing a fixture

Directories are pinned as one digest over every regular file (relative path and
SHA-256), so a regenerated frame inside a capture is detected too. Finder and
Spotlight metadata (.DS_Store, ._*) is not evidence and is left out. The
default set is verified before the headless gate; the VALIDATE_LIVE=1 tier
verifies its own set with --live. Each --write re-pins one set and keeps the
other's rows.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tests/gate_fixtures.json'

# Inputs of the default headless gate, with the check(s) that read them.
FIXTURES = {
    'artifacts/finish-20260928/cursor-struts/coverage-fixtures.json': 'pc_cursor_struts, pc_cockpit_refinement',
    'artifacts/finish-20260928/effect-mode-fixtures.json': 'pc_effect_modes',
    'artifacts/finish-20260928/maps/live-trace': 'pc_dynamic_map (--live)',
    'artifacts/finish-20260928/status-damage-oracle-02': 'pc_instrument_damage, pc_tactical_hud',
    'artifacts/finish-20260928/target-lock-oracle.json': 'pc_instrument_lock',
    'artifacts/intro-menu-20260930/trace': 'pc_frontend_scene',
    'artifacts/pc-driver-assembly-trace-03': 'pc_cursor_struts, pc_cockpit_refinement',
    'artifacts/pc-genesis-arming-allocations-trace-01': 'pc_motor_pool_arming_art',
    'artifacts/pc-information-baseline-02': 'pc_information_art, pc_frontend_art, pc_graphics_modes, pc_portrait_coverage',
    'artifacts/pc-intro-skip-trace-01': 'pc_intro_art',
    'artifacts/pc-intro-trace-01': 'pc_intro_art, pc_graphics_modes, pc_frontend_music',
    'artifacts/pc-live-type-cockpit-02': 'pc_tandem_frame, pc_cockpit_mask_reuse, pc_cockpit_refinement, pc_commander_trim, pc_graphics_modes, pc_presentation_reuse',
    'artifacts/pc-live-type-crew-02': 'pc_portrait_art',
    'artifacts/pc-live-type-lifecycle-01': 'pc_frontend_art, pc_graphics_modes, pc_frontend_completeness',
    'artifacts/pc-menu-text-trace-04': 'pc_menu_text, pc_cursor_struts, pc_frontend_art',
    'artifacts/pc-motor-pool-baseline-01/mission-summary.png': 'pc_map_art',
    'artifacts/pc-motor-pool-controls-01': 'pc_motor_pool_controls_art',
    'artifacts/pc-motor-pool-trace-03': 'pc_motor_pool_art',
    'artifacts/pc-portrait-lifecycle-trace-01': 'pc_portrait_coverage',
    'artifacts/pc-sprite-controls-02': 'pc_effect_art, pc_hill_art, pc_vehicle_art, pc_modern, pc_modern_mapping_reuse',
    'artifacts/performance-60fps-20260929/optimized-canvas/diagnostic-draws.json': 'pc_modern_mapping_reuse',
}

# Inputs of the opt-in VALIDATE_LIVE=1 tier. Each test reads its report and
# the files beside it (comparison.json, reference frames).
LIVE_FIXTURES = {
    'artifacts/pc-all-scenarios-trace-01': 'pc_scenario_frames',
    'artifacts/pc-combat-loss-trace-01': 'pc_combat_outcome',
    'artifacts/pc-crew-trace-01': 'pc_crew_bridge',
    'artifacts/pc-radio-trace-01': 'pc_radio_bridge',
    'artifacts/pc-warning-trace-03': 'pc_warning_bridge',
}

# Manifest key and registry of each set, by live flag.
SETS = {False: ('fixtures', FIXTURES), True: ('live', LIVE_FIXTURES)}
METADATA = ('.DS_Store',)


def _evidence(path: Path) -> bool:
    return path.is_file() and not path.is_symlink() and path.name not in METADATA and not path.name.startswith('._')


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def digest(path: Path) -> dict | None:
    """{kind, files, sha256} for a file or a whole directory, None if absent."""
    if path.is_file():
        return {'kind': 'file', 'files': 1, 'sha256': _file_sha256(path)}
    if not path.is_dir():
        return None
    rows = []
    for item in sorted(p for p in path.rglob('*') if _evidence(p)):
        rows.append(f'{item.relative_to(path).as_posix()}\0{_file_sha256(item)}\n')
    return {'kind': 'dir', 'files': len(rows), 'sha256': hashlib.sha256(''.join(rows).encode()).hexdigest()}


def problems(root: Path = ROOT, manifest: Path = MANIFEST, live: bool = False) -> list[str]:
    key, fixtures = SETS[live]
    try:
        pinned = json.loads(manifest.read_text())[key]
    except (OSError, ValueError, KeyError) as error:
        return [f'fixture manifest unreadable: {manifest} ({error!r})']
    found = []
    if set(pinned) != set(fixtures):
        found.append('fixture manifest out of date with tests/gate_fixtures.py; rerun --write' + (' --live' if live else ''))
    for name, row in sorted(pinned.items()):
        actual = digest(root / name)
        if actual is None:
            found.append(f'fixture missing: {name} (read by {row.get("read_by", "?")})')
        elif {k: actual[k] for k in ('kind', 'files', 'sha256')} != {k: row.get(k) for k in ('kind', 'files', 'sha256')}:
            found.append(f'fixture changed: {name} ({row.get("files")} -> {actual["files"]} files; read by {row.get("read_by", "?")})')
    return found


def write(root: Path = ROOT, manifest: Path = MANIFEST, live: bool = False) -> None:
    from tools.source_guard import inside_source
    if inside_source(manifest, root):
        raise ValueError(f'refusing to write inside original sources: {manifest}')
    key, fixtures = SETS[live]
    other = SETS[not live][0]
    rows = {}
    for name, readers in sorted(fixtures.items()):
        actual = digest(root / name)
        if actual is None:
            raise FileNotFoundError(f'fixture missing: {name}; restore it before pinning')
        rows[name] = actual | {'read_by': readers}
    try:
        kept = json.loads(manifest.read_text()).get(other, {})
    except FileNotFoundError:
        kept = {}
    except ValueError as error:
        raise ValueError(f'fixture manifest unreadable: {manifest}; repair it before pinning') from error
    manifest.write_text(json.dumps({'schema': 1, 'scope': 'Local gate inputs under gitignored artifacts/; '
                                    'pinned so a cleared or regenerated capture fails before any Godot check.',
                                    key: rows, other: kept}, indent=1, sort_keys=True) + '\n')


def main(argv: list[str]) -> int:
    live = argv[1:] == ['--live']
    label = 'live inputs' if live else 'inputs'
    fixtures = SETS[live][1]
    if argv[:1] == ['--write'] and argv[1:] in ([], ['--live']):
        write(live=live)
        print(f'GATE_FIXTURES: pinned {len(fixtures)} {label} in {MANIFEST.relative_to(ROOT)}')
        return 0
    if argv[:1] == ['--verify'] and argv[1:] in ([], ['--live']):
        found = problems(live=live)
        for line in found:
            print(line, file=sys.stderr)
        print(f'GATE_FIXTURES: {len(fixtures)} {label}, {len(found)} problems')
        return 1 if found else 0
    print('usage: python3 -m tests.gate_fixtures --verify [--live] | --write [--live]', file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.path.insert(0, str(ROOT))
    raise SystemExit(main(sys.argv[1:]))
