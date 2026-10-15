#!/bin/sh
# Local source/test gate; captured visual review remains a separate check.
#
# Default tier: the Python suite, pinned local fixtures, the web-prototype node
# tests, every headless Godot check and a parse of the promo capture scripts.
# Opt-in tiers, each printed as NOT RUN when skipped:
#   VALIDATE_NATIVE=1  windowed GPU checks (gl_compatibility): Modern ownership,
#                      Tactical shader includes, startup cover, frontend scenes.
#   VALIDATE_LIVE=1    checks that drive the original PC host (minutes to hours).
# Every Godot check must print its exact completion receipt; a bounded run that
# exits 0 without one fails. `tools/validate.sh --list` prints
# "tier<TAB>name<TAB>receipt<TAB>command" for every check and runs nothing.
#
# ABRAMS_PYTHON selects the interpreter (a venv with Pillow and unicorn runs the
# oracle guard subtests that plain python3 skips). VALIDATE_STRICT_SKIPS=1 fails
# on any unicorn skip; VALIDATE_MAX_SKIPS=N fails above N skipped Python tests.
# ABRAMS_ALLOW_GODOT_VERSION_MISMATCH=1 permits an engine other than 4.7.2.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
LIST=0
if [ "${1:-}" = --list ]; then LIST=1; fi
PYTHON=${ABRAMS_PYTHON:-python3}
GODOT_VERSION=4.7.2
TIER=default
OUT="artifacts/validation-$(date -u +%Y%m%dT%H%M%SZ)"
if [ "$LIST" = 0 ]; then mkdir -p "$OUT"; fi
# A GDScript runtime error before quit() leaves Godot running forever; bound every check.
CHECK_TIMEOUT=${VALIDATE_CHECK_TIMEOUT:-1200}
# A skip whose reason says unicorn itself is missing, in either unittest quote
# style. Reasons that also need local inputs ("Requires unicorn, the original
# SIM.EXE ...") or several modules ("needs ('unicorn', 'PIL')") are not counted:
# they skip under a unicorn interpreter too. tests/test_tool_guards_pinned_venv.py
# uses the same pattern.
UNICORN_SKIP="skipped ['\"].*(unicorn (unavailable|required)|pinned unicorn|needs \('unicorn',\)|\('unicorn',\) unavailable)"

# "PC_NAME: N checks, 0 errors" with an optional "; ..." or ", ..." tail, where
# PC_NAME is the check name in capitals.
counted() {
  printf '^%s: [1-9][0-9]* checks, 0 errors([,;] .*)?$' "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
}

