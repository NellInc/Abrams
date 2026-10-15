"""Local-only test inputs: a missing one is a counted skip, never an ERROR.

GAME/, GENESIS/, reference/, local-art/ and artifacts/ never enter Git, so a
source-kit checkout, a contributor without captures, or a cleared artifacts/
tree must see honest skips from `python3 -m unittest discover -s tests`.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def missing(*paths):
    return [path for path in paths if not (ROOT / path).exists()]


def requires(*paths):
    """Class or test decorator: skip unless every repo-relative path exists.

    On a class it also prevents setUpClass from reading absent inputs.
    """
    absent = missing(*paths)
    return unittest.skipIf(bool(absent), 'local input missing: ' + ', '.join(absent))
