"""Standalone provisioning contracts using tiny synthetic originals and payloads.

No proprietary game, bundled engine, native UI or external service is required.
"""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.standalone import runtime

HAS_PIL = importlib.util.find_spec('PIL') is not None


def digest(data):
    return hashlib.sha256(data).hexdigest()


def _symlinks_supported():
    with tempfile.TemporaryDirectory() as temporary:
        try:
            (Path(temporary) / 'link').symlink_to(Path(temporary), target_is_directory=True)
            return True
        except (OSError, NotImplementedError):
            return False


# Windows runners may lack the privilege to create symlinks; those cases are
# POSIX-only, while every other provisioning contract also runs on Windows.
needs_symlinks = unittest.skipUnless(_symlinks_supported(), 'symlink creation is unavailable')


class StandaloneRuntimeTests(unittest.TestCase):
    def test_explicit_profile_does_not_require_a_system_home(self):
        with patch('tools.standalone.runtime.Path.home',side_effect=RuntimeError('missing home')):
            with patch.dict('os.environ', {'ABRAMS_DATA_HOME':str(self.home)}):
                self.assertEqual(runtime.profile_home(self.bundle),self.home)
            self.assertEqual(runtime.profile_home(self.bundle,str(self.home)),self.home)

    def test_platform_profile_environment_does_not_evaluate_home_fallback(self):
        with patch('tools.standalone.runtime.Path.home',side_effect=RuntimeError('missing home')):
            with patch.dict('os.environ', {'LOCALAPPDATA':str(self.root),'XDG_DATA_HOME':str(self.root)},clear=True):
                for platform,name in [('win32','Abrams'),('linux','abrams')]:
                    with patch.object(runtime.sys,'platform',platform):
                        self.assertEqual(runtime.profile_home(self.bundle),self.root/name)

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
        # Long enough for one synthetic 16-word palette record.
        self.rom_data = b'synthetic supported Genesis ROM' + bytes(range(1, 33))
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
            'files': [{'path': path.relative_to(self.kit).as_posix(), 'sha256': digest(path.read_bytes()), 'mode': 0o644}
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
        # A build that pins no Genesis data has nothing to verify, so it stays off.
        self.assertFalse(status['genesis_enabled'])
        receipt = json.loads((self.home / 'content/genesis.json').read_text())
        self.assertEqual(receipt, {'schema': 2, 'rom_sha256': runtime.ROM_SHA, 'files': {}, 'unavailable': []})
        self.assertEqual(self.rom.read_bytes(), self.rom_data)
        self.prepare.assert_called_once()

    def derived_manifest(self):
        """Synthetic pinned derivations: one PC, one Genesis, one unreproducible PNG."""
        pc = {'kind': 'json', 'template': {'schema': 1, 'pixels': None}, 'fills': [
            {'at': ['pixels'], 'value': {'kind': 'pc-resource-base64', 'source': 'ABRAMS.COM'}}]}
        genesis = {'kind': 'gimp-palette', 'name': 'Synthetic', 'segments': [[0, 16]]}
        # Encoder-dependent, so it may be unavailable without disabling Genesis.
        plate = {'kind': 'genesis-plate', 'tiles': 0x40000, 'map': 0x40000, 'palette_commands': [0], 'overlay': None}
        with patch('tools.inspect_scenarios.decode_resource', side_effect=lambda data: data[::-1]):
            pc_bytes = runtime.derive(pc, runtime.DerivationInputs(game=self.game))
        genesis_bytes = runtime.derive(genesis, runtime.DerivationInputs(rom=self.rom_data))
        self.manifest['derived'] = [
            {'path': 'local-art/pc-synthetic/catalog.json', 'origin': 'pc', 'sha256': digest(pc_bytes), 'recipe': pc},
            {'path': 'reference/genesis/synthetic/palette.gpl', 'origin': 'genesis', 'sha256': digest(genesis_bytes), 'recipe': genesis},
            {'path': 'local-art/genesis/source/unmatched.png', 'origin': 'genesis', 'sha256': '0' * 64, 'recipe': plate}]
        self.write_manifest()
        patch('tools.inspect_scenarios.decode_resource', side_effect=lambda data: data[::-1]).start()
        return pc_bytes, genesis_bytes

    def test_genesis_import_derives_pinned_data_and_receipt_lists_real_files(self):
        pc_bytes, genesis_bytes = self.derived_manifest()
        self.imported()
        install = runtime.prepare_install(self.bundle, self.home)
        self.assertEqual((install / 'local-art/pc-synthetic/catalog.json').read_bytes(), pc_bytes)
        self.assertFalse((install / 'reference').exists())
        status = runtime.import_games(self.bundle, self.home, genesis=self.rom)
        self.assertTrue(status['genesis_enabled'])
        receipt = json.loads((self.home / 'content/genesis.json').read_text())
        self.assertEqual(receipt['files'], {'reference/genesis/synthetic/palette.gpl': digest(genesis_bytes)})
        self.assertEqual([entry.split(': ', 1)[0] for entry in receipt['unavailable']], ['local-art/genesis/source/unmatched.png'])
        # The ROM is never copied into the profile, only its pinned derivations.
        self.assertFalse(any(path.read_bytes() == self.rom_data for path in self.home.rglob('*') if path.is_file()))
        # A late Genesis import reaches an already accepted installation.
        install = runtime.prepare_install(self.bundle, self.home)
        self.assertEqual((install / 'reference/genesis/synthetic/palette.gpl').read_bytes(), genesis_bytes)
        self.assertFalse((install / 'local-art/genesis/source/unmatched.png').exists())
        # A hand-written receipt cannot enable Genesis without its data.
        (self.home / runtime.DERIVED_STORE / digest(genesis_bytes)).write_bytes(b'forged')
        self.assertFalse(runtime.status(self.bundle, self.home)['genesis_enabled'])
        self.assertIn('Genesis ROM again', runtime.status(self.bundle, self.home)['problem'])

    def test_legacy_genesis_receipt_asks_for_rom_instead_of_enabling_art(self):
        self.imported()
        (self.home / 'content/genesis.json').write_text(json.dumps({'schema': 1, 'rom_sha256': runtime.ROM_SHA}))
        status = runtime.status(self.bundle, self.home)
        self.assertFalse(status['genesis_enabled'])
        self.assertIn('Genesis ROM again', status['problem'])

    def test_receipt_listing_pinned_data_as_unavailable_never_enables_genesis(self):
        # Every committed Genesis row claimed unavailable, with no data at all.
        table = json.loads((REPO / 'tools/standalone/import-derived.json').read_text())
        self.manifest['derived'] = table['derived']; self.write_manifest()
        self.imported()
        rows = [row for row in table['derived'] if row['origin'] == 'genesis']
        self.assertTrue(any(row['recipe']['kind'] not in runtime.ENCODED_RECIPES for row in rows))
        forged = {'schema': 2, 'rom_sha256': runtime.ROM_SHA, 'files': {},
                  'unavailable': [row['path'] + ': x' for row in rows]}
        (self.home / 'content/genesis.json').write_text(json.dumps(forged))
        self.assertFalse(runtime.genesis_enabled(self.home, self.manifest))
        self.assertIn('Genesis ROM again', runtime.status(self.bundle, self.home)['problem'])
        # Only encoder-dependent PNGs may be missing, and only beside verified data.
        pure = [row for row in rows if row['recipe']['kind'] not in runtime.ENCODED_RECIPES]
        forged['unavailable'] = [row['path'] + ': x' for row in rows if row not in pure]
        forged['files'] = {row['path']: row['sha256'] for row in pure}
        (self.home / 'content/genesis.json').write_text(json.dumps(forged))
        self.assertFalse(runtime.genesis_enabled(self.home, self.manifest))
        for row in pure:
            path = self.home / runtime.DERIVED_STORE / row['sha256']
            path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b'not the derived bytes')
        self.assertFalse(runtime.genesis_enabled(self.home, self.manifest))

    @unittest.skipIf(sys.platform == 'win32', 'macOS application launch layout')
    def test_forged_receipt_launch_stays_pc_only(self):
        self.manifest['derived'] = [row for row in json.loads((REPO / 'tools/standalone/import-derived.json').read_text())['derived']
                                    if row['origin'] == 'genesis']
        self.write_manifest(); self.imported()
        (self.home / 'content/genesis.json').write_text(json.dumps({'schema': 2, 'rom_sha256': runtime.ROM_SHA, 'files': {},
            'unavailable': [row['path'] + ': x' for row in self.manifest['derived']]}))
        renderer = self.bundle / 'Contents/Helpers/AbramsRenderer.app/Contents/MacOS/AbramsRenderer'
        engine = self.resources / 'runtime/AbramsRuntime/AbramsRuntime'
        for path in [renderer, engine]: path.parent.mkdir(parents=True, exist_ok=True); path.write_text('synthetic'); path.chmod(0o755)
        with patch.object(runtime, 'prepare_install', return_value=self.root / 'install'), \
             patch.object(runtime, 'renderer_import'), patch.object(runtime, 'renderer_preflight'), \
             patch.object(runtime.os, 'execve') as execute:
            runtime.launch(self.bundle, self.home, [])
        self.assertIn('--pc-only', execute.call_args[0][1])

    def test_older_profile_derives_missing_pc_data_lazily(self):
        self.imported()
        pc_bytes, _ = self.derived_manifest()
        install = runtime.prepare_install(self.bundle, self.home)
        self.assertEqual((install / 'local-art/pc-synthetic/catalog.json').read_bytes(), pc_bytes)
        # A changed derived copy in the installation is restored from the store.
        (install / 'local-art/pc-synthetic/catalog.json').write_bytes(b'changed')
        runtime.prepare_install(self.bundle, self.home)
        self.assertEqual((install / 'local-art/pc-synthetic/catalog.json').read_bytes(), pc_bytes)

    def test_unreproducible_pc_data_is_reported_not_installed(self):
        self.derived_manifest()
        self.manifest['derived'].append({'path': 'local-art/pc-ui-v2/frame.png', 'origin': 'pc', 'sha256': '1' * 64,
            'recipe': {'kind': 'json', 'template': {'x': 1}, 'fills': []}})
        self.write_manifest()
        status = self.imported()
        self.assertTrue(status['pc_installed'])
        self.assertEqual([entry.split(': ', 1)[0] for entry in status['derived_unavailable']], ['local-art/pc-ui-v2/frame.png'])
        install = runtime.prepare_install(self.bundle, self.home)
        self.assertFalse((install / 'local-art/pc-ui-v2/frame.png').exists())
        self.assertTrue((install / 'local-art/pc-synthetic/catalog.json').is_file())

    def test_derived_manifest_paths_are_validated(self):
        for name in ['../escape', '/absolute', 'a\\b']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                runtime.derived_rows({'derived': [{'path': name, 'origin': 'pc', 'sha256': '0' * 64}]}, 'pc')
        self.manifest['derived'] = [{'path': 'godot/project.godot', 'origin': 'pc', 'sha256': '0' * 64,
                                     'recipe': {'kind': 'json', 'template': {}, 'fills': []}}]
        self.write_manifest(); self.imported()
        with self.assertRaisesRegex(ValueError, 'collides'):
            runtime.prepare_install(self.bundle, self.home)

    def test_accepted_version_is_not_hashed_twice_per_launch(self):
        self.imported()
        with patch.object(runtime, 'valid_payload', wraps=runtime.valid_payload) as payload, \
             patch.object(runtime, 'validate_install', wraps=runtime.validate_install) as install:
            runtime.prepare_install(self.bundle, self.home)
            self.assertEqual((payload.call_count, install.call_count), (1, 1))
            runtime.prepare_install(self.bundle, self.home)
            self.assertEqual((payload.call_count, install.call_count), (1, 2))
        self.manifest['build_id'] = digest(b'verified by launcher'); self.write_manifest()
        with patch.object(runtime, 'valid_payload') as payload, \
             patch.dict('os.environ', {runtime.PAYLOAD_VERIFIED_ENV: self.manifest['build_id']}):
            runtime.prepare_install(self.bundle, self.home)
            payload.assert_not_called()

    def test_junctions_are_links_for_every_guard(self):
        self.imported()
        junction = self.home / 'versions'
        junction.mkdir()
        original = runtime.os.lstat
        class Reparse:
            def __init__(self, info): self.info = info
            def __getattr__(self, name): return getattr(self.info, name)
            st_file_attributes = runtime.stat.FILE_ATTRIBUTE_REPARSE_POINT
            st_reparse_tag = 0xA0000003  # IO_REPARSE_TAG_MOUNT_POINT
        def lstat(path, *args, **kwargs):
            info = original(path, *args, **kwargs)
            return Reparse(info) if Path(path) == junction else info
        with patch.object(runtime.os, 'lstat', lstat):
            self.assertTrue(runtime.is_link(junction))
            self.assertFalse(runtime.regular(junction / 'missing'))
            with self.assertRaisesRegex(ValueError, 'junctions'):
                runtime.prepare_install(self.bundle, self.home)
        self.assertEqual(list(junction.iterdir()), [])

    def test_cloud_placeholder_reparse_points_are_ordinary_inputs(self):
        # OneDrive Files-On-Demand and deduplicated files carry the reparse
        # attribute with a non-link tag; a chosen game folder there must import.
        original = runtime.os.lstat
        class Placeholder:
            def __init__(self, info): self.info = info
            def __getattr__(self, name): return getattr(self.info, name)
            st_file_attributes = runtime.stat.FILE_ATTRIBUTE_REPARSE_POINT
            st_reparse_tag = 0x9000001A  # IO_REPARSE_TAG_CLOUD_6
        def lstat(path, *args, **kwargs):
            info = original(path, *args, **kwargs)
            return Placeholder(info) if Path(path).is_relative_to(self.game) else info
        with patch.object(runtime.os, 'lstat', lstat):
            self.assertFalse(runtime.is_link(self.game))
            self.assertTrue(runtime.regular(self.game / 'ABRAMS.COM'))
            self.assertTrue(self.imported()['pc_installed'])

    def test_windows_promotion_retries_transient_locks_only(self):
        source, target = self.root / 'staged', self.root / 'promoted'
        attempts, sleeps = [], []
        original = Path.rename
        def rename(path, destination):
            attempts.append(path)
            if len(attempts) < 3: raise PermissionError(13, 'in use by antivirus')
            return original(path, destination)
        source.mkdir()
        with patch.object(Path, 'rename', rename):
            runtime.rename_directory(source, target, windows=True, sleep=sleeps.append)
        self.assertTrue(target.is_dir()); self.assertEqual(len(attempts), 3); self.assertEqual(len(sleeps), 2)
        with patch.object(Path, 'rename', side_effect=PermissionError(13, 'locked')):
            with self.assertRaisesRegex(ValueError, 'in use by another program') as caught:
                runtime.rename_directory(source, target, windows=True, attempts=3, sleep=lambda _: None)
            self.assertIsInstance(caught.exception.__cause__, PermissionError)
            with self.assertRaises(PermissionError):
                runtime.rename_directory(source, target, windows=False)
        with patch.object(Path, 'rename', side_effect=OSError('disk failure')):
            with self.assertRaisesRegex(OSError, 'disk failure'):
                runtime.rename_directory(source, target, windows=True, sleep=lambda _: None)

    def test_player_data_inside_original_game_folder_is_refused(self):
        inner = self.game / 'profile'
        with self.assertRaisesRegex(ValueError, 'outside the original game folder'):
            runtime.import_games(self.bundle, inner, self.game)
        self.assertFalse(inner.exists())

    def test_miscased_bundle_path_counts_as_inside_application(self):
        miscased = self.bundle.parent / self.bundle.name.swapcase() / 'Contents/Resources/players'
        with self.assertRaisesRegex(ValueError, 'outside the application'):
            runtime.profile_home(self.bundle, str(miscased))
        with patch.dict('os.environ', {'ABRAMS_DATA_HOME': str(miscased)}):
            with self.assertRaises(ValueError): runtime.profile_home(self.bundle)

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

    @needs_symlinks
    def test_symlinked_source_file_rejected(self):
        source = self.game / 'ABRAMS.COM'
        external = self.root / 'real original'
        source.rename(external)
        source.symlink_to(external)
        with self.assertRaises(ValueError):
            self.imported()
        self.assertFalse(self.home.exists())

    @needs_symlinks
    def test_symlinked_source_directory_rejected(self):
        alias = self.root / 'game alias'
        alias.symlink_to(self.game, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.import_games(self.bundle, self.home, alias)
        self.assertFalse(self.home.exists())

    @needs_symlinks
    def test_symlinked_genesis_rejected(self):
        alias = self.root / 'Genesis alias.bin'
        alias.symlink_to(self.rom)
        with self.assertRaises(ValueError):
            runtime.import_games(self.bundle, self.home, self.game, alias)
        self.assertFalse(self.home.exists())

    @needs_symlinks
    def test_invalid_or_symlinked_receipt_rejected(self):
        self.imported()
        receipt = self.home / 'content/genesis.json'
        receipt.write_text(json.dumps({'schema': 1, 'rom_sha256': 'unsupported'}))
        with self.assertRaises(ValueError):
            runtime.genesis_enabled(self.home, self.manifest)
        receipt.unlink()
        receipt.symlink_to(self.rom)
        with self.assertRaises(ValueError):
            runtime.genesis_enabled(self.home, self.manifest)

    def test_payload_tamper_refuses_install_and_preserves_profile(self):
        self.imported()
        save = self.preserved_save()
        (self.kit / 'godot/project.godot').write_bytes(b'changed payload')
        with self.assertRaisesRegex(ValueError, 'payload'):
            runtime.prepare_install(self.bundle, self.home)
        self.assertFalse((self.home / 'versions').exists())
        self.assertEqual(save.read_bytes(), b'important campaign and profile state')

    @needs_symlinks
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

    @needs_symlinks
    def test_symlinked_content_parent_cannot_redirect_import(self):
        self.home.mkdir()
        external = self.root / 'external content'
        external.mkdir()
        (self.home / 'content').symlink_to(external, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.imported()
        self.assertEqual(list(external.iterdir()), [])

    @needs_symlinks
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

    def test_changed_imported_game_file_points_to_fresh_home_not_reimport(self):
        self.imported()
        save = self.preserved_save()
        changed = self.content() / 'GAME/ABRAMS.COM'
        changed.write_bytes(b'changed import retained for recovery')
        problem = runtime.status(self.bundle, self.home)['problem']
        with self.assertRaises(ValueError) as reimport:
            self.imported()
        # Re-choosing the PC folder is deliberately refused, so never advise it.
        for message in (problem, str(reimport.exception)):
            self.assertNotIn('folder again', message)
            self.assertIn('ABRAMS_DATA_HOME', message)
        self.assertEqual(changed.read_bytes(), b'changed import retained for recovery')
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

    @needs_symlinks
    def test_symlinked_installed_payload_directory_rejected(self):
        self.imported()
        install = runtime.prepare_install(self.bundle, self.home)
        external = self.root / 'redirected installed code'
        (install / 'godot').rename(external)
        (install / 'godot').symlink_to(external, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.prepare_install(self.bundle, self.home)
        self.assertEqual((external / 'project.godot').read_bytes(), b'config_version=5\n')

    def test_failed_version_copy_removes_only_own_staging(self):
        self.imported(); save = self.preserved_save()
        sentinel = self.home / 'versions/unrelated-work'; sentinel.mkdir(parents=True)
        (sentinel / 'keep').write_text('unrelated')
        with patch.object(runtime.shutil, 'copyfile', side_effect=OSError('disk full')):
            with self.assertRaisesRegex(OSError, 'disk full'): runtime.prepare_install(self.bundle, self.home)
        self.assertEqual(list((self.home / 'versions').glob('.install-*')), [])
        self.assertEqual((sentinel / 'keep').read_text(), 'unrelated')
        self.assertEqual(save.read_bytes(), b'important campaign and profile state')
        self.assertTrue(runtime.status(self.bundle, self.home)['pc_installed'])

    def test_failed_version_promotion_preserves_profile_and_removes_staging(self):
        self.imported(); save = self.preserved_save(); original = Path.rename
        def rename(path, target):
            if path.name.startswith('.install-'): raise OSError('promotion blocked')
            return original(path, target)
        with patch.object(Path, 'rename', rename), self.assertRaisesRegex(OSError, 'promotion blocked'):
            runtime.prepare_install(self.bundle, self.home)
        self.assertEqual(list((self.home / 'versions').glob('.install-*')), [])
        self.assertEqual(save.read_bytes(), b'important campaign and profile state')

    def test_corrupt_successful_copy_is_refused_before_promotion_and_retry_works(self):
        self.imported(); save = self.preserved_save()
        first = runtime.prepare_install(self.bundle, self.home)
        self.manifest['build_id'] = digest(b'candidate build'); self.write_manifest()
        target = self.home / 'versions' / self.manifest['build_id']
        sentinel = self.home / 'versions/unrelated-work'; sentinel.mkdir()
        (sentinel / 'keep').write_bytes(b'keep unrelated work')
        copyfile, copytree = runtime.shutil.copyfile, runtime.shutil.copytree
        for relative in ['godot/project.godot', 'GAME/ABRAMS.COM', '.runtime/pc-core/abrams-ref.zip']:
            with self.subTest(relative=relative):
                def corrupt(source, destination, **kwargs):
                    result = copyfile(source, destination, **kwargs)
                    if Path(destination).as_posix().endswith('/' + relative):
                        Path(destination).write_bytes(b'corrupt successful copy')
                    return result
                # copytree's default copy2 uses CopyFile2 on Windows, bypassing copyfile.
                tree = lambda source, destination, **kwargs: copytree(source, destination, copy_function=corrupt, **kwargs)
                with patch.object(runtime.shutil, 'copyfile', corrupt), patch.object(runtime.shutil, 'copytree', tree):
                    with self.assertRaisesRegex(ValueError, 'copy failed verification'):
                        runtime.prepare_install(self.bundle, self.home)
                self.assertFalse(target.exists())
                self.assertEqual(list(target.parent.glob('.install-*')), [])
                self.assertEqual((first / 'godot/project.godot').read_bytes(), b'config_version=5\n')
                self.assertEqual((sentinel / 'keep').read_bytes(), b'keep unrelated work')
                self.assertEqual(save.read_bytes(), b'important campaign and profile state')
                for name, data in self.originals.items():
                    self.assertEqual((self.game / name).read_bytes(), data)
                    self.assertEqual((self.content() / 'GAME' / name).read_bytes(), data)
                self.assertEqual((self.content() / '.runtime/pc-core/abrams-ref.zip').read_bytes(), self.archive)
        self.assertEqual(runtime.prepare_install(self.bundle, self.home), target)
        self.assertEqual(runtime.prepare_install(self.bundle, self.home), target)

    def test_install_uses_captured_original_hashes_after_application_manifest_edit(self):
        self.imported(); save = self.preserved_save()
        records = self.kit / 'tools/package/game-inputs.json'; original = records.read_bytes()
        copyfile, copytree = runtime.shutil.copyfile, runtime.shutil.copytree
        def corrupt(source, destination, **kwargs):
            result = copyfile(source, destination, **kwargs)
            if Path(destination).as_posix().endswith('/GAME/ABRAMS.COM'):
                Path(destination).write_bytes(b'changed game')
                changed = [dict(row) for row in self.rows]
                changed[0]['sha256'] = digest(b'changed game')
                records.write_text(json.dumps({'files': changed}))
            return result
        tree = lambda source, destination, **kwargs: copytree(source, destination, copy_function=corrupt, **kwargs)
        try:
            with patch.object(runtime.shutil, 'copyfile', corrupt), patch.object(runtime.shutil, 'copytree', tree):
                with self.assertRaisesRegex(ValueError, 'original-content copy failed verification'):
                    runtime.prepare_install(self.bundle, self.home)
            self.assertFalse((self.home / 'versions' / self.manifest['build_id']).exists())
            self.assertEqual(list((self.home / 'versions').glob('.install-*')), [])
            self.assertEqual(save.read_bytes(), b'important campaign and profile state')
        finally:
            records.write_bytes(original)
        self.assertTrue(runtime.prepare_install(self.bundle, self.home).is_dir())

    def test_original_expectations_must_match_verified_application_payload(self):
        self.imported()
        records = self.kit / 'tools/package/game-inputs.json'
        original = runtime.valid_payload
        def edit_after_validation(resources, manifest):
            original(resources, manifest)
            records.write_text(json.dumps({'files': []}))
        with patch.object(runtime, 'valid_payload', edit_after_validation):
            with self.assertRaisesRegex(ValueError, 'manifest changed during installation'):
                runtime.prepare_install(self.bundle, self.home)
        self.assertFalse((self.home / 'versions').exists())

    def test_original_expectations_manifest_is_required_for_install(self):
        self.imported()
        self.manifest['files'] = [row for row in self.manifest['files'] if row['path'] != 'tools/package/game-inputs.json']
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'manifest is missing'):
            runtime.prepare_install(self.bundle, self.home)
        self.assertFalse((self.home / 'versions').exists())

    @needs_symlinks
    @unittest.skipIf(sys.platform == 'win32', 'macOS application launch layout')
    def test_failed_preflight_never_executes_game_and_log_link_is_refused(self):
        self.imported(); install = runtime.prepare_install(self.bundle, self.home)
        renderer = self.bundle / 'Contents/Helpers/AbramsRenderer.app/Contents/MacOS/AbramsRenderer'
        engine = self.resources / 'runtime/AbramsRuntime/AbramsRuntime'
        for path in [renderer, engine]: path.parent.mkdir(parents=True, exist_ok=True); path.write_text('synthetic'); path.chmod(0o755)
        with patch.object(runtime, 'renderer_preflight', side_effect=runtime.subprocess.SubprocessError('SCRIPT ERROR')), patch.object(runtime.os, 'execve') as execute:
            with self.assertRaisesRegex(runtime.subprocess.SubprocessError, 'SCRIPT ERROR'): runtime.launch(self.bundle, self.home, [])
            execute.assert_not_called()
        external = self.root / 'external-log'; external.write_bytes(b'preserve')
        (self.home / 'logs/application.log').symlink_to(external)
        with patch.object(runtime.os, 'execve') as execute:
            with self.assertRaisesRegex(ValueError, 'symlink'): runtime.launch(self.bundle, self.home, [])
            execute.assert_not_called()
        self.assertEqual(external.read_bytes(), b'preserve')

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

    @needs_symlinks
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


REPO = Path(__file__).resolve().parents[1]
ROM_PATH = REPO / 'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md'


class NativeDerivationTableTests(unittest.TestCase):
    def test_table_carries_no_original_pixels_and_covers_every_native_exclusion(self):
        from tools.standalone.build import native_derivations, derivation_specs
        table = native_derivations(REPO)
        self.assertEqual({row['path'] for row in table['derived']}, set(derivation_specs()))
        for row in table['derived']:
            recipe = row['recipe']
            if recipe['kind'] == 'json':
                # Every decoded member is an empty hole in the committed template.
                for fill in recipe['fills']:
                    at = recipe['template']
                    for key in fill['at']: at = at[key]
                    self.assertIsNone(at, row['path'])
        self.assertLess((REPO / 'tools/standalone/import-derived.json').stat().st_size, 200_000)
        # Committed templates must not leak the author's checkout location.
        text = (REPO / 'tools/standalone/import-derived.json').read_text()
        self.assertNotRegex(text, r'"(/Users/|/home/|[A-Za-z]:\\\\)')

    def test_modern_source_registry_is_derived_under_the_catalogue_pin(self):
        from tools.standalone.build import native_derivations, check_registry_pin, SHAPE_REGISTRY
        row = next(row for row in native_derivations(REPO)['derived'] if row['path'] == SHAPE_REGISTRY)
        self.assertEqual((row['origin'], row['recipe']), ('pc', {'kind': 'pc-shape-registry', 'source': 'SHAPE.TBL'}))
        # Godot's loader looks for this name beside catalog.json.
        self.assertIn('"source-shapes.json"', (REPO / 'godot/scripts/pc_modern_assets.gd').read_text())
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root / 'local-art/pc-modern').mkdir(parents=True)
            (root / 'local-art/pc-modern/catalog.json').write_text(json.dumps(
                {'source_registry': {'file': 'source-shapes.json', 'sha256': '0' * 64}}))
            with self.assertRaisesRegex(ValueError, 'pin differs'):
                check_registry_pin(root, [row])
            check_registry_pin(root, [dict(row, sha256='0' * 64)])
        # A foreign SHAPE.TBL is refused before any decode is written.
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary) / 'home'; game = Path(temporary) / 'GAME'
            game.mkdir(); (game / 'SHAPE.TBL').write_bytes(b'\x02' + b'\0' * 64)
            written, unavailable = runtime.derive_into_store(home, [row], runtime.DerivationInputs(game=game))
            self.assertEqual(written, {})
            self.assertRegex(unavailable[0], 'source-shapes.json: ValueError: unsupported SHAPE.TBL fingerprint')
            self.assertFalse((home / runtime.DERIVED_STORE / row['sha256']).exists())

    @unittest.skipUnless((REPO / 'GAME/SHAPE.TBL').is_file() and (REPO / 'local-art/pc-modern/catalog.json').is_file(),
                         'Requires the local SHAPE.TBL and Modern catalogue')
    def test_modern_source_registry_reproduces_the_builder_bytes(self):
        from tools.standalone.build import native_derivations, SHAPE_REGISTRY
        from tools.build_pc_modern_assets import source_registry, registry_bytes, merge_catalog
        row = next(row for row in native_derivations(REPO)['derived'] if row['path'] == SHAPE_REGISTRY)
        data = runtime.derive(row['recipe'], runtime.DerivationInputs(game=REPO / 'GAME'))
        self.assertEqual(data, registry_bytes(source_registry((REPO / 'GAME/SHAPE.TBL').read_bytes())))
        catalog = json.loads((REPO / 'local-art/pc-modern/catalog.json').read_text())
        self.assertEqual(digest(data), catalog['source_registry']['sha256'])
        self.assertEqual(digest(data), row['sha256'])
        self.assertTrue(merge_catalog(catalog, json.loads(data))['models'])

    @unittest.skipUnless((REPO / 'GAME/FACES.BMP').is_file() and ROM_PATH.is_file(), 'Requires local original PC files and Genesis ROM')
    @unittest.skipUnless(HAS_PIL, 'Plate recipes encode PNGs with Pillow')
    def test_every_pin_is_reproduced_from_local_originals_and_matches_godot(self):
        from tools.standalone.build import native_derivations
        rom = ROM_PATH.read_bytes()
        inputs = runtime.DerivationInputs(game=REPO / 'GAME', rom=rom)
        for row in native_derivations(REPO)['derived']:
            with self.subTest(path=row['path']):
                self.assertEqual(digest(runtime.derive(row['recipe'], inputs)), row['sha256'])
        pins = {row['path']: row['sha256'] for row in native_derivations(REPO)['derived']}
        # The loaders gate on these exact bytes; a derived file must satisfy them.
        self.assertIn(pins['local-art/genesis/source/effects-v1/effects.json'], (REPO / 'godot/scripts/pc_effect_art.gd').read_text())
        self.assertIn(pins['reference/genesis/extracted/gunner/palette.gpl'], (REPO / 'godot/scripts/pc_genesis_style.gd').read_text())
        # These PC plates are gated on decoded RGB8 pixels rather than file bytes.
        from PIL import Image
        scripts = ''.join(path.read_text() for path in sorted((REPO / 'godot/scripts').glob('*.gd')))
        for path in ['local-art/pc-ui-v2/' + name + '-bin.png' for name in ('gps', 'tc', 'aa', 'driver', 'status')] + ['local-art/pc-graphics-native-v1/expected.png']:
            with self.subTest(pixels=path):
                row = next(row for row in native_derivations(REPO)['derived'] if row['path'] == path)
                with Image.open(io.BytesIO(runtime.derive(row['recipe'], inputs))) as image:
                    self.assertIn(digest(image.convert('RGB').tobytes()), scripts)
        # Newspaper and aftermath plates satisfy their catalogs' donor pins.
        donors = {}
        for catalog in ('local-art/pc-newspapers-v1/newspapers.json', 'local-art/pc-splash-aftermath-v1/catalog.json'):
            def walk(value):
                if isinstance(value, dict):
                    if isinstance(value.get('path'), str) and 'sha256' in value: donors[value['path']] = value['sha256']
                    for item in value.values(): walk(item)
                elif isinstance(value, list):
                    for item in value: walk(item)
            walk(json.loads((REPO / catalog).read_text()))
        plates = [row for row in native_derivations(REPO)['derived'] if row['recipe']['kind'] == 'genesis-plate']
        self.assertEqual(len(plates), 5)
        for row in plates: self.assertEqual(donors[row['path']], row['sha256'], row['path'])

    def test_ported_decoder_covers_every_token_and_refuses_wrapping_cases(self):
        def block(fields, count, width=0):
            value = bits = 0
            for size, field in fields: value |= field << bits; bits += size
            stream = value.to_bytes((bits + 15) // 16 * 2, 'little')
            body = count.to_bytes(2, 'little') + bytes([0x55] + [0] * 15) + bytes([width]) + stream
            return len(body).to_bytes(2, 'little') + body
        tokens = [(2, 1), (8, 0x41),                       # literal byte
                  (2, 3), (4, 15),                         # common byte 0
                  (2, 0), (6, 4), (1, 0), (8, 0x7A),       # run of a literal
                  (2, 2), (6, 3), (8, 6),                  # back-reference
                  (2, 0), (6, 1), (8, 5), (1, 1), (4, 15)]  # long run of a common byte
        data = block(tokens, 14) + b'\0\0'
        self.assertEqual(runtime.genesis_decompress(data, 0), bytes.fromhex('41557a7a7a7a41557a5555555555'))
        # A long back-reference width adds high offset bits.
        far = block([(2, 1), (8, 9), (2, 0), (6, 2), (14, 299), (1, 0), (8, 0x7A),
                     (2, 2), (6, 3), (8, 300 & 255), (1, 300 >> 8)], 303, width=1) + b'\0\0'
        self.assertEqual(runtime.genesis_decompress(far, 0), bytes([9] + [0x7A] * 299 + [9, 0x7A, 0x7A]))
        for broken in (block(tokens, 13) + b'\0\0',              # overruns its declared size
                       block([(2, 2), (6, 3), (8, 1)], 3) + b'\0\0',  # reference before any output
                       block(tokens, 0) + b'\0\0',               # zero count would wrap
                       block(tokens, 14)):                       # chain runs off the data
            with self.subTest(broken=broken.hex()[:16]), self.assertRaises(ValueError):
                runtime.genesis_decompress(broken, 0)

    @unittest.skipUnless(ROM_PATH.is_file(), 'Requires the local Genesis ROM')
    def test_ported_decoder_matches_the_original_routine_receipts(self):
        # Unicorn decodes of the unchanged 9AFE routine, recorded by the extractors.
        rom = ROM_PATH.read_bytes()
        for folder in ('newspapers-v1', 'aftermath-v1'):
            manifest = json.loads((REPO / 'local-art/genesis/source' / folder / 'manifest.json').read_text())
            for name, entry in manifest['entries'].items():
                resources = entry['resources'] if 'resources' in entry else {kind: entry[kind] for kind in ('tiles', 'map')}
                for kind, resource in resources.items():
                    with self.subTest(name=name, kind=kind):
                        self.assertEqual(digest(runtime.genesis_decompress(rom, resource['record'] + 12)), resource['sha256'])


class NativePayloadBoundaryTests(unittest.TestCase):
    """Native and portable payloads carry the review kits' boundary scan."""
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'tools/package').mkdir(parents=True)
        (self.root / 'tools/package/game-inputs.json').write_text(json.dumps({'files': []}))
        (self.root / 'tools/clean.py').write_text('print("hello")\n')
        # Assembled so this file carries no credential signature itself.
        (self.root / 'tools/leak.py').write_text('KEY = "' + 'sk-' + 'A1b2' * 10 + '"\n')
        self.table = {'derived': [], 'excluded': []}

    def test_macos_payload_rejects_credentials(self):
        from tools.standalone import build
        with patch.object(build, 'native_derivations', return_value=self.table), \
             patch.object(build.package_build, 'check_source_closure'), \
             patch.object(build.package_build, 'verify_private_inputs'):
            with patch.object(build.package_build, 'selected_files', return_value=['tools/clean.py', 'tools/leak.py']), \
                 self.assertRaisesRegex(ValueError, 'Boundary violation .* tools/leak.py: credential signature'):
                build.payload(self.root)
            with patch.object(build.package_build, 'selected_files', return_value=['tools/clean.py']):
                self.assertEqual([row['path'] for row in build.payload(self.root)], ['tools/clean.py'])

    @unittest.skipUnless(HAS_PIL, 'portable_build imports the Pillow-backed core loader')
    def test_portable_payload_rejects_credentials(self):
        from tools.standalone import portable_build
        allow = self.root / 'tools/package/allowlist.json'
        with patch.object(portable_build, 'native_derivations', return_value=self.table), \
             patch.object(portable_build.package_build, 'check_source_closure'):
            allow.write_text(json.dumps({'schema': 1, 'source': ['tools/clean.py', 'tools/leak.py'], 'private': []}))
            with self.assertRaisesRegex(ValueError, 'Boundary violation .* tools/leak.py: credential signature'):
                portable_build.payload(self.root)
            allow.write_text(json.dumps({'schema': 1, 'source': ['tools/clean.py'], 'private': []}))
            self.assertEqual([row['path'] for row in portable_build.payload(self.root)], ['tools/clean.py'])


