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
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('capture_pc_render_trace', ['--state', 's', '--output', out],
                             'output must be outside original sources')

    @unittest.skipUnless(HAS_PIL, 'Pillow required')
    def test_pc_effects(self):
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('extract_pc_effects', ['--capture', 'c', '--trace', 't', '--output', out],
                             'output must be outside original sources')

    def test_genesis_effects(self):
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('extract_genesis_effects', ['--capture', 'c', '--palette-bank', '0', '--output', out],
                             'output must be outside original sources')

    def test_genesis_damage(self):
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('pc_instrument_genesis_damage', ['--output', out], 'output must be outside original sources')

    @unittest.skipUnless(HAS_UNICORN, 'Unicorn required')
    def test_vehicle_oracle(self):
        mod = importlib.import_module('tools.pc_vehicle_oracle')
        if mod.unicorn.__version__ != '2.1.4':
            self.skipTest('pinned Unicorn 2.1.4 required')
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('pc_vehicle_oracle', ['--capture', 'c', '--output', out], 'output must be outside original sources')

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
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(out=out):
                self.rejects('inspect_scenarios', ['--game', self.root / 'GAME', '--output', out / 'r.json'],
                             'report output must be outside original sources and --game')
                self.rejects('unpack_pc_executables', ['--root', self.root / 'GAME', '--out', out],
                             'outputs must be outside original sources and --root')
        from tools.source_guard import inside_source
        self.assertFalse(inside_source(self.root / 'GAME-copy/x', self.root, ('GAME',)))
        # Decoded resources and decoded-prefix reports hash-match no pinned input: tracked paths are refused.
        for out in (self.root / 'docs/research/scenarios.json', self.root / 'website/dist/s.json'):
            for extra in ([], ['--extract']):
                with self.subTest(out=out, extra=extra):
                    self.rejects('inspect_scenarios', ['--game', self.root / 'GAME', '--output', out, *extra],
                                 'report output must be in a private directory')

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

    @unittest.skipUnless(HAS_PIL, 'Pillow required')
    def test_tactical_authoring_tools_reject_source_aliases_before_writing(self):
        for out in self.aliases('GAME', 'GENESIS'):
            with self.subTest(tool='roster', out=out):
                self.rejects('build_pc_tactical_roster', ['--output', out],
                             'Output must be outside original game inputs')
            with self.subTest(tool='refinement', out=out):
                self.rejects('refine_pc_tactical_exports', ['--', '--output', out],
                             'output must be outside original sources')


# Every tool with a caller-chosen output path must call inside_source(). Exempt only with a reason.
OUTPUT_OPTIONS = {'--output', '--out', '--output-dir', '--out-dir', '--dest', '--destination', 'output'}
EXEMPT = {
    'build_pc_trace_core.py': 'core-gpl cluster owns it; guard requested on --output-dir',
}
# Tools guarded in the output sweep: extra required arguments, none read before the guard.
SWEPT = {'audit_pc_audio': [], 'audit_pc_effect_inventory': [], 'audit_pc_effect_modes': [], 'build_frontend_music': [],
         'build_pc_map_frame_catalog': [], 'check_crew_transcripts': ['--directory', 'x'], 'extract_genesis_audio': ['--label', 'x'],
         'extract_genesis_samples': [], 'generate_crew_voice': [], 'genesis_capture': [], 'genesis_effect_oracle': [],
         'genesis_model_oracle': [], 'pc_audio_loop_oracle': [], 'pc_bitmap_oracle': ['--capture', 'x'],
         'pc_damage_voice_oracle': [], 'pc_dissolve_oracle': ['--capture', 'x'], 'pc_dynamic_map_oracle': [],
         'pc_font_oracle': ['--capture', 'x'], 'pc_map_frame_oracle': [], 'pc_material_oracle': ['--capture', 'x'],
         'pc_plate_oracle': ['--capture', 'x'], 'pc_remaining_voice_oracle': [], 'pc_request_sound_oracle': [],
         'pc_vehicle_catalog_oracle': ['--capture', 'x'], 'verify_pc_audio_trace': ['--trace', 'x', '--baseline', 'x'],
         'verify_pc_bridge': ['--state', 'x'], 'verify_pc_dialogue': ['--trace', 'x', '--baseline', 'x'],
         'verify_pc_driver_overlay': ['--trace', 'x', '--baseline', 'x'], 'verify_pc_dynamic_map': ['--mode', 'trace', '--state', 'x'],
         'verify_pc_held_inputs': [], 'verify_pc_plate_overlay': ['--report', 'x'], 'verify_pc_readiness': ['--trace', 'x', '--baseline', 'x'],
         'verify_pc_save_states': [], 'verify_pc_text_trace': ['--trace', 'x', '--baseline', 'x'], 'extract_genesis_vdp': None,
         'modern_assets/round_span_probe': ['--output-dir']}