# The exact receipt each check must print. A check without one cannot run.
receipt_for() {
  case $1 in
    reference) echo '^OK( \(skipped=[0-9]+\))?$' ;;
    gate_fixtures) echo '^GATE_FIXTURES: [1-9][0-9]* inputs, 0 problems$' ;;
    live_fixtures) echo '^GATE_FIXTURES: [1-9][0-9]* live inputs, 0 problems$' ;;
    preservation) echo '^Reference inventory verified unchanged$' ;;
    pc_audio_assets) echo '^PC_AUDIO_AUDIT: [0-9]+ WAVs, [0-9]+ source captions, 0 errors' ;;
    web_prototype_unit) echo '^OK( \(skipped=[0-9]+\))?$' ;;
    web_service_worker) echo '^# pass [1-9][0-9]*$' ;;
    web_derived_art) echo '^(PASS: visitor-derived Genesis effects match the desktop decode|SKIP: (no local desktop Genesis effects decode|Genesis derivation integration requires the local ROM))$' ;;
    web_prototype_local) echo '^(\{"stage":"step-save-load-step",|SKIP: local inputs absent )' ;;
    # --check-only exits 0 and prints only the banner even on a parse error; the
    # SCRIPT ERROR grep in run_check is the real gate, the banner proves launch.
    promo_modern_batch_parse|promo_replay_parse|promo_colonel_stills_parse) echo '^Godot Engine v[0-9]' ;;
    simulation) echo '^SIMULATION: [1-9][0-9]* checks passed$' ;;
    pc_rules) echo '^PC_RULES: 256 degree values and 256 hit-bark strings match original CPU fixture$' ;;
    pc_world) echo '^PC_WORLD_VIEW: [1-9][0-9]* original-coordinate and draw-mask checks passed$' ;;
    pc_keyboard) echo '^PC_KEYBOARD: [1-9][0-9]* original, [1-9][0-9]* physical identity cases, event layout/release and 16-key cap; 0 failures$' ;;
    pc_camera) echo '^PC_CAMERA: [1-9][0-9]* projections; maximum original-pixel error 0\.[0-9]+$' ;;
    pc_play_display) echo '^PC_PLAY_DISPLAY: [1-9][0-9]* checks, 0 errors;' ;;
    pc_frame_pacing) echo '^PC_FRAME_PACING: [1-9][0-9]* checks, 0 errors;' ;;
    pc_presentation_reuse) echo '^PC_PRESENTATION_REUSE: [1-9][0-9]* checks, 0 errors;' ;;
    pc_live_scheduling) echo '^PC_LIVE_SCHEDULING: [1-9][0-9]* checks, 0 errors$' ;;
    pc_interface_reference) echo '^PC_INTERFACE_REFERENCE: [1-9][0-9]* checks, 0 errors$' ;;
    portable_setup) echo '^PORTABLE_SETUP_RECOVERY: PASS$' ;;
    pc_graphics_modes) echo '^PC_GRAPHICS_MODES: PASS; [1-9][0-9]* checks;' ;;
    pc_modern) echo '^PC_MODERN: PASS; [1-9][0-9]* checks; native=false$' ;;
    pc_modern_mapping_reuse) echo '^PC_MODERN_MAPPING_REUSE: PASS; [1-9][0-9]* checks; [1-9][0-9]* facets; ' ;;
    pc_surfaces) echo '^PC_SURFACES: PASS; native=false$' ;;
    pc_colour) echo '^PC_COLOUR: [0-9]+ exact RGB checks; 0 failures$' ;;
    pc_sprites) echo '^PC_SPRITES: PASS; [0-9]+ native pixel checks$' ;;
    pc_effect_modes) echo '^PC_EFFECT_ART: [1-9][0-9]* checks, 0 errors; [0-9]+ native pixels$' ;;
    pc_effect_art) echo '^PC_EFFECT_ART: [1-9][0-9]* checks, 0 errors;' ;;
    pc_tandem_frame) echo '^PC_TANDEM_FRAME: PASS; ' ;;
    pc_plate_art) echo '^PC_PLATE_ART: [0-9]+ exact RGB checks, [0-9]+ changed source samples, 0 failures; [1-9][0-9]* assertions$' ;;
    pc_genesis_style) echo '^PC_GENESIS_STYLE: 0 failures; native=false$' ;;
    pc_terrain_style) echo '^PC_TERRAIN_STYLE: \{.*"checks":[1-9][0-9]*,"errors":\[\],' ;;
    pc_hill_art) echo '^PC_HILL_ART: [1-9][0-9]* checks, 0 errors;' ;;
    pc_vehicle_art) echo '^PC_VEHICLE_ART: [1-9][0-9]* checks, 0 errors;' ;;
    genesis_vehicle_studies) echo '^GENESIS_VEHICLE_STUDIES: [1-9][0-9]* checks, 0 errors$' ;;
    pc_cockpit_art) echo '^PC_COCKPIT_ART: [1-9][0-9]* checks, 0 failures$' ;;
    pc_world_bearing) echo '^PC_WORLD_BEARING: [1-9][0-9]* checks, 0 errors$' ;;
    pc_orientation) echo '^PC_ORIENTATION: [1-9][0-9]* checks, 0 errors$' ;;
    pc_reticle) echo '^PC_RETICLE: [1-9][0-9]* checks, 0 errors;' ;;
    pc_gauges) echo '^PC_GAUGES: [1-9][0-9]* checks, 0 errors$' ;;
    pc_frontend_art) echo '^PC_FRONTEND_ART: [1-9][0-9]* checks, 0 errors$' ;;
    pc_splash_aftermath) echo '^SPLASH_AFTERMATH_TEST: failures=0 entries=3$' ;;
    pc_cursor_struts) echo '^CURSOR_STRUTS: [1-9][0-9]* checks, 0 errors$' ;;
    pc_intro_art) echo '^PC_INTRO_ART: [1-9][0-9]* checks, 0 errors$' ;;
    pc_motor_pool_art|pc_motor_pool_controls_art|pc_motor_pool_arming_art) echo '^PC_MOTOR_POOL_ART: [1-9][0-9]* checks, 0 errors$' ;;
    pc_information_art) echo '^PC_INFORMATION_ART: [1-9][0-9]* checks, 0 errors$' ;;
    pc_typography) echo '^PC_TYPOGRAPHY: \{"changed":[0-9]+,"checks":[1-9][0-9]*,"errors":\[\],' ;;
    pc_menu_text) echo '^PC_MENU_TEXT: [1-9][0-9]* checks, 0 errors$' ;;
    pc_frontend_scene) echo '^PC_FRONTEND_SCENE: [1-9][0-9]* checks, 0 errors, [1-9][0-9]* selectors, 8 missions$' ;;
    geometry) echo '^GEOMETRY: 60000 upward normals and complete range bounds verified$' ;;
    audio) echo '^AUDIO: [1-9][0-9]* generated crew samples loaded with matching format, duration and captions$' ;;
    pc_audio) echo '^PC_AUDIO: [1-9][0-9]* checks, 0 failures$' ;;
    pc_radio) echo '^PC_RADIO: [1-9][0-9]* checks, 0 failures$' ;;
    audio_shutdown) echo '^AUDIO_SHUTDOWN: three live playback instances released before teardown$' ;;
    runtime) echo '^RUNTIME_SMOKE_PASS:' ;;
    pc_portrait_art|pc_cockpit_mask_reuse|pc_gunner_trim|pc_cockpit_refinement|pc_commander_trim|pc_instrument_damage|pc_instrument_status|pc_instrument_lock|pc_reticle_target|pc_newspapers|pc_wilson_completion|pc_map_art|pc_dynamic_map|pc_audio_limiter|pc_tactical_hud|pc_tactical_effects|pc_draw_pass|pc_optional_genesis|pc_play_menu|pc_render_quality|pc_play_shortcuts|pc_bridge_transport|pc_reference_search|pc_genesis_cockpits|pc_portrait_coverage|pc_audio_mix|pc_frontend_music|pc_remaining_audio)
      counted "$1" ;;
    # Native tier.
    pc_modern_native) echo '^PC_MODERN: PASS; [1-9][0-9]* checks; native=true$' ;;
    pc_modern_startup_native) echo '^PC_MODERN_STARTUP: PASS; entered_before_load=false; native=true; prewarmed=true$' ;;
    pc_modern_environment_native) echo '^PC_MODERN_ENVIRONMENT: [1-9][0-9]* checks, 0 errors$' ;;
    pc_modern_palette_native) echo '^PC_MODERN_PALETTE: [1-9][0-9]* checks, 0 errors$' ;;
    pc_modern_driver_native) echo '^PC_DRIVER_PALETTE: 0 errors$' ;;
    pc_modern_cupola_native) echo '^PASS: Modern cupola palette, ownership, fixtures and restoration$' ;;
    pc_environment_polish_native) echo '^PC_ENVIRONMENT_POLISH: [1-9][0-9]* checks, 0 errors$' ;;
    pc_tactical_*_gpu) counted "$1" ;;
    pc_startup_splash_native) echo '^PC_STARTUP_SPLASH: [1-9][0-9]* checks, 0 errors$' ;;
    pc_frontend_scene_native) echo '^PC_FRONTEND_SCENE: [1-9][0-9]* checks, 0 errors, [1-9][0-9]* selectors, 8 missions$' ;;
    # Live tier.
    pc_live_bridge) echo '^PC_LIVE_BRIDGE: original movement, stations, braking, turret, firing and child shutdown passed;' ;;
    pc_session_bridge) echo '^PC_SESSION_BRIDGE: [1-9][0-9]* stages, [0-9]+ paired worlds, [0-9]+ exact RGB checks, 0 failures, host exit 0$' ;;
    pc_audio_bridge) echo '^PC_AUDIO_NATIVE: \{.*"errors":\[\],' ;;
    pc_crew_bridge) echo '^PC_CREW_NATIVE: \{"barks":[0-9]+,"child_exit":0,"errors":\[\],' ;;
    pc_radio_bridge) echo '^PC_RADIO_NATIVE: [1-9][0-9]* checks, 3716 frames, 0 errors$' ;;
    pc_warning_bridge) echo '^PC_WARNING_NATIVE: [1-9][0-9]* checks, 1060 frames, 0 errors$' ;;
    pc_combat_outcome) echo '^PC_COMBAT_OUTCOME: [1-9][0-9]* checks, [1-9][0-9]* boundaries, 0 errors$' ;;
    pc_scenario_frames) echo '^PC_SCENARIO_FRAMES: [1-9][0-9]* checks, 32 cases, 0 errors$' ;;
    pc_conveniences) echo '^PC_CONVENIENCES: [1-9][0-9]* checks, 0 errors$' ;;
    pc_endurance) echo '^PC_ENDURANCE_NATIVE: [1-9][0-9]* checks, 0 errors, [1-9][0-9]* segments$' ;;
    pc_play_resize) echo '^PC_PLAY_RESIZE: [1-9][0-9]* samples, 0 errors$' ;;
    pc_soak) echo '^PC_SOAK: [1-9][0-9]* checks, 0 errors, ' ;;
    pc_mix_bridge) echo '^PC_MIX_BRIDGE: \{("[A-Za-z0-9_]+":true,?)+\}$' ;;
    pc_startup_viewer_early_close) echo '^PC_STARTUP_VIEWER: early-close, [1-9][0-9]* checks, 0 errors$' ;;
    pc_startup_viewer_invalid_frame) echo '^PC_STARTUP_VIEWER: invalid-frame, [1-9][0-9]* checks, 0 errors$' ;;
    pc_startup_viewer_normal) echo '^PC_STARTUP_VIEWER: normal, [1-9][0-9]* checks, 0 errors$' ;;
    *) return 1 ;;
  esac
}

