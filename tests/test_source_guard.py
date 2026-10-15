"""Shared original-source output guard: case, symlink and '..' aliases, no writes."""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

from tools.source_guard import ROOT, inside_source, pinned_evidence, recorded


class SourceGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve() / 'repo'
        for name in ('GAME', 'local-art', 'reference'):
            (self.root / name).mkdir(parents=True)

    def test_original_trees_and_aliases_are_inside(self):
        r = self.root
        for path in (r / 'GAME', r / 'GAME/x', r / 'game/x', r / 'Game/new/x', r / 'GENESIS/x', r / 'genesis',
                     r / 'local-art/../game/x', r / 'local-art/../../repo/GAME/x'):
            with self.subTest(path=path):
                self.assertTrue(inside_source(path, r))
                self.assertTrue(inside_source(os.path.relpath(path), r))

    def test_neighbours_are_outside(self):
        r = self.root
        for path in (r, r / 'gamey', r / 'GAME-copy/x', r / 'local-art/pc-modern', r / 'reference/x', r.parent / 'GAME/x',
                     r / 'GAME/../local-art/x'):
            with self.subTest(path=path):
                self.assertFalse(inside_source(path, r))

    def test_names_select_protected_trees(self):
        r = self.root
        self.assertTrue(inside_source(r / 'Reference/x', r, ('GAME', 'GENESIS', 'reference')))
        self.assertFalse(inside_source(r / 'GAME/x', r, ('reference',)))

    def test_symlinks_into_or_as_source_trees_are_inside(self):
        r = self.root
        (r / 'local-art/link').symlink_to(r / 'GAME', target_is_directory=True)
        self.assertTrue(inside_source(r / 'local-art/link/x', r))
        # GAME itself a symlink out of the repo: only the same-file check sees it.
        outside = r.parent / 'elsewhere'
        outside.mkdir()
        (r / 'GENESIS').symlink_to(outside, target_is_directory=True)
        self.assertTrue(inside_source(r / 'GENESIS/x', r))
        self.assertTrue(inside_source(outside / 'new/x', r))
        self.assertFalse(inside_source(r.parent / 'elsewhere-2', r))

    def test_miscased_repo_root_on_case_insensitive_filesystem(self):
        if not (self.root / 'game').exists():
            self.skipTest('case-sensitive filesystem')
        alias = Path(str(self.root.parent) + '/REPO')
        self.assertTrue(inside_source(alias / 'game/new/x', self.root))
        self.assertFalse(inside_source(alias / 'local-art/x', self.root))

    def test_check_never_writes(self):
        before = sorted(self.root.rglob('*'))
        with mock.patch.object(Path, 'mkdir', side_effect=AssertionError('wrote')), \
                mock.patch('os.mkdir', side_effect=AssertionError('wrote')):
            self.assertTrue(inside_source(self.root / 'game/a/b/c', self.root))
            self.assertFalse(inside_source(self.root / 'new/a/b', self.root))
        self.assertEqual(sorted(self.root.rglob('*')), before)

    def test_bootstrap_rejects_miscased_output_before_mkdir(self):
        import tools.bootstrap_pc_source as bootstrap
        stderr = io.StringIO()
        with mock.patch.object(bootstrap, 'ROOT', self.root), \
                mock.patch.object(sys, 'argv', ['bootstrap', '--output', str(self.root / 'game/fixture')]), \
                mock.patch.object(Path, 'mkdir', side_effect=AssertionError('wrote')), \
                contextlib.redirect_stderr(stderr), self.assertRaises(SystemExit) as caught:
            bootstrap.main()
        self.assertEqual(caught.exception.code, 2)
        self.assertIn('output must be outside proprietary source directories', stderr.getvalue())
        self.assertFalse((self.root / 'GAME/fixture').exists())

    def test_existing_pinned_gate_inputs_are_refused(self):
        # Regenerating a pinned gate input in place would change what the gate proves.
        r = self.root
        (r / 'tests').mkdir()
        (r / 'tests/gate_fixtures.json').write_text(json.dumps({
            'fixtures': {'artifacts/trace-01': {}, 'artifacts/finish/fixture.json': {}},
            'live': {'artifacts/live-01': {}, 'artifacts/cleared-01': {}}}))
        for name in ('trace-01', 'live-01'):
            (r / 'artifacts' / name).mkdir(parents=True)
        (r / 'artifacts/finish').mkdir()
        (r / 'artifacts/finish/fixture.json').write_text('{}')
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            for path, pinned in ((r / 'artifacts/trace-01', 'artifacts/trace-01'),
                                 (r / 'artifacts/trace-01/new/report.json', 'artifacts/trace-01'),
                                 (r / 'Artifacts/TRACE-01/x', 'artifacts/trace-01'),
                                 (r / 'artifacts/finish/fixture.json', 'artifacts/finish/fixture.json'),
                                 (r / 'artifacts/live-01/x', 'artifacts/live-01')):
                with self.subTest(path=path):
                    self.assertEqual(pinned_evidence(path, r), pinned)
                    self.assertTrue(inside_source(path, r))
                    self.assertTrue(inside_source(path, r, ('reference',)))
        self.assertIn('pinned gate input artifacts/trace-01', stderr.getvalue())
        (r / 'local-art/link').symlink_to(r / 'artifacts/trace-01', target_is_directory=True)
        self.assertEqual(pinned_evidence(r / 'local-art/link/x', r), 'artifacts/trace-01')
        # Neighbours, parents and a cleared (absent) fixture may still be written.
        for path in (r / 'artifacts/trace-012', r / 'artifacts', r / 'artifacts/finish/other.json',
                     r / 'artifacts/cleared-01/report.json', r / 'local-art/x'):
            with self.subTest(path=path):
                self.assertIsNone(pinned_evidence(path, r))
                self.assertFalse(inside_source(path, r))

    def test_unreadable_gate_manifest_protects_nothing(self):
        (self.root / 'tests').mkdir()
        (self.root / 'tests/gate_fixtures.json').write_text('{not json')
        self.assertIsNone(pinned_evidence(self.root / 'reference/x', self.root))
        self.assertFalse(inside_source(self.root / 'reference/x', self.root))

    @unittest.skipUnless((ROOT / 'tests/gate_fixtures.json').is_file()
                         and (ROOT / 'artifacts/finish-20260928/cursor-struts/coverage-fixtures.json').is_file(),
                         'Requires the local pinned gate inputs')
    def test_strut_coverage_generator_refuses_to_regenerate_its_fixture(self):
        import subprocess
        fixture = ROOT / 'artifacts/finish-20260928/cursor-struts/coverage-fixtures.json'
        before = fixture.read_bytes()
        result = subprocess.run([sys.executable, str(ROOT / 'tools/verify_pc_strut_coverage.py')],
                                capture_output=True, text=True, cwd=ROOT)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Refusing to overwrite artifacts/finish-20260928/cursor-struts/coverage-fixtures.json', result.stderr)
        self.assertEqual(fixture.read_bytes(), before)

    @unittest.skipUnless((ROOT / 'GAME').is_dir(), 'Requires private original inputs')
    def test_real_tree(self):
        self.assertTrue(inside_source(ROOT / 'GAME'))
        self.assertTrue(inside_source(ROOT / 'GAME/../game/never-created'))
        self.assertFalse(inside_source(ROOT / 'artifacts/never-created'))
        self.assertFalse(inside_source(ROOT / 'reference/never-created'))

    def test_recorded_paths_are_repo_relative_or_bare_names(self):
        # Receipts must not depend on where the checkout lives, nor leak a home directory.
        self.assertEqual(recorded(self.root / 'reference/genesis/cap', self.root), 'reference/genesis/cap')
        self.assertEqual(recorded(self.root / 'local-art/../reference/x.json', self.root), 'reference/x.json')
        outside = Path(self.tmp.name) / 'elsewhere' / 'capture-01'
        self.assertEqual(recorded(outside, self.root), 'capture-01')
        cwd = os.getcwd()
        try:
            os.chdir(self.root)
            self.assertEqual(recorded('reference/x', self.root), 'reference/x')
        finally:
            os.chdir(cwd)


if __name__ == '__main__':
    unittest.main()
