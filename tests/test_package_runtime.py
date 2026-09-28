"""Dependency/upgrade contract tests, without native runtime or game content."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
from tools import package_build, package_runtime as runtime, package_setup as setup


class PackageRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='abrams install ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'kit'
        self.root.mkdir()
        self.profile = Path(self.temp.name) / 'profile'
        self.profile.mkdir()
        (self.profile / 'campaign.keep').write_bytes(b'preserve campaign')
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, {'ABRAMS_DATA_HOME': str(self.profile), 'GODOT_BIN': '/fake/godot'}).start()
        patch.object(runtime.platform, 'system', return_value='Darwin').start()
        patch.object(runtime.platform, 'machine', return_value='arm64').start()
        patch.dict(sys.modules, {'PIL': types.SimpleNamespace(__version__='test')}).start()

    def private_fixture(self):
        for name in ['GAME/SIM.EXE', 'GAME/SHAPE.TBL', '.runtime/pc-core/abrams-ref.zip', '.runtime/pc-core/abrams-trace.dylib']:
            path = self.root / name; path.parent.mkdir(parents=True, exist_ok=True); path.touch()
        (self.root / '.runtime/pc-core/abrams-trace.json').write_text(json.dumps({'trace_sha256': '0' * 64}))
        patch.object(package_build, 'selected_files', return_value=[]).start()
        patch.object(package_build, 'check_source_closure').start()
        patch.object(package_build, 'verify_private_inputs').start()

    def test_platform_rejected_before_optional_dependencies(self):
        for system, machine in [('Windows', 'AMD64'), ('Linux', 'aarch64'), ('Darwin', 'x86_64')]:
            with self.subTest(system=system), patch.object(runtime.platform, 'system', return_value=system), patch.object(runtime.platform, 'machine', return_value=machine):
                with self.assertRaisesRegex(ValueError, 'macOS ARM64 only'):
                    runtime.dependencies(self.root)

    def test_old_python_rejected(self):
        with patch.object(runtime.sys, 'version_info', (3, 9)), self.assertRaisesRegex(ValueError, 'Python 3.10'):
            runtime.dependencies(self.root)

    def test_missing_pillow_is_actionable(self):
        with patch.dict(sys.modules, {'PIL': None}), self.assertRaisesRegex(ValueError, 'Pillow is required'):
            runtime.dependencies(self.root)

    def test_missing_godot_is_actionable(self):
        with patch.dict(os.environ, {'GODOT_BIN': ''}), patch.object(runtime.shutil, 'which', return_value=None), patch.object(Path, 'is_file', return_value=False):
            with self.assertRaisesRegex(ValueError, 'GODOT_BIN'):
                runtime.dependencies(self.root)

    def test_unsupported_godot_versions(self):
        for version in ['3.6.stable', '4.3.stable', '5.0.stable', 'garbage']:
            with self.subTest(version=version), patch.object(runtime.subprocess, 'check_output', return_value=version):
                with self.assertRaisesRegex(ValueError, 'Godot 4.4'):
                    runtime.dependencies(self.root)

    def test_missing_originals_fails_without_touching_profile(self):
        with patch.object(runtime.subprocess, 'check_output', return_value='4.7.2.stable'):
            with self.assertRaisesRegex(ValueError, 'source kit is not playable'):
                runtime.dependencies(self.root)
        self.assertEqual(list(self.profile.iterdir()), [self.profile / 'campaign.keep'])
        self.assertEqual((self.profile / 'campaign.keep').read_bytes(), b'preserve campaign')

    def test_successful_preflight_does_not_create_save_or_log_dirs(self):
        self.private_fixture()
        with patch.object(runtime.subprocess, 'check_output', return_value='4.7.2.stable'):
            report = runtime.dependencies(self.root)
        self.assertEqual(report['data_home'], str(self.profile.resolve()))
        self.assertFalse((self.profile / 'saves').exists())
        self.assertFalse((self.profile / 'logs').exists())
        package_build.verify_private_inputs.assert_called_once_with(self.root)

    def test_check_cli_does_not_launch_or_write_profile(self):
        with patch.object(runtime, 'dependencies', return_value={'data_home': str(self.profile)}), patch.object(sys, 'argv', ['runtime', '--check']), patch.object(runtime.os, 'execve') as execute, patch.object(runtime.subprocess, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            runtime.main()
        execute.assert_not_called(); run.assert_not_called()
        self.assertEqual(list(self.profile.iterdir()), [self.profile / 'campaign.keep'])

    def test_managed_paths_cannot_be_overridden(self):
        for option in ['--saves=/tmp/other', '--output', '--trace', '--reference']:
            with self.subTest(option=option), patch.object(runtime, 'dependencies', return_value={'data_home': str(self.profile)}), patch.object(sys, 'argv', ['runtime', option]), patch.object(runtime.os, 'execve') as execute, contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                runtime.main()
            self.assertEqual(error.exception.code, 1); execute.assert_not_called()
        self.assertFalse((self.profile / 'saves').exists())

    def test_upgrade_and_launch_preserve_existing_profile(self):
        report = {'data_home': str(self.profile), 'godot_bin': '/fake/godot'}
        for kit in [self.root, self.root.with_name('upgraded-kit')]:
            with patch.object(runtime, 'ROOT', kit), patch.object(runtime, 'dependencies', return_value=report), patch.object(sys, 'argv', ['runtime', '--fullscreen']), patch.object(runtime.subprocess, 'run') as run, patch.object(runtime.os, 'execve') as execute:
                runtime.main()
                self.assertEqual(run.call_count, 2)
                args = execute.call_args.args[1]
                self.assertEqual(args[0], str(kit / 'PC Bridge.command'))
                self.assertIn(str(self.profile / 'saves'), args)
                self.assertIn('--fullscreen', args)
            self.assertEqual((self.profile / 'campaign.keep').read_bytes(), b'preserve campaign')

    def test_import_bad_hash_or_incomplete_manifest_leaves_no_destination(self):
        source = self.root / 'originals'; source.mkdir()
        (source / 'SIM.EXE').write_bytes(b'synthetic')
        records = [{'name': 'SIM.EXE', 'sha256': '0' * 64}]
        destination = self.root / 'new-kit'
        with self.assertRaisesRegex(ValueError, 'Unsupported'):
            setup.prepare(source, destination, records)
        self.assertFalse(destination.exists())
        records[0]['sha256'] = hashlib.sha256(b'synthetic').hexdigest()
        with self.assertRaisesRegex(ValueError, 'ZIP reconstruction'):
            setup.prepare(source, destination, records)
        self.assertFalse(destination.exists())

    def test_import_duplicate_traversal_or_symlink_preserves_destination(self):
        source = self.root / 'originals'; source.mkdir()
        (source / 'SIM.EXE').write_bytes(b'synthetic')
        row = {'name': 'SIM.EXE', 'sha256': hashlib.sha256(b'synthetic').hexdigest()}
        destination = self.root / 'new-kit'
        for records in [[row, row], [dict(row, name='../escape')], [dict(row, name='a\\b')]]:
            with self.assertRaisesRegex(ValueError, 'Unsafe'):
                setup.prepare(source, destination, records)
            self.assertFalse(destination.exists())
        destination.mkdir()
        (destination / 'GAME').symlink_to(self.root / 'missing')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            setup.prepare(source, destination, [row])
        self.assertTrue((destination / 'GAME').is_symlink())


if __name__ == '__main__':
    unittest.main()