# Godot harnesses under godot/tests that this gate deliberately does not run,
# each with the reason; --list prints them so a new test cannot go unnoticed.
not_run() {
  if [ "$LIST" = 1 ]; then
    printf 'manual\t%s\t-\t%s\n' "$1" "$2"
  else
    printf 'NOT RUN %s: %s\n' "$1" "$2" >> "$OUT/results.txt"
  fi
}

run_check() {
  name=$1
  shift
  if ! receipt=$(receipt_for "$name"); then
    echo "FAIL: $name (no completion receipt registered in tools/validate.sh)" >&2
    exit 1
  fi
  if [ "$LIST" = 1 ]; then
    printf '%s\t%s\t%s\t%s\n' "$TIER" "$name" "$receipt" "$*"
    return 0
  fi
  echo "RUN $name" >&2
  start=$(date +%s)
  # The pending alarm survives exec (godot.sh execs Godot), so SIGALRM ends the real process.
  if perl -e 'alarm shift; exec @ARGV or exit 127' "$CHECK_TIMEOUT" "$@" > "$OUT/$name.log" 2>&1; then
    if grep -Eq 'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:' "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (engine error despite successful process exit)" >&2
      exit 1
    fi
    if ! grep -Eq "$receipt" "$OUT/$name.log"; then
      cat "$OUT/$name.log"
      echo "FAIL: $name (bounded run did not report its completion receipt: $receipt)" >&2
      printf 'FAIL %s missing-receipt\n' "$name" >> "$OUT/results.txt"
      exit 1
    fi
    cat "$OUT/$name.log"
    printf 'PASS %s\n' "$name" >> "$OUT/results.txt"
  else
    rc=$?
    cat "$OUT/$name.log"
    if [ $(( $(date +%s) - start )) -ge "$CHECK_TIMEOUT" ]; then
      echo "FAIL: $name (timed out after ${CHECK_TIMEOUT}s; likely a GDScript runtime error before quit())" >&2
      printf 'FAIL %s timeout=%ss exit=%s\n' "$name" "$CHECK_TIMEOUT" "$rc" >> "$OUT/results.txt"
      exit 124
    fi
    printf 'FAIL %s exit=%s\n' "$name" "$rc" >> "$OUT/results.txt"
    exit "$rc"
  fi
}

