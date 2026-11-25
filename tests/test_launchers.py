"""Check public launch targets and argument forwarding without starting Godot."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


# --- clone-first copies: APFS clones on macOS, plain shutil elsewhere (rule: "Reference inputs; clone, never copy") ---
import shutil as _cc_shutil


def _cc_build():
    import ctypes
    import os
    import sys

    names = ('copyfile', 'copy', 'copy2', 'copytree')
    orig = {n: getattr(_cc_shutil, n) for n in names}
    clonefile = None
    if sys.platform == 'darwin':
        try:
            clonefile = ctypes.CDLL(None, use_errno=True).clonefile
            clonefile.argtypes = (ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32)
            clonefile.restype = ctypes.c_int
        except (OSError, AttributeError):
            clonefile = None
    umask = os.umask(0)
    os.umask(umask)

    def clone(name, src, dst, follow):
        # Clone only when shutil is unpatched, src is a regular file and dst does not exist yet; else plain shutil.
        if clonefile is None or any(getattr(_cc_shutil, n) is not orig[n] for n in names):
            return False  # a test has patched shutil: let the patched function handle it
        if os.path.lexists(dst) or not (os.path.isfile(src) and (follow or not os.path.islink(src))):
            return False
        if clonefile(os.fsencode(src), os.fsencode(dst), 0 if follow else 1) != 0:
            return False
        os.chflags(dst, 0, follow_symlinks=False)  # clones inherit the source's flags (e.g. uchg)
        if name == 'copy2':
            _cc_shutil.copystat(src, dst, follow_symlinks=follow)
        else:
            if name == 'copy':
                _cc_shutil.copymode(src, dst, follow_symlinks=follow)
            else:
                os.chmod(dst, 0o666 & ~umask)
            os.utime(dst, None)
        return True

    def copyfile(src, dst, *, follow_symlinks=True):
        if clone('copyfile', src, dst, follow_symlinks):
            return dst
        return getattr(_cc_shutil, 'copyfile')(src, dst, follow_symlinks=follow_symlinks)

    def make(name):
        def copier(src, dst, *, follow_symlinks=True):
            target = os.path.join(dst, os.path.basename(src)) if os.path.isdir(dst) else dst
            if clone(name, src, target, follow_symlinks):
                return target
            return getattr(_cc_shutil, name)(src, dst, follow_symlinks=follow_symlinks)
        return copier

    copy, copy2 = make('copy'), make('copy2')
    mapped = {orig['copy2']: copy2, orig['copy']: copy, orig['copyfile']: copyfile}

    def copytree(src, dst, *args, **kwargs):
        patched = any(getattr(_cc_shutil, n) is not orig[n] for n in names)
        if len(args) < 3 and not patched:  # copy_function not passed positionally; shutil not patched by a test
            fn = kwargs.get('copy_function', orig['copy2'])
            kwargs['copy_function'] = mapped.get(fn, fn)
        return getattr(_cc_shutil, 'copytree')(src, dst, *args, **kwargs)

    return copyfile, copy, copy2, copytree


_cc_copyfile, _cc_copy, _cc_copy2, _cc_copytree = _cc_build()
# --- end clone-first copies ---


ROOT = Path(__file__).resolve().parents[1]


class LauncherTests(unittest.TestCase):
    def test_managed_templates_forward_paths_and_arguments(self):
        with tempfile.TemporaryDirectory(prefix='abrams managed launch ') as temp:
            root = Path(temp)
            (root / 'tools/package').mkdir(parents=True)
            _cc_copy2(ROOT / 'tools/package/Play.command', root / 'Play.command')
            _cc_copy2(ROOT / 'tools/package/Launch.command', root / 'tools/package/Launch.command')
            stub = root / 'python stub'
            stub.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
            stub.chmod(0o755)
            for launcher in [root / 'Play.command', root / 'tools/package/Launch.command']:
                result = subprocess.run(['sh', str(launcher), '--check', '--window-size', '1920x1080'],
                                        cwd='/', env=dict(os.environ, ABRAMS_PYTHON=str(stub)),
                                        check=True, text=True, capture_output=True)
                arguments = json.loads(result.stdout)
                self.assertEqual(Path(arguments[0]).resolve(), root.resolve() / 'tools/package_runtime.py')
                self.assertEqual(arguments[1:], ['--check', '--window-size', '1920x1080'])

    def test_launch_targets_and_arguments(self):
        with tempfile.TemporaryDirectory(prefix='abrams launch ') as temp:
            root = Path(temp)
            (root / 'tools').mkdir()
            (root / '.runtime/pc-core').mkdir(parents=True)
            for name in ['Play.command', 'Calibration Range.command', 'Art Review.command',
                         'PC Bridge.command', 'tools/godot.sh']:
                _cc_copy2(ROOT / name, root / name)
            for name in ['abrams-ref.zip', 'abrams-trace.dylib', 'abrams-trace.json']:
                (root / '.runtime/pc-core' / name).touch()
            stub = root / 'godot stub'
            stub.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
            stub.chmod(0o755)
            environment = dict(os.environ, GODOT_BIN=str(stub))
            for launcher, args, expected in [
                ('Play.command', ['--capture', '--boot'],
                 ['--script', 'res://scripts/pc_bridge_viewer.gd', '--', '--play', '--capture', '--boot']),
                ('Play.command', ['--compare', '--fullscreen', '--window-size', '1920x1080'],
                 ['--script', 'res://scripts/pc_bridge_viewer.gd', '--', '--play', '--compare', '--fullscreen', '--window-size', '1920x1080']),
                ('PC Bridge.command', ['--capture', '--boot'],
                 ['--script', 'res://scripts/pc_bridge_viewer.gd', '--', '--capture', '--boot']),
                ('Art Review.command', ['--capture-art', '/tmp/art review'],
                 ['res://scenes/art_review.tscn', '--', '--capture-art', '/tmp/art review']),
                ('Calibration Range.command', ['--headless', '--', '--smoke-test'],
                 ['--headless', '--', '--smoke-test']),
            ]:
                with self.subTest(launcher=launcher):
                    result = subprocess.run([str(root / launcher), *args], cwd='/', env=environment,
                                            check=True, text=True, capture_output=True)
                    self.assertEqual(json.loads(result.stdout), ['--path', str(root / 'godot'), *expected])

    def test_relative_launch_ignores_cdpath(self):
        # An inherited CDPATH must not redirect `cd "$(dirname "$0")"` to a
        # same-named checkout elsewhere, nor print that path to stdout.
        with tempfile.TemporaryDirectory(prefix='abrams cdpath ') as temp:
            temp = Path(temp)
            for side, word in [('work', 'REAL'), ('decoy', 'DECOY')]:
                root = temp / side / 'Abrams'
                (root / 'tools').mkdir(parents=True)
                for name in ['PC Bridge.command', 'tools/godot.sh']:
                    (root / name).write_text(f'#!/bin/sh\necho {word}\n')
                    (root / name).chmod(0o755)
            for launcher in ['Play.command', 'Art Review.command', 'Calibration Range.command']:
                _cc_copy2(ROOT / launcher, temp / 'work/Abrams' / launcher)
                with self.subTest(launcher=launcher):
                    result = subprocess.run(['sh', 'Abrams/' + launcher], cwd=temp / 'work',
                                            env=dict(os.environ, CDPATH=str(temp / 'decoy')),
                                            check=True, text=True, capture_output=True)
                    self.assertEqual(result.stdout, 'REAL\n')

    def test_missing_python_is_reported(self):
        with tempfile.TemporaryDirectory(prefix='abrams launch ') as temp:
            root = Path(temp)
            (root / 'tools').mkdir()
            (root / '.runtime/pc-core').mkdir(parents=True)
            for name in ['PC Bridge.command', 'tools/godot.sh']:
                _cc_copy2(ROOT / name, root / name)
            for name in ['abrams-ref.zip', 'abrams-trace.dylib', 'abrams-trace.json']:
                (root / '.runtime/pc-core' / name).touch()
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            (bin_dir / 'dirname').symlink_to(shutil.which('dirname'))
            result = subprocess.run(['/bin/sh', str(root / 'PC Bridge.command')], cwd='/',
                                    env={'PATH': str(bin_dir), 'GODOT_BIN': '/nonexistent'},
                                    check=False, text=True, capture_output=True)
            self.assertEqual(result.returncode, 127)
            self.assertIn('ABRAMS_PYTHON', result.stderr)
            self.assertIn('docs/pc-live-bridge.md', result.stderr)

    def test_shipped_launchers_carry_no_machine_paths(self):
        source = json.loads((ROOT / 'tools/package/allowlist.json').read_text())['source']
        launchers = [name for name in source if name.endswith(('.command', '.sh'))]
        self.assertIn('tools/godot.sh', launchers)
        for name in launchers:
            with self.subTest(launcher=name):
                self.assertNotIn('/Users/', (ROOT / name).read_text())


if __name__ == '__main__':
    unittest.main()
