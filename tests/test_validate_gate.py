"""tools/validate.sh runs every Godot test and requires the receipt it prints.

The gate's receipt regexes and the tests' print statements drift independently
(the 2026-10 'PC_DRAW_PASS: basic axes' receipt outlived its print and stopped
the gate at a passing check). These tests read the gate's own --list table and
instantiate each test script's print templates, so a renamed receipt, a new
test under godot/tests or a check without a receipt fails here first.
"""
import itertools
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / 'tools/validate.sh'
TESTS = ROOT / 'godot/tests'
GENERIC = ('PASS', 'true', 'false', 'x')
FORMAT = re.compile(r'%(?:\.\d+)?[dsf]')


def gate_table():
    result = subprocess.run(['sh', str(GATE), '--list'], cwd=ROOT, check=True, text=True, capture_output=True)
    return [line.split('\t', 3) for line in result.stdout.splitlines() if line.strip()]


def _string_end(text, at):
    quote, at = text[at], at + 1
    while text[at] != quote:
        at += 2 if text[at] == '\\' else 1
    return at + 1


def _split(text, separator):
    """Top-level split on a one-character separator, outside strings and brackets."""
    parts, depth, start, at = [], 0, 0, 0
    while at < len(text):
        char = text[at]
        if char in '"\'':
            at = _string_end(text, at)
            continue
        if char in '([{': depth += 1
        elif char in ')]}': depth -= 1
        elif char == separator and depth == 0:
            parts.append(text[start:at]); start = at + 1
        at += 1
    parts.append(text[start:])
    return [part.strip() for part in parts]


def _literals(text):
    found, at = [], 0
    while at < len(text):
        if text[at] in '"\'':
            end = _string_end(text, at)
            found.append(text[at + 1:end - 1].encode().decode('unicode_escape'))
            at = end
        else:
            at += 1
    return found


def _is_literal(text):
    return len(text) >= 2 and text[0] in '"\'' and _string_end(text, 0) == len(text)


def _term(term):
    """A print argument term as [literal str | hole tuple | None (JSON)].

    A hole is ('%d',) for a number or ('%s', literals...) for any other value;
    template_matches() fills them.
    """
    if _is_literal(term):
        return [_literals(term)[0]]
    head = _split(term, '%')
    if len(head) == 2 and _is_literal(head[0]):
        literal = _literals(head[0])[0]
        args = head[1].strip()
        args = _split(args[1:-1], ',') if args.startswith('[') else [args]
        pieces, index = [], 0
        for part, spec in itertools.zip_longest(FORMAT.split(literal), FORMAT.findall(literal)):
            pieces.append(part)
            if spec is None:
                continue
            source = args[index] if index < len(args) else ''
            index += 1
            if spec.endswith('f'):
                pieces.append(('0.000001',))
            elif spec == '%d':
                pieces.append(('%d',))
            else:
                pieces.append(('%s', *_literals(source)))
        return pieces
    if 'JSON.stringify' in term:
        return [None]
    if term.startswith('(') and term.endswith(')') and ' if ' not in term:
        return _expression(term[1:-1])
    return [('%s', *_literals(term))]


def _expression(text):
    pieces = []
    for term in _split(text, '+'):
        pieces.extend(_term(term))
    return pieces


def print_templates(path, seen=None):
    """Templates of every print() in path and the scripts it extends."""
    seen = seen or set()
    if path in seen or not path.is_file():
        return []
    seen.add(path)
    text = path.read_text()
    templates = []
    for match in re.finditer(r'(?<![\w.])print\(', text):
        depth, at = 1, match.end()
        while depth:
            if text[at] in '"\'':
                at = _string_end(text, at); continue
            depth += {'(': 1, ')': -1}.get(text[at], 0)
            at += 1
        pieces = []
        for argument in _split(text[match.end():at - 1], ','):
            pieces.extend(_expression(argument))
        templates.append(pieces)
    parent = re.search(r'^extends\s+"res://(tests/[^"]+\.gd)"', text, re.M)
    if parent:
        templates += print_templates(ROOT / 'godot' / parent.group(1), seen)
    return templates


