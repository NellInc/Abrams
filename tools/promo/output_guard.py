"""Shared --output guard for the promo writers (run as plain scripts from tools/promo)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.source_guard import inside_source  # noqa: E402


def guarded_output(parser, path):
    """Resolved output path, or parser.error (exit 2) when it lies inside GAME/ or GENESIS/."""
    path = Path(path).resolve()
    if inside_source(path, ROOT):
        parser.error('output must be outside original sources')
    return path
