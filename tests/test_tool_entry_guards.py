"""Builders, captures and oracles: script-mode imports and miscased source refusals.

`python3 tools/<name>.py` puts tools/, not the repo, on sys.path; every `tools.`
import must still resolve. Each output guard must refuse case aliases of the
original trees ('game', 'Genesis') before any read or write.
"""
import ast
import contextlib
import io
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ['build_pc_frontend_catalog', 'build_pc_newspaper_catalog', 'build_pc_wilson_completion', 'capture_pc_intro',
           'capture_pc_session', 'extract_genesis_information_inventory', 'extract_pc_portraits', 'inspect_shapes',
           'package_runtime', 'pc_camera_oracle', 'pc_instrument_status_oracle', 'pc_reticle_target_oracle',
           'pc_warning_voice_oracle', 'standalone/portable_build', 'verify_pc_endurance']
# Extra required arguments; none is read before the output guard.
GUARDED = {'build_pc_frontend_catalog': [], 'build_pc_newspaper_catalog': [], 'build_pc_wilson_completion': [],
           'capture_pc_intro': ['--mode', 'trace'], 'capture_pc_session': ['--mode', 'trace'],
           'extract_genesis_information_inventory': [], 'extract_pc_portraits': ['--capture', 'x', '--trace', 'x'],
           'inspect_shapes': ['--source', str(ROOT / 'GAME/SHAPE.TBL')], 'pc_camera_oracle': ['--captures', 'x'],
           'pc_instrument_status_oracle': ['--capture', 'x'], 'pc_reticle_target_oracle': ['--capture', 'x'],
           'pc_warning_voice_oracle': [], 'verify_pc_endurance': []}
OPTIONAL = ('unicorn', 'PIL')


def missing_optional(error):
    # A script-mode fallback can mask the real cause (PIL) behind its own name.
    while error is not None:
        if isinstance(error, ModuleNotFoundError) and error.name in OPTIONAL:
            return error.name
        error = error.__cause__ or error.__context__


@contextlib.contextmanager
def no_writes():
    wrote = AssertionError('wrote before the output guard')
    with mock.patch.object(Path, 'mkdir', side_effect=wrote), mock.patch.object(Path, 'write_text', side_effect=wrote), \
            mock.patch.object(Path, 'write_bytes', side_effect=wrote), mock.patch('os.mkdir', side_effect=wrote):
        yield


def run_main(name, argv):
    stderr = io.StringIO()
    with mock.patch.object(sys, 'argv', [name, *argv]), no_writes(), contextlib.redirect_stderr(stderr):
        try:
            runpy.run_path(str(ROOT / 'tools' / f'{name}.py'), run_name='__main__')
        except SystemExit as exit:
            return exit.code, stderr.getvalue()
    return 0, stderr.getvalue()


class ScriptModeImportTests(unittest.TestCase):
    def test_scripts_import_from_a_foreign_cwd(self):
        # Keep extra site-packages on PYTHONPATH, but never the repo root itself.
        paths = [p for p in os.environ.get('PYTHONPATH', '').split(os.pathsep) if p and Path(p).resolve() != ROOT]
        env = os.environ | {'PYTHONPATH': os.pathsep.join(paths), 'PYTHONDONTWRITEBYTECODE': '1'}
        with tempfile.TemporaryDirectory() as cwd:
            for name in SCRIPTS:
                path = ROOT / 'tools' / f'{name}.py'
                with self.subTest(script=name):
                    code = f'import runpy,sys; sys.path[0]={str(path.parent)!r}; runpy.run_path({str(path)!r}, run_name="probe")'
                    done = subprocess.run([sys.executable, '-c', code], cwd=cwd, env=env, capture_output=True, text=True, timeout=60)
                    missing = [m for m in OPTIONAL if f"No module named '{m}'" in done.stderr]
                    if done.returncode and missing:
                        self.skipTest(f'{missing[0]} unavailable in this interpreter')
                    self.assertEqual(done.returncode, 0, done.stderr[-600:])

    def test_tools_imports_are_script_safe(self):
        # Lazy imports run only on some paths; each must sit in a ModuleNotFoundError
        # fallback unless a module-level sys.path.insert ran before it.
        for name in SCRIPTS:
            tree = ast.parse((ROOT / 'tools' / f'{name}.py').read_text())
            inserts = [s.end_lineno for s in tree.body for c in ast.walk(s) if isinstance(c, ast.Call)
                       and ast.unparse(c.func) == 'sys.path.insert']
            after = min(inserts, default=float('inf'))
            guarded = {id(node) for t in ast.walk(tree) if isinstance(t, ast.Try)
                       and any('ModuleNotFoundError' in ast.unparse(h.type) for h in t.handlers if h.type)
                       for statement in t.body for node in ast.walk(statement)}
            for node in ast.walk(tree):
                if isinstance(node, ast.ImportFrom) and (node.module or '').split('.')[0] == 'tools' and node.lineno <= after:
                    with self.subTest(script=name, line=node.lineno):
                        self.assertIn(id(node), guarded)


