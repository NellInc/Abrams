"""STATUS damage catalog masks and output boundaries."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from PIL import Image
from tools.pc_instrument_damage_catalog import difference_mask


# --- clone-first copies: APFS clones on macOS, plain shutil elsewhere (rule: "Reference inputs; clone, never copy") ---
import shutil as _cc_shutil


def _cc_build():
    import ctypes
    import os
    import sys

    names = ('copyfile', 'copy', 'copy2', 'copytree')
    orig = {n: getattr(_cc_shutil, n) for n in names}
    clonefile = None
    if sys.platform == 'darwin':
        try:
            clonefile = ctypes.CDLL(None, use_errno=True).clonefile
            clonefile.argtypes = (ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32)
            clonefile.restype = ctypes.c_int
        except (OSError, AttributeError):
            clonefile = None
    umask = os.umask(0)
    os.umask(umask)

    def clone(name, src, dst, follow):
        # Clone only when shutil is unpatched, src is a regular file and dst does not exist yet; else plain shutil.
        if clonefile is None or any(getattr(_cc_shutil, n) is not orig[n] for n in names):
            return False  # a test has patched shutil: let the patched function handle it
        if os.path.lexists(dst) or not (os.path.isfile(src) and (follow or not os.path.islink(src))):
            return False
        if clonefile(os.fsencode(src), os.fsencode(dst), 0 if follow else 1) != 0:
            return False
        os.chflags(dst, 0, follow_symlinks=False)  # clones inherit the source's flags (e.g. uchg)
        if name == 'copy2':
            _cc_shutil.copystat(src, dst, follow_symlinks=follow)
        else:
            if name == 'copy':
                _cc_shutil.copymode(src, dst, follow_symlinks=follow)
            else:
                os.chmod(dst, 0o666 & ~umask)
            os.utime(dst, None)
        return True

    def copyfile(src, dst, *, follow_symlinks=True):
        if clone('copyfile', src, dst, follow_symlinks):
            return dst
        return getattr(_cc_shutil, 'copyfile')(src, dst, follow_symlinks=follow_symlinks)

    def make(name):
        def copier(src, dst, *, follow_symlinks=True):
            target = os.path.join(dst, os.path.basename(src)) if os.path.isdir(dst) else dst
            if clone(name, src, target, follow_symlinks):
                return target
            return getattr(_cc_shutil, name)(src, dst, follow_symlinks=follow_symlinks)
        return copier

    copy, copy2 = make('copy'), make('copy2')
    mapped = {orig['copy2']: copy2, orig['copy']: copy, orig['copyfile']: copyfile}

    def copytree(src, dst, *args, **kwargs):
        patched = any(getattr(_cc_shutil, n) is not orig[n] for n in names)
        if len(args) < 3 and not patched:  # copy_function not passed positionally; shutil not patched by a test
            fn = kwargs.get('copy_function', orig['copy2'])
            kwargs['copy_function'] = mapped.get(fn, fn)
        return getattr(_cc_shutil, 'copytree')(src, dst, *args, **kwargs)

    return copyfile, copy, copy2, copytree


_cc_copyfile, _cc_copy, _cc_copy2, _cc_copytree = _cc_build()
# --- end clone-first copies ---


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
            for path in SOURCE.glob('*-[0-9][0-9].bin'): _cc_copy(path, source)
            out = Path(tmp) / 'catalog'; out.mkdir()
            for i in range(5): _cc_copy(CATALOG / f'damage-{i}.png', out)
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
