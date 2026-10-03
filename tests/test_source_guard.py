"""Shared original-source output guard: case, symlink and '..' aliases, no writes."""
import contextlib
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

from tools.source_guard import ROOT, inside_source


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

    @unittest.skipUnless((ROOT / 'GAME').is_dir(), 'Requires private original inputs')
    def test_real_tree(self):
        self.assertTrue(inside_source(ROOT / 'GAME'))
        self.assertTrue(inside_source(ROOT / 'GAME/../game/never-created'))
        self.assertFalse(inside_source(ROOT / 'artifacts/never-created'))
        self.assertFalse(inside_source(ROOT / 'reference/never-created'))


if __name__ == '__main__':
    unittest.main()
