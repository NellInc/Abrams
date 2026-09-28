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
    if [ "$name" = pc_intro_art ] && ! grep -Eq '^PC_INTRO_ART: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_information_art ] && ! grep -Eq '^PC_INFORMATION_ART: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_frontend_art ] && ! grep -Eq '^PC_FRONTEND_ART: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_motor_pool_art ] && ! grep -Eq '^PC_MOTOR_POOL_ART: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_menu_text ] && ! grep -Eq '^PC_MENU_TEXT: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_world_bearing ] && ! grep -Eq '^PC_WORLD_BEARING: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_orientation ] && ! grep -Eq '^PC_ORIENTATION: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_play_display ] && ! grep -Eq '^PC_PLAY_DISPLAY: [1-9][0-9]* checks, 0 errors;' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_frame_pacing ] && ! grep -Eq '^PC_FRAME_PACING: [1-9][0-9]* checks, 0 errors;' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_live_scheduling ] && ! grep -Eq '^PC_LIVE_SCHEDULING: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_reticle ] && ! grep -Eq '^PC_RETICLE: [1-9][0-9]* checks, 0 errors;' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_effect_art ] && ! grep -Eq '^PC_EFFECT_ART: [1-9][0-9]* checks, 0 errors;' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_hill_art ] && ! grep -Eq '^PC_HILL_ART: [1-9][0-9]* checks, 0 errors;' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_vehicle_art ] && ! grep -Eq '^PC_VEHICLE_ART: [1-9][0-9]* checks, 0 errors;' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
      exit 1
    fi
    if [ "$name" = pc_gauges ] && ! grep -Eq '^PC_GAUGES: [1-9][0-9]* checks, 0 errors$' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report completion)" >&2
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
run_check pc_play_display ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_play_display.gd
run_check pc_frame_pacing ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_frame_pacing.gd
run_check pc_live_scheduling ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_live_scheduling.gd
run_check pc_play_menu ./tools/godot.sh --headless --script res://tests/test_pc_play_menu.gd
run_check pc_graphics_modes ./tools/godot.sh --headless --script res://tests/test_pc_graphics_modes.gd
run_check pc_draw_pass ./tools/godot.sh --headless --script res://tests/test_pc_draw_pass.gd
run_check pc_surfaces ./tools/godot.sh --headless --script res://tests/test_pc_surfaces.gd
run_check pc_colour ./tools/godot.sh --headless --script res://tests/test_pc_colour.gd
run_check pc_sprites ./tools/godot.sh --headless --script res://tests/test_pc_sprites.gd
run_check pc_effect_art ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_effect_art.gd
run_check pc_tandem_frame ./tools/godot.sh --headless --script res://tests/test_pc_tandem_frame.gd
run_check pc_plate_art ./tools/godot.sh --headless --script res://tests/test_pc_plate_art.gd
run_check pc_genesis_style ./tools/godot.sh --headless --script res://tests/test_pc_genesis_style.gd
run_check pc_terrain_style ./tools/godot.sh --headless --script res://tests/test_pc_terrain_style.gd
run_check pc_hill_art ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_hill_art.gd
run_check pc_vehicle_art ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_vehicle_art.gd
run_check genesis_vehicle_studies ./tools/godot.sh --headless --script res://tests/test_genesis_vehicle_studies.gd
run_check pc_cockpit_art ./tools/godot.sh --headless --script res://tests/test_pc_cockpit_art.gd
run_check pc_genesis_cockpits ./tools/godot.sh --headless --script res://tests/test_pc_genesis_cockpits.gd
run_check pc_world_bearing ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_world_bearing.gd
run_check pc_orientation ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_orientation.gd
run_check pc_reticle ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_reticle.gd
run_check pc_gauges ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_gauges.gd
run_check pc_portrait_art ./tools/godot.sh --headless --script res://tests/test_pc_portrait_art.gd
run_check pc_frontend_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_frontend_art.gd
run_check pc_intro_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_intro_art.gd
run_check pc_motor_pool_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_motor_pool_art.gd -- --text
run_check pc_information_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_information_art.gd -- --tandem
run_check pc_typography ./tools/godot.sh --headless --script res://tests/test_pc_typography.gd
run_check pc_menu_text ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_menu_text.gd
run_check geometry ./tools/godot.sh --headless --script res://tests/test_geometry.gd
run_check audio ./tools/godot.sh --headless --script res://tests/test_audio.gd
run_check pc_audio ./tools/godot.sh --headless --script res://tests/test_pc_audio.gd
run_check pc_radio ./tools/godot.sh --headless --script res://tests/test_pc_radio.gd
run_check pc_audio_mix ./tools/godot.sh --headless --script res://tests/test_pc_audio_mix.gd
run_check pc_frontend_music ./tools/godot.sh --headless --script res://tests/test_pc_frontend_music.gd
run_check pc_remaining_audio ./tools/godot.sh --headless --script res://tests/test_pc_remaining_audio.gd
run_check audio_shutdown ./tools/godot.sh --headless --verbose --script res://tests/test_audio_shutdown.gd
run_check runtime ./tools/godot.sh --headless --verbose -- --smoke-test
printf 'VALIDATION_COMPLETE %s\n' "$OUT"
