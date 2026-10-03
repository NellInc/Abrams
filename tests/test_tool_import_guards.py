"""Audit, capture, extraction and oracle tools: script-mode imports and miscased original-source refusals.

`python3 tools/<name>.py` puts the script's own directory, not the repo, on
sys.path; every `tools.` import must still resolve. Each output guard must refuse
case aliases of the protected tree ('game', 'Genesis') before any write.
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
SCRIPTS = ['audit_pc_portrait_coverage', 'build_pc_information_completion', 'build_pc_splash_aftermath',
           'capture_pc_crew_footers', 'capture_pc_modifiers', 'extract_genesis_aftermath', 'extract_genesis_newspapers',
           'inspect_pc_recognition', 'modern_assets/round_span_probe', 'pc_bearing_oracle', 'pc_instrument_damage_oracle',
           'pc_radio_voice_oracle', 'pc_vehicle_catalog', 'reference_inventory', 'standalone/sign_macos']
# Extra required arguments; none is read before the output guard.
GUARDED = {'capture_pc_modifiers': ['--mode', 'trace'], 'extract_genesis_aftermath': [], 'extract_genesis_newspapers': [],
           'pc_instrument_damage_oracle': ['--capture', 'x'], 'pc_radio_voice_oracle': [], 'pc_vehicle_catalog': ['--capture', 'x']}
OPTIONAL = ('unicorn', 'PIL', 'fontTools')


def missing_optional(error):
    # A try/except fallback re-raises for the sibling name; the cause is in the context.
    while error is not None:
        if isinstance(error, ModuleNotFoundError) and error.name in OPTIONAL:
            return error.name
        error = error.__context__


@contextlib.contextmanager
def no_writes():
    wrote = AssertionError('touched a file before the output guard')
    with mock.patch.object(Path, 'mkdir', side_effect=wrote), mock.patch.object(Path, 'write_text', side_effect=wrote), \
            mock.patch.object(Path, 'write_bytes', side_effect=wrote), mock.patch.object(Path, 'open', side_effect=wrote), \
            mock.patch('os.mkdir', side_effect=wrote):
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
        env = {k: v for k, v in os.environ.items() if k != 'PYTHONPATH'} | {'PYTHONDONTWRITEBYTECODE': '1'}
        with tempfile.TemporaryDirectory() as cwd:
            for name in SCRIPTS:
                path = ROOT / 'tools' / f'{name}.py'
                with self.subTest(script=name):
                    # run_name keeps __main__ bodies (some write fixed outputs) from running.
                    code = f'import runpy,sys; sys.path[0]={str(path.parent)!r}; runpy.run_path({str(path)!r}, run_name="probe")'
                    done = subprocess.run([sys.executable, '-c', code], cwd=cwd, env=env, capture_output=True, text=True, timeout=60)
                    final = (done.stderr.strip().splitlines() or [''])[-1]
                    self.assertNotIn("No module named 'tools", final)
                    missing = [m for m in OPTIONAL if f"No module named '{m}'" in final]
                    if done.returncode and missing:
                        self.skipTest(f'{missing[0]} unavailable in this interpreter')
                    self.assertEqual(done.returncode, 0, done.stderr[-600:])

    def test_tools_imports_are_script_safe(self):
        # Lazy imports run only on some paths; each must sit in a ModuleNotFoundError
        # fallback unless the file puts the repo root on sys.path first.
        for name in SCRIPTS:
            tree = ast.parse((ROOT / 'tools' / f'{name}.py').read_text())
            inserts = [n.lineno for n in ast.walk(tree) if isinstance(n, ast.Call) and ast.unparse(n.func) == 'sys.path.insert']
            guarded = {id(node) for t in ast.walk(tree) if isinstance(t, ast.Try)
                       and any('ModuleNotFoundError' in ast.unparse(h.type) for h in t.handlers if h.type)
                       for statement in t.body for node in ast.walk(statement)}
            for node in ast.walk(tree):
                if isinstance(node, ast.ImportFrom) and (node.module or '').split('.')[0] == 'tools':
                    with self.subTest(script=name, line=node.lineno):
                        self.assertTrue(id(node) in guarded or (inserts and min(inserts) < node.lineno))


class MiscasedOutputTests(unittest.TestCase):
    def test_original_tree_aliases_are_refused_before_writing(self):
        for name, extra in GUARDED.items():
            for alias in ('game', 'Genesis'):
                output = ROOT / alias / 'never-created-sweep1-guard' / 'out.json'
                with self.subTest(tool=name, alias=alias):
                    try:
                        code, stderr = run_main(name, [*extra, '--output', str(output)])
                    except ModuleNotFoundError as error:
                        if not missing_optional(error):
                            raise
                        self.skipTest(f'{missing_optional(error)} unavailable in this interpreter')
                    self.assertEqual(code, 2, stderr)
                    self.assertIn('must ', stderr)
                    self.assertIn('outside original', stderr)
                    self.assertFalse(output.parent.exists())

    def test_bearing_oracle_refuses_miscased_root(self):
        try:
            import unicorn  # noqa: F401
        except ModuleNotFoundError:
            self.skipTest('unicorn unavailable in this interpreter')
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp).resolve() / 'Ref'
            source.mkdir()
            for root, out in ((source, source.parent / 'ref/new/x.json'), (ROOT / 'GAME', ROOT / 'game/never-created-sweep1-guard/x.json')):
                with self.subTest(out=out):
                    code, stderr = run_main('pc_bearing_oracle', ['--root', str(root), '--out', str(out)])
                    self.assertEqual(code, 2, stderr)
                    self.assertIn('output must be outside original reference directory', stderr)
                    self.assertFalse(out.parent.exists())

    def test_reference_inventory_refuses_miscased_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp).resolve() / 'Ref'
            source.mkdir()
            (source / 'a.bin').write_bytes(b'a')
            manifest = source.parent / 'ref' / 'm.json'
            code, stderr = run_main('reference_inventory', ['--root', str(source), '--manifest', str(manifest)])
            self.assertEqual(code, 2, stderr)
            self.assertIn('manifest must be outside reference directory', stderr)
            self.assertEqual(sorted(p.name for p in source.iterdir()), ['a.bin'])
            # A neighbour is not over-blocked.
            neighbour = source.parent / 'Ref-reports' / 'm.json'
            with mock.patch.object(sys, 'argv', ['reference_inventory', '--root', str(source), '--manifest', str(neighbour)]), \
                    contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as caught:
                runpy.run_path(str(ROOT / 'tools/reference_inventory.py'), run_name='__main__')
            self.assertEqual(caught.exception.code, 0)
            self.assertTrue(neighbour.is_file())


if __name__ == '__main__':
    unittest.main()
