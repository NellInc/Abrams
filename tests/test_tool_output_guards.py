"""Tool output guards reject case/symlink aliases of original sources before any write,
and the shebang tools import their siblings when run as scripts from a foreign cwd."""
import contextlib
import importlib
import importlib.util
import io
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
HAS_PIL = importlib.util.find_spec('PIL') is not None
HAS_UNICORN = importlib.util.find_spec('unicorn') is not None


@contextlib.contextmanager
def no_writes():
    with mock.patch.object(Path, 'mkdir', side_effect=AssertionError('wrote')), \
            mock.patch.object(Path, 'write_text', side_effect=AssertionError('wrote')), \
            mock.patch.object(Path, 'write_bytes', side_effect=AssertionError('wrote')):
        yield


class OutputGuardTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name).resolve() / 'repo'
        for name in ('GAME', 'GENESIS', 'reference', 'local-art'):
            (self.root / name).mkdir(parents=True)
        (self.root / 'local-art/link').symlink_to(self.root / 'GAME', target_is_directory=True)

    def rejects(self, module, argv, message, call='main', exc=SystemExit):
        """Run module.main with ROOT moved to the temporary tree; expect the guard's own message."""
        mod = importlib.import_module('tools.' + module)
        stderr = io.StringIO()
        with mock.patch.object(mod, 'ROOT', self.root, create=True), mock.patch.object(sys, 'argv', [module, *map(str, argv)]), \
                no_writes(), contextlib.redirect_stderr(stderr), self.assertRaises(exc) as caught:
            getattr(mod, call)()
        if exc is SystemExit:
            self.assertEqual(caught.exception.code, 2)
            self.assertIn(message, stderr.getvalue())
        else:
            self.assertIn(message, str(caught.exception))

    def aliases(self, *names):
        r = self.root
        return [r / name.lower() / 'x' for name in names] + [r / name.title() / 'x' for name in names] + \
            [r / 'local-art/../' / name.lower() / 'x' for name in names] + \
            ([r / 'local-art/link/x'] if 'GAME' in names else [])

    @unittest.skipUnless(HAS_PIL, 'Pillow required')
    def test_intro_catalog(self):
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('build_pc_intro_catalog', ['--output', out], 'output must be outside source directories')

    @unittest.skipUnless(HAS_PIL, 'Pillow required')
    def test_dialogue_capture(self):
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('capture_pc_dialogue', ['--mode', 'trace', '--state', 's', '--output', out],
                             'output must be outside original sources')

    @unittest.skipUnless(HAS_PIL, 'Pillow required')
    def test_render_trace_capture(self):
        for out in self.aliases('GAME'):
            with self.subTest(out=out):
                self.rejects('capture_pc_render_trace', ['--state', 's', '--output', out],
                             'output must be outside original GAME')

    @unittest.skipUnless(HAS_PIL, 'Pillow required')
    def test_pc_effects(self):
        for out in self.aliases('GAME'):
            with self.subTest(out=out):
                self.rejects('extract_pc_effects', ['--capture', 'c', '--trace', 't', '--output', out],
                             'output must be outside GAME')

    def test_genesis_effects(self):
        for out in self.aliases('GENESIS'):
            with self.subTest(out=out):
                self.rejects('extract_genesis_effects', ['--capture', 'c', '--palette-bank', '0', '--output', out],
                             'output must be outside GENESIS')

    def test_genesis_damage(self):
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('pc_instrument_genesis_damage', ['--output', out], 'output must be outside original sources')

    @unittest.skipUnless(HAS_UNICORN, 'Unicorn required')
    def test_vehicle_oracle(self):
        mod = importlib.import_module('tools.pc_vehicle_oracle')
        if mod.unicorn.__version__ != '2.1.4':
            self.skipTest('pinned Unicorn 2.1.4 required')
        for out in self.aliases('GAME'):
            with self.subTest(out=out):
                self.rejects('pc_vehicle_oracle', ['--capture', 'c', '--output', out], 'output must be outside original GAME')

    @unittest.skipUnless(HAS_UNICORN, 'Unicorn required')
    def test_reticle_oracle(self):
        # Inline __main__: run against the real ROOT; a missing capture stops a regressed guard before any write.
        for out in ('game/never-created/r.json', 'local-art/../Genesis/never-created/r.json'):
            argv = ['pc_reticle_oracle', '--capture', str(self.root / 'none'), '--output', str(ROOT / out)]
            stderr = io.StringIO()
            with self.subTest(out=out), mock.patch.object(sys, 'argv', argv), no_writes(), \
                    contextlib.redirect_stderr(stderr), self.assertRaises(SystemExit):
                runpy.run_path(str(ROOT / 'tools/pc_reticle_oracle.py'), run_name='__main__')
            self.assertIn('output must be outside original references', stderr.getvalue())

    @unittest.skipUnless(HAS_PIL, 'Pillow required')
    def test_bridge_save_overlay(self):
        from tools import pc_bridge_host
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out), mock.patch.object(pc_bridge_host, 'ROOT', self.root), no_writes(), \
                    self.assertRaisesRegex(ValueError, 'Save overlays must remain outside original source directories'):
                pc_bridge_host.lock_saves(out)

    def test_user_rooted_guards(self):
        # --game/--root name the protected tree; its aliases are inside it, its neighbours are not.
        (self.root / 'GAME/SIM.EXE').write_bytes(b'')
        for out in self.aliases('GAME'):
            with self.subTest(out=out):
                self.rejects('inspect_scenarios', ['--game', self.root / 'GAME', '--output', out / 'r.json'],
                             'report output must be outside GAME')
                self.rejects('unpack_pc_executables', ['--root', self.root / 'GAME', '--out', out],
                             'outputs must be outside original reference directory')
        from tools.source_guard import inside_source
        self.assertFalse(inside_source(self.root / 'GAME-copy/x', self.root, ('GAME',)))

    def test_blender_builders(self):
        # Blender scripts: stub bpy, run as __main__ against the real ROOT; reference/ is protected too.
        stubs = {name: types.ModuleType(name) for name in ('bpy', 'bmesh', 'mathutils')}
        stubs['mathutils'].Vector = object
        for script, exc, out in (('build_genesis_vehicle_studies.py', SystemExit, 'Reference/never-created'),
                                 ('build_pc_vehicle_studies.py', ValueError, 'game/never-created'),
                                 ('build_pc_vehicle_studies.py', ValueError, 'local-art/../Genesis/never-created')):
            argv = ['blender', '--', '--source', str(self.root / 'none'), '--output', str(ROOT / out)]
            with self.subTest(script=script, out=out), mock.patch.dict(sys.modules, stubs), \
                    mock.patch.object(sys, 'argv', argv), no_writes(), contextlib.redirect_stderr(io.StringIO()), \
                    self.assertRaises(exc):
                runpy.run_path(str(ROOT / 'tools' / script), run_name='__main__')


