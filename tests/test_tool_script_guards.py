"""Owned tools run as `python tools/<name>.py` from a foreign cwd, and their
original-source output guards reject miscased aliases of GAME/GENESIS.

Guard cases pass an existing source directory (or /nonexistent inputs) so a
regressed guard fails on mkdir(exist_ok=False) or a missing read, never writes.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
VENV = ROOT / '.runtime/pc-analysis-venv/bin/python'
# tool, third-party modules it needs at import, extra args, original message
ARGPARSE = [
    ('build_pc_outline_fonts.py', ('fontTools', 'PIL'), [], 'output must be outside source directories'),
    ('extract_genesis_models.py', (), ['--rom', '/nonexistent', '--capture', '/nonexistent'], 'output must be outside original source directories'),
    ('capture_pc_menu_text.py', ('PIL',), ['--mode', 'trace'], 'output must be outside original sources'),
    ('capture_pc_views.py', ('PIL',), [], 'output must be outside original GAME'),
    ('extract_pc_ui.py', ('PIL',), ['--capture', '/nonexistent', '--trace', '/nonexistent'], 'output must be outside GAME'),
    ('pc_gauge_oracle.py', ('unicorn',), ['--capture', '/nonexistent'], 'output must be outside original reference directories'),
    ('pc_orientation_oracle.py', ('unicorn',), ['--capture', '/nonexistent'], 'output must be outside original references'),
    ('pc_strut_oracle.py', ('unicorn',), ['--capture', '/nonexistent'], 'output must stay outside originals'),
    ('pc_world_oracle.py', ('unicorn',), ['--capture', '/nonexistent'], 'output must be outside original directory'),
    ('modern_assets/opaque_probe.py', ('unicorn',), None, None),
]
# No argparse: importing in script mode must not run build() (it writes).
NO_ARGPARSE = [('build_pc_graphics_catalog.py', ('PIL',)), ('build_reference_maps.py', ()),
               ('verify_pc_strut_coverage.py', ('PIL',))]
_cache = {}


def interpreter(modules):
    for py in (sys.executable, str(VENV)):
        if not Path(py).exists(): continue
        key = (py, modules)
        if key not in _cache:
            _cache[key] = subprocess.run([py, '-c', ''.join(f'import {m}\n' for m in modules)], capture_output=True).returncode == 0
        if _cache[key]: return py
    return None


def alias(name):
    """An existing miscased spelling of ROOT/name, or None on case-sensitive filesystems."""
    real, other = ROOT / name, ROOT / name.lower()
    return other if real.is_dir() and other.exists() and os.path.samefile(real, other) else None


class ToolScriptGuardTests(unittest.TestCase):
    def run_tool(self, py, *args):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1'); env.pop('PYTHONPATH', None)
        with tempfile.TemporaryDirectory() as cwd:
            return subprocess.run([py, *map(str, args)], cwd=cwd, env=env, capture_output=True, text=True, timeout=120)

    def test_argparse_tools_run_as_scripts(self):
        for tool, modules, _, _ in ARGPARSE:
            with self.subTest(tool=tool):
                py = interpreter(modules)
                if not py: self.skipTest(f'{modules} unavailable'); continue
                done = self.run_tool(py, ROOT / 'tools' / tool, '--help')
                self.assertEqual(done.returncode, 0, done.stderr[-400:])
                self.assertIn('--output', done.stdout)

    def test_guards_reject_miscased_source_aliases(self):
        for name in ('GAME', 'GENESIS'):
            target = alias(name)
            for tool, modules, extra, message in ARGPARSE:
                if extra is None: continue
                if name == 'GENESIS' and tool == 'pc_world_oracle.py': continue  # guards its --root (GAME)
                with self.subTest(tool=tool, source=name):
                    py = interpreter(modules)
                    if not target or not py: self.skipTest('needs case-insensitive FS, local sources and deps'); continue
                    done = self.run_tool(py, ROOT / 'tools' / tool, *extra, '--output', target)
                    self.assertEqual(done.returncode, 2, done.stderr[-400:])
                    self.assertIn(message, done.stderr)

    def test_world_oracle_guards_custom_root_alias(self):
        py, target = interpreter(('unicorn',)), alias('GAME')
        if not py or not target: self.skipTest('needs case-insensitive FS, local sources and unicorn')
        done = self.run_tool(py, ROOT / 'tools/pc_world_oracle.py', '--root', ROOT / 'GAME', '--capture', '/nonexistent', '--output', target / 'x.json')
        self.assertEqual(done.returncode, 2, done.stderr[-400:])
        self.assertIn('output must be outside original directory', done.stderr)

    def test_builders_import_in_script_mode(self):
        for tool, modules in NO_ARGPARSE:
            with self.subTest(tool=tool):
                py = interpreter(modules)
                if not py: self.skipTest(f'{modules} unavailable'); continue
                code = f"import runpy,sys; sys.path[0]={str(ROOT / 'tools')!r}; runpy.run_path({str(ROOT / 'tools' / tool)!r}, run_name='not_main')"
                done = self.run_tool(py, '-c', code)
                self.assertEqual(done.returncode, 0, done.stderr[-400:])


if __name__ == '__main__':
    unittest.main()