# Python skips are recorded, and fail when the interpreter could have run them.
python_skips() {
  [ "$LIST" = 1 ] && return 0
  log="$OUT/reference.log"
  skipped=$(sed -n 's/^OK (skipped=\([0-9][0-9]*\))$/\1/p' "$log" | tail -n 1)
  skipped=${skipped:-0}
  unicorn=$(grep -Eci "$UNICORN_SKIP" "$log" || true)
  printf 'SKIPPED reference total=%s unicorn=%s python=%s\n' "$skipped" "$unicorn" "$PYTHON" >> "$OUT/results.txt"
  echo "reference: $skipped skipped tests ($unicorn need unicorn) under $PYTHON" >&2
  # An interpreter that has unicorn is the pinned mode: none of its tests may skip for it.
  pinned=0
  if "$PYTHON" -c 'import unicorn' >/dev/null 2>&1; then pinned=1; fi
  if [ "$unicorn" -gt 0 ]; then
    if [ "$pinned" = 1 ] || [ "${VALIDATE_STRICT_SKIPS:-0}" = 1 ]; then
      grep -Ei "$UNICORN_SKIP" "$log" >&2 || true
      echo "FAIL: reference ($unicorn unicorn-dependent tests skipped under $PYTHON)" >&2
      exit 1
    fi
    # tests/test_tool_guards_pinned_venv.py reruns the guard modules under .runtime/pc-analysis-venv.
    if grep -Eq '^test_oracle_guards_pass_under_the_pinned_venv .* \.\.\. ok$' "$log"; then
      echo "NOTE: $unicorn unicorn skips here; the guard modules passed under .runtime/pc-analysis-venv" >&2
    else
      echo "WARNING: $unicorn oracle guard tests skipped and no pinned venv rerun; set ABRAMS_PYTHON to a venv with Pillow and unicorn" >&2
    fi
  fi
  if [ -n "${VALIDATE_MAX_SKIPS:-}" ] && [ "$skipped" -gt "$VALIDATE_MAX_SKIPS" ]; then
    echo "FAIL: reference ($skipped skipped tests exceed VALIDATE_MAX_SKIPS=$VALIDATE_MAX_SKIPS)" >&2
    exit 1
  fi
}

