"""STATUS damage catalog masks and output boundaries."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from PIL import Image
from tools.pc_instrument_damage_catalog import difference_mask

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools/pc_instrument_damage_catalog.py'
SOURCE = ROOT / 'artifacts/finish-20260928/status-damage-oracle-02'
CATALOG = ROOT / 'local-art/genesis/status-damage-v1'


class DamageCatalogTests(unittest.TestCase):
    def test_difference_mask_marks_any_channel_change_exactly(self):
        base = Image.new('RGB', (6, 4), (10, 20, 30))
        patch = Image.new('RGB', (2, 2), (10, 20, 30))
        patch.putpixel((1, 0), (10, 20, 31))  # a one-step blue change must count
        patch.putpixel((0, 1), (11, 20, 30))
        mask = difference_mask(patch, base, 3, 1)
        self.assertEqual((mask.mode, mask.size), ('L', (2, 2)))
        self.assertEqual(list(mask.getdata()), [0, 255, 255, 0])
        with self.assertRaisesRegex(ValueError, 'outside the original STATUS image'):
            difference_mask(patch, base, 5, 0)

    def test_outputs_inside_original_sources_are_refused(self):
        for flag in ('--out', '--pngs', '--source'):
            with self.subTest(flag=flag):
                result = subprocess.run([sys.executable, str(TOOL), flag, str(ROOT / 'game/derived')],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('outside original sources', result.stderr)

    @unittest.skipUnless(SOURCE.is_dir() and (SOURCE / 'state-00.png').exists()
                         and (CATALOG / 'manifest.json').exists() and (ROOT / 'GAME').is_dir(),
                         'local oracle fixtures and authored catalog required')
    def test_rebuild_reproduces_catalog_and_godot_fixture_pngs(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'oracle'; source.mkdir()
            for path in SOURCE.glob('*-[0-9][0-9].bin'): shutil.copy(path, source)
            out = Path(tmp) / 'catalog'; out.mkdir()
            for i in range(5): shutil.copy(CATALOG / f'damage-{i}.png', out)
            subprocess.run([sys.executable, str(TOOL), '--source', str(source), '--out', str(out)],
                           check=True, capture_output=True)
            for name in [f'difference-{i}.png' for i in range(5)] + ['manifest.json']:
                self.assertEqual((out / name).read_bytes(), (CATALOG / name).read_bytes(), name)
            # By default the PNGs land beside the .bin fixtures, where the Godot
            # STATUS damage and Tactical HUD tests load them.
            for name in [f'{kind}-{bits:02}.png' for kind in ('state', 'tags') for bits in range(32)]:
                self.assertEqual((source / name).read_bytes(), (SOURCE / name).read_bytes(), name)
            pngs = Path(tmp) / 'pngs'
            subprocess.run([sys.executable, str(TOOL), '--source', str(source), '--out', str(out),
                            '--pngs', str(pngs)], check=True, capture_output=True)
            self.assertEqual((pngs / 'state-31.png').read_bytes(), (SOURCE / 'state-31.png').read_bytes())

if __name__ == '__main__': unittest.main()