class ScriptModeImportTests(unittest.TestCase):
    SCRIPTS = {'build_pc_intro_catalog': ('PIL',), 'capture_pc_dialogue': ('PIL',), 'capture_pc_render_trace': ('PIL',),
               'extract_pc_effects': ('PIL',), 'pc_bridge_host': ('PIL',), 'extract_genesis_effects': (),
               'pc_instrument_genesis_damage': (), 'inspect_scenarios': (), 'unpack_pc_executables': (),
               'pc_reticle_oracle': ('unicorn',), 'pc_vehicle_oracle': ('unicorn',)}

    def test_help_from_foreign_cwd(self):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
        env.pop('PYTHONPATH', None)
        with tempfile.TemporaryDirectory() as cwd:
            for name, needs in self.SCRIPTS.items():
                with self.subTest(script=name):
                    if not all(importlib.util.find_spec(n) for n in needs):
                        self.skipTest(f'{name} needs {needs}')
                    result = subprocess.run([sys.executable, str(ROOT / 'tools' / f'{name}.py'), '--help'], cwd=cwd,
                                            env=env, capture_output=True, text=True, timeout=60)
                    self.assertEqual(result.returncode, 0, result.stderr[-400:])
                    self.assertIn('usage:', result.stdout)

    @unittest.skipUnless(HAS_PIL, 'Pillow required by the VDP renderer')
    def test_genesis_damage_lazy_vdp_import_in_script_mode(self):
        # The --render path imports tools.extract_genesis_vdp lazily; it must resolve with tools/ as sys.path[0].
        code = ('import sys; sys.path[0] = sys.argv[1]; import pc_instrument_genesis_damage, importlib; '
                'importlib.import_module("tools.extract_genesis_vdp")')
        with tempfile.TemporaryDirectory() as cwd:
            result = subprocess.run([sys.executable, '-c', code, str(ROOT / 'tools')], cwd=cwd,
                                    env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONPATH=''),
                                    capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr[-400:])


if __name__ == '__main__':
    unittest.main()
