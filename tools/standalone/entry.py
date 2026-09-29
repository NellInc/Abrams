"""Frozen runtime entry. Gameplay modules remain in the verified versioned kit."""
# These runtime libraries are intentionally collected; no globally installed
# Python or Pillow is consulted by the frozen executable.
import argparse, ast, base64, collections, contextlib, ctypes, dataclasses
import datetime, functools, hashlib, importlib, io, itertools, json
import math, os, pathlib, platform, re, runpy, select, shutil, stat, struct
import subprocess, sys, tempfile, time, traceback, typing, wave, zipfile, zlib
from PIL import Image, PngImagePlugin
if os.name == "nt":
    import msvcrt
else:
    import fcntl


def bundle_path():
    parents=list(pathlib.Path(sys.executable).resolve().parents)
    # macOS keeps its manifest inside Resources, below the actual app root.
    # Prefer the enclosing app before considering portable-folder manifests.
    for parent in parents:
        if parent.suffix=='.app':return parent
    for parent in parents:
        if (parent/'RUNTIME.json').is_file():return parent
    raise RuntimeError('Run this helper from its Abrams application bundle')


def main():
    bundle=bundle_path()
    resources=bundle/'Contents/Resources' if bundle.suffix == '.app' else bundle
    args=sys.argv[1:]
    if args and args[0]=='-u':args=args[1:]
    if args and args[0] == '--launcher':
        script=resources/'kit/tools/standalone/portable_launcher.py'
        sys.path.insert(0,str(resources/'kit'))
        sys.argv=[str(script),'--bundle',str(bundle),*args[1:]]
    elif args and args[0].endswith('pc_bridge_host.py'):
        script=pathlib.Path(args[0]).resolve()
        expected=resources/'kit/tools/pc_bridge_host.py'
        if script.name!='pc_bridge_host.py' or script.parent.name!='tools' or script.read_bytes()!=expected.read_bytes():
            raise RuntimeError('Unexpected bridge entry point')
        sys.path.insert(0,str(script.parents[1]))
        sys.argv=[str(script),*args[1:]]
    else:
        script=resources/'kit/tools/standalone/runtime.py'
        sys.path.insert(0,str(resources/'kit'))
        sys.argv=[str(script),'--bundle',str(bundle),*args]
    runpy.run_path(str(script),run_name='__main__')

if __name__=='__main__':main()
