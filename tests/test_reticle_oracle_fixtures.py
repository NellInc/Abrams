"""The committed reticle ink fixtures equal the CPU raster model they claim.

tools/validate.sh passes these fixtures to test_pc_reticle.gd and
test_pc_reticle_target.gd as ``--oracle``, so Godot's analytic sight geometry
(including the original clipped-endpoint swap) is checked against
tools/pc_reticle(.py|_target.py).ink_pixels in every gate run. The ink is a pure
function of the tracked offset table; no original bytes are stored.

Regenerate after a deliberate change to that model with:
    python3 -m tests.test_reticle_oracle_fixtures --write
"""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools import pc_reticle, pc_reticle_target  # noqa: E402

RETICLE = ROOT / 'godot/tests/fixtures/pc_reticle_ink.json'
TARGET = ROOT / 'godot/tests/fixtures/pc_reticle_target_ink.json'
SCOPE = ('Derived from the tracked offset table by the CPU raster model, not from '
         'original bytes; regenerate with python3 -m tests.test_reticle_oracle_fixtures --write.')


def reticle_fixture():
    # Every centre from fully clipped above to fully clipped below, including
    # the 10-16 and 97-105 rows where the original swaps clipped endpoints.
    cases = [{'center': c, 'ink_pixels': [list(p) for p in pc_reticle.ink_pixels(c)]} for c in range(-40, 161)]
    return {'schema': 1, 'model': 'tools/pc_reticle.py ink_pixels', 'table_sha256': pc_reticle.TABLE_SHA256,
            'clip': list(pc_reticle.CLIP), 'scope': SCOPE, 'cases': cases}


def target_centres():
    x0, y0, x1, y1 = pc_reticle.CLIP
    centres = {(159, 61)}
    # Each clip edge is crossed one pixel at a time, then corners on a coarse grid.
    centres.update((x, 61) for x in [*range(x0 - 10, x0 + 11), *range(x1 - 10, x1 + 11)])
    centres.update((159, y) for y in [*range(y0 - 10, y0 + 11), *range(y1 - 10, y1 + 11)])
    edges_x = [x0 - 10, x0 - 5, x0, x0 + 5, x0 + 10, x1 - 10, x1 - 5, x1, x1 + 5, x1 + 10]
    edges_y = [y0 - 10, y0 - 5, y0, y0 + 5, y0 + 10, y1 - 10, y1 - 5, y1, y1 + 5, y1 + 10]
    centres.update((x, y) for x in edges_x for y in edges_y)
    return sorted(centres, key=lambda p: (p[1], p[0]))


def target_fixture():
    cases = [{'center': [x, y], 'ink_pixels': [list(p) for p in pc_reticle_target.ink_pixels(x, y)]}
             for x, y in target_centres()]
    return {'schema': 1, 'model': 'tools/pc_reticle_target.py ink_pixels', 'clip': list(pc_reticle.CLIP),
            'scope': SCOPE, 'cases': cases}


def encode(data):
    return json.dumps(data, separators=(',', ':')) + '\n'


class ReticleOracleFixtureTests(unittest.TestCase):
    def test_committed_fixtures_match_cpu_raster_model(self):
        for path, build in ((RETICLE, reticle_fixture), (TARGET, target_fixture)):
            with self.subTest(path=path.name):
                self.assertTrue(path.is_file(), f'{path.relative_to(ROOT)} missing; run with --write')
                self.assertEqual(path.read_text(), encode(build()))

    def test_fixtures_exercise_clipping_and_swap_rows(self):
        cases = {case['center']: case['ink_pixels'] for case in reticle_fixture()['cases']}
        self.assertEqual(cases[-40], [])
        self.assertEqual(cases[160], [])
        full = len(cases[61])
        for centre in [*range(10, 17), *range(97, 106)]:
            with self.subTest(centre=centre):
                self.assertTrue(0 < len(cases[centre]) < full)
        target = target_fixture()['cases']
        self.assertTrue(any(not case['ink_pixels'] for case in target))
        self.assertTrue(any(case['ink_pixels'] and len(case['ink_pixels']) < 40 for case in target))

    def test_gate_passes_both_fixtures_as_oracles(self):
        gate = (ROOT / 'tools/validate.sh').read_text()
        self.assertIn('res://tests/test_pc_reticle.gd -- --oracle res://tests/fixtures/pc_reticle_ink.json', gate)
        self.assertIn('res://tests/test_pc_reticle_target.gd -- --oracle res://tests/fixtures/pc_reticle_target_ink.json', gate)


if __name__ == '__main__':
    if sys.argv[1:] == ['--write']:
        for path, build in ((RETICLE, reticle_fixture), (TARGET, target_fixture)):
            path.write_text(encode(build()))
            print(path.relative_to(ROOT), path.stat().st_size, 'bytes')
    else:
        unittest.main()
