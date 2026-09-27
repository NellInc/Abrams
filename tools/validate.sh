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
run_check pc_rules ./tools/godot.sh --headless --script res://tests/test_pc_rules.gd
run_check pc_world ./tools/godot.sh --headless --script res://tests/test_pc_world_view.gd
run_check pc_keyboard ./tools/godot.sh --headless --script res://tests/test_pc_keyboard.gd
run_check pc_camera ./tools/godot.sh --headless --script res://tests/test_pc_camera.gd
run_check pc_draw_pass ./tools/godot.sh --headless --script res://tests/test_pc_draw_pass.gd
run_check pc_surfaces ./tools/godot.sh --headless --script res://tests/test_pc_surfaces.gd
run_check pc_colour ./tools/godot.sh --headless --script res://tests/test_pc_colour.gd
run_check pc_sprites ./tools/godot.sh --headless --script res://tests/test_pc_sprites.gd
run_check pc_tandem_frame ./tools/godot.sh --headless --script res://tests/test_pc_tandem_frame.gd
run_check pc_plate_art ./tools/godot.sh --headless --script res://tests/test_pc_plate_art.gd
run_check pc_genesis_style ./tools/godot.sh --headless --script res://tests/test_pc_genesis_style.gd
run_check pc_terrain_style ./tools/godot.sh --headless --script res://tests/test_pc_terrain_style.gd
run_check pc_cockpit_art ./tools/godot.sh --headless --script res://tests/test_pc_cockpit_art.gd
run_check pc_genesis_cockpits ./tools/godot.sh --headless --script res://tests/test_pc_genesis_cockpits.gd
run_check pc_portrait_art ./tools/godot.sh --headless --script res://tests/test_pc_portrait_art.gd
run_check pc_typography ./tools/godot.sh --headless --script res://tests/test_pc_typography.gd
run_check geometry ./tools/godot.sh --headless --script res://tests/test_geometry.gd
run_check audio ./tools/godot.sh --headless --script res://tests/test_audio.gd
run_check pc_audio ./tools/godot.sh --headless --script res://tests/test_pc_audio.gd
run_check audio_shutdown ./tools/godot.sh --headless --verbose --script res://tests/test_audio_shutdown.gd
run_check runtime ./tools/godot.sh --headless --verbose -- --smoke-test
printf 'VALIDATION_COMPLETE %s\n' "$OUT"
