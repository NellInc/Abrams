"""Read-only parity verifiers fail closed: self-comparison, unpinned cores, missing or renamed
loop-channel stages, and asserts stripped by `python -O` can never yield a passing receipt."""
import ast
import copy
from pathlib import Path
import unittest

from tools.verify_pc_audio_trace import check_core_pins, verify

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = {'trace_sha256': 'trace-core', 'baseline_sha256': 'baseline-core', 'trace_header_sha256': 'header'}


def loop(engine=True, turret=False, period=1, enabled=True):
    return {'loops': {'engine': {'active': engine, 'period': period}, 'turret': {'active': turret}}, 'enabled': enabled}


def audio_pair():
    ammunition = {'HEAT': 10, 'COAX': 10, 'SABOT': 5, 'AX': 1}
    fired = ammunition | {'HEAT': 7, 'COAX': 9}
    states = [{'stage': 'baseline', **loop(period=1)}, {'stage': 'turn-coast', **loop(turret=True, period=2)},
              {'stage': 'turret-stopped', **loop(turret=True)}, {'stage': 'turret-stopped', **loop()},
              {'stage': 'muted', **loop(enabled=False)}, {'stage': 'paused', **loop(enabled=False)}]
    trace = {'mode': 'trace', 'core_sha256': 'trace-core', 'trace_header_sha256': 'header', 'profile': 'audio',
             'state_sha256': 's', 'state_core_sha256': 'baseline-core', 'frames': [{'index': i} for i in range(2001)],
             'stages': {'baseline': {'ammunition': ammunition}, 'audible-fire': {'ammunition': fired},
                        'rejected-fire-key': {'ammunition': fired}},
             'audio_events': [], 'audio_states': states}
    baseline = copy.deepcopy(trace) | {'mode': 'baseline', 'core_sha256': 'baseline-core'}
    return trace, baseline


class CorePinTests(unittest.TestCase):
    def test_only_distinct_pinned_trace_and_baseline_cores_pass(self):
        trace, baseline = audio_pair()
        self.assertTrue(all(check_core_pins(trace, baseline, MANIFEST).values()))
        for fault, (t, b, m) in {
                'same report twice': (trace, trace, MANIFEST),
                'two trace-core runs': (trace, baseline | {'core_sha256': 'trace-core'}, MANIFEST),
                'baseline labelled trace': (trace, baseline | {'mode': 'trace'}, MANIFEST),
                'unpinned baseline core': (trace, baseline | {'core_sha256': 'other'}, MANIFEST),
                'missing manifest': (trace, baseline, {}),
                'stale trace header': (trace | {'trace_header_sha256': 'old'}, baseline, MANIFEST),
                'render trace without header': ({k: v for k, v in trace.items() if k != 'trace_header_sha256'}, baseline, MANIFEST),
                'headerless trace, missing manifest': ({k: v for k, v in trace.items() if k != 'trace_header_sha256'}, baseline, {})}.items():
            with self.subTest(fault=fault):
                self.assertFalse(all(check_core_pins(t, b, m).values()))

    def test_reused_baseline_is_judged_by_its_core_not_its_recorded_header(self):
        # The baseline core has no trace header; its recorded value is only the receipt of its capture day.
        trace, baseline = audio_pair()
        headerless = {k: v for k, v in baseline.items() if k != 'trace_header_sha256'}
        for name, b in (('older header', baseline | {'trace_header_sha256': 'old'}), ('no header', headerless)):
            with self.subTest(baseline=name):
                self.assertTrue(all(check_core_pins(trace, b, MANIFEST).values()))
                self.assertTrue(verify(trace, b, MANIFEST)['checks']['trace_header_matches_receipt'])

    def test_dialogue_traces_from_before_the_header_receipt_may_omit_it(self):
        trace, baseline = audio_pair()
        legacy = {k: v for k, v in trace.items() if k != 'trace_header_sha256'}
        self.assertTrue(all(check_core_pins(legacy, baseline, MANIFEST, require_header=False).values()))
        self.assertFalse(all(check_core_pins(trace | {'trace_header_sha256': 'old'}, baseline, MANIFEST,
                                             require_header=False).values()))
        self.assertIn('require_header=False', (ROOT / 'tools/verify_pc_dialogue.py').read_text())

    def test_every_parity_verifier_merges_the_pin_checks(self):
        for name in ('verify_pc_audio_trace', 'verify_pc_text_trace', 'verify_pc_dialogue', 'verify_pc_driver_overlay'):
            with self.subTest(tool=name):
                source = (ROOT / 'tools' / f'{name}.py').read_text()
                self.assertIn('check_core_pins(', source.split('def check_core_pins', 1)[-1])
        self.assertIn('verify_audio(trace,baseline,manifest)', (ROOT / 'tools/verify_pc_readiness.py').read_text())


