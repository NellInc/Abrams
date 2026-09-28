from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, call

from tools.verify_pc_endurance import BoundedClient, percentile, native_rss_kib, source_hashes


class EnduranceGateTests(unittest.TestCase):
    def test_percentiles_are_defined_for_empty_and_small_sets(self):
        self.assertIsNone(percentile([], .95))
        self.assertEqual(percentile([3], .95), 3)
        self.assertEqual(percentile([3, 1, 2], .5), 2)

    def test_memory_sample_excludes_unrelated_processes(self):
        rows = '1 0 999\n10 1 100\n11 10 200\n12 11 300\n20 1 9999\n'
        with patch('tools.verify_pc_endurance.subprocess.check_output', return_value=rows):
            self.assertEqual(native_rss_kib(10), 600)

    def test_sources_detect_added_and_modified_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'GAME').mkdir(); (root/'GENESIS').mkdir()
            (root/'GAME/TEST').write_bytes(b'first')
            with patch('tools.verify_pc_endurance.ROOT', root):
                first = source_hashes()
                (root/'GAME/TEST').write_bytes(b'second')
                self.assertNotEqual(source_hashes(), first)
                first = source_hashes()
                (root/'GENESIS/NEW').write_bytes(b'added')
                self.assertNotEqual(source_hashes(), first)

    def test_long_fixture_steps_keep_inputs_and_respect_transport_limit(self):
        client = BoundedClient.__new__(BoundedClient)
        with patch('tools.verify_pc_endurance.Client.step', side_effect=[{'sequence': 600}, {'sequence': 1200}, {'sequence': 1201}]) as step:
            self.assertEqual(client.step(1201, ['return'])['sequence'], 1201)
            self.assertEqual(step.call_args_list, [call(600, ['return']), call(600, ['return']), call(1, ['return'])])
        with self.assertRaises(ValueError):
            client.step(0)

    def test_native_reply_buffer_preserves_multiple_packets(self):
        client = BoundedClient.__new__(BoundedClient)
        client.buffer = b'{"type":"sample","id":1}\n{"type":"sample","id":2}\n'
        self.assertEqual(client.read()['id'], 1)
        self.assertEqual(client.read()['id'], 2)

    def test_native_error_is_not_reported_as_completion(self):
        client = BoundedClient.__new__(BoundedClient)
        client.buffer = b'{"type":"error","message":"core failed"}\n'
        with self.assertRaisesRegex(RuntimeError, 'core failed'):
            client.read()


if __name__ == '__main__':
    unittest.main()
