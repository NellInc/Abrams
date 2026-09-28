"""Frozen runtime entry. Gameplay modules remain in the verified versioned kit."""
# These runtime libraries are intentionally collected; no globally installed
# Python or Pillow is consulted by the frozen executable.
import argparse, ast, base64, collections, contextlib, ctypes, dataclasses
import datetime, fcntl, functools, hashlib, importlib, io, itertools, json
import math, os, pathlib, platform, re, runpy, select, shutil, stat, struct
import subprocess, sys, tempfile, time, traceback, typing, wave, zipfile, zlib
from PIL import Image, PngImagePlugin


def bundle_path():
    for parent in pathlib.Path(sys.executable).resolve().parents:
        if parent.suffix=='.app':return parent
    raise RuntimeError('Run this helper from its Abrams application bundle')


def main():
    bundle=bundle_path()
    resources=bundle/'Contents/Resources'
    args=sys.argv[1:]
    if args and args[0]=='-u':args=args[1:]
    if args and args[0].endswith('pc_bridge_host.py'):
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