class LoopChannelTests(unittest.TestCase):
    LOOP_CHECKS = ('engine_idle_channel_present', 'turret_persists_on_key_release', 'turret_original_deceleration_tail',
                   'mute_and_pause_preserve_silent_engine_state')

    def test_complete_loop_states_pass(self):
        checks = verify(*audio_pair(), MANIFEST)['checks']
        for name in ('audio_states_present', 'original_sound_channel_states_identical', *self.LOOP_CHECKS,
                     'modes_trace_and_baseline', 'core_pins_distinct_and_match_receipt'):
            self.assertTrue(checks[name], name)

    def test_missing_states_fail_instead_of_skipping(self):
        trace, baseline = audio_pair()
        for t, b in ((trace | {'audio_states': []}, baseline), ({k: v for k, v in trace.items() if k != 'audio_states'}, baseline),
                     (trace, baseline | {'audio_states': []})):
            with self.subTest(trace_states=bool(t.get('audio_states')), baseline_states=bool(b.get('audio_states'))):
                self.assertFalse(verify(t, b, MANIFEST)['checks']['audio_states_present'])

    def test_renamed_stage_is_not_a_vacuous_pass(self):
        for stage, check in (('baseline', 'engine_idle_channel_present'), ('turn-coast', 'turret_persists_on_key_release'),
                             ('turret-stopped', 'turret_original_deceleration_tail'),
                             ('muted', 'mute_and_pause_preserve_silent_engine_state'),
                             ('paused', 'mute_and_pause_preserve_silent_engine_state')):
            trace, baseline = audio_pair()
            for row in trace['audio_states']:
                if row['stage'] == stage: row['stage'] = stage + '-renamed'
            with self.subTest(stage=stage):
                self.assertFalse(verify(trace, baseline, MANIFEST)['checks'][check])

    def test_legacy_reports_need_the_explicit_flag(self):
        trace, baseline = audio_pair()
        trace['audio_states'] = baseline['audio_states'] = []
        self.assertNotIn('engine_idle_channel_present', verify(trace, baseline, MANIFEST, legacy_no_loop_states=True)['checks'])
        self.assertFalse(verify(trace, baseline, MANIFEST)['checks']['engine_idle_channel_present'])

    def test_readiness_refuses_reports_without_loop_states(self):
        from tools.verify_pc_readiness import verify as verify_readiness
        trace, baseline = audio_pair()
        trace['audio_states'] = []
        with self.assertRaisesRegex(ValueError, 'readiness requires original loop-channel audio_states'):
            verify_readiness(trace, baseline, MANIFEST)


class OptimisedRuntimeTests(unittest.TestCase):
    def test_gates_do_not_depend_on_assert(self):
        # `python -O` strips assert; a stripped gate must not turn a failure into exit 0.
        for name in ('verify_pc_held_inputs', 'verify_pc_save_states', 'build_player_reference'):
            with self.subTest(tool=name):
                tree = ast.parse((ROOT / 'tools' / f'{name}.py').read_text())
                self.assertEqual([n.lineno for n in ast.walk(tree) if isinstance(n, ast.Assert)], [])

    def test_held_inputs_exit_status_is_the_reported_verdict(self):
        main = (ROOT / 'tools/verify_pc_held_inputs.py').read_text().split('def main():', 1)[1]
        self.assertIn("'passed':passed,", main)
        self.assertIn('return 0 if passed else 1', main)


if __name__ == '__main__':
    unittest.main()
