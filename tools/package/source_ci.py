#!/usr/bin/env python3
"""Run the dependency-free source-kit contract in a clean temporary directory."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile
from tools import package_build

ROOT = Path(__file__).resolve().parents[2]
TESTS = ['tests.test_packaging', 'tests.test_package_runtime', 'tests.test_git_boundary', 'tests.test_launchers']


def main():
    with tempfile.TemporaryDirectory(prefix='abrams source ci ') as directory:
        stage = Path(directory)
        archive = stage / 'source.zip'
        report = package_build.build(ROOT, archive, 'source')
        clean = stage / 'clean'; clean.mkdir()
        with zipfile.ZipFile(archive) as package:
            # Build and verification above establish member paths and types.
            package.extractall(clean)
            for member in package.infolist():
                (clean / member.filename).chmod((member.external_attr >> 16) & 0o777)
        for excluded in ['GAME', 'GENESIS', '.runtime', 'local-art', 'local-audio', 'godot/assets']:
            if (clean / excluded).exists():
                raise ValueError(f'Private inputs leaked into source kit: {excluded}')
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONPATH=str(clean), PYTHONNOUSERSITE='1')
        subprocess.run([sys.executable, '-S', '-m', 'unittest', *TESTS], cwd=clean, env=env, check=True)
        print(f"PASS: clean source kit, {report['files']} files, stdlib only, no originals or native runtime", flush=True)


if __name__ == '__main__':
    main()
