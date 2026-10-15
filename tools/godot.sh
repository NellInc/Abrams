#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# The pinned checkout engine wins over whatever Godot happens to be on PATH;
# tools/validate.sh also refuses an untested version.
if [ -n "${GODOT_BIN:-}" ]; then
  BIN=$GODOT_BIN
elif [ -x "$ROOT/.runtime/Godot.app/Contents/MacOS/Godot" ]; then
  BIN="$ROOT/.runtime/Godot.app/Contents/MacOS/Godot"
elif command -v godot >/dev/null 2>&1; then
  BIN=$(command -v godot)
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
  BIN=/Applications/Godot.app/Contents/MacOS/Godot
else
  echo 'Godot 4 is required. Set GODOT_BIN to its executable.' >&2
  exit 127
fi
exec "$BIN" --path "$ROOT/godot" "$@"
