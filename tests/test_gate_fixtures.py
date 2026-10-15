"""Gate fixture pins detect missing, regenerated and edited local inputs."""
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tests import gate_fixtures  # noqa: E402


class GateFixtureTests(unittest.TestCase):
    def fixture(self, directory):
        root = Path(directory)
        (root / 'artifacts/capture').mkdir(parents=True)
        (root / 'artifacts/capture/report.json').write_text('{}')
        (root / 'artifacts/capture/frame-0001.png').write_bytes(b'png')
        (root / 'artifacts/oracle.json').write_text('[]')
        return root

    def test_missing_regenerated_and_edited_inputs_fail(self):
        fixtures = {'artifacts/capture': 'pc_test', 'artifacts/oracle.json': 'pc_oracle'}
        with tempfile.TemporaryDirectory() as directory, patch.dict(gate_fixtures.FIXTURES, fixtures, clear=True):
            root = self.fixture(directory)
            manifest = root / 'tests/gate_fixtures.json'
            manifest.parent.mkdir()
            gate_fixtures.write(root, manifest)
            self.assertEqual(gate_fixtures.problems(root, manifest), [])
            (root / 'artifacts/capture/frame-0001.png').write_bytes(b'regenerated')
            self.assertEqual(gate_fixtures.problems(root, manifest), ['fixture changed: artifacts/capture (2 -> 2 files; read by pc_test)'])
            (root / 'artifacts/capture/frame-0001.png').write_bytes(b'png')
            (root / 'artifacts/capture/extra.png').write_bytes(b'png')
            self.assertIn('fixture changed: artifacts/capture', gate_fixtures.problems(root, manifest)[0])
            (root / 'artifacts/capture/extra.png').unlink()
            (root / 'artifacts/oracle.json').unlink()
            self.assertEqual(gate_fixtures.problems(root, manifest), ['fixture missing: artifacts/oracle.json (read by pc_oracle)'])
            with self.assertRaisesRegex(FileNotFoundError, 'fixture missing'):
                gate_fixtures.write(root, manifest)

    def test_finder_metadata_is_not_evidence(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(gate_fixtures.FIXTURES, {'artifacts/capture': 'pc_test'}, clear=True):
            root = self.fixture(directory)
            manifest = root / 'tests/gate_fixtures.json'
            manifest.parent.mkdir()
            gate_fixtures.write(root, manifest)
            (root / 'artifacts/capture/.DS_Store').write_bytes(b'finder')
            (root / 'artifacts/capture/._frame-0001.png').write_bytes(b'resource fork')
            self.assertEqual(gate_fixtures.problems(root, manifest), [])

    def test_live_set_is_pinned_separately(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.dict(gate_fixtures.FIXTURES, {'artifacts/oracle.json': 'pc_oracle'}, clear=True), \
                patch.dict(gate_fixtures.LIVE_FIXTURES, {'artifacts/capture': 'pc_live'}, clear=True):
            root = self.fixture(directory)
            manifest = root / 'tests/gate_fixtures.json'
            manifest.parent.mkdir()
            gate_fixtures.write(root, manifest)
            self.assertIn('rerun --write --live', gate_fixtures.problems(root, manifest, live=True)[0])
            gate_fixtures.write(root, manifest, live=True)
            self.assertEqual(gate_fixtures.problems(root, manifest), [])
            self.assertEqual(gate_fixtures.problems(root, manifest, live=True), [])
            (root / 'artifacts/capture/report.json').write_text('{"regenerated": true}')
            self.assertEqual(gate_fixtures.problems(root, manifest), [])
            self.assertIn('fixture changed: artifacts/capture', gate_fixtures.problems(root, manifest, live=True)[0])
            # Re-pinning the default set keeps the live rows.
            gate_fixtures.write(root, manifest)
            self.assertIn('fixture changed', gate_fixtures.problems(root, manifest, live=True)[0])

    def test_every_artifacts_input_named_by_the_gate_is_pinned(self):
        gate = (ROOT / 'tools/validate.sh').read_text()
        pinned = [*gate_fixtures.FIXTURES, *gate_fixtures.LIVE_FIXTURES]
        for name in sorted(set(re.findall(r'artifacts/[\w.-]+(?:/[\w.-]+)*', gate)) - {'artifacts/validation-'}):
            with self.subTest(input=name):
                self.assertTrue(any(name == key or name.startswith(key + '/') for key in pinned), name)
        self.assertIn('tests.gate_fixtures --verify --live', gate)

    def test_manifest_and_registry_agree(self):
        manifest = json.loads(gate_fixtures.MANIFEST.read_text())
        pinned = manifest['fixtures']
        self.assertEqual(set(pinned), set(gate_fixtures.FIXTURES))
        self.assertEqual(set(manifest['live']), set(gate_fixtures.LIVE_FIXTURES))
        for name in [*pinned, *manifest['live']]:
            self.assertTrue(name.startswith('artifacts/'), name)
        with tempfile.TemporaryDirectory() as directory, patch.dict(gate_fixtures.FIXTURES, {'artifacts/x': 'y'}, clear=True):
            self.assertIn('out of date', gate_fixtures.problems(Path(directory))[0])

    def test_gate_inputs_are_pinned(self):
        gate = (ROOT / 'tools/validate.sh').read_text()
        for name in ['artifacts/pc-motor-pool-controls-01', 'artifacts/pc-genesis-arming-allocations-trace-01',
                     'artifacts/intro-menu-20260930/trace']:
            self.assertIn(name, gate)
            self.assertIn(name, gate_fixtures.FIXTURES)

    def test_refuses_to_write_inside_original_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            (root / 'GAME').mkdir()
            with patch.dict(gate_fixtures.FIXTURES, {'artifacts/oracle.json': 'pc_oracle'}, clear=True):
                with self.assertRaisesRegex(ValueError, 'inside original sources'):
                    gate_fixtures.write(root, root / 'game/gate_fixtures.json')


if __name__ == '__main__':
    unittest.main()
