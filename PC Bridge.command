#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"
BACKEND_FILES=".runtime/pc-core/abrams-trace.dylib .runtime/pc-core/abrams-trace.json"
BOOT=0
for arg in "$@"; do
  if [ "$arg" = "--boot" ]; then BOOT=1; fi
  if [ "$arg" = "--reference" ]; then
    BACKEND_FILES=".runtime/pc-core/dosbox_pure_libretro.dylib reference/pc-live/mission-entry/reference.state"
  fi
  if [ "$arg" = "--trace" ]; then
    BACKEND_FILES=".runtime/pc-core/abrams-trace.dylib .runtime/pc-core/abrams-trace.json artifacts/pc-source-boot-01/mission-entry/reference.state"
  fi
done
if [ "$BOOT" = 1 ]; then
  BACKEND_FILES=".runtime/pc-core/abrams-trace.dylib .runtime/pc-core/abrams-trace.json"
fi
for file in .runtime/pc-core/abrams-ref.zip $BACKEND_FILES; do
  if [ ! -f "$file" ]; then
    printf 'Local research dependency missing: %s\nSee docs/pc-live-bridge.md.\n' "$file" >&2
    exit 1
  fi
done
if [ -z "${ABRAMS_PYTHON:-}" ]; then
  if ! ABRAMS_PYTHON=$(command -v python3); then
    printf 'Python 3 was not found on PATH. Set ABRAMS_PYTHON to a Python 3 interpreter.\nSee docs/pc-live-bridge.md.\n' >&2
    exit 127
  fi
  export ABRAMS_PYTHON
fi
exec ./tools/godot.sh --script res://scripts/pc_bridge_viewer.gd -- "$@"
