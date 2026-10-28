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

    def test_unselected_load_and_package_imports_are_rejected(self):
        # load(), tests.* / tools.* package imports, plain imports and relative imports all count as code dependencies.
        cases = {
            'godot/scripts/a.gd': ('extends Node\nvar b = load("res://scripts/b.gd")\n', 'godot/scripts/b.gd'),
            'tests/test_a.py': ('from tests.test_b import x\n', 'tests/test_b.py'),
            'tests/test_c.py': ('import tools.helper\n', 'tools/helper.py'),
            'tools/pkg/a.py': ('from .b import x\n', 'tools/pkg/b.py'),
        }
        for member, (text, dependency) in cases.items():
            with self.subTest(member=member), tempfile.TemporaryDirectory() as directory:
                root = self.fixture(directory)
                for name, body in ((member, text), (dependency, 'x = 1\n')):
                    (root / name).parent.mkdir(parents=True, exist_ok=True)
                    (root / name).write_text(body)
                manifest = json.loads((root / package.MANIFEST).read_text())
                manifest['source'].append(member)
                (root / package.MANIFEST).write_text(json.dumps(manifest))
                with self.assertRaisesRegex(ValueError, 'Missing code dependency: .* -> ' + dependency):
                    package.build(root, root / 'bad.zip', 'source')
                self.assertFalse((root / 'bad.zip').exists())
                manifest['source'].append(dependency)
                (root / package.MANIFEST).write_text(json.dumps(manifest))
                package.check_source_closure(root, package.selected_files(root, 'source'))

    def test_resource_closure_accepts_plain_and_escaped_delimiters_and_checks_each(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            caller = 'godot/scripts/a.gd'
            dependencies = ['scripts/plain.png', 'scripts/escaped.gdshaderinc',
                            'scripts/adjacent.gdshaderinc', 'scripts/single.gdshaderinc']
            source = ('var plain = "res://scripts/plain.png"\n'
                      'var shader = "#include \\"res://scripts/escaped.gdshaderinc\\" \\"res://scripts/adjacent.gdshaderinc\\""\n'
                      "var other = '#include \\'res://scripts/single.gdshaderinc\\''\n")
            for name, data in [(caller, source), *[('godot/' + d, 'fixture') for d in dependencies]]:
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text(data)
            names = [caller] + ['godot/' + d for d in dependencies]
            package.check_source_closure(root, names, include_assets=True)
            for dependency in dependencies:
                with self.subTest(dependency=dependency):
                    # Escaped includes also fail the code closure, which runs first.
                    with self.assertRaisesRegex(ValueError, 'Missing (?:code|resource) dependency'):
                        package.check_source_closure(root, [n for n in names if n != 'godot/' + dependency], include_assets=True)

    def test_historical_comparison_exception_is_exact_and_preserves_code_closure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); caller = 'godot/tests/test_pc_effect_art.gd'
            path = root / caller; path.parent.mkdir(parents=True)
            path.write_text('var baseline = FileAccess.get_file_as_string("res://tests/effects-before.gdshader")\n')
            package.check_source_closure(root, [caller], include_assets=True)
            production = root / 'godot/scripts/a.gd'; production.parent.mkdir()
            production.write_text(path.read_text())
            with self.assertRaisesRegex(ValueError, 'Missing resource dependency'):
                package.check_source_closure(root, [production.relative_to(root).as_posix()], include_assets=True)
            for text, error in [
                ('extends "res://tests/missing.gd"\n', 'Missing code dependency'),
                ('var image = "res://tests/unrelated.png"\n', 'Missing resource dependency'),
                ('var shader = load("res://tests/effects-before.gdshader")\n', 'Missing code dependency'),
            ]:
                with self.subTest(text=text):
                    path.write_text(text)
                    with self.assertRaisesRegex(ValueError, error):
                        package.check_source_closure(root, [caller], include_assets=True)

    def test_declared_authoring_output_is_not_a_missing_input(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); caller = 'tools/build_cover_export.gd'
            path = root/caller; path.parent.mkdir(parents=True)
            target = 'res://../local-art/cover-blender-v1/source.json'
            path.write_text(f'var output = FileAccess.open("{target}",FileAccess.WRITE)\n')
            package.check_source_closure(root, [caller], include_assets=True)
            for expression in [f'FileAccess.open("{target}",FileAccess.READ)',
                               f'FileAccess.open("{target}",FileAccess.WRITE_READ)',
                               f'load("{target}")',
                               'FileAccess.open("res://unrelated.json",FileAccess.WRITE)']:
                path.write_text('var resource = '+expression+'\n')
                with self.assertRaisesRegex(ValueError, 'Missing (?:code|resource) dependency'):
                    package.check_source_closure(root, [caller], include_assets=True)

    def test_escaped_resource_scanner_cannot_absorb_adjacent_dynamic_text(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); name = 'godot/scripts/a.gd'; path = root / name
            path.parent.mkdir(parents=True)
            path.write_text('var shader = "#include \\"res://scripts/missing.gdshaderinc\\""\nvar dynamic = "%s"\n')
            with self.assertRaisesRegex(ValueError, 'Missing code dependency: .* -> godot/scripts/missing.gdshaderinc'):
                package.check_source_closure(root, [name], include_assets=True)
            path.write_text('var image = "\\"res://scripts/missing.png\\""\nvar dynamic = "%s"\n')
            with self.assertRaisesRegex(ValueError, 'Missing resource dependency: .* -> godot/scripts/missing.png'):
                package.check_source_closure(root, [name], include_assets=True)

    def test_shader_includes_and_script_inheritance_close_in_both_modes(self):
        files = {
            'godot/scripts/a.gdshader': 'shader_type spatial;\n#include "res://scripts/b.gdshaderinc"\n',
            'godot/scripts/b.gdshaderinc': '#include "res://scripts/c.gdshaderinc"\n',
            'godot/scripts/c.gdshaderinc': 'float c() { return 1.0; }\n',
            'godot/scripts/child.gd': 'extends "res://scripts/base.gd"\n',
            'godot/scripts/base.gd': 'extends Node\n',
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, text in files.items():
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text)
            for include_assets in (False, True):
                package.check_source_closure(root, list(files), include_assets=include_assets)
                for missing in ['godot/scripts/b.gdshaderinc', 'godot/scripts/c.gdshaderinc', 'godot/scripts/base.gd']:
                    with self.subTest(missing=missing, include_assets=include_assets):
                        with self.assertRaisesRegex(ValueError, 'Missing code dependency: .* -> ' + missing):
                            package.check_source_closure(root, [n for n in files if n != missing], include_assets=include_assets)
            # A formatted include in a shader template is resolved at runtime.
            dynamic = root / 'godot/scripts/template.gd'
            dynamic.write_text('const SOURCE := "#include \\"res://scripts/%s.gdshaderinc\\"\n"\n')
            for include_assets in (False, True):
                with self.subTest(dynamic=True, include_assets=include_assets):
                    package.check_source_closure(root, [*files, 'godot/scripts/template.gd'], include_assets=include_assets)

    def test_mixed_case_exclusions_fail_closed(self):
        for name in ['Godot/assets/voice.json', 'godot/Data/pc_crew_voice_script.json', 'godot/DATA/x.json',
                     'godot/tests/Fixtures/dialogue.json', 'godot/tests/Fixtures/a_steps.json',
                     'Local-Audio/notes.md', 'Game/notes.txt', 'Local-Art/a.json', 'Reference/a.json']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.validate_name(name, 'source')
        for name in ['Local-Audio/frontend-music-v1/a.wav', 'local-audio/Frontend-Music-v1/a.wav', 'Local-Art/Genesis/a.png', 'local-art/GENESIS/a.png']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.validate_name(name, 'private')
        package.validate_name('godot/tests/fixtures/a_steps.json', 'source')
        package.validate_name('local-audio/frontend-music-v1/a.wav', 'private')

    def test_allowlist_spelling_must_match_disk(self):
        for spelling in ['tools/A.py', 'Tools/a.py']:
            with self.subTest(spelling=spelling), tempfile.TemporaryDirectory() as directory:
                root = self.fixture(directory)
                manifest = json.loads((root / package.MANIFEST).read_text())
                manifest['source'] = [package.MANIFEST, spelling]
                (root / package.MANIFEST).write_text(json.dumps(manifest))
                # Case-insensitive volumes open the file; case-sensitive ones do not.
                with self.assertRaisesRegex(ValueError, 'case differs|Missing'):
                    package.build(root, root / 'bad.zip', 'source')
                self.assertFalse((root / 'bad.zip').exists())

    def test_working_tree_credentials_and_originals_never_enter_kits(self):
        token = 'sk-' + 'A1b2' * 10  # Assembled so this file carries no signature.
        original = b'synthetic original bytes'
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            (root / 'tools/a.py').write_text(f'KEY = "{token}"\n')
            with self.assertRaisesRegex(ValueError, 'Boundary violation .* tools/a.py: credential signature'):
                package.build(root, root / 'secret.zip', 'source')
            with zipfile.ZipFile(root / 'secret.zip') as archive:
                self.assertNotIn('tools/a.py', archive.namelist())
                self.assertNotIn(package.RECEIPT, archive.namelist())
            (root / 'tools/a.py').write_text('print("hello")\n')
            launchers = ['Play.command', 'tools/package/Play.command']
            for name in launchers:
                (root / name).write_text('#!/bin/sh\n')
            for name in ['tools/renamed.txt', '.runtime/pc-core/abrams-ref.zip']:
                (root / name).parent.mkdir(parents=True, exist_ok=True); (root / name).write_bytes(original)
            manifest = json.loads((root / package.MANIFEST).read_text())
            manifest['source'] += launchers
            boundary = package.git_boundary()
            with patch.object(boundary, 'known_inputs', return_value={hashlib.sha256(original).hexdigest()}), \
                    patch('tools.package_setup.CONTENT_SHA', hashlib.sha256(original).hexdigest()), \
                    patch.object(package, 'verify_private_inputs'):
                manifest['private'] = ['.runtime/pc-core/abrams-ref.zip']
                (root / package.MANIFEST).write_text(json.dumps(manifest))
                # Only an original at its pinned path with its pinned hash is exempt.
                self.assertEqual(package.build(root, root / 'pinned.zip', 'private')['kind'], 'private')
                for kind, rows in [('private', ['tools/renamed.txt']), ('source', [])]:
                    with self.subTest(kind=kind):
                        manifest['private'] = rows
                        manifest['source'] = [package.MANIFEST, 'tools/a.py', *launchers] + (['tools/renamed.txt'] if kind == 'source' else [])
                        (root / package.MANIFEST).write_text(json.dumps(manifest))
                        with self.assertRaisesRegex(ValueError, 'tools/renamed.txt: fingerprinted original'):
                            package.build(root, root / f'{kind}-renamed.zip', kind)

    def test_output_inside_original_sources_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            (root / 'GAME').mkdir()
            for output in [root / 'GAME/kit.zip', root / 'game/nested/kit.zip']:
                with self.subTest(output=output), self.assertRaisesRegex(ValueError, 'outside original source'):
                    package.build(root, output, 'source')
            self.assertEqual(list((root / 'GAME').iterdir()), [])

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

    def test_real_source_allowlist(self):
        source = package.selected_files(ROOT, 'source')
        self.assertIn('tools/package_build.py', source)
        # Output guards (and the runtime host) import the shared helper.
        self.assertIn('tools/source_guard.py', source)
        package.check_source_closure(ROOT, source)

    @unittest.skipUnless((ROOT / 'GAME').is_dir(), 'Requires private original inputs')
    def test_real_private_custody(self):
        # The source kit deliberately has no private dependencies; this skip is counted.
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

    def test_import_destination_inside_original_sources_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            for alias in ['GAME', 'game', 'Genesis']:
                destination = ROOT / alias / 'never-created-setup-kit'
                with self.subTest(alias=alias), self.assertRaisesRegex(ValueError, 'outside original source'):
                    prepare(Path(directory), destination, [])
                self.assertFalse(destination.exists())


if __name__ == '__main__':
    unittest.main()
