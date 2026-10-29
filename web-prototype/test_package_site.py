import contextlib
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('browser_package', Path(__file__).with_name('package_site.py'))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
verify_spec = importlib.util.spec_from_file_location('website_verify', package.ROOT / 'website/verify.py')
website_verify = importlib.util.module_from_spec(verify_spec)
verify_spec.loader.exec_module(website_verify)

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
    def test_every_embedded_font_ships_its_licence(self):
        # OFL condition 2: each font the Godot PCK embeds travels with its licence text.
        published = {name: package.SOURCE / name for name in package.APP} | package.LICENSES
        licences = {'IBMPlex': ('LICENSES/IBM-Plex-OFL.txt', 'Plex-OFL.txt'),
                    'Barlow': ('assets/Barlow-OFL.txt', 'Barlow-OFL.txt')}
        fonts = sorted((package.ROOT / 'godot/assets/fonts').glob('*.ttf'))
        self.assertTrue(fonts)
        for font in fonts:
            with self.subTest(font=font.name):
                family = next((key for key in licences if font.name.startswith(key)), None)
                self.assertIsNotNone(family, 'map this font family to its licence in package_site')
                name, text = licences[family]
                self.assertIn(name, published)
                self.assertEqual(published[name].read_bytes(), (font.parent / text).read_bytes())
    def test_copy_failure_preserves_previous(self):
        with patch.object(package.shutil, 'copy2', side_effect=OSError('disk full')):
            with self.assertRaisesRegex(OSError, 'disk full'): package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.unchanged()

    def make_lock(self):
        lock = self.target / package.LOCAL_LOCK
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_bytes(b'local owner')
        self.before[package.LOCAL_LOCK] = lock.read_bytes()
        return lock

    def test_local_lock_inode_survives_promotion_without_publication(self):
        lock = self.make_lock(); identity = package.local_lock_identity(lock)
        self.source.write_text('new accepted')
        records = package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual(package.local_lock_identity(lock), identity)
        self.assertEqual(lock.read_bytes(), b'local owner')
        self.assertNotIn(package.LOCAL_LOCK, records)
        self.assertNotIn(package.LOCAL_LOCK, json.loads((self.target / 'BUNDLE.json').read_text())['files'])
        self.assertEqual(website_verify.LOCAL_BROWSER_LOCK, package.LOCAL_LOCK)
        self.assertEqual(website_verify.browser_publication_files(self.target), {'remaster.mjs', 'BUNDLE.json'})

    def test_busy_local_lock_refuses_without_changes(self):
        lock = self.make_lock()
        with lock.open('rb') as owner:
            fcntl.flock(owner, fcntl.LOCK_SH | fcntl.LOCK_NB)
            with self.assertRaisesRegex(SystemExit, 'in use'):
                package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.unchanged()

    def test_local_lock_cannot_hide_other_extras_or_be_published(self):
        self.make_lock()
        with self.assertRaisesRegex(SystemExit, 'Unsafe'):
            package.install_bundle({package.LOCAL_LOCK: self.source}, self.target)
        extra = self.target / 'foreign'; extra.write_text('keep')
        with self.assertRaisesRegex(SystemExit, 'changed browser site files'):
            package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual(extra.read_text(), 'keep')

    def test_invalid_local_lock_types_refused(self):
        lock = self.target / package.LOCAL_LOCK; lock.parent.mkdir(parents=True)
        for kind in ('symlink', 'directory', 'fifo'):
            if kind == 'symlink': lock.symlink_to(self.source)
            elif kind == 'directory': lock.mkdir()
            else: os.mkfifo(lock)
            with self.subTest(kind=kind), self.assertRaisesRegex(SystemExit, 'invalid local browser build lock'):
                package.install_bundle({'remaster.mjs': self.source}, self.target)
            with self.assertRaisesRegex(ValueError, 'Invalid local browser build lock'):
                website_verify.browser_publication_files(self.target)
            if kind == 'directory': lock.rmdir()
            else: lock.unlink()

    def test_lock_mutation_during_staging_refuses(self):
        lock = self.make_lock(); original = package.shutil.copy2
        def copy(source, destination):
            result = original(source, destination); lock.write_bytes(b'changed owner marker'); return result
        with patch.object(package.shutil, 'copy2', copy), self.assertRaisesRegex(SystemExit, 'lock changed'):
            package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual((self.target / 'remaster.mjs').read_text(), 'accepted')
        self.assertEqual(lock.read_bytes(), b'changed owner marker')

    def test_locked_rename_failure_rolls_back_same_inode(self):
        lock = self.make_lock(); identity = package.local_lock_identity(lock); original = Path.replace
        def replace(path, dest):
            if path.name == 'candidate': raise OSError('rename failed')
            return original(path, dest)
        with patch.object(Path, 'replace', replace), self.assertRaisesRegex(OSError, 'rename failed'):
            package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual(package.local_lock_identity(lock), identity)
        self.unchanged()

    def test_lock_created_in_rename_gap_is_preserved_with_accepted_backup(self):
        lock = self.make_lock(); identity = package.local_lock_identity(lock); original = Path.replace
        def replace(path, dest):
            result = original(path, dest)
            if path == self.target:
                foreign = self.target / package.LOCAL_LOCK
                foreign.parent.mkdir(parents=True); foreign.write_bytes(b'new foreign lock')
            return result
        with patch.object(Path, 'replace', replace), self.assertRaisesRegex(RuntimeError, 'accepted build retained'):
            package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual(lock.read_bytes(), b'new foreign lock')
        backups = list(self.root.glob('.abrams-play-*/previous'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(package.local_lock_identity(backups[0] / package.LOCAL_LOCK), identity)
        self.assertEqual((backups[0] / 'remaster.mjs').read_text(), 'accepted')
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
    def test_stale_observer_source_is_detected(self):
        import io, sys, types, zipfile
        def write(stream, body=b'observer v2'):
            with zipfile.ZipFile(stream, 'w') as archive:
                archive.writestr('tools/__init__.py', '')
                archive.writestr('browser_observer.py', body)
        fake = types.ModuleType('build_observer'); fake.write_source_archive = write
        packaged = self.root / 'python-source.zip'
        with patch.dict(sys.modules, {'build_observer': fake}):
            write(packaged)
            self.assertEqual(package.observer_drift(packaged), [])
            write(packaged, b'observer v1')
            self.assertEqual(package.observer_drift(packaged), ['browser_observer.py'])
            with zipfile.ZipFile(packaged, 'a') as archive: archive.writestr('tools/extra.py', 'x')
            self.assertEqual(package.observer_drift(packaged), ['browser_observer.py', 'tools/extra.py'])
    def test_real_observer_builder_round_trips(self):
        import io, zipfile
        from build_observer import write_source_archive
        stream = io.BytesIO(); write_source_archive(stream)
        packaged = self.root / 'python-source.zip'; packaged.write_bytes(stream.getvalue())
        self.assertEqual(package.observer_drift(packaged), [])
    def test_complete_replacement_is_verified(self):
        self.source.write_text('new')
        rows = package.install_bundle({'remaster.mjs': self.source}, self.target)
        self.assertEqual(rows['remaster.mjs']['sha256'], package.sha(self.source))
        self.assertIsNotNone(package.verify_owned(self.target))

if __name__ == '__main__': unittest.main()
