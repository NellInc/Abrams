"""Standalone provisioning contracts using tiny synthetic originals and payloads.

No proprietary game, bundled engine, native UI or external service is required.
"""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.standalone import runtime


def digest(data):
    return hashlib.sha256(data).hexdigest()


class StandaloneRuntimeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='abrams standalone contract ')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.bundle = self.root / 'Abrams.app'
        self.resources = self.bundle / 'Contents/Resources'
        self.kit = self.resources / 'kit'
        self.home = self.root / 'independent player data'
        self.game = self.root / 'original PC'
        self.game.mkdir()
        self.originals = {'ABRAMS.COM': b'synthetic PC executable', 'STENCIL.FNT': b'synthetic PC font'}
        self.archive = b'synthetic reconstructed PC archive'
        self.rom_data = b'synthetic supported Genesis ROM'
        self.rom = self.root / 'original Genesis.bin'
        self.rom.write_bytes(self.rom_data)
        self.rows = [{'name': name, 'sha256': digest(data)} for name, data in self.originals.items()]
        for name, data in self.originals.items():
            (self.game / name).write_bytes(data)
        for name, data in {
            'tools/package/game-inputs.json': json.dumps({'files': self.rows}).encode(),
            'godot/project.godot': b'config_version=5\n',
            '.runtime/pc-core/abrams-trace.dylib': b'synthetic host core',
        }.items():
            path = self.kit / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.manifest = {
            'schema': 1, 'originals_included': False, 'build_id': digest(b'build one'),
            'files': [{'path': str(path.relative_to(self.kit)), 'sha256': digest(path.read_bytes()), 'mode': 0o644}
                      for path in sorted(self.kit.rglob('*')) if path.is_file()],
        }
        self.write_manifest()
        self.addCleanup(patch.stopall)
        patch.object(runtime, 'CONTENT_SHA', digest(self.archive)).start()
        patch.object(runtime, 'ROM_SHA', digest(self.rom_data)).start()
        patch.object(runtime, 'MIN_FREE', 0).start()
        self.prepare = patch('tools.package_setup.prepare', side_effect=self.fake_prepare).start()
        # Provisioning inserts its kit path for the real reconstruction module.
        original_path = sys.path[:]
        self.addCleanup(lambda: sys.path.__setitem__(slice(None), original_path))

    def write_manifest(self):
        self.resources.mkdir(parents=True, exist_ok=True)
        (self.resources / 'RUNTIME.json').write_text(json.dumps(self.manifest))

    def fake_prepare(self, source, destination, records):
        self.assertEqual(records, self.rows)
        (destination / 'GAME').mkdir(parents=True)
        for row in records:
            data = (source / row['name']).read_bytes()
            self.assertEqual(digest(data), row['sha256'])
            (destination / 'GAME' / row['name']).write_bytes(data)
        archive = destination / '.runtime/pc-core/abrams-ref.zip'
        archive.parent.mkdir(parents=True)
        archive.write_bytes(self.archive)

    def imported(self):
        return runtime.import_games(self.bundle, self.home, self.game)

    def content(self):
        return self.home / 'content' / runtime.CONTENT_SHA

    def preserved_save(self):
        path = self.home / 'saves' / 'slot-1.state'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'important campaign and profile state')
        return path

    def test_sha_streams_empty_and_multiblock_files_without_python311_api(self):
        path = self.root / 'hash-input'
        # Python 3.10 has no file_digest; newer interpreters must not hide that.
        with patch.object(hashlib, 'file_digest', None, create=True):
            for length in [0, 1, 1024 * 1024, 1024 * 1024 + 257]:
                with self.subTest(length=length):
                    data = (bytes(range(256)) * ((length + 255) // 256))[:length]
                    path.write_bytes(data)
                    self.assertEqual(runtime.sha(path), digest(data))

    def test_first_run_has_no_pc_and_requires_pc_before_genesis(self):
        self.assertFalse(runtime.status(self.bundle, self.home)['pc_installed'])
        with self.assertRaisesRegex(ValueError, 'PC game folder'):
            runtime.import_games(self.bundle, self.home, genesis=self.rom)
        self.assertFalse(self.home.exists())
        self.prepare.assert_not_called()

    def test_missing_pc_folder_rejected_without_modification(self):
        with self.assertRaises(ValueError):
            runtime.import_games(self.bundle, self.home, self.root / 'missing')
        self.assertFalse(self.home.exists())
        self.prepare.assert_not_called()

    def test_missing_or_modified_pc_file_preserves_saves_and_originals(self):
        save = self.preserved_save()
        source = self.game / 'ABRAMS.COM'
        for changed in (b'modified', None):
            with self.subTest(changed=changed):
                if changed is None:
                    source.unlink()
                else:
                    source.write_bytes(changed)
                with self.assertRaises(ValueError):
                    self.imported()
                self.assertEqual(save.read_bytes(), b'important campaign and profile state')
                self.assertFalse(self.content().exists())
        self.prepare.assert_not_called()

    def test_unsupported_genesis_prevents_partial_pc_import(self):
        self.rom.write_bytes(b'unsupported revision')
        with self.assertRaisesRegex(ValueError, 'Unsupported Genesis'):
            runtime.import_games(self.bundle, self.home, self.game, self.rom)
        self.assertFalse(self.home.exists())
        self.prepare.assert_not_called()

    def test_optional_genesis_receipt_and_pc_only_import(self):
        status = self.imported()
        self.assertTrue(status['pc_installed'])
        self.assertFalse(status['genesis_enabled'])
        self.assertFalse((self.home / 'content/genesis.json').exists())
        status = runtime.import_games(self.bundle, self.home, genesis=self.rom)
        self.assertTrue(status['genesis_enabled'])
        receipt = json.loads((self.home / 'content/genesis.json').read_text())
        self.assertEqual(receipt, {'schema': 1, 'rom_sha256': runtime.ROM_SHA})
        self.assertEqual(self.rom.read_bytes(), self.rom_data)
        self.prepare.assert_called_once()

    def test_case_insensitive_inputs_normalized_without_changing_originals(self):
        for name in self.originals:
            (self.game / name).rename(self.game / name.lower())
        self.assertTrue(self.imported()['pc_installed'])
        for name, data in self.originals.items():
            self.assertEqual((self.content() / 'GAME' / name).read_bytes(), data)
            self.assertEqual((self.game / name.lower()).read_bytes(), data)
        self.prepare.assert_called_once()

    def test_case_collision_rejected(self):
        # macOS can have a case-insensitive host filesystem. A mocked directory
        # inventory exercises the collision predicate independently of that FS.
        upper = self.game / 'ABRAMS.COM'
        lower = self.game / 'abrams.com'
        original = Path.iterdir
        def listing(path):
            return iter([upper, lower, self.game / 'STENCIL.FNT']) if path == self.game else original(path)
        with patch.object(Path, 'iterdir', listing):
            with self.assertRaises(ValueError):
                self.imported()
        self.assertFalse(self.home.exists())
        self.prepare.assert_not_called()

    def test_symlinked_source_file_rejected(self):
        source = self.game / 'ABRAMS.COM'
        external = self.root / 'real original'
        source.rename(external)
        source.symlink_to(external)
        with self.assertRaises(ValueError):
            self.imported()
        self.assertFalse(self.home.exists())

    def test_symlinked_source_directory_rejected(self):
        alias = self.root / 'game alias'
        alias.symlink_to(self.game, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.import_games(self.bundle, self.home, alias)
        self.assertFalse(self.home.exists())

    def test_symlinked_genesis_rejected(self):
        alias = self.root / 'Genesis alias.bin'
        alias.symlink_to(self.rom)
        with self.assertRaises(ValueError):
            runtime.import_games(self.bundle, self.home, self.game, alias)
        self.assertFalse(self.home.exists())

    def test_invalid_or_symlinked_receipt_rejected(self):
        self.imported()
        receipt = self.home / 'content/genesis.json'
        receipt.write_text(json.dumps({'schema': 1, 'rom_sha256': 'unsupported'}))
        with self.assertRaises(ValueError):
            runtime.genesis_enabled(self.home)
        receipt.unlink()
        receipt.symlink_to(self.rom)
        with self.assertRaises(ValueError):
            runtime.genesis_enabled(self.home)

    def test_payload_tamper_refuses_install_and_preserves_profile(self):
        self.imported()
        save = self.preserved_save()
        (self.kit / 'godot/project.godot').write_bytes(b'changed payload')
        with self.assertRaisesRegex(ValueError, 'payload'):
            runtime.prepare_install(self.bundle, self.home)
        self.assertFalse((self.home / 'versions').exists())
        self.assertEqual(save.read_bytes(), b'important campaign and profile state')

    def test_payload_symlink_parent_rejected(self):
        self.imported()
        external = self.root / 'external godot'
        (self.kit / 'godot').rename(external)
        (self.kit / 'godot').symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            runtime.prepare_install(self.bundle, self.home)
        self.assertFalse((self.home / 'versions').exists())

    def test_payload_path_escape_or_duplicates_rejected(self):
        original = self.manifest['files'][:]
        for name in ['../escape', '/absolute/escape', original[0]['path']]:
            with self.subTest(name=name):
                self.manifest['files'] = original + [{'path': name, 'sha256': digest(b'x'), 'mode': 0o644}]
                with self.assertRaises(ValueError):
                    runtime.valid_payload(self.resources, self.manifest)

    def test_build_id_cannot_escape_version_directory(self):
        self.imported()
        self.manifest['build_id'] = '../../escaped-install'
        self.write_manifest()
        with self.assertRaises(ValueError):
            runtime.prepare_install(self.bundle, self.home)
        self.assertFalse((self.root / 'escaped-install').exists())

    def test_symlinked_content_parent_cannot_redirect_import(self):
        self.home.mkdir()
        external = self.root / 'external content'
        external.mkdir()
        (self.home / 'content').symlink_to(external, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.imported()
        self.assertEqual(list(external.iterdir()), [])

    def test_symlinked_versions_parent_cannot_redirect_install(self):
        self.imported()
        external = self.root / 'external versions'
        external.mkdir()
        (self.home / 'versions').symlink_to(external, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.prepare_install(self.bundle, self.home)
        self.assertEqual(list(external.iterdir()), [])

    def test_corrupt_existing_content_is_reported_and_preserved(self):
        self.imported()
        save = self.preserved_save()
        archive = self.content() / '.runtime/pc-core/abrams-ref.zip'
        archive.write_bytes(b'corrupted content retained for recovery')
        result = runtime.status(self.bundle, self.home)
        self.assertFalse(result['pc_installed'])
        self.assertTrue(result['problem'])
        with self.assertRaises(ValueError):
            self.imported()
        self.assertEqual(archive.read_bytes(), b'corrupted content retained for recovery')
        self.assertEqual(save.read_bytes(), b'important campaign and profile state')
        self.prepare.assert_called_once()

    def test_reconstruction_failure_does_not_commit_receipt_or_content(self):
        self.prepare.side_effect = ValueError('synthetic reconstruction failure')
        with self.assertRaisesRegex(ValueError, 'reconstruction failure'):
            runtime.import_games(self.bundle, self.home, self.game, self.rom)
        self.assertFalse(self.content().exists())
        self.assertFalse((self.home / 'content/genesis.json').exists())
        for name, data in self.originals.items():
            self.assertEqual((self.game / name).read_bytes(), data)

    def test_symlinked_installed_payload_directory_rejected(self):
        self.imported()
        install = runtime.prepare_install(self.bundle, self.home)
        external = self.root / 'redirected installed code'
        (install / 'godot').rename(external)
        (install / 'godot').symlink_to(external, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.prepare_install(self.bundle, self.home)
        self.assertEqual((external / 'project.godot').read_bytes(), b'config_version=5\n')

    def test_reusing_content_does_not_reconstruct_or_change_originals(self):
        self.imported()
        archive = self.content() / '.runtime/pc-core/abrams-ref.zip'
        before = archive.stat().st_mtime_ns
        self.assertTrue(self.imported()['pc_installed'])
        self.prepare.assert_called_once()
        self.assertEqual(archive.stat().st_mtime_ns, before)
        for name, data in self.originals.items():
            self.assertEqual((self.game / name).read_bytes(), data)

    def test_two_build_ids_preserve_shared_saves_profiles_and_content(self):
        self.imported()
        save = self.preserved_save()
        profile = self.home / 'profile.json'
        profile.write_text('{"music": 42}')
        first = runtime.prepare_install(self.bundle, self.home)
        self.manifest['build_id'] = digest(b'build two')
        self.write_manifest()
        second = runtime.prepare_install(self.bundle, self.home)
        self.assertNotEqual(first, second)
        self.assertTrue(first.is_dir() and second.is_dir())
        self.assertEqual(save.read_bytes(), b'important campaign and profile state')
        self.assertEqual(profile.read_text(), '{"music": 42}')
        self.assertTrue(runtime.status(self.bundle, self.home)['pc_installed'])
        self.prepare.assert_called_once()
        self.assertEqual(runtime.prepare_install(self.bundle, self.home), second)

    def test_changed_installed_payload_is_refused_without_overwrite(self):
        self.imported()
        install = runtime.prepare_install(self.bundle, self.home)
        path = install / 'godot/project.godot'
        path.write_bytes(b'keep for recovery')
        with self.assertRaisesRegex(ValueError, 'installation changed'):
            runtime.prepare_install(self.bundle, self.home)
        self.assertEqual(path.read_bytes(), b'keep for recovery')

    def test_independent_external_home_and_app_internal_home_rejected(self):
        with patch.dict('os.environ', {'ABRAMS_DATA_HOME': str(self.home)}):
            self.assertEqual(runtime.profile_home(self.bundle), self.home)
        self.assertEqual(runtime.profile_home(self.bundle, str(self.home)), self.home)
        for invalid in [self.bundle, self.bundle / 'Contents/Resources/players', Path('relative-home')]:
            with self.subTest(invalid=invalid):
                with self.assertRaises(ValueError):
                    runtime.profile_home(self.bundle, str(invalid))
        alias = self.root / 'app alias'
        alias.symlink_to(self.bundle, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.profile_home(self.bundle, str(alias / 'players'))
        self.imported()
        install = runtime.prepare_install(self.bundle, self.home)
        self.assertTrue(install.is_relative_to(self.home))
        self.assertFalse(install.is_relative_to(self.bundle))


if __name__ == '__main__':
    unittest.main()