class GenesisColourTests(unittest.TestCase):
    @unittest.skipUnless(HAS_PIL, 'The reference converter lives in a Pillow-backed extractor')
    def test_stdlib_cram_conversion_matches_the_extractor(self):
        from tools.extract_genesis_vdp import color_rgb565
        for packed in range(512):
            self.assertEqual(runtime.cram_rgb(packed), color_rgb565(packed), packed)


class RendererPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.log = Path(self.temp.name) / 'application.log'
        self.log.write_bytes(b'Historical SCRIPT ERROR: previously corrected\n')
    def invoke(self, output, code=0):
        def run(args, **kwargs):
            self.assertEqual(kwargs['timeout'], 300)
            self.assertEqual(kwargs['stderr'], runtime.subprocess.STDOUT)
            kwargs['stdout'].write(output)
            return runtime.subprocess.CompletedProcess(args, code)
        with patch.object(runtime.subprocess, 'run', run): runtime.renderer_preflight(['owned renderer'], {}, self.log)
    def test_clean_output_ignores_historical_error_and_preserves_full_log(self):
        self.invoke(b'Godot ready\n')
        self.assertEqual(self.log.read_bytes(), b'Historical SCRIPT ERROR: previously corrected\nGodot ready\n')
    def test_zero_exit_parse_and_shader_errors_refuse(self):
        for marker in [b'SCRIPT ERROR:', b'Parse Error:', b'SHADER ERROR:', b'ERROR:']:
            with self.subTest(marker=marker), self.assertRaisesRegex(runtime.subprocess.SubprocessError, 'preflight failed') as caught:
                self.invoke(marker+b' invalid resource\n')
            self.assertIn(str(self.log), str(caught.exception)); self.assertIn(marker.decode(), str(caught.exception))
    def test_diagnostic_across_read_boundary_is_detected(self):
        with self.assertRaisesRegex(runtime.subprocess.SubprocessError, 'SCRIPT ERROR'):
            self.invoke(b'x' * 8188 + b'SCRIPT ERROR: boundary\n' + b'x' * 16384)
    def test_nonzero_exit_reports_tail_even_without_diagnostic_marker(self):
        with self.assertRaisesRegex(runtime.subprocess.SubprocessError, 'exit 2') as caught:
            self.invoke(b'export unavailable\n', 2)
        self.assertIn('export unavailable', str(caught.exception))
    def test_timeout_is_clear_and_points_to_complete_log(self):
        with patch.object(runtime.subprocess, 'run', side_effect=runtime.subprocess.TimeoutExpired(['owned renderer'], 300)):
            with self.assertRaisesRegex(runtime.subprocess.SubprocessError, '300 seconds') as caught:
                runtime.renderer_preflight(['owned renderer'], {}, self.log)
        self.assertIn(str(self.log), str(caught.exception))


if __name__ == '__main__':
    unittest.main()
