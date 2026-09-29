import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from tools import package_build as package
from tools.package_runtime import data_home
from tools.package_setup import prepare, CONTENT_SHA

ROOT = Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def test_first_launch_imports_are_serialized(self):
        import configparser
        config = configparser.ConfigParser(strict=False)
        config.read_string((ROOT / "godot/project.godot").read_text().replace("config_version=5", ""))
        self.assertFalse(config.getboolean("editor", "import/use_multiple_threads"))

    def fixture(self, directory):
        root = Path(directory)
        (root / 'tools/package').mkdir(parents=True)
        (root / 'tools/a.py').write_text('print("hello")\n')
        manifest = {'schema': 1, 'source': [package.MANIFEST, 'tools/a.py'], 'private': []}
        (root / package.MANIFEST).write_text(json.dumps(manifest))
        return root

    def test_deterministic_archive_and_verified_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            a, b = root / 'a.zip', root / 'b.zip'
            first = package.build(root, a, 'source')
            os.utime(root / 'tools/a.py', (12345678, 12345678))
            second = package.build(root, b, 'source')
            self.assertEqual(first, second)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            self.assertFalse(first['release_ready'])

    def test_unlisted_files_and_local_state_excluded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            (root / 'secret.env').write_text('secret')
            (root / 'unrelated.py').write_text('unrelated')
            package.build(root, root / 'a.zip', 'source')
            with zipfile.ZipFile(root / 'a.zip') as archive:
                self.assertEqual(set(archive.namelist()), {package.MANIFEST, 'tools/a.py', package.RECEIPT})

    def test_private_play_is_managed_without_editing_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            (root / 'Play.command').write_text('original')
            (root / 'tools/package/Play.command').write_text('managed')
            manifest = json.loads((root / package.MANIFEST).read_text())
            manifest['source'] += ['Play.command', 'tools/package/Play.command']
            (root / package.MANIFEST).write_text(json.dumps(manifest))
            with patch.object(package, 'verify_private_inputs'):
                package.build(root, root / 'private.zip', 'private')
            with zipfile.ZipFile(root / 'private.zip') as archive:
                self.assertEqual(archive.read('Play.command'), b'managed')
            self.assertEqual((root / 'Play.command').read_text(), 'original')

    def test_source_excludes_proprietary_and_derivative_assets(self):
        for name in ['GAME/SIM.EXE', 'local-art/art.png', 'reference/palette.gpl', '.runtime/core.dylib', 'godot/assets/audio/voice.wav', 'godot/data/voice.json']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.validate_name(name, 'source')

    def test_save_state_secrets_and_traversal_rejected_for_both_kinds(self):
        for kind in ['private', 'source']:
            for name in ['../escape.py', '/escape.py', 'tools/../escape.py', 'saves/state.json', 'states/slot.json', 'artifacts/capture.json', '.env', 'tools/a.state', 'tools\\a.py', 'SAVES/state.json', 'secret.env', '.SSH/id_rsa', 'key.PEM', 'genesis/rom.md']:
                with self.subTest(name=name, kind=kind), self.assertRaises(ValueError):
                    package.validate_name(name, kind)

    def test_symlink_and_missing_input_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            p = root / 'tools/a.py'
            p.unlink()
            with self.assertRaisesRegex(ValueError, 'Missing'):
                package.selected_files(root, 'source')
            p.symlink_to(root / package.MANIFEST)
            with self.assertRaisesRegex(ValueError, 'Symlinks'):
                package.selected_files(root, 'source')

    def test_missing_local_preload_is_rejected_before_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            (root / 'godot/scripts').mkdir(parents=True)
            (root / 'godot/scripts/a.gd').write_text('extends Node\nconst B = preload("res://scripts/missing.gd")\n')
            manifest = json.loads((root / package.MANIFEST).read_text())
            manifest['source'].append('godot/scripts/a.gd')
            (root / package.MANIFEST).write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'Missing code dependency'):
                package.build(root, root / 'bad.zip', 'source')
            self.assertFalse((root / 'bad.zip').exists())

    def test_symlink_archive_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            package.build(root, root / 'a.zip', 'source')
            with zipfile.ZipFile(root / 'a.zip') as before, zipfile.ZipFile(root / 'bad.zip', 'w') as after:
                for info in before.infolist():
                    data = before.read(info.filename)
                    if info.filename == 'tools/a.py':
                        info.external_attr = (0o120000 | 0o644) << 16
                    after.writestr(info, data)
            with self.assertRaisesRegex(ValueError, 'Noncanonical'):
                package.verify(root / 'bad.zip')

    def test_tampered_archive_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            package.build(root, root / 'a.zip', 'source')
            with zipfile.ZipFile(root / 'a.zip') as before, zipfile.ZipFile(root / 'bad.zip', 'w') as after:
                for info in before.infolist():
                    data = before.read(info.filename)
                    after.writestr(info, b'changed' if info.filename == 'tools/a.py' else data)
            with self.assertRaisesRegex(ValueError, 'fingerprint'):
                package.verify(root / 'bad.zip')

    def test_existing_output_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            output = root / 'existing.zip'
            output.write_bytes(b'keep')
            with self.assertRaises(FileExistsError):
                package.build(root, output, 'source')
            self.assertEqual(output.read_bytes(), b'keep')

    def test_player_data_is_external_and_stable_across_upgrades(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'kit'
            profile = Path(directory) / 'profile'
            profile.mkdir()
            (profile / 'campaign').write_bytes(b'keep')
            with patch.dict(os.environ, {'ABRAMS_DATA_HOME': str(profile)}):
                self.assertEqual(data_home(root), data_home(Path(directory) / 'kit-upgrade'))
            self.assertEqual((profile / 'campaign').read_bytes(), b'keep')
            for invalid in [str(root / 'saves'), 'relative/saves']:
                with patch.dict(os.environ, {'ABRAMS_DATA_HOME': invalid}), self.assertRaises(ValueError):
                    data_home(root)

    def test_real_source_allowlist_and_private_custody(self):
        source = package.selected_files(ROOT, 'source')
        self.assertIn('tools/package_build.py', source)
        if not (ROOT / 'GAME').exists():
            return  # The source kit deliberately has no private dependencies.
        private = package.selected_files(ROOT, 'private')
        self.assertIn('.runtime/pc-core/abrams-ref.zip', private)
        self.assertNotIn('tools/build_pc_vehicle_studies.py', private)
        self.assertIn('tools/pc_vehicle_catalog.py', private)
        self.assertIn('tools/build_pc_modern_assets.py', private)
        self.assertIn('local-art/pc-modern/catalog.json', private)
        self.assertIn('local-art/pc-modern/tree.png', private)
        self.assertNotIn('tests/test_pc_vehicle_catalog.py', private)
        self.assertIn('godot/assets/fonts/Plex-OFL.txt', private)
        self.assertIn('.runtime/dosbox-pure-source/LICENSE', private)

    @unittest.skipUnless((ROOT / 'GAME').is_dir(), 'Requires private original inputs')
    def test_private_runtime_asset_provenance(self):
        allowed = set(package.selected_files(ROOT, 'private'))
        voices = json.loads((ROOT / 'godot/assets/audio/pc_remaining_provenance.json').read_text())['voices']
        music = json.loads((ROOT / 'local-audio/frontend-music-v1/manifest.json').read_text())['tracks']
        donors = json.loads((ROOT / 'local-art/pc-graphics-native-v1/graphics.json').read_text())['donors']
        records = [('godot/assets/audio/voice_' + key + '.wav', row['sha256']) for key, row in voices.items()]
        records += [('local-audio/frontend-music-v1/' + row['file'], row['sha256']) for row in music.values()]
        records += [(row['path'], row['sha256']) for row in donors.values()]
        for name, fingerprint in records:
            with self.subTest(name=name):
                self.assertIn(name, allowed)
                self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), fingerprint)
        package.verify_private_inputs(ROOT)

    @unittest.skipUnless((ROOT / 'GAME').is_dir(), 'Requires private original inputs')
    def test_owned_input_import_reproduces_exact_pinned_zip(self):
        records = json.loads((ROOT / 'tools/package/game-inputs.json').read_text())['files']
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            self.assertEqual(prepare(ROOT / 'GAME', target, records), CONTENT_SHA)
            with self.assertRaisesRegex(ValueError, 'already exists'):
                prepare(ROOT / 'GAME', target, records)
            self.assertEqual(hashlib.sha256((target / '.runtime/pc-core/abrams-ref.zip').read_bytes()).hexdigest(), CONTENT_SHA)


if __name__ == '__main__':
    unittest.main()
