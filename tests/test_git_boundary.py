"""Synthetic index/history violations; no real credentials or owned originals."""
import hashlib
from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile
from tools.package import git_boundary as boundary


class GitBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='abrams git boundary ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Boundary Test')
        self.git('config', 'user.email', 'boundary@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args], stderr=subprocess.STDOUT)

    def add(self, name, data=b'clean source'):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        self.git('add', '-f', '--', name)

    def test_clean_index(self):
        self.add('tools/test.py')
        self.assertEqual(boundary.check(self.root, known_hashes=set()), [])

    def test_originals_roms_private_directories_and_secrets(self):
        names = ['GAME/SIM.EXE', 'nested/gEnEsIs/game.md', 'input.ROM', 'other/SIM.exe',
                 'saves/slot.json', 'states/slot.json', '.runtime/core.txt', 'local-art/a.png',
                 'artifacts/report.json', 'config.env', '.env.local', 'nested/.ssh/config']
        for name in names:
            self.add(name)
        failures = boundary.check(self.root, known_hashes=set())
        self.assertEqual({name for name, _ in failures}, set(names))

    def test_index_bytes_override_clean_worktree(self):
        secret = b'gh' + b'p_' + b'A' * 36
        self.add('innocent.txt', secret)
        (self.root / 'innocent.txt').write_bytes(b'now clean but not staged')
        self.assertIn(('innocent.txt', 'credential signature'), boundary.check(self.root, known_hashes=set()))

    def test_renamed_original_is_detected_by_fingerprint(self):
        data = b'synthetic original content'
        self.add('notes.txt', data)
        self.assertIn(('notes.txt', 'fingerprinted original game/ROM/content archive'),
                      boundary.check(self.root, known_hashes={hashlib.sha256(data).hexdigest()}))

    def test_empty_marker_does_not_impersonate_original_content(self):
        self.add('tools/__init__.py', b'')
        self.assertEqual(boundary.check(self.root, known_hashes={hashlib.sha256(b'').hexdigest()}), [])

    def test_oversized_blob(self):
        self.add('large.txt', b'x' * 33)
        self.assertEqual(boundary.limit_text(), '50 MB')
        with patch.object(boundary, 'MAX_BYTES', 32):
            self.assertIn(('large.txt', 'file exceeds 32 bytes'), boundary.check(self.root, known_hashes=set()))
        with patch.object(boundary, 'MAX_BYTES', 100_000_000):
            self.assertEqual(boundary.inspect_blob(b'x' * 33, set()), None)
            self.assertEqual(boundary.limit_text(), '100 MB')

    def test_deleted_historical_violation_is_still_rejected(self):
        self.add('GENESIS/old.md')
        self.git('commit', '-qm', 'synthetic original')
        self.git('rm', '-q', 'GENESIS/old.md')
        self.git('commit', '-qm', 'remove synthetic original')
        self.assertEqual(boundary.check(self.root, known_hashes=set()), [])
        self.assertTrue(boundary.check(self.root, history=True, known_hashes=set()))

    def test_symlink_rejected_without_reading_target(self):
        (self.root / 'link.txt').symlink_to('/nonexistent/sensitive')
        self.git('add', 'link.txt')
        self.assertIn(('link.txt', 'symlink, submodule or nonregular entry'), boundary.check(self.root, known_hashes=set()))

    def test_shallow_history_is_not_reported_clean(self):
        self.add('source.py'); self.git('commit', '-qm', 'clean')
        (self.root / '.git/shallow').write_bytes(self.git('rev-parse', 'HEAD'))
        with self.assertRaisesRegex(ValueError, 'Full history'):
            boundary.check(self.root, history=True, known_hashes=set())

    def test_canonical_pins_are_available_without_originals(self):
        self.assertGreaterEqual(len(boundary.known_inputs()), 68)

    def test_published_browser_archives_are_inspected_not_blanket_rejected(self):
        def archive(name, contents):
            stream = BytesIO()
            with ZipFile(stream, 'w') as package:
                package.writestr(name, contents)
            return stream.getvalue()

        prefix = 'website/dist/play/.generated/'
        self.add(prefix + 'python-source.zip', archive('tools/bridge.py', b'clean source'))
        self.add(prefix + 'remaster-assets-00.zip', archive('local-art/pc-modern/tree.png', b'authored art'))
        wasm = b'\x00asm\x01\x00\x00\x00' + b'ghp_' + b'A' * 36
        self.add(prefix + 'godot/index.wasm', wasm)
        with patch.object(boundary, 'WEB_WASM_SHA256', hashlib.sha256(wasm).hexdigest()):
            self.assertEqual(boundary.check(self.root, known_hashes=set()), [])
        self.assertIn((prefix + 'godot/index.wasm', 'credential signature'),
                      boundary.check(self.root, known_hashes=set()))
        self.add(prefix + 'remaster-assets-01.zip', archive('local-art/../../GAME/SIM.EXE', b'private'))
        self.assertIn((prefix + 'remaster-assets-01.zip', 'unsafe browser archive member'),
                      boundary.check(self.root, known_hashes=set()))

    def test_browser_archive_member_secret_and_original_fingerprint_rejected(self):
        def archive(payload):
            stream = BytesIO()
            with ZipFile(stream, 'w') as package:
                package.writestr('local-art/pc-modern/tree.png', payload)
            return stream.getvalue()

        name = 'website/dist/play/.generated/remaster-assets-00.zip'
        original = b'known synthetic original'
        self.add(name, archive(original))
        self.assertIn((name, 'browser archive member: fingerprinted original game/ROM/content archive'),
                      boundary.check(self.root, known_hashes={hashlib.sha256(original).hexdigest()}))
        self.add(name, archive(b'ghp_' + b'A' * 36))
        self.assertIn((name, 'browser archive member: credential signature'),
                      boundary.check(self.root, known_hashes=set()))

    def test_web_exceptions_do_not_extend_to_other_paths(self):
        self.add('other/remaster-assets-00.zip', b'archive')
        self.add('website/dist/play/.generated/godot/other.wasm', b'\x00asm\x00ghp_' + b'A' * 36)
        failures = boundary.check(self.root, known_hashes=set())
        self.assertIn(('other/remaster-assets-00.zip', 'original/runtime/archive/credential format'), failures)
        self.assertIn(('website/dist/play/.generated/godot/other.wasm', 'credential signature'), failures)


if __name__ == '__main__':
    unittest.main()