# Exact pixel receipts are only meaningful on the tested engine.
godot_version() {
  [ "$LIST" = 1 ] && return 0
  version=$(./tools/godot.sh --version 2>/dev/null | tail -n 1)
  printf 'GODOT %s\n' "$version" >> "$OUT/results.txt"
  case $version in
    "$GODOT_VERSION".*) ;;
    *)
      if [ "${ABRAMS_ALLOW_GODOT_VERSION_MISMATCH:-0}" = 1 ]; then
        echo "WARNING: Godot '$version' is not the tested $GODOT_VERSION; receipts are not release evidence" >&2
      else
        echo "FAIL: Godot '$version' is not the tested $GODOT_VERSION (set GODOT_BIN, or ABRAMS_ALLOW_GODOT_VERSION_MISMATCH=1 for upgrade testing)" >&2
        exit 1
      fi
      ;;
  esac
}

# Live and native outputs are always fresh, never a dated evidence folder.
fresh() {
  printf '%s/%s/%s' "$ROOT" "$OUT" "$1"
}

run_check reference "$PYTHON" -m unittest discover -s tests -v
python_skips
run_check gate_fixtures "$PYTHON" -m tests.gate_fixtures --verify
run_check preservation "$PYTHON" tools/reference_inventory.py --verify
run_check pc_audio_assets "$PYTHON" tools/audit_pc_audio.py --output "$OUT/pc-audio-assets.json"
# The source kit ships only part of web-prototype/ and none of tools/promo/;
# there these checks are recorded as NOT RUN instead of failing on absent files.
# test:local and the derived-art check print SKIP lines without local inputs.
if [ "$LIST" = 1 ] || [ -f web-prototype/package.json ]; then
  run_check web_prototype_unit npm --prefix web-prototype test
  run_check web_service_worker node --test --test-reporter=tap web-prototype/test_service_worker.mjs
  run_check web_derived_art node web-prototype/test_derived_art.mjs
  run_check web_prototype_local npm --prefix web-prototype run test:local
else
  echo 'NOT RUN web-prototype checks: web-prototype/package.json absent (source kit)' >> "$OUT/results.txt"
