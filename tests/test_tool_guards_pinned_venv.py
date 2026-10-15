"""Oracle output guards run even when the gate's interpreter lacks unicorn.

Plain python3 has Pillow but not unicorn, so the guard tests for the unicorn
oracles (pc_vehicle_oracle, pc_reticle_oracle, pc_bearing_oracle, ...) skip under
it. The pinned analysis venv (.runtime/pc-analysis-venv) has unicorn 2.1.4 but
no Pillow. When the current interpreter cannot import unicorn and that venv can,
this re-runs every test module that depends on unicorn there and requires that
none of their unicorn-dependent tests skip again, so tools/validate.sh covers
both halves.
"""
import importlib.util
import os
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENV = ROOT / '.runtime/pc-analysis-venv/bin/python'


def unicorn_modules():
    """Every test module whose code (not just a comment) mentions unicorn."""
    found = []
    for path in sorted((ROOT / 'tests').glob('test_*.py')):
        if path.name == Path(__file__).name:
            continue
        code = [line for line in path.read_text().splitlines() if not line.lstrip().startswith('#')]
        if any('unicorn' in line.lower() for line in code):
            found.append('tests.' + path.stem)
    return found


def unicorn_skip():
    """The gate's own pattern for a skip caused by a missing unicorn."""
    line = re.search(r'^UNICORN_SKIP="(.*)"$', (ROOT / 'tools/validate.sh').read_text(), re.M).group(1)
    return re.compile(line.replace('\\"', '"'), re.I)


def venv_has_unicorn():
    if not VENV.exists():
        return False
    return subprocess.run([str(VENV), '-c', 'import unicorn'], capture_output=True).returncode == 0


class UnicornModuleTests(unittest.TestCase):
    def test_rerun_covers_every_unicorn_guard_module(self):
        modules = unicorn_modules()
        for name in ['tests.test_tool_entry_guards', 'tests.test_tool_output_guards',
                     'tests.test_tool_script_guards', 'tests.test_tool_import_guards']:
            self.assertIn(name, modules)

    def test_gate_pattern_counts_only_missing_unicorn(self):
        pattern = unicorn_skip()
        for reason in ["'unicorn unavailable in this interpreter'", "'Unicorn required'", "'pinned Unicorn unavailable'",
                       "'pinned Unicorn 2.1.4 required'", '"pc_reticle_oracle needs (\'unicorn\',)"',
                       '"(\'unicorn\',) unavailable"']:
            self.assertRegex('test ... skipped ' + reason, pattern)
        for reason in ["'Requires unicorn, the original SIM.EXE and the local scanout capture'",
                       "'needs case-insensitive FS, local sources and unicorn'", '"x needs (\'unicorn\', \'PIL\')"',
                       "'PIL unavailable in this interpreter'"]:
            self.assertNotRegex('test ... skipped ' + reason, pattern)


@unittest.skipIf(importlib.util.find_spec('unicorn') is not None, 'this interpreter already runs the oracle guards')
class PinnedVenvGuardTests(unittest.TestCase):
    def test_oracle_guards_pass_under_the_pinned_venv(self):
        if not venv_has_unicorn():
            self.skipTest('no pinned analysis venv with unicorn at .runtime/pc-analysis-venv')
        env = {k: v for k, v in os.environ.items() if k != 'PYTHONPATH'} | {'PYTHONDONTWRITEBYTECODE': '1'}
        done = subprocess.run([str(VENV), '-m', 'unittest', '-v', *unicorn_modules()], cwd=ROOT, env=env,
                              capture_output=True, text=True, timeout=1200)
        self.assertEqual(done.returncode, 0, done.stderr[-2000:])
        pattern = unicorn_skip()
        skipped = [line for line in done.stderr.splitlines() if pattern.search(line)]
        self.assertEqual(skipped, [], 'unicorn-dependent guard tests still skipped under ' + str(VENV))
        self.assertRegex(done.stderr, r'\nOK( \(skipped=\d+\))?\s*$')


if __name__ == '__main__':
    unittest.main()
