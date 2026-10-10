#!/usr/bin/env python3
"""Build the locally patched DOSBox Pure core for a browser feasibility test.

The generated files remain under .runtime and contain no original game data.
Run after sourcing .runtime/emsdk/emsdk_env.sh.
"""
from __future__ import annotations

from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".runtime/dosbox-pure-source"
OUTPUT = ROOT / ".runtime/web-core"
SERVE = ROOT / "web-prototype/.generated"
UPSTREAM = "73e03aa145e0549ed4d5a20f8e65532714da33f5"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-archive', action='store_true',
                        help='Rebuild from the published SOURCE-FILES.json inventory without a Git checkout')
    args = parser.parse_args()
    compiler = shutil.which("em++")
    if not compiler:
        raise SystemExit("Emscripten is not active; source .runtime/emsdk/emsdk_env.sh")
    if args.source_archive:
        inventory = json.loads((ROOT / '.runtime/pc-core/SOURCE-FILES.json').read_text())
        if inventory.get('schema') != 1 or inventory.get('upstream_commit') != UPSTREAM:
            raise SystemExit('The published Web source inventory is not the pinned core')
        for row in inventory['files']:
            name = row['path'].removeprefix('source/')
            path = SOURCE / name
            if row['path'] != 'source/' + name or not path.is_file() or path.is_symlink() or \
                    path.stat().st_size != row['size'] or hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                raise SystemExit(f'The published Web source differs from its inventory: {name}')
    else:
        revision = subprocess.check_output(
            ["git", "-C", str(SOURCE), "rev-parse", "HEAD"], text=True
        ).strip()
        if revision != UPSTREAM:
            raise SystemExit("DOSBox Pure source revision differs from the pinned core")
        if not (SOURCE / "src/cpu/abrams_trace.h").is_file():
            raise SystemExit("The reviewed tracing patch is not present")
        receipt = json.loads((ROOT / ".runtime/pc-core/abrams-trace.json").read_text())
        if receipt.get("commit") != UPSTREAM:
            raise SystemExit("The native tracing receipt has the wrong source revision")
        pins = {
            "src/cpu/core_normal.cpp": receipt["patched_core_normal_sha256"],
            "src/cpu/abrams_trace.h": receipt["trace_header_sha256"],
            "src/cpu/abrams_vga_ownership.h": receipt["ownership_header_sha256"],
            "src/cpu/abrams_plate_ownership.h": receipt["plate_ownership_header_sha256"],
            "src/cpu/abrams_observer_checkpoint.h": receipt["observer_checkpoint_header_sha256"],
            "src/dos/abrams_state_overlay.h": receipt["state_overlay_header_sha256"],
            **{name: pair["patched"] for name, pair in receipt["video_patch_hashes"].items()},
        }
        for name, expected in pins.items():
            if hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() != expected:
                raise SystemExit(f"The local DOSBox Pure source differs from the native pin: {name}")

    files = []
    for pattern in ("*.cpp", "src/*.cpp", "src/*/*.cpp", "src/*/*/*.cpp"):
        files.extend(sorted(SOURCE.glob(pattern)))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    exported = [
        "retro_set_environment", "retro_set_video_refresh", "retro_set_audio_sample",
        "retro_set_audio_sample_batch", "retro_set_input_poll", "retro_set_input_state",
        "retro_init", "retro_deinit", "retro_load_game", "retro_unload_game",
        "retro_run", "retro_get_system_av_info", "retro_serialize_size",
        "retro_serialize", "retro_unserialize", "abrams_web_start",
        "abrams_web_step", "abrams_web_key", "abrams_web_video",
        "abrams_web_video_width", "abrams_web_video_height", "abrams_web_video_pitch",
        "abrams_web_trace_frontend", "abrams_web_trace_sim", "abrams_web_trace_stop", "abrams_web_trace_events",
        "abrams_web_trace_size", "abrams_web_trace_count", "abrams_web_trace_overflow",
        "abrams_web_set_claim_catalog", "abrams_web_claim_fault",
        "abrams_web_claim_receipts", "abrams_web_claim_receipts_size",
        "abrams_web_paired_ram", "abrams_web_paired_ram_size", "abrams_web_state_size",
        "abrams_web_save_state", "abrams_web_flush_overlay",
        "abrams_web_restore_state", "abrams_web_ram_now", "malloc", "free",
    ]
    command = [
        compiler, "-O2", "-pthread", "-DDISABLE_DYNAREC=1", "-D__LIBRETRO__",
        "-D_FILE_OFFSET_BITS=64", "-std=gnu++11", "-fexceptions",
        "-Wno-address-of-packed-member", "-Wno-format", "-Wno-switch",
        f"-I{SOURCE / 'include'}", f"-I{SOURCE}", "--no-entry", "-sMODULARIZE=1",
        "-sEXPORT_ES6=1", "-sENVIRONMENT=web,worker,node", "-sPTHREAD_POOL_SIZE=2",
        "-sALLOW_MEMORY_GROWTH=1", "-sINITIAL_MEMORY=268435456",
        "-sMAXIMUM_MEMORY=536870912", "-sALLOW_TABLE_GROWTH=1",
        "-sFORCE_FILESYSTEM=1", "-sASSERTIONS=1",
        "-sEXPORTED_FUNCTIONS=" + ",".join("_" + name for name in exported),
        "-sEXPORTED_RUNTIME_METHODS=FS,HEAPU8,addFunction,removeFunction,ccall,cwrap,getValue,setValue",
        *(str(path) for path in files), str(ROOT / "web-prototype/core_frontend.cpp"),
        "-o", str(OUTPUT / "core.js"),
    ]
    log_path = OUTPUT / "build.log"
    with log_path.open("w") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print("\n".join(log_path.read_text(errors="replace").splitlines()[-70:]))
        raise SystemExit(result.returncode)
    SERVE.mkdir(parents=True, exist_ok=True)
    for name in ("core.js", "core.wasm"):
        shutil.copy2(OUTPUT / name, SERVE / name)
    shutil.copy2(ROOT / "tools/package/game-inputs.json", SERVE / "game-inputs.json")
    (SERVE / "build-info.json").write_text(json.dumps({
        "schema": 1,
        "source_revision": UPSTREAM,
        "wasm_sha256": hashlib.sha256((OUTPUT / "core.wasm").read_bytes()).hexdigest(),
    }, indent=2) + "\n")
    print(f"Built {OUTPUT / 'core.js'} from {len(files)} C++ files")


if __name__ == "__main__":
    main()