fi
godot_version
run_check simulation ./tools/godot.sh --headless --script res://tests/test_simulation.gd
run_check pc_rules ./tools/godot.sh --headless --script res://tests/test_pc_rules.gd
run_check pc_world ./tools/godot.sh --headless --script res://tests/test_pc_world_view.gd
run_check pc_keyboard ./tools/godot.sh --headless --script res://tests/test_pc_keyboard.gd
run_check pc_camera ./tools/godot.sh --headless --script res://tests/test_pc_camera.gd
run_check pc_play_display ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_play_display.gd
run_check pc_tactical_hud ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_tactical_hud.gd
run_check pc_tactical_effects ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_tactical_effects.gd
run_check pc_frame_pacing ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_frame_pacing.gd
run_check pc_live_scheduling ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_live_scheduling.gd
run_check pc_presentation_reuse ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_presentation_reuse.gd
run_check pc_optional_genesis ./tools/godot.sh --headless --script res://tests/test_pc_optional_genesis.gd
run_check pc_play_menu ./tools/godot.sh --headless --script res://tests/test_pc_play_menu.gd
run_check pc_render_quality ./tools/godot.sh --headless --audio-driver Dummy --script res://tests/test_pc_render_quality.gd
run_check pc_play_shortcuts ./tools/godot.sh --headless --script res://tests/test_pc_play_shortcuts.gd
run_check pc_bridge_transport ./tools/godot.sh --headless --script res://tests/test_pc_bridge_transport.gd
run_check pc_interface_reference ./tools/godot.sh --headless --script res://tests/test_pc_interface_reference.gd
run_check pc_reference_search ./tools/godot.sh --headless --audio-driver Dummy --script res://tests/test_pc_reference_search.gd
run_check portable_setup ./tools/godot.sh --headless --audio-driver Dummy --script res://tests/test_portable_setup.gd
run_check pc_graphics_modes ./tools/godot.sh --headless --script res://tests/test_pc_graphics_modes.gd
run_check pc_draw_pass ./tools/godot.sh --headless --script res://tests/test_pc_draw_pass.gd
run_check pc_modern ./tools/godot.sh --headless --quit-after 3000 --script res://tests/test_pc_modern.gd
# Representative rows and one timed round by default; VALIDATE_EXHAUSTIVE=1 restores the full sweeps and benchmarks.
if [ "${VALIDATE_EXHAUSTIVE:-0}" = 1 ]; then BENCH=--bench; SWEEP=--exhaustive; else BENCH=--sampled; SWEEP=--sampled; fi
run_check pc_modern_mapping_reuse ./tools/godot.sh --headless --quit-after 12000 --script res://tests/test_pc_modern_mapping_reuse.gd -- "$BENCH"
run_check pc_cockpit_mask_reuse ./tools/godot.sh --headless --quit-after 20000 --script res://tests/test_pc_cockpit_mask_reuse.gd -- "$SWEEP"
run_check pc_surfaces ./tools/godot.sh --headless --script res://tests/test_pc_surfaces.gd
run_check pc_colour ./tools/godot.sh --headless --script res://tests/test_pc_colour.gd
run_check pc_sprites ./tools/godot.sh --headless --script res://tests/test_pc_sprites.gd
run_check pc_effect_modes ./tools/godot.sh --headless --script res://tests/test_pc_effect_modes.gd
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
run_check pc_cockpit_refinement ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_cockpit_refinement.gd
run_check pc_commander_trim ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_commander_trim.gd
run_check pc_gunner_trim ./tools/godot.sh --headless --script res://tests/test_pc_gunner_trim.gd
run_check pc_world_bearing ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_world_bearing.gd
run_check pc_orientation ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_orientation.gd
run_check pc_reticle ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_reticle.gd -- --oracle res://tests/fixtures/pc_reticle_ink.json
run_check pc_instrument_lock ./tools/godot.sh --headless --script res://tests/test_pc_instrument_lock.gd
run_check pc_instrument_damage ./tools/godot.sh --headless --script res://tests/test_pc_instrument_damage.gd
run_check pc_instrument_status ./tools/godot.sh --headless --script res://tests/test_pc_instrument_status.gd
run_check pc_reticle_target ./tools/godot.sh --headless --script res://tests/test_pc_reticle_target.gd -- --oracle res://tests/fixtures/pc_reticle_target_ink.json
run_check pc_gauges ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_gauges.gd
run_check pc_portrait_coverage ./tools/godot.sh --headless --script res://tests/test_pc_portrait_coverage.gd
run_check pc_portrait_art ./tools/godot.sh --headless --script res://tests/test_pc_portrait_art.gd
run_check pc_frontend_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_frontend_art.gd
run_check pc_frontend_scene ./tools/godot.sh --headless --audio-driver Dummy --script res://tests/test_pc_frontend_scene.gd -- --fixture "$ROOT/artifacts/intro-menu-20260930/trace/report.json"
run_check pc_newspapers ./tools/godot.sh --headless --script res://tests/test_pc_newspaper_art.gd
run_check pc_wilson_completion ./tools/godot.sh --headless --script res://tests/test_pc_wilson_completion.gd
run_check pc_splash_aftermath ./tools/godot.sh --headless --script res://tests/test_pc_splash_aftermath.gd
run_check pc_dynamic_map ./tools/godot.sh --headless --script res://tests/test_pc_dynamic_map.gd -- --live
run_check pc_cursor_struts ./tools/godot.sh --headless --script res://tests/test_pc_cursor_struts.gd
run_check pc_map_art ./tools/godot.sh --headless --script res://tests/test_pc_map_art.gd
run_check pc_intro_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_intro_art.gd
run_check pc_motor_pool_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_motor_pool_art.gd -- --text
run_check pc_motor_pool_controls_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_motor_pool_art.gd -- --text --fixture artifacts/pc-motor-pool-controls-01/report.json
run_check pc_motor_pool_arming_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_motor_pool_art.gd -- --text --fixture artifacts/pc-genesis-arming-allocations-trace-01/report.json
run_check pc_information_art ./tools/godot.sh --headless --quit-after 300 --script res://tests/test_pc_information_art.gd -- --tandem
run_check pc_typography ./tools/godot.sh --headless --script res://tests/test_pc_typography.gd
run_check pc_menu_text ./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_menu_text.gd
run_check geometry ./tools/godot.sh --headless --script res://tests/test_geometry.gd
run_check audio ./tools/godot.sh --headless --script res://tests/test_audio.gd
run_check pc_audio ./tools/godot.sh --headless --script res://tests/test_pc_audio.gd
run_check pc_radio ./tools/godot.sh --headless --script res://tests/test_pc_radio.gd
run_check pc_audio_limiter ./tools/godot.sh --headless --quit-after 10000 --script res://tests/test_pc_audio_limiter.gd
run_check pc_audio_mix ./tools/godot.sh --headless --script res://tests/test_pc_audio_mix.gd
run_check pc_frontend_music ./tools/godot.sh --headless --script res://tests/test_pc_frontend_music.gd
run_check pc_remaining_audio ./tools/godot.sh --headless --script res://tests/test_pc_remaining_audio.gd
run_check audio_shutdown ./tools/godot.sh --headless --verbose --script res://tests/test_audio_shutdown.gd
# The promo capture scripts extend pc_bridge_viewer.gd and call its private
# members; a parse catches a renamed base-class function before a capture run.
if [ "$LIST" = 1 ] || [ -d tools/promo ]; then
  for promo in modern_batch replay colonel_stills; do
    run_check "promo_${promo}_parse" ./tools/godot.sh --headless --check-only --script "$ROOT/tools/promo/$promo.gd"
  done