OPTIONAL_MODULES = ('PIL', 'unicorn', 'fontTools', 'reportlab')


class OutputSweepTests(unittest.TestCase):
    def test_every_output_tool_calls_the_source_guard(self):
        import ast
        for path in sorted([*(ROOT / 'tools').glob('*.py'), *(ROOT / 'tools/modern_assets').glob('*.py')]):
            tree = ast.parse(path.read_text())
            options = {a.value for n in ast.walk(tree) if isinstance(n, ast.Call) and getattr(n.func, 'attr', '') == 'add_argument'
                       for a in n.args if isinstance(a, ast.Constant) and isinstance(a.value, str)}
            if not options & OUTPUT_OPTIONS or path.name in EXEMPT:
                continue
            calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and ast.unparse(n.func).endswith('inside_source')]
            with self.subTest(tool=str(path.relative_to(ROOT))):
                self.assertTrue(calls, 'writes a caller-chosen path without tools.source_guard.inside_source()')

    def test_swept_tools_refuse_miscased_sources_before_writing(self):
        wrote = AssertionError('touched a file before the output guard')
        for name, extra in SWEPT.items():
            for alias in ('game', 'Genesis'):
                target = ROOT / alias / 'never-created-output-sweep' / 'x'
                argv = [str(ROOT / 'capture'), str(target)] if extra is None else \
                    [*extra, str(target)] if extra == ['--output-dir'] else [*extra, '--output', str(target)]
                stderr = io.StringIO()
                with self.subTest(tool=name, alias=alias):
                    try:
                        with mock.patch.object(sys, 'argv', [name, *argv]), mock.patch.object(sys, 'path', [str(ROOT / 'tools'), *sys.path]), \
                                mock.patch.object(Path, 'mkdir', side_effect=wrote), mock.patch.object(Path, 'write_text', side_effect=wrote), \
                                mock.patch.object(Path, 'write_bytes', side_effect=wrote), mock.patch.object(Path, 'open', side_effect=wrote), \
                                mock.patch('os.mkdir', side_effect=wrote), contextlib.redirect_stderr(stderr), \
                                self.assertRaises(SystemExit) as caught:
                            runpy.run_path(str(ROOT / 'tools' / f'{name}.py'), run_name='__main__')
                    except ModuleNotFoundError as error:
                        if error.name not in OPTIONAL_MODULES: raise
                        self.skipTest(f'{error.name} unavailable in this interpreter')
                    self.assertEqual(caught.exception.code, 2, stderr.getvalue()[-400:])
                    self.assertIn('outside original', stderr.getvalue())
                    self.assertFalse(target.parent.exists())

    def test_swept_tools_import_the_guard_in_script_mode(self):
        # `python3 tools/<name>.py` puts tools/, not the repo, on sys.path: the guard import must still resolve.
        env = {k: v for k, v in os.environ.items() if k != 'PYTHONPATH'} | {'PYTHONDONTWRITEBYTECODE': '1'}
        with tempfile.TemporaryDirectory() as cwd:
            for name in SWEPT:
                with self.subTest(tool=name):
                    done = subprocess.run([sys.executable, str(ROOT / 'tools' / f'{name}.py'), '--help'], cwd=cwd, env=env,
                                          capture_output=True, text=True, timeout=60)
                    missing = [m for m in OPTIONAL_MODULES if f"No module named '{m}'" in done.stderr]
                    if done.returncode and missing:
                        self.skipTest(f'{missing[0]} unavailable in this interpreter')
                    self.assertEqual(done.returncode, 0, done.stderr[-400:])
                    self.assertIn('usage:', done.stdout)

    def test_bearing_install_refuses_outside_source_before_any_take_is_read(self):
        from tools.install_pc_bearings import prepare
        with tempfile.TemporaryDirectory() as outside, \
                mock.patch.object(Path, 'read_text', side_effect=AssertionError('read before the source check')), \
                self.assertRaisesRegex(ValueError, '--source must be inside the repository'):
            prepare(Path(outside) / 'bearing-batches')

    def test_request_sounds_refuse_the_whole_batch_before_writing(self):
        from tools import build_pc_request_sounds
        for existing in ('pc_request_10.wav', 'pc_request_provenance.json'):
            with self.subTest(existing=existing), tempfile.TemporaryDirectory() as tmp:
                audio = Path(tmp) / 'godot/assets/audio'
                audio.mkdir(parents=True)
                (audio / existing).write_bytes(b'kept')
                with mock.patch.object(build_pc_request_sounds, 'ROOT', Path(tmp)), self.assertRaises(FileExistsError):
                    build_pc_request_sounds.main()
                self.assertEqual([p.name for p in audio.iterdir()], [existing])


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
