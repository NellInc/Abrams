"""Regression proof for failed local export/asset replacement, no real game inputs."""
import ast
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).parent))
import build_remaster as build
import build_remaster_assets as assets
import package_site as package

class GeneratedBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.out = self.root / 'generated'; self.out.mkdir()
        for name, raw in {'remaster-assets.json': b'old manifest', 'remaster-assets-00.zip': b'old part',
                          'remaster-assets-01.zip': b'obsolete', 'core.wasm': b'foreign'}.items():
            (self.out / name).write_bytes(raw)
        self.before = self.contents()
        self.expected = assets.output_identity(self.out)
        self.input = self.root / 'candidate'; self.input.write_bytes(b'new manifest')
        self.inputs = {'remaster-assets.json': self.input, 'genesis-input.json': self.input}
    def contents(self):
        return {p.relative_to(self.out).as_posix(): p.read_bytes() for p in self.out.rglob('*') if p.is_file() and p.name != '.abrams-build.lock'}
    def unchanged(self):
        self.assertEqual(self.before, self.contents())
        self.assertEqual(list(self.out.glob('.abrams-promotion-*')), [])
    def install(self):
        return assets.install_outputs(self.inputs, self.out, self.expected)
    def test_success_replaces_managed_only_and_removes_stale_parts(self):
        rows = self.install()
        self.assertEqual(self.contents(), {'remaster-assets.json': b'new manifest', 'genesis-input.json': b'new manifest', 'core.wasm': b'foreign'})
        self.assertEqual(rows['genesis-input.json']['bytes'], 12)
    def test_copy_failure_preserves_old_build(self):
        with patch.object(assets.shutil, 'copy2', side_effect=OSError('disk full')):
            with self.assertRaisesRegex(OSError, 'disk full'): self.install()
        self.unchanged()
    def test_partial_install_failure_restores_parts_and_absent_file(self):
        original = Path.replace
        def replace(path, dest):
            if 'candidate' in path.parts and path.name == 'genesis-input.json': raise OSError('rename failed')
            return original(path, dest)
        with patch.object(Path, 'replace', replace), self.assertRaisesRegex(OSError, 'rename failed'): self.install()
        self.unchanged()
    def test_failed_recovery_retains_backup_and_journal(self):
        original = Path.replace
        def replace(path, dest):
            if ('candidate' in path.parts and path.name == 'genesis-input.json') or ('previous' in path.parts and path.name == 'remaster-assets.json'): raise OSError('destination blocked')
            return original(path, dest)
        with patch.object(Path, 'replace', replace), self.assertRaisesRegex(RuntimeError, 'recovery retained at'): self.install()
        saved = list(self.out.glob('.abrams-promotion-*/previous/remaster-assets.json'))
        self.assertEqual(len(saved), 1); self.assertEqual(saved[0].read_bytes(), b'old manifest')
        self.assertTrue((saved[0].parent.parent / 'recovery.json').is_file())
        self.assertEqual((self.out / 'core.wasm').read_bytes(), b'foreign')
    def test_target_edit_and_new_managed_part_are_refused(self):
        for name in ('remaster-assets.json', 'remaster-assets-09.zip'):
            with self.subTest(name=name):
                path = self.out / name; old = path.read_bytes() if path.exists() else None; path.write_bytes(b'concurrent')
                with self.assertRaisesRegex(SystemExit, 'target changed'): self.install()
                self.assertEqual(path.read_bytes(), b'concurrent')
                if old is None: path.unlink()
                else: path.write_bytes(old)
                self.expected = assets.output_identity(self.out)
    def test_unsafe_output_and_linked_target_refused(self):
        for name in ('../secret', 'core.wasm', 'godot/index.html', 'remaster-assets-100.zip'):
            with self.subTest(name=name), self.assertRaisesRegex(SystemExit, 'Unsafe'): assets.install_outputs({name: self.input}, self.out, self.expected)
        (self.out / 'godot').symlink_to(self.root)
        with self.assertRaisesRegex(SystemExit, 'linked'): assets.output_identity(self.out, True)
        (self.out / 'godot').unlink(); self.unchanged()
    def test_cooperative_lock_excludes_writer_and_packager(self):
        with assets.generated_lock(self.out):
            for exclusive in (True, False):
                with self.subTest(exclusive=exclusive), self.assertRaisesRegex(SystemExit, 'in use'):
                    with assets.generated_lock(self.out, exclusive): pass
        with assets.generated_lock(self.out, False):
            with assets.generated_lock(self.out, False): pass
    def test_site_packager_observes_the_generated_writer_lock(self):
        generated = self.root / '.generated'
        with assets.generated_lock(generated), patch.object(package, 'SOURCE', self.root):
            with self.assertRaisesRegex(SystemExit, 'in use'): package.main()

    def test_candidate_change_during_copy_refused(self):
        original = assets.shutil.copy2
        def copy(src, dst):
            result = original(src, dst); self.input.write_bytes(b'changed'); return result
        with patch.object(assets.shutil, 'copy2', copy), self.assertRaisesRegex(SystemExit, 'candidate changed'): self.install()
        self.unchanged()
    def setup_assets(self):
        control = self.root / 'tools/package/allowlist.json'; control.parent.mkdir(parents=True); control.write_text('{}')
        paths = [self.root / 'local-art/a.png', self.root / 'local-art/b.png']
        paths[0].parent.mkdir()
        for path in paths: path.write_bytes(b'full resolution authored payload')
        return paths
    def test_asset_catalog_matches_stored_zip_entries(self):
        paths = self.setup_assets(); target = self.root / 'private-assets'
        with patch.object(assets, 'ROOT', self.root), patch.object(assets, 'selected', return_value=iter(paths)) as select:
            select.side_effect = lambda: iter(paths)
            inputs = assets.stage_assets(target)
        catalog = json.loads(inputs['remaster-assets.json'].read_text())
        self.assertEqual(len(catalog['files']), 2)
        for part in catalog['parts']:
            archive = inputs[part['name']]; self.assertEqual(assets.fingerprint(archive)[-1], part['sha256']); self.assertEqual(archive.stat().st_size, part['bytes'])
            with zipfile.ZipFile(archive) as z:
                for info in z.infolist():
                    self.assertEqual(info.compress_type, zipfile.ZIP_STORED)
                    self.assertEqual(z.read(info), (self.root / info.filename).read_bytes())
    def test_asset_read_failure_preserves_normal_outputs_and_closes_archive(self):
        paths = self.setup_assets(); original = Path.read_bytes
        def read(path):
            if path == paths[1]: raise OSError('asset unavailable')
            return original(path)
        with patch.object(assets, 'ROOT', self.root), patch.object(assets, 'OUT', self.out), patch.object(assets, 'selected', side_effect=lambda: iter(paths)), patch.object(Path, 'read_bytes', read):
            with self.assertRaisesRegex(OSError, 'asset unavailable'): assets.main()
        self.unchanged(); self.assertEqual(list(self.out.glob('.abrams-assets-*')), [])
    def test_asset_change_and_inventory_drift_refused(self):
        paths = self.setup_assets(); original = Path.read_bytes
        def read(path):
            result = original(path)
            if path == paths[0]: path.write_bytes(b'changed source')
            return result
        with patch.object(assets, 'ROOT', self.root), patch.object(assets, 'selected', side_effect=lambda: iter(paths)), patch.object(Path, 'read_bytes', read):
            with self.assertRaisesRegex(SystemExit, 'changed during building'): assets.stage_assets(self.root / 'changed-assets')
        with patch.object(assets, 'ROOT', self.root), patch.object(assets, 'selected', side_effect=[iter(paths), iter(paths[:1])]):
            with self.assertRaisesRegex(SystemExit, 'inventory changed'): assets.stage_assets(self.root / 'inventory-drift')
        self.unchanged()
    def test_part_bound_and_empty_inventory_refused(self):
        paths = self.setup_assets()
        with patch.object(assets, 'ROOT', self.root), patch.object(assets, 'selected', side_effect=lambda: iter(paths)), patch.object(assets, 'MAX_PART_BYTES', 150):
            with self.assertRaisesRegex(SystemExit, 'exceeds'): assets.stage_assets(self.root / 'oversized')
        with patch.object(assets, 'ROOT', self.root), patch.object(assets, 'selected', side_effect=lambda: iter([])):
            with self.assertRaisesRegex(SystemExit, 'empty'): assets.stage_assets(self.root / 'empty')
        self.unchanged()
    def setup_project(self):
        source = self.root / 'godot'; source.mkdir()
        (source / 'project.godot').write_text('run/main_scene="res://scenes/main.tscn"\n')
        (source / 'export_presets.cfg').write_text('template="../.runtime/godot-web-templates/web_release.zip"')
        for name in ('scripts', 'assets', 'data', 'scenes'): (source / name).mkdir()
        (source / 'scripts/pc_bridge_viewer.gd').write_text('extends SceneTree\n')
        tree = ast.parse(Path(build.__file__).read_text())
        fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'patch_audio_shutdown')
        replacements = ast.literal_eval(next(n for n in fn.body if isinstance(n, ast.Assign)).value)
        self.original_loader = '\n'.join(old for old, new in replacements)
    def export(self, *, diagnostic='', missing=None, drift=False, setup=True, after_export=None):
        if setup: self.setup_project()
        out = self.root / 'private-export'
        def run(*args, **kwargs):
            for name in assets.GODOT_FILES:
                if name != missing: (out / name).write_text(self.original_loader if name == 'index.js' and not drift else 'runtime')
            (out / 'index.html').write_text('not eligible')
            if after_export: after_export()
            return subprocess.CompletedProcess(args, 0, diagnostic, '')
        with patch.object(build, 'ROOT', self.root), patch.object(build.subprocess, 'run', run):
            return build.stage_export(self.root / 'private-project', out)
    def test_clean_export_has_only_six_files_and_correct_play_entry(self):
        inputs = self.export()
        self.assertEqual(set(inputs), {'godot/' + n for n in assets.GODOT_FILES})
        self.assertIn('run/main_loop_type="AbramsWebPlayLoop"', (self.root / 'private-project/project.godot').read_text())
        self.assertTrue((self.root / 'private-project/scripts/pc_bridge_viewer.gd').read_text().startswith('class_name AbramsWebPlayLoop\n'))
        receipt = json.loads((self.root / 'export-sources.json').read_text())
        self.assertEqual(receipt, {'schema': 1, 'files': build.presentation_snapshot(self.root / 'godot')})
        self.assertNotEqual(inputs['godot/index.js'].read_text(), self.original_loader); self.unchanged()

    def test_corrupt_presentation_copy_refused_before_export(self):
        copytree = build.shutil.copytree
        def corrupt(source, destination, **kwargs):
            result = copytree(source, destination, **kwargs)
            if Path(source).name == 'scripts':
                (Path(destination) / 'pc_bridge_viewer.gd').write_text('corrupt copy')
            return result
        with patch.object(build.shutil, 'copytree', corrupt):
            with self.assertRaisesRegex(SystemExit, 'Staged presentation differs'):
                self.export()
        self.assertFalse((self.root / 'export.log').exists()); self.unchanged()

    def test_presentation_edits_additions_removals_and_config_drift_refused(self):
        self.setup_project(); source = self.root / 'godot'
        viewer = source / 'scripts/pc_bridge_viewer.gd'
        copytree = build.shutil.copytree
        mutations = [lambda: viewer.write_text('changed source'),
                     lambda: (source / 'scripts/new.gd').write_text('new source'),
                     lambda: viewer.unlink(),
                     lambda: (source / 'export_presets.cfg').write_text('changed preset'),
                     lambda: (source / 'project.godot').write_text('changed entry')]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                def copy_then_edit(src, dest, **kwargs):
                    result = copytree(src, dest, **kwargs)
                    if Path(src).name == 'scripts': mutate()
                    return result
                with patch.object(build, 'ROOT', self.root), patch.object(build.shutil, 'copytree', copy_then_edit), patch.object(build.subprocess, 'run') as run:
                    with self.assertRaisesRegex(SystemExit, 'source changed during building'):
                        build.stage_export(self.root / f'candidate-{index}', self.root / f'export-{index}')
                    run.assert_not_called()
                viewer.write_text('extends SceneTree\n')
                (source / 'scripts/new.gd').unlink(missing_ok=True)
                (source / 'export_presets.cfg').write_text('template="../.runtime/godot-web-templates/web_release.zip"')
                (source / 'project.godot').write_text('run/main_scene="res://scenes/main.tscn"\n')
                self.unchanged()

    def test_edit_during_clean_export_refuses_candidate(self):
        def edit(): (self.root / 'godot/scripts/pc_bridge_viewer.gd').write_text('late source')
        with self.assertRaisesRegex(SystemExit, 'source changed during building'):
            self.export(after_export=edit)
        self.assertTrue((self.root / 'export.log').is_file()); self.unchanged()

    def test_ignored_cache_activity_does_not_invalidate_export(self):
        self.setup_project(); source = self.root / 'godot'
        def cache_activity():
            (source / 'scripts/__pycache__').mkdir(exist_ok=True)
            (source / 'scripts/__pycache__/nested.gd').write_text('ignored')
            (source / 'scripts/ignored.pyc').write_text('ignored')
            (source / 'assets/.DS_Store').write_text('ignored')
        cache_activity()
        inputs = self.export(setup=False, after_export=cache_activity)
        self.assertEqual(len(inputs), 6)
        self.assertFalse((self.root / 'private-project/scripts/__pycache__').exists())
        self.assertFalse((self.root / 'private-project/scripts/ignored.pyc').exists())
        self.assertFalse((self.root / 'private-project/assets/.DS_Store').exists())
        self.unchanged()

    def test_linked_selected_file_directory_and_control_input_refused(self):
        self.setup_project(); source = self.root / 'godot'
        external = self.root / 'external'; external.mkdir()
        (external / 'source.gd').write_text('external')
        for index, name in enumerate(['scripts/linked.gd', 'assets/linked-dir', 'export_presets.cfg']):
            with self.subTest(name=name):
                path = source / name; old = path.read_bytes() if path.is_file() else None
                if old is not None: path.unlink()
                path.symlink_to(external if name.endswith('dir') else external / 'source.gd')
                with patch.object(build, 'ROOT', self.root), patch.object(build.subprocess, 'run') as run:
                    with self.assertRaisesRegex(SystemExit, '[Ll]inked'):
                        build.stage_export(self.root / f'link-{index}', self.root / f'link-export-{index}')
                    run.assert_not_called()
                path.unlink()
                if old is not None: path.write_bytes(old)
        self.assertEqual((external / 'source.gd').read_text(), 'external'); self.unchanged()

    def test_combined_build_late_source_edit_prevents_promotion(self):
        self.setup_project(); runtime = self.root / '.runtime'; runtime.mkdir()
        editor = runtime / 'Godot'; editor.write_text('editor')
        def exported(stage, web):
            snapshot = build.presentation_snapshot(self.root / 'godot')
            (stage.parent / 'export-sources.json').write_text(json.dumps({'schema': 1, 'files': snapshot}))
            return {'godot/index.js': self.input}
        def staged(out):
            (self.root / 'godot/scripts/pc_bridge_viewer.gd').write_text('edit during asset staging')
            return self.inputs
        with patch.object(build, 'ROOT', self.root), patch.object(build, 'GODOT', editor), patch.object(build, 'WEB', self.out / 'godot'), patch.object(build, 'stage_export', exported), patch.object(build, 'stage_assets', staged), patch.object(build, 'install_outputs') as install:
            with self.assertRaisesRegex(SystemExit, 'source changed during building'): build.main()
            install.assert_not_called()
        self.unchanged(); self.assertEqual(list(runtime.glob('abrams-web-*')), [])
    def test_zero_exit_script_error_refused(self):
        with self.assertRaisesRegex(SystemExit, 'SCRIPT ERROR'): self.export(diagnostic='SCRIPT ERROR: Parse Error: bad type')
        self.unchanged()
    def test_missing_export_file_refused(self):
        with self.assertRaisesRegex(SystemExit, 'Incomplete'): self.export(missing='index.pck')
        self.unchanged()
    def test_template_drift_refused(self):
        with self.assertRaisesRegex(ValueError, 'loader changed'): self.export(drift=True)
        self.unchanged()
    def test_combined_build_asset_failure_never_promotes_export(self):
        runtime = self.root / '.runtime'; runtime.mkdir(); editor = runtime / 'Godot'; editor.write_text('editor')
        with patch.object(build, 'ROOT', self.root), patch.object(build, 'GODOT', editor), patch.object(build, 'WEB', self.out / 'godot'), patch.object(build, 'stage_export', return_value={'godot/index.js': self.input}), patch.object(build, 'stage_assets', side_effect=OSError('assets failed')):
            with self.assertRaisesRegex(OSError, 'assets failed'): build.main()
        self.unchanged(); self.assertEqual(list(runtime.glob('abrams-web-*')), [])

if __name__ == '__main__': unittest.main()
