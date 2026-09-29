#!/usr/bin/env python3
"""Local stdin/stdout research bridge. PC code owns all gameplay decisions.

Bounded keyboard steps, local checkpoints and graceful shutdown are accepted. No sockets,
original memory writes, replacement combat simulation or mixed audio capture.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import fcntl
import io
import json
import os
from pathlib import Path
import sys
import struct

try:
    from tools.pc_reference_core import PcReferenceCore, CORE_SHA256, KEYS
    from tools.pc_live_state import SimStateReader
    from tools.inspect_scenarios import decode_resource
    from tools.inspect_shapes import inspect_shapes, primitive_vertices
    from tools.pc_render_state import static_faces_for_state
    from tools.pc_session import PresentationSession
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore, CORE_SHA256, KEYS
    from pc_live_state import SimStateReader
    from inspect_scenarios import decode_resource
    from inspect_shapes import inspect_shapes, primitive_vertices
    from pc_render_state import static_faces_for_state
    from pc_session import PresentationSession

ROOT = Path(__file__).resolve().parents[1]


class FramePng:
    """One immutable framebuffer encoding, without caching any live metadata."""
    def __init__(self):
        self.video = None
        self.encoded = None

    def encode(self, core):
        if core.last_video is not None and core.last_video == self.video:
            return self.encoded
        image = io.BytesIO()
        core.screenshot().save(image, format='PNG')
        self.encoded = base64.b64encode(image.getvalue()).decode('ascii')
        self.video = core.last_video
        return self.encoded


def lock_saves(directory):
    """One host owns an overlay until its final original-game flush completes."""
    directory=directory.resolve()
    if any(directory.is_relative_to((ROOT/name).resolve()) for name in ('GAME','GENESIS')):
        raise ValueError('Save overlays must remain outside original source directories')
    directory.mkdir(parents=True,exist_ok=True)
    handle=(directory/'.abrams-session.lock').open('a+b')
    try:
        fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        raise ValueError('This save directory is already open in another Abrams window. Close that window before reopening it.') from None
    return handle


def frame_audit(core):
    """Fingerprint the already paired boundary, without another guest read/run."""
    if core.last_video is None or core.last_video_ram is None:
        raise ValueError('frame audit requires a paired original boundary')
    raw, width, height, pitch = core.last_video
    if len(core.last_video_ram) != 640*1024 or len(raw) != pitch*height:
        raise ValueError('incomplete paired original audit bytes')
    return {'ram_sha256': hashlib.sha256(core.last_video_ram).hexdigest(),
            'video_sha256': hashlib.sha256(raw).hexdigest(),
            'ram_bytes': len(core.last_video_ram), 'video_bytes': len(raw),
            'width': width, 'height': height, 'pitch': pitch}


def validate_command(command):
    if not isinstance(command, dict) or command.get("op") not in ("step", "quit", "save_state", "load_state"):
        raise ValueError("expected step, save_state, load_state or quit")
    if command["op"] == "quit":
        if set(command) != {"op"}:
            raise ValueError("unexpected quit fields")
        return
    if command["op"] in ("save_state", "load_state"):
        if set(command) != {"op", "id", "slot"}:
            raise ValueError("unexpected checkpoint fields")
        if type(command["id"]) is not int or command["id"] < 0:
            raise ValueError("nonnegative request id required")
        minimum = 0 if command["op"] == "load_state" else 1
        if type(command["slot"]) is not int or not minimum <= command["slot"] <= 5:
            raise ValueError("invalid checkpoint slot")
        return
    if set(command) != {"op", "id", "frames", "keys"}:
        raise ValueError("unexpected step fields")
    if type(command["id"]) is not int or command["id"] < 0:
        raise ValueError("nonnegative request id required")
    if type(command["frames"]) is not int or not 1 <= command["frames"] <= 600:
        raise ValueError("step must contain 1 to 600 frames")
    keys = command["keys"]
    if (not isinstance(keys, list) or len(keys) > 16
            or any(not isinstance(k, str) or k not in KEYS for k in keys)
            or len(keys) != len(set(keys))):
        raise ValueError("invalid keyboard set")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--state", type=Path, help="omit for original cold boot with trace backend")
    p.add_argument("--saves", type=Path, required=True)
    p.add_argument("--core", type=Path, default=ROOT / ".runtime/pc-core/dosbox_pure_libretro.dylib")
    p.add_argument("--backend", choices=["reference", "trace"], default="reference")
    p.add_argument("--content", type=Path, default=ROOT / ".runtime/pc-core/abrams-ref.zip")
    p.add_argument("--frame-audit", action="store_true", help="diagnostic hashes of paired original RAM and framebuffer; no memory dumps")
    p.add_argument("--state-worker", action="store_true", help=argparse.SUPPRESS)
    p.add_argument("--local-resume", type=Path, help=argparse.SUPPRESS)
    args = p.parse_args()
    if args.state is None and args.backend != 'trace': p.error('cold boot requires the trace backend')
    if not args.state_worker:
        try:
            from tools.pc_state_host import supervise
        except ModuleNotFoundError:
            from pc_state_host import supervise
        return supervise(args, sys.argv[1:], lock_saves, validate_command)
    # Core printf/log output must never corrupt the JSON channel.
    output = os.fdopen(os.dup(sys.stdout.fileno()), "w", buffering=1)
    os.dup2(sys.stderr.fileno(), sys.stdout.fileno())
    reader = SimStateReader(ROOT / "GAME/SIM.EXE")
    shape_bytes = decode_resource((ROOT / "GAME/SHAPE.TBL").read_bytes())
    shapes = inspect_shapes(shape_bytes)["shapes"]
    core = None
    session = None
    save_lock = None

    def send(message):
        output.write(json.dumps(message, separators=(",", ":")) + "\n")

    try:
        # The supervisor retains the inherited exclusive save lock.

        pin, source_pin = CORE_SHA256, CORE_SHA256
        if args.backend == "trace":
            manifest = json.loads((ROOT / ".runtime/pc-core/abrams-trace.json").read_text())
            if manifest.get("frontend_scene_schema") != 1:
                raise ValueError("Rebuild the local trace core for the opening scenario preview")
            if manifest.get("schema") != 2:
                raise ValueError("trace backend requires the scanout-aware source build")
            if manifest.get("audio_event_schema") != 1:
                raise ValueError("Rebuild the local trace core for original audio-event support")
            if manifest.get("text_event_schema") != 2:
                raise ValueError("Rebuild the local trace core for original visible-text support")
            if manifest.get("frontend_text_schema") != 1:
                raise ValueError("Rebuild the local trace core for original menu-text support")
            if manifest.get("message_event_schema") != 1:
                raise ValueError("Rebuild the local trace core for original message identity support")
            if manifest.get("strut_event_schema") != 1:
                raise ValueError("Rebuild the local trace core for original strut attribution")
            if manifest.get("driver_overlay_schema") != 1:
                raise ValueError("Rebuild the local trace core for original moving-driver overlay")
            if manifest.get("state_overlay_schema") != 1:
                raise ValueError("Rebuild the local trace core for complete disk checkpoints")
            if manifest.get("round_form_event_schema") != 1:
                raise ValueError("Rebuild the local trace core for original round-form raster support")
            pin, source_pin = manifest["trace_sha256"], manifest["baseline_sha256"]
            args.core = ROOT / ".runtime/pc-core/abrams-trace.dylib"
        core = PcReferenceCore(args.core, args.content, args.saves, expected_sha256=pin)
        if args.backend == 'trace':
            session = PresentationSession(core,reader,shape_bytes)
            session.step(240)
        else: core.run(240)
        if args.state and not args.local_resume:
            if session:session.close();session=None
            core.restore(args.state, expected_source_sha256=source_pin)
            core.run(1)  # documented stale-native-framebuffer priming step
        if args.local_resume:
            if session: session.close(); session = None
            resume = json.loads((args.local_resume / 'resume.json').read_text())
            try:
                from tools.pc_state_store import atomic_write
            except ModuleNotFoundError:
                from pc_state_store import atomic_write
            disk_path = args.saves / (args.content.stem + '.pure.zip')
            disk = (args.local_resume / 'campaign.zip').read_bytes()
            if disk: atomic_write(disk_path, disk)
            elif disk_path.exists(): disk_path.unlink()
            # Cold initialization can delete SIM.OUT. Reload the full selected
            # overlay into native memory before unserialize recreates handles.
            core.local_overlay('reload')
            core.restore_local((args.local_resume / 'state.bin').read_bytes(), resume['keys'], resume['frame'], resume['ram_sha256'])
            if args.backend == 'trace':
                session = PresentationSession(core, reader, shape_bytes)
                session.before_frame()  # Attach before restoring host-only ownership.
                observer = args.local_resume / 'observer.bin'
                if observer.exists(): core.observer_checkpoint(observer.read_bytes())
        elif args.backend == "trace":
            if session is None:session = PresentationSession(core,reader,shape_bytes)
            session.step(1)
        else:
            core.run(1)
        sequence = resume['sequence'] if args.local_resume else 0
        restored_frames = 0 if args.local_resume else 2
        frame_png = FramePng()

        def packet(kind, request_id):
            sample = session.sample() if session else {}
            state = sample.get('state') if session else reader.read(core.last_video_ram)
            if state is not None and session is None:
                state["render_static_faces"] = static_faces_for_state(state, shapes)
            result = {"type": kind, "id": request_id, "sequence": sequence,
                    "state": state, "png": frame_png.encode(core),
                    "fps": core.pause_at_frame_end().timing.fps}
            if session:
                result.update(sample)
                result["audio"] = session.drain_audio()
            if args.frame_audit:
                result["frame_audit"] = frame_audit(core)
            return result

        ready = (resume['packet'] | {'type': 'ready', 'id': -1, 'timeline_reset': True,
                 'held_frame': True}) if args.local_resume else packet("ready", -1)
        # No pending audio is replayed from a checkpoint. Observer counters
        # restart. EGA ownership resumes separately; raster masks and drawing
        # candidates are reacquired from freshly observed original execution.
        if args.local_resume and 'audio' in ready:
            ready['audio'] = {'schema': 3, 'frame': core.frame, 'epoch': 0,
                              'last_id': 0, 'events': [], 'active': False, 'enabled': False}
        last_packet = ready
        ready.update({"protocol": 4 if session else 2, "backend": args.backend, "core_sha256": pin,
                      "startup_frames_after_restore": 0 if args.local_resume else (2 if args.state else 0),
                      "startup": "local-checkpoint" if args.local_resume else ("snapshot" if args.state else "original-cold-boot"),
                      "sampling": "paired completed VGA boundary; original drawing may lag simulation"})
        if ready["state"] is None and not session:
            raise ValueError("SIM not initialized for original shape extraction")
        # Geometry remains local. The per-frame mask selects original roots and
        # static faces; unresolved dynamic/opaque drawing is not substituted.
        if session is None and not args.local_resume:
            ds = ready["state"]["load_segment"]*16+0x19E00
            offset,segment = struct.unpack_from('<HH',core.last_video_ram,ds+0x6D50)
            if core.last_video_ram[segment*16+offset:segment*16+offset+len(shape_bytes)] != shape_bytes:
                raise ValueError('supplied SHAPE.TBL does not match the running original')
            ready["static_wire_geometry"] = {
                str(shape["index"]): {str(p["offset"]): primitive_vertices(shape, p) for p in shape["primitives"]}
                for shape in shapes[:127]}
        send(ready)
        while True:
            line = sys.stdin.readline(8193)
            if not line:
                break
            if len(line) > 8192:
                raise ValueError("oversized bridge command")
            command = json.loads(line)
            if command.get('op') == '_capture':
                try:
                    destination = Path(command['directory'])
                    core.local_overlay('flush')
                    raw = core.serialize_local()
                    (destination / 'state.bin').write_bytes(raw)
                    if session:
                        (destination / 'observer.bin').write_bytes(core.observer_checkpoint())
                    inverse_keys = {value: key for key, value in KEYS.items()}
                    snapshot = {'frame': core.frame, 'sequence': sequence,
                                'keys': [inverse_keys[key] for key in sorted(core.pressed)],
                                'ram_sha256': hashlib.sha256(core.conventional_memory()).hexdigest(),
                                'packet': last_packet}
                    (destination / 'resume.json').write_text(json.dumps(snapshot))
                except Exception as error:
                    send({'type': 'capture_error', 'message': str(error)})
                    continue
                if session: session.close(); session = None
                core.close(); core = None
                send({'type': 'captured'})
                break
            validate_command(command)
            if command["op"] == "quit":
                break
            if session: session.step(command["frames"],command["keys"])
            else: core.run(command["frames"], command["keys"])
            sequence += command["frames"]
            restored_frames += command['frames']
            if restored_frames < 2:
                last_packet = last_packet | {'type': 'sample', 'id': command['id'],
                                             'sequence': sequence, 'held_frame': True, 'timeline_reset': False}
            else:
                last_packet = packet("sample", command["id"])
            send(last_packet)
    except BrokenPipeError:
        pass  # parent closed its pipe; shut down only our own core
    except Exception as error:
        send({"type": "error", "message": str(error)})
        raise
    finally:
        if core:
            if session: session.close()
            core.close()
        if save_lock: save_lock.close()
        output.close()


if __name__ == "__main__":
    main()
