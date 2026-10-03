import ast
import importlib.util
from pathlib import Path
import unittest
from unittest import mock
from tools.pc_materials import material_pattern, material_pixel

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / 'artifacts/pc-scanout-trace-02/first-render.bin'


class MaterialTests(unittest.TestCase):
    def test_solid_span_uses_low_byte_without_unintended_black_dither(self):
        self.assertEqual(material_pattern([7, 7]), [7, 7, 7, 7])
        self.assertEqual(material_pattern([0x0102, 0x0102]), [2, 2, 2, 2])

    def test_original_parity_is_in_framebuffer_coordinates(self):
        self.assertEqual(material_pattern([0x0700, 0x0007]), [0, 7, 7, 0])
        self.assertEqual(material_pattern([0x0807, 0x0708]), [7, 8, 8, 7])
        self.assertEqual(material_pixel([0x0700, 0x0007], 32, 13), 7)
        self.assertEqual(material_pixel([0x0700, 0x0007], 33, 13), 0)


    def test_original_oracles_fail_closed_without_asserts(self):
        # `python -O` strips assert; oracle checks must raise so fixtures are never written unchecked.
        for path in sorted((ROOT / 'tools').glob('*oracle*.py')):
            tree = ast.parse(path.read_text())
            self.assertFalse(any(isinstance(n, ast.Assert) for n in ast.walk(tree)), path.name)

    @unittest.skipUnless(importlib.util.find_spec('unicorn') and (ROOT / 'GAME/SIM.EXE').exists() and CAPTURE.exists(),
                         'Requires unicorn, the original SIM.EXE and the local scanout capture')
    def test_material_oracle_detects_a_silent_solid_white_span(self):
        from tools import pc_material_oracle as oracle
        from unicorn.x86_const import UC_X86_REG_AX, UC_X86_REG_DX
        original = oracle.run_until
        def skip_white(m, *args):
            if m.reg_read(UC_X86_REG_AX) == m.reg_read(UC_X86_REG_DX) == 0x000F: return
            return original(m, *args)
        with mock.patch.object(oracle, 'run_until', skip_white), self.assertRaisesRegex(ValueError, r'^material 15,'):
            oracle.verify(CAPTURE.read_bytes())


if __name__ == '__main__': unittest.main()
