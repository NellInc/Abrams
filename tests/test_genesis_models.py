import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

from tools.extract_genesis_models import (ROM_HASH, canonical_cycle, command,
    compare_pc, decode_models, export_models, neutral_geometry, obj, program)

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md"
CAPTURE = ROOT / "reference/genesis/instruments/gunner"


class GenesisModelGrammarTests(unittest.TestCase):
    def test_signed_literal_vertices_and_register_range(self):
        raw = bytes([4, 3, 1, 54]) + struct.pack(">hhh", -32768, 32767, -7) + b'\xf0'
        c = command(raw, 0)
        self.assertEqual(c["vertices"], [[-32768, 32767, -7]])
        self.assertEqual((c["destination"], c["count"], c["matrix"], c["end"]), (3, 1, 54, 10))

    def test_malformed_commands_fail_closed(self):
        for raw in [b'', b'\xff', b'\x04\x00\x00\x00', b'\x04\xff\x02\x00',
                    b'\x04\x00\x01\x00', b'\xec\x07\x01\x00', b'\xec\x08\x00\x00',
                    b'\x58\xff\x02', b'\xa0\x10\x02\x00\x01', b'\x74\x7f\xff']:
            with self.subTest(raw=raw.hex()), self.assertRaises(ValueError):
                command(raw, 0)

    def test_jump_uses_postincremented_word_base_and_keeps_shared_program(self):
        raw = b'\x74\x00\x01\xff\x0c\xf0'
        commands = program(raw, 0)
        self.assertEqual([c["offset"] for c in commands], [0, 4, 5])
        self.assertEqual(commands[0]["targets"], [4])

    def test_branch_into_an_operand_is_rejected(self):
        raw = b'\x68\x00\xff\xff\xff\xfb\xf0'
        with self.assertRaisesRegex(ValueError, 'Overlapping'):
            program(raw, 0)

    def test_conditional_polygon_and_sort_keep_source_semantics(self):
        raw = b'\xb0\x04\x25\x03\x00\x02\x01\xf0'
        c = command(raw, 0)
        self.assertEqual((c["condition_flag"], c["material"], c["indices"]), (4, 37, [0, 2, 1]))
        raw = bytes([0xec, 8, 1, 5]) + struct.pack('>iH', 3, 17) + b'\xf0\xf0'
        c = command(raw, 0)
        self.assertEqual(c["groups"], [{"target": 11, "sort_vertex": 17}])
        self.assertEqual(c["successors"], [10, 11])

    def test_topology_comparison_ignores_start_corner_and_reversal_only(self):
        a = [[1, 0, 0], [2, 1, 0], [3, 2, 0], [4, 3, 0]]
        self.assertEqual(canonical_cycle(a), canonical_cycle(a[2:] + a[:2]))
        self.assertEqual(canonical_cycle(a), canonical_cycle(a[::-1]))
        self.assertNotEqual(canonical_cycle(a), canonical_cycle([a[0], a[2], a[1], a[3]]))


@unittest.skipUnless(ROM.exists(), "Requires the user's local Genesis ROM")
class LocalGenesisModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rom = ROM.read_bytes()
        cls.catalog = decode_models(cls.rom)

    def test_fingerprint_and_corrupted_version_rejection(self):
        self.assertEqual(hashlib.sha256(self.rom).hexdigest(), ROM_HASH)
        with self.assertRaisesRegex(ValueError, 'Unrecognized'):
            decode_models(self.rom[:-1] + bytes([self.rom[-1] ^ 1]))

    def test_complete_class_program_graph_and_shared_replacements(self):
        models = self.catalog['models']
        self.assertEqual([m['index'] for m in models], list(range(115, 168)))
        self.assertEqual(len(self.catalog['directory']), 188)
        self.assertEqual(len({c['offset'] for m in models for c in m['commands']}), 1423)
        self.assertEqual(len({c['offset'] for m in models for c in m['commands'] if c['opcode'] == 4}), 34)
        jumps = [c for m in models for c in m['commands'] if c['opcode'] == 0x74]
        self.assertEqual(len(jumps), 19)
        self.assertTrue(all(c['targets'] == [0x56980] for c in jumps))
        for m in models:
            boundaries = {c['offset'] for c in m['commands']}
            for c in m['commands']:
                self.assertTrue(set(c['successors']) <= boundaries)
                self.assertEqual(bytes.fromhex(c['hex']), self.rom[c['offset']:c['end']])

    def test_pc_topology_and_material_correspondence_is_bounded(self):
        report = compare_pc(self.catalog['models'], ROOT / 'GAME/SHAPE.TBL')
        self.assertEqual(report['source_sha256'], '81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193')
        self.assertEqual(len(report['models']), 54)
        matched = [m for m in report['models'] if m['index'] != 159]
        self.assertEqual(len(matched), 52)
        self.assertEqual(sum(m['matching_unique_polygons'] for m in matched), 585)
        for m in matched:
            self.assertFalse(m['pc_vertices_absent'])
            self.assertFalse(m['pc_polygons_absent'])
            self.assertFalse(m['genesis_extra_polygons'])
            self.assertTrue(all(p['material_plus_16_matches'] for p in m['polygon_links']))
        for m in report['models']:
            if m['index'] == 159:
                self.assertTrue(m['pc_vertices_absent'])
                self.assertTrue(m['pc_polygons_absent'])

    def test_truck_retains_both_construction_paths(self):
        m = next(m for m in self.catalog['models'] if m['index'] == 159)
        low, high = m['poses']
        self.assertEqual([len(p['vertices']) for p in m['poses']], [52, 69])
        self.assertEqual(low['vertices'][0], [44, -39, -79])
        self.assertEqual(high['vertices'][0], [44, -39, -79])
        self.assertEqual(len(low['unmeshed_commands']), 12)
        self.assertEqual(high['unmeshed_commands'], [])
        self.assertNotEqual(low['construction_path'], high['construction_path'])
        self.assertEqual(sum(len(m['poses']) for m in self.catalog['models']), 54)

    def test_obj_excludes_normals_and_keeps_source_face_order(self):
        for m in self.catalog['models']:
            for pose in m['poses']:
                rows = obj(m, pose, 'source.mtl').splitlines()
                used = {i for p in pose['polygons'] + pose['lines'] for i in p['indices']}
                self.assertEqual(sum(s.startswith('v ') for s in rows), len(used))
                self.assertEqual(sum(s.startswith('f ') for s in rows), len(pose['polygons']))
                self.assertEqual(sum(s.startswith('l ') for s in rows), len(pose['lines']))

    @unittest.skipUnless(CAPTURE.exists(), "Requires native Genesis palette capture")
    def test_export_roundtrip_hashes_palette_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'models'
            result = export_models(ROM, CAPTURE, output)
            self.assertEqual(len(result['models']), 53)
            self.assertEqual(len(list(output.glob('*.obj'))), 54)
            self.assertEqual(len(result['materials']), 16)
            for path, sha in result['files'].items():
                self.assertEqual(hashlib.sha256((output / path).read_bytes()).hexdigest(), sha)
            for m in result['models']:
                stored = json.loads((output / f"shape-{m['index']:03d}.json").read_text())
                self.assertEqual(stored['commands'], m['commands'])
            with self.assertRaises(FileExistsError):
                export_models(ROM, CAPTURE, output)
            self.assertEqual(hashlib.sha256(ROM.read_bytes()).hexdigest(), ROM_HASH)


if __name__ == '__main__':
    unittest.main()