class MiscasedOutputTests(unittest.TestCase):
    def test_original_tree_aliases_are_refused_before_writing(self):
        for name, extra in GUARDED.items():
            for alias in ('game', 'Genesis'):
                output = ROOT / alias / 'never-created-entry-guard' / 'out.json'
                with self.subTest(tool=name, alias=alias):
                    try:
                        code, stderr = run_main(name, [*extra, '--output', str(output)])
                    except ModuleNotFoundError as error:
                        if not missing_optional(error):
                            raise
                        self.skipTest(f'{missing_optional(error)} unavailable in this interpreter')
                    if name == 'pc_camera_oracle' and 'pinned Unicorn' in stderr:
                        self.skipTest('pinned Unicorn unavailable')
                    self.assertEqual(code, 2, stderr)
                    self.assertRegex(stderr, 'error: output must (be|remain) outside')
                    self.assertFalse(output.parent.exists())

    def test_wilson_extract_destination_is_guarded(self):
        output = ROOT / 'game' / 'never-created-entry-guard'
        try:
            code, stderr = run_main('build_pc_wilson_completion', ['--extract', str(output)])
        except ModuleNotFoundError as error:
            if not missing_optional(error):
                raise
            self.skipTest(f'{missing_optional(error)} unavailable in this interpreter')
        self.assertEqual((code, 'must be outside' in stderr), (2, True), stderr)

    def test_player_data_refuses_miscased_kit_path(self):
        from tools.package_runtime import data_home
        with tempfile.TemporaryDirectory() as tmp:
            kit = Path(tmp).resolve() / 'Kit'
            kit.mkdir()
            if not (Path(tmp) / 'kit').exists():
                self.skipTest('temporary filesystem is case-sensitive')
            for invalid in [Path(tmp) / 'kit/profile', Path(tmp) / 'KIT', kit / 'saves']:
                with self.subTest(path=invalid), mock.patch.dict(os.environ, {'ABRAMS_DATA_HOME': str(invalid)}), \
                        self.assertRaisesRegex(ValueError, 'outside the kit'):
                    data_home(kit)
            with mock.patch.dict(os.environ, {'ABRAMS_DATA_HOME': str(Path(tmp) / 'kit-profile')}):
                self.assertEqual(data_home(kit), Path(tmp).resolve() / 'kit-profile')

    def test_inspect_shapes_refuses_miscased_custom_source_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp).resolve() / 'Shapes' / 'SHAPE.TBL'
            source.parent.mkdir()
            source.write_bytes(b'')
            code, stderr = run_main('inspect_shapes', ['--source', str(source), '--output', str(source.parent.parent / 'shapes/x.json')])
            self.assertEqual(code, 2, stderr)
            self.assertIn('outside source directory', stderr)


if __name__ == '__main__':
    unittest.main()
