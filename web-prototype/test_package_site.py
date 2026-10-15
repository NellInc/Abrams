import contextlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('browser_package', Path(__file__).with_name('package_site.py'))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)

class BrowserPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'; self.source.write_text('accepted')
        self.target = self.root / 'play'
        package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.before = {p.relative_to(self.target).as_posix(): p.read_bytes() for p in self.target.rglob('*') if p.is_file()}
    def unchanged(self):
        self.assertEqual(self.before, {p.relative_to(self.target).as_posix(): p.read_bytes() for p in self.target.rglob('*') if p.is_file()})
        self.assertEqual(list(self.root.glob('.abrams-play-*')), [])
    def test_copy_failure_preserves_previous(self):
        with patch.object(package.shutil, 'copy2', side_effect=OSError('disk full')):
            with self.assertRaisesRegex(OSError, 'disk full'): package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.unchanged()
    def test_rename_failure_rolls_back(self):
        original = Path.replace
        def replace(path, dest):
            if path.name == 'candidate': raise OSError('rename failed')
            return original(path, dest)
        with patch.object(Path, 'replace', replace):
            with self.assertRaisesRegex(OSError, 'rename failed'): package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.unchanged()
    def test_failed_rollback_retains_recoverable_accepted_build(self):
        original = Path.replace
        def replace(path, dest):
            if path.name in ('candidate', 'previous'): raise OSError('destination blocked')
            return original(path, dest)
        with patch.object(Path, 'replace', replace):
            with self.assertRaisesRegex(RuntimeError, 'accepted build retained'): package.install_bundle({'remaster.mjs': self.source}, self.target)
        backups = list(self.root.glob('.abrams-play-*/previous'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(self.before, {p.relative_to(backups[0]).as_posix(): p.read_bytes() for p in backups[0].rglob('*') if p.is_file()})

    def test_modified_owned_file_refused(self):
        (self.target / 'remaster.mjs').write_text('unrelated edit')
        with self.assertRaisesRegex(SystemExit, 'changed browser site file'): package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual((self.target / 'remaster.mjs').read_text(), 'unrelated edit')
    def test_unsafe_destination_refused(self):
        for path in ('../secret', '/absolute', 'bad//path', 'BUNDLE.json'):
            with self.subTest(path=path), self.assertRaisesRegex(SystemExit, 'Unsafe'): package.install_bundle({path: self.source}, self.target)
        self.unchanged()
    def test_wrong_manifest_identity_preserves_previous(self):
        for wanted in ({'sha256': '0'*64}, {'bytes': self.source.stat().st_size+1}):
            with self.subTest(wanted=wanted), self.assertRaisesRegex(SystemExit, 'differs from its build manifest'):
                package.install_bundle({'remaster.mjs': self.source}, self.target, {'remaster.mjs': wanted})
            self.unchanged()
    def test_source_changed_while_copying_preserves_previous(self):
        original = package.shutil.copy2
        def copy(source, destination):
            result = original(source, destination)
            self.source.write_text('changed after copy')
            return result
        with patch.object(package.shutil, 'copy2', copy), self.assertRaisesRegex(SystemExit, 'changed during packaging'):
            package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.unchanged()
    def test_valid_manifest_identity_accepted(self):
        wanted = {'bytes': self.source.stat().st_size, 'sha256': package.sha(self.source)}
        result = package.install_bundle({'remaster.mjs': self.source}, self.target, {'remaster.mjs': wanted})
        self.assertEqual(result['remaster.mjs'], wanted)
    def test_complete_replacement_is_verified(self):
        self.source.write_text('new')
        rows = package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual(rows['remaster.mjs']['sha256'], package.sha(self.source))
        self.assertIsNotNone(package.verify_owned(self.target))

if __name__ == '__main__': unittest.main()
