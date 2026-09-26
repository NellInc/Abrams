#!/bin/sh
# Local source/test gate; captured visual review remains a separate check.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
OUT="artifacts/validation-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
run_check() {
  name=$1
  shift
  if "$@" > "$OUT/$name.log" 2>&1; then
    if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (engine error despite successful process exit)" >&2
      exit 1
    fi
    cat "$OUT/$name.log"
    printf 'PASS %s\n' "$name" >> "$OUT/results.txt"
  else
    rc=$?
    cat "$OUT/$name.log"
    printf 'FAIL %s exit=%s\n' "$name" "$rc" >> "$OUT/results.txt"
    exit "$rc"
  fi
}
run_check reference python3 -m unittest discover -s tests -v
run_check preservation python3 tools/reference_inventory.py --verify
run_check simulation ./tools/godot.sh --headless --script res://tests/test_simulation.gd
run_check geometry ./tools/godot.sh --headless --script res://tests/test_geometry.gd
run_check runtime ./tools/godot.sh --headless --verbose -- --smoke-test
printf 'VALIDATION_COMPLETE %s\n' "$OUT"
