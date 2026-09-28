"""Check public launch targets and argument forwarding without starting Godot."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LauncherTests(unittest.TestCase):
    def test_managed_templates_forward_paths_and_arguments(self):
        with tempfile.TemporaryDirectory(prefix='abrams managed launch ') as temp:
            root = Path(temp)
            (root / 'tools/package').mkdir(parents=True)
            shutil.copy2(ROOT / 'tools/package/Play.command', root / 'Play.command')
            shutil.copy2(ROOT / 'tools/package/Launch.command', root / 'tools/package/Launch.command')
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
                shutil.copy2(ROOT / name, root / name)
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


if __name__ == '__main__':
    unittest.main()