else
  echo 'NOT RUN promo script parses: tools/promo absent (source kit)' >> "$OUT/results.txt"
fi
run_check runtime ./tools/godot.sh --headless --verbose -- --smoke-test

TIER=native
if [ "${VALIDATE_NATIVE:-0}" = 1 ] || [ "$LIST" = 1 ]; then
  NATIVE="--rendering-method gl_compatibility --audio-driver Dummy"
  # Modern's concealment guarantee lives in the GPU ownership mask; only these runs exercise it.
  # shellcheck disable=SC2086
  run_check pc_modern_native ./tools/godot.sh $NATIVE --quit-after 1200 --script res://tests/test_pc_modern.gd -- --native --output "$(fresh native/modern)"
  # shellcheck disable=SC2086
  run_check pc_modern_startup_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_modern_startup.gd
  # shellcheck disable=SC2086
  run_check pc_modern_environment_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_modern_environment.gd -- --output "$(fresh native/modern-environment)"
  # shellcheck disable=SC2086
  run_check pc_modern_palette_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_modern_palette.gd -- --output "$(fresh native/modern-palette)"
  # shellcheck disable=SC2086
  run_check pc_modern_driver_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_modern_driver.gd -- --output "$(fresh native/modern-driver)"
  # shellcheck disable=SC2086
  run_check pc_modern_cupola_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_modern_cupola.gd -- --output "$(fresh native/modern-cupola)"
  # shellcheck disable=SC2086
  run_check pc_environment_polish_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_modern_environment_polish.gd -- --output "$(fresh native/environment-polish)"
  # The Tactical shader includes compile only in the runtime-patched surface variants.
  for contract in finishgrain diffusion groundlight optics radiance sheen bevel aerial microfinish arbor grounding horizon lighting naturalism; do
    # shellcheck disable=SC2086
    run_check "pc_tactical_${contract}_gpu" ./tools/godot.sh $NATIVE --script res://tests/test_pc_modern_environment_polish.gd -- "--${contract}-gpu" --output "$(fresh "native/tactical-$contract")"
  done
  # shellcheck disable=SC2086
  run_check pc_startup_splash_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_startup_splash.gd -- --output "$(fresh native/startup-splash)"
  # shellcheck disable=SC2086
  run_check pc_frontend_scene_native ./tools/godot.sh $NATIVE --script res://tests/test_pc_frontend_scene.gd -- --native --fixture "$ROOT/artifacts/intro-menu-20260930/trace/report.json" --output "$(fresh native/frontend-scene)"
