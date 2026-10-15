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
        copyfile = runtime.shutil.copyfile
        for relative in ['godot/project.godot', 'GAME/ABRAMS.COM', '.runtime/pc-core/abrams-ref.zip']:
            with self.subTest(relative=relative):
                def corrupt(source, destination, **kwargs):
                    result = copyfile(source, destination, **kwargs)
                    if Path(destination).as_posix().endswith('/' + relative):
                        Path(destination).write_bytes(b'corrupt successful copy')
                    return result
                with patch.object(runtime.shutil, 'copyfile', corrupt):
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
        copyfile = runtime.shutil.copyfile
        def corrupt(source, destination, **kwargs):
            result = copyfile(source, destination, **kwargs)
            if Path(destination).as_posix().endswith('/GAME/ABRAMS.COM'):
                Path(destination).write_bytes(b'changed game')
                changed = [dict(row) for row in self.rows]
                changed[0]['sha256'] = digest(b'changed game')
                records.write_text(json.dumps({'files': changed}))
            return result
        try:
            with patch.object(runtime.shutil, 'copyfile', corrupt):
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
