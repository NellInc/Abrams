#!/usr/bin/env python3
"""Stage the pinned Pyodide runtime and authored Python observer for local Web QA.

The resulting directory contains code only. Original game data is supplied by
each visitor and never copied into this package.
"""
from pathlib import Path
import io
import shutil
import sys
import zipfile


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
PYODIDE = ROOT / '.runtime/pyodide/node_modules/pyodide'
OUTPUT = ROOT / 'web-prototype/.generated'
NAMES = (
    'pyodide.mjs', 'pyodide.asm.js', 'pyodide.asm.wasm', 'python_stdlib.zip',
    'pyodide-lock.json',
    'pillow-11.3.0-cp313-cp313-pyemscripten_2025_0_wasm32.whl',
)


def write_source_archive(stream) -> None:
    """Write python-source.zip: the observer and the desktop tools it reuses."""
    with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('tools/__init__.py', '')
        for source in sorted((ROOT / 'tools').glob('*.py')):
            archive.write(source, 'tools/' + source.name)
        for source in sorted((ROOT / 'godot/data').glob('*.json')):
            archive.write(source, 'godot/data/' + source.name)
        archive.write(ROOT / 'web-prototype/browser_observer.py', 'browser_observer.py')


def main():
    if sys.argv[1:] == ['--source-zip-stdout']:
        # Integration tests consume the working-tree observer without
        # replacing the generated site input.
        buffer = io.BytesIO()
        write_source_archive(buffer)
        sys.stdout.buffer.write(buffer.getvalue())
        return
    if sys.argv[1:]:
        raise SystemExit('usage: build_observer.py [--source-zip-stdout]')
    if not all((PYODIDE / name).is_file() for name in NAMES):
        raise SystemExit('Install pinned Pyodide 0.29.5 and Pillow into .runtime/pyodide first')
    target = OUTPUT / 'pyodide'
    target.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        _cc_copy2(PYODIDE / name, target / name)
    with (OUTPUT / 'python-source.zip').open('wb') as stream:
        write_source_archive(stream)
    print('Staged self-hosted Pyodide and observer source without original game files')


if __name__ == '__main__':
    main()