else
  echo 'NOT RUN native tier: Modern GPU ownership/concealment, Tactical shader includes, startup cover (set VALIDATE_NATIVE=1)' >> "$OUT/results.txt"
  echo 'NOTE: native Modern ownership checks NOT run (VALIDATE_NATIVE=1 runs them)' >&2
fi

TIER=live
if [ "${VALIDATE_LIVE:-0}" = 1 ] || [ "$LIST" = 1 ]; then
  # The retained traces these checks replay are pinned like the default inputs.
  run_check live_fixtures "$PYTHON" -m tests.gate_fixtures --verify --live
  run_check pc_live_bridge ./tools/godot.sh --headless --script res://tests/test_pc_live_bridge.gd -- --trace
  run_check pc_session_bridge ./tools/godot.sh --disable-render-loop --script res://tests/test_pc_session_bridge.gd -- --native --output "$(fresh live/session)"
  run_check pc_audio_bridge ./tools/godot.sh --script res://tests/test_pc_audio_bridge.gd -- --output "$(fresh live/audio)"
  run_check pc_crew_bridge ./tools/godot.sh --script res://tests/test_pc_crew_bridge.gd -- --reference "$ROOT/artifacts/pc-crew-trace-01/report.json" --output "$(fresh live/crew)"
  run_check pc_radio_bridge ./tools/godot.sh --script res://tests/test_pc_radio_bridge.gd -- --fixture "$ROOT/artifacts/pc-radio-trace-01/report.json" --output "$(fresh live/radio)" --capture --trace --play --frame-audit
  run_check pc_warning_bridge ./tools/godot.sh --script res://tests/test_pc_warning_bridge.gd -- --fixture "$ROOT/artifacts/pc-warning-trace-03/report.json" --output "$(fresh live/warning)" --capture --trace --play --frame-audit
  run_check pc_combat_outcome ./tools/godot.sh --script res://tests/test_pc_combat_outcome.gd -- --fixture "$ROOT/artifacts/pc-combat-loss-trace-01/report.json" --output "$(fresh live/combat)" --capture --boot --play --frame-audit
  run_check pc_scenario_frames ./tools/godot.sh --script res://tests/test_pc_scenario_frames.gd -- --fixture "$ROOT/artifacts/pc-all-scenarios-trace-01/report.json" --output "$(fresh live/scenario-frames)" --capture --no-audio --play
  run_check pc_conveniences ./tools/godot.sh --script res://tests/test_pc_conveniences.gd -- --trace --play --frame-audit --capture --output "$(fresh live/conveniences)"
  run_check pc_mix_bridge ./tools/godot.sh --script res://tests/test_pc_mix_bridge.gd -- --play --trace --capture --capture-station gunner --interactive-clock --replay-controls --frame-audit --output "$(fresh live/mix)"
  for mode in normal early-close invalid-frame; do
    run_check "pc_startup_viewer_$(printf '%s' "$mode" | tr - _)" ./tools/godot.sh --script res://tests/test_pc_startup_viewer.gd -- --play --boot --no-audio --output "$(fresh "live/startup-$mode")" --startup-test "$mode"
  done
  run_check pc_endurance ./tools/godot.sh --script res://tests/test_pc_endurance.gd -- --boot --play --capture --frame-audit --output "$(fresh live/endurance)"
  run_check pc_play_resize ./tools/godot.sh --script res://tests/test_pc_play_resize.gd -- --boot --play --capture --frame-audit --output "$(fresh live/resize)"
  # A bounded paced soak (cycles every mode, station, checkpoint and 8x); release runs use --seconds 7200 --modern-soak.
  run_check pc_soak ./tools/godot.sh --script res://tests/test_pc_soak.gd -- --boot --play --capture --frame-audit --output "$(fresh live/soak)" --seconds "${VALIDATE_SOAK_SECONDS:-60}"
else
  echo 'NOT RUN live tier: original-PC host bridge, session, audio, endurance and soak checks (set VALIDATE_LIVE=1)' >> "$OUT/results.txt"
  echo 'NOTE: live original-PC host checks NOT run (VALIDATE_LIVE=1 runs them)' >&2
fi

TIER=manual
not_run pc_audio_menu_native 'interactive: a person chooses the Audio menu levels it announces'
not_run pc_native_window 'observer: real focus, menu and window changes come from a person or CUA'
not_run pc_endurance_profile 'profiler: timing receipt only, no pass/fail contract'
not_run pc_vehicle_studies 'research harness: needs local --assets authoring studies and reference/pc-vehicles'
if [ "$LIST" = 0 ]; then printf 'VALIDATION_COMPLETE %s\n' "$OUT"; fi
