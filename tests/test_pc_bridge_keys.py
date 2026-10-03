"""Pin the keyboard contract shared by pc_keyboard.gd and the bridge host."""
from pathlib import Path
import re
import string
import unittest

from tools.pc_reference_core import KEYS
from tools.pc_bridge_host import validate_command

ROOT = Path(__file__).resolve().parents[1]
KEYBOARD = (ROOT / 'godot/scripts/pc_keyboard.gd').read_text()


def step(keys):
    return {'op': 'step', 'id': 1, 'frames': 1, 'keys': keys}


class PcBridgeKeyContractTests(unittest.TestCase):
    def test_host_accepts_sixteen_distinct_keys_and_rejects_seventeen(self):
        names = sorted(KEYS)
        validate_command(step(names[:16]))
        with self.assertRaisesRegex(ValueError, 'invalid keyboard set'):
            validate_command(step(names[:17]))
        with self.assertRaisesRegex(ValueError, 'invalid keyboard set'):
            validate_command(step(['a', 'a']))

    def test_godot_cap_matches_the_host_limit(self):
        cap = re.search(r'const MAX_KEYS := (\d+)', KEYBOARD)
        self.assertIsNotNone(cap)
        self.assertEqual(int(cap.group(1)), 16)
        names = sorted(KEYS)
        validate_command(step(names[:int(cap.group(1))]))
        with self.assertRaises(ValueError):
            validate_command(step(names[:int(cap.group(1)) + 1]))

    def test_every_name_godot_can_encode_is_a_host_key(self):
        special = re.search(r'const SPECIAL = \{(.*?)\}', KEYBOARD, re.S)
        self.assertIsNotNone(special)
        names = set(re.findall(r'KEY_\w+: "(\w+)"', special.group(1)))
        # encode(): letters lower-cased, digits, kp0-kp9, f1-f12.
        for pattern in (r'KEY_A and key <= KEY_Z', r'KEY_0 and key <= KEY_9', r'KEY_KP_0 and key <= KEY_KP_9', r'KEY_F1 and key <= KEY_F12'):
            self.assertRegex(KEYBOARD, pattern)
        names |= set(string.ascii_lowercase) | set(string.digits)
        names |= {f'kp{i}' for i in range(10)} | {f'f{i}' for i in range(1, 13)}
        self.assertEqual(names, set(KEYS))


if __name__ == '__main__':
    unittest.main()
