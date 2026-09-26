#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"
for file in .runtime/pc-core/dosbox_pure_libretro.dylib .runtime/pc-core/abrams-ref.zip reference/pc-live/mission-entry/reference.state; do
  if [ ! -f "$file" ]; then
    printf 'Local research dependency missing: %s\nSee docs/pc-live-bridge.md.\n' "$file" >&2
    exit 1
  fi
done
if [ -z "${ABRAMS_PYTHON:-}" ]; then
  ABRAMS_PYTHON=$(command -v python3)
  export ABRAMS_PYTHON
fi
exec ./tools/godot.sh --script res://scripts/pc_bridge_viewer.gd -- "$@"