def template_matches(pieces, receipt):
    if None in pieces:
        # A JSON receipt: require the literal before the object to match the
        # regex's literal head; the object's content is the test's own output.
        head = ''.join(p for p in pieces[:pieces.index(None)] if isinstance(p, str))
        literal = re.match(r'\^((?:[^\\^$.|?*+()\[\]{}]|\\.)*)', receipt).group(1).replace('\\', '')
        return bool(head) and (literal.startswith(head) or head.startswith(literal))
    # Numbers and words the receipt pins (e.g. '32 cases', 'early-close') are
    # candidate values, alongside each hole's own literals.
    numbers = ('0', '1', '12', *re.findall(r'(?<![\w\[-])\d+(?![\w\]-])', receipt))
    words = (*GENERIC, *re.findall(r'[A-Za-z][A-Za-z0-9_-]*', receipt))
    holes = []
    for piece in pieces:
        if not isinstance(piece, tuple):
            continue
        if piece[0] == '%d':
            holes.append(tuple(dict.fromkeys(numbers)))
        elif piece[0] == '%s':
            holes.append(tuple(dict.fromkeys((*piece[1:], *numbers, *words))))
        else:
            holes.append(piece)
    pattern = re.compile(receipt)
    for fill in itertools.islice(itertools.product(*holes), 500000):
        values = iter(fill)
        line = ''.join(p if isinstance(p, str) else next(values) for p in pieces)
        if pattern.search(line):
            return True
    return False


class ValidateGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.table = gate_table()

    def test_shell_syntax(self):
        subprocess.run(['sh', '-n', str(GATE)], check=True)

    def test_listing_runs_nothing(self):
        # A private copy, so a concurrent real gate run cannot race this check.
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / 'tools').mkdir()
            shutil.copy2(GATE, Path(directory) / 'tools/validate.sh')
            listed = subprocess.run(['sh', 'tools/validate.sh', '--list'], cwd=directory, check=True, text=True, capture_output=True)
            self.assertEqual(len(listed.stdout.splitlines()), len(self.table))
            self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ['tools'])

    def test_check_names_are_unique(self):
        names = [row[1] for row in self.table]
        self.assertEqual(len(names), len(set(names)))

    def test_every_godot_test_is_run_or_explicitly_not_run(self):
        scripts = {path.name for path in TESTS.glob('test_*.gd')}
        covered = set()
        for tier, name, receipt, command in self.table:
            if tier == 'manual':
                covered.add('test_' + name + '.gd')
                self.assertTrue(command.strip() and command != '-', name)
            covered.update(re.findall(r'res://tests/(test_[\w]+\.gd)', command))
        self.assertEqual(sorted(scripts - covered), [], 'add these to tools/validate.sh (run_check or not_run)')
        self.assertEqual(sorted(covered - scripts), [], 'tools/validate.sh names tests that do not exist')

    def test_default_tier_is_headless(self):
        for tier, name, receipt, command in self.table:
            if tier == 'default' and './tools/godot.sh' in command:
                with self.subTest(check=name):
                    self.assertIn('--headless', command)

    def test_every_godot_receipt_matches_a_print_in_its_script(self):
        for tier, name, receipt, command in self.table:
            script = re.search(r'--script res://(tests/[\w]+\.gd)', command)
            if tier == 'manual' or not script:
                continue
            with self.subTest(check=name):
                self.assertTrue(receipt.startswith('^'), receipt)
                templates = print_templates(ROOT / 'godot' / script.group(1))
                self.assertTrue(any(template_matches(t, receipt) for t in templates),
                                f'{name}: {receipt!r} matches no print() in {script.group(1)}')

    def test_receipts_reject_reported_failures(self):
        failing = {'PC_DRAW_PASS: 40 checks, 1 errors', 'PC_TACTICAL_HUD: 12 checks, 2 errors',
                   'PC_COCKPIT_ART: 50 checks, 1 failures', 'PC_MODERN: FAIL; 12 checks; native=false',
                   'PC_CAMERA: 12 projections; maximum original-pixel error 1.250000',
                   'PC_TERRAIN_STYLE: {"changed_terrain_pixels":0,"checks":3,"errors":["x"],"native":false}',
                   'PC_FRONTEND_SCENE: 12 checks, 0 errors, 23 selectors, 7 missions',
                   'PC_DRAW_PASS: 0 checks, 0 errors'}
        receipts = [row[2] for row in self.table if row[0] != 'manual']
        for line in failing:
            with self.subTest(line=line):
                self.assertFalse(any(re.search(r, line) for r in receipts))

    def test_gate_runs_the_findings_receipts(self):
        rows = {row[1]: row for row in self.table}
        self.assertEqual(rows['pc_draw_pass'][2], '^PC_DRAW_PASS: [1-9][0-9]* checks, 0 errors([,;] .*)?$')
        self.assertIn('pc_tactical_hud', rows)
        self.assertIn('-- --live', rows['pc_dynamic_map'][3])
        self.assertIn('--native', rows['pc_modern_native'][3])
        self.assertEqual(rows['pc_modern_native'][0], 'native')
        for shard in (0,1,2,3,4,5,7):self.assertIn(f'pc_tactical_vehicles_format_{shard}',rows)
        self.assertNotIn('pc_tactical_vehicles_format_6',rows)
        for kind in ('passthrough','partial','scene_bank'):
            row=rows[f'pc_tactical_vehicles_format_6_{kind}']
            self.assertIn(f'--format-shard 6 --scene-format-kind {kind}',row[3])
            self.assertIn(f'PC_TACTICAL_SCENE_FORMAT: {kind};',row[2])
        for shard in range(1,6):self.assertIn(f'pc_tactical_vehicles_native_{shard}',rows)
        self.assertNotIn('pc_tactical_vehicles_native_0',rows)
        for phase,option in (('scene','--scene-only'),('views','--defer-scene-contracts')):
            row=rows[f'pc_tactical_vehicles_native_0_{phase}']
            self.assertIn(f'--view-shard 0 {option}',row[3])
            self.assertIn(f'PC_TACTICAL_NATIVE_PHASE: {phase};',row[2])
        for contract in ['groundlight', 'diffusion', 'finishgrain']:
            self.assertEqual(rows[f'pc_tactical_{contract}_gpu'][0], 'native')
        self.assertEqual(rows['pc_soak'][0], 'live')
        gate = GATE.read_text()
        self.assertIn('SHADER ERROR:', gate)
        self.assertIn('python_skips', gate)
        self.assertIn('ABRAMS_PYTHON', gate)
        self.assertIn('tests.gate_fixtures --verify', gate)

    def test_every_file_the_gate_runs_ships_in_the_source_kit(self):
        # tools/validate.sh is in the source kit, so every script, module and
        # fixture it names must be too, or the kit's own gate cannot run.
        source = set(json.loads((ROOT / 'tools/package/allowlist.json').read_text())['source'])
        self.assertIn('tools/validate.sh', source)
        named = set()
        for tier, name, receipt, command in self.table:
            named.update('godot/' + path for path in re.findall(r'res://((?:tests|scripts)/[\w/.-]+)', command))
            named.update(module.replace('.', '/') + '.py' for module in re.findall(r'-m ((?:tests|tools)(?:\.\w+)+)', command))
        if 'tests/gate_fixtures.py' in named:
            named.add('tests/gate_fixtures.json')
        self.assertEqual(sorted(named - source), [], 'add these to tools/package/allowlist.json "source"')

    def test_godot_launcher_prefers_pinned_engine(self):
        launcher = (ROOT / 'tools/godot.sh').read_text()
        self.assertLess(launcher.index('.runtime/Godot.app'), launcher.index('command -v godot'))
        self.assertIn('GODOT_VERSION=4.7.2', GATE.read_text())


if __name__ == '__main__':
    unittest.main()
