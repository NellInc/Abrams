#!/usr/bin/env python3
"""Finite native endurance gate using original keyboard routes and isolated saves.

No mission victory, baseline-core parity or real-time playback claim is made.
The companion Godot gate measures production playback and audio consumption.
"""
from __future__ import annotations
import argparse
import base64
import io
import hashlib
import json
import os
from pathlib import Path
import select
import struct
import subprocess
import time
import zipfile
from PIL import Image

try:
    from tools.verify_pc_save_states import Client, ROOT
    from tools.capture_pc_session import scenario_steps, information_steps, INFORMATION_PAGES, no_sim_geometry
    from tools.source_guard import inside_source
    from tools.pc_fonts import decode_font, text_pixels
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from verify_pc_save_states import Client, ROOT
    from capture_pc_session import scenario_steps, information_steps, INFORMATION_PAGES, no_sim_geometry
    from source_guard import inside_source
    from pc_fonts import decode_font, text_pixels


def source_hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for name in ('GAME', 'GENESIS') for p in (ROOT/name).rglob('*') if p.is_file()}


def percentile(values, fraction):
    return sorted(values)[min(len(values)-1, int((len(values)-1)*fraction))] if values else None


class BoundedClient(Client):
    def __init__(self, directory, log):
        self.buffer = b''
        super().__init__(directory, log)
        self.last = self.ready

    def read(self):
        deadline = time.monotonic()+120
        while b'\n' not in self.buffer:
            remaining = deadline-time.monotonic()
            if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                raise TimeoutError('native bridge reply exceeded 120 seconds')
            chunk = os.read(self.process.stdout.fileno(), 65536)
            if not chunk:
                raise RuntimeError('native bridge exited without a complete response')
            self.buffer += chunk
        line, self.buffer = self.buffer.split(b'\n', 1)
        value = json.loads(line)
        if value.get('type') == 'error':
            raise RuntimeError(value['message'])
        return value

    def step(self, frames, keys=()):
        if frames < 1:
            raise ValueError('positive original frame count required')
        remaining = frames
        while remaining:
            chunk = min(remaining, 600)
            self.last = super().step(chunk, keys)
            remaining -= chunk
        return self.last

    def sample(self):
        return self.last

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write('{"op":"quit"}\n')
            self.process.stdin.flush()
        try:
            status = self.process.wait(timeout=30)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f'host PID {self.process.pid} did not finish cooperative quit; no signal sent') from error
        self.process.stdin.close()
        self.process.stdout.close()
        if status != 0:
            raise RuntimeError(f'native host exited {status}')


def native_rss_kib(pid):
    """Read only this host and descendants, including its current core worker."""
    rows = subprocess.check_output(['ps', '-axo', 'pid=,ppid=,rss='], text=True)
    entries = [tuple(map(int, row.split())) for row in rows.splitlines() if row.strip()]
    owned = {pid}
    while True:
        added = {child for child, parent, _ in entries if parent in owned}-owned
        if not added:
            break
        owned.update(added)
    return sum(rss for child, _, rss in entries if child in owned)


def campaign_record(raw):
    """Read END's original 50-byte record, without treating played as won.

    END 0000:06aa increments the count and played marker after incomplete
    missions too. Status 3 means the original eight-mission tour ended; it is
    not proof of eight objective victories. See pc-executable-research.md.
    """
    if len(raw) != 50:
        raise ValueError('original campaign record must contain exactly 50 bytes')
    score, count, status = struct.unpack_from('<HBB', raw)
    played = list(raw[4:12])
    if count > 8 or status > 3 or any(value not in (0, 1) for value in played):
        raise ValueError('invalid original campaign count, status or played markers')
    return {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
            'score_raw_u16': score, 'mission_count': count, 'career_status': status,
            'played_markers': played, 'category_totals': list(struct.unpack_from('<14H', raw, 12))}


def rnr_choice(packet):
    """Classify the original END choice from all three current source/RGB cells.

    Working if both valid highlight roles classify, while partial/stale/unpaired
    menus fail closed. None means no R&R source row is identified, not a
    source-qualified page and never permission to rest. No identified partial
    menu may fall back to page-Space.
    """
    presentation = packet.get('presentation') or {}
    rows = presentation.get('text_runs') or []
    specs = [('NOW WHAT SOLDIER?', 0xa1c, [92, 90, 136, 8], 0xc71),
             ('TAKE R&R', 0xa2e, [92, 102, 64, 8], 0xe10),
             ('CONTINUE', 0xa37, [164, 102, 64, 8], 0xe10)]
    if not any(row.get('text') in {spec[0] for spec in specs} or
               row.get('source_pointer') in {spec[1] for spec in specs} for row in rows):
        return None
    def require(condition):
        if not condition:
            raise ValueError('Unqualified original END R&R source/RGB cells')
    program = packet.get('program') or {}
    require(program.get('name') == 'END' and presentation.get('frontend_program') == program)
    try:
        with Image.open(io.BytesIO(base64.b64decode(packet['png'], validate=True))) as png:
            image = png.convert('RGB')
    except (KeyError, ValueError, OSError) as error:
        raise ValueError('Missing or invalid paired R&R PNG') from error
    require(image.size == (320, 200))
    palette = presentation.get('palette_rgb')
    require(isinstance(palette, list) and len(palette) == 16 and
            all(isinstance(rgb, (list, tuple)) and len(rgb) == 3 and
                all(isinstance(value, int) and 0 <= value <= 255 for value in rgb) for rgb in palette))
    require(palette[1] != palette[4])
    # Use the same pinned native font/raster machinery as pc_frontend_text.
    # A crop hash alone cannot bind a claimed highlight role to its pixels.
    try:
        font_bytes = (ROOT/'GAME/STENCIL.FNT').read_bytes()
    except OSError as error:
        raise ValueError('Pinned original STENCIL font required for R&R') from error
    require(hashlib.sha256(font_bytes).hexdigest() == '3f92e8c7488278d86aeaa978d87d980d6a688fc9c8dbf87befaf4e6bbc9f4181')
    font = decode_font(font_bytes)
    colours = []
    for text, pointer, rect, return_ip in specs:
        matches = [row for row in rows if row.get('text') == text]
        require(len(matches) == 1)
        row = matches[0]
        require((row.get('source_pointer'), row.get('rect'), row.get('return_ip')) ==
                (pointer, rect, return_ip))
        require(row.get('basis') == 'completed original string and exact full current glyph cell; original highlight colours retained')
        require(row.get('font_sha256') == '3f92e8c7488278d86aeaa978d87d980d6a688fc9c8dbf87befaf4e6bbc9f4181')
        x, y, width, height = rect
        require(hashlib.sha256(image.crop((x, y, x+width, y+height)).tobytes()).hexdigest() == row.get('pixel_sha256'))
        fg, bg = row.get('foreground'), row.get('background')
        require((fg, bg) in ((1, 4), (4, 1)))
        glyph_width, glyph_height, ink = text_pixels(font, text.encode('ascii'))
        require((glyph_width, glyph_height) == (width, height))
        expected = b''.join(bytes(palette[fg if bit else bg]) for bit in ink)
        require(image.crop((x, y, x+width, y+height)).tobytes() == expected)
        colours.append((fg, bg))
    require(colours[0] == (1, 4))
    if colours[1:] == [(4, 1), (1, 4)]:
        return 'rest'
    require(colours[1:] == [(1, 4), (4, 1)])
    return 'continue'


def run_campaign_tour(output):
    """Exercise all eight original campaign handoffs and cold disk continuations.

    Uses ordinary incomplete mission exits deliberately. Objective victories,
    combat survival and independent baseline-core parity remain separate gates.
    No RAM checkpoint is loaded or campaign record authored by this route.
    """
    before = source_hashes()
    routes = json.loads((ROOT/'godot/tests/fixtures/pc_campaign_steps.json').read_text())
    quit_route = json.loads((ROOT/'godot/tests/fixtures/pc_reentry_steps.json').read_text())[:8]
    checks, missions, stages, visited = {}, [], [], set()
    client, error = None, None
    started = time.monotonic()
    log = (output/'native.log').open('w')

    def check(label, passed):
        checks[label] = bool(passed)
        if not passed:
            raise AssertionError(label)

    def step(label, frames, keys=()):
        packet = client.step(frames, keys)
        audit = packet.get('frame_audit', {})
        check(label+':audit', audit.get('ram_bytes') == 655360 and audit.get('video_bytes') == 256000)
        check(label+':outside-SIM-ownership', (packet.get('program') or {}).get('name') == 'SIM' or no_sim_geometry(packet))
        stages.append({'label': label, 'frames': frames, 'keys': list(keys),
                       'sequence': packet['sequence'], 'program': (packet.get('program') or {}).get('name'),
                       'frame_audit': audit})
        return packet

    def photograph(packet, label):
        picture = Image.open(io.BytesIO(base64.b64decode(packet['png']))).convert('RGB')
        picture.save(output/(label+'.png'))
        return hashlib.sha256(picture.tobytes()).hexdigest()

    try:
        previous_raw = None
        for mission in range(1, 9):
            prefix = f'mission-{mission}'
            # Every mission uses a NEW native process and the same original
            # disk overlay. Neither ready nor Continue restores guest RAM.
            client = BoundedClient(output/'campaign-saves', log)
            if previous_raw is not None:
                with zipfile.ZipFile(output/'campaign-saves/abrams-ref.pure.zip') as archive:
                    check(prefix+':cold-disk-unchanged', archive.read(campaign_member) == previous_raw)
            route = routes['new'][:43] if mission == 1 else routes['continue']
            for index, (frames, keys) in enumerate(route):
                packet = step(prefix+f':entry-{index}', frames, keys)
            check(prefix+':original-SIM', packet['program']['name'] == 'SIM' and bool(packet.get('state')))
            scenario = packet['state']['scenario_resource_index']
            check(prefix+':unplayed-scenario', scenario in range(8) and scenario not in visited)
            visited.add(scenario)
            photograph(packet, prefix+'-battle')
            for item in quit_route:
                packet = step(prefix+':'+item['label'], item['frames'], item['keys'])
            check(prefix+':original-END', packet['program']['name'] == 'END')
            photograph(packet, prefix+'-debrief')
            for page in range(12):
                if (packet.get('program') or {}).get('name') == 'START':
                    break
                check(prefix+f':review-{page}-END', packet['program']['name'] == 'END')
                photograph(packet, prefix+f'-review-{page}')
                choice = rnr_choice(packet)
                if choice:
                    check(prefix+':no-rest-after-final', mission < 8)
                    if choice == 'continue':
                        step(prefix+':choose-rest', 10, ['left'])
                        packet = step(prefix+':choose-rest-release', 90)
                    check(prefix+':source-rest-selected', rnr_choice(packet) == 'rest')
                    step(prefix+':rest-confirm', 10, ['return'])
                    packet = step(prefix+':rest-return', 600)
                else:
                    step(prefix+f':review-{page}-press', 10, ['space'])
                    packet = step(prefix+f':review-{page}-release', 600)
            check(prefix+':original-START', packet['program']['name'] == 'START')
            photograph(packet, prefix+'-main-menu')
            client.close(); client = None
            with zipfile.ZipFile(output/'campaign-saves/abrams-ref.pure.zip') as archive:
                members = [name for name in archive.namelist() if name.upper().endswith('.TC')]
                check(prefix+':one-original-career', len(members) == 1)
                campaign_member = members[0]
                previous_raw = archive.read(campaign_member)
            record = campaign_record(previous_raw)
            (output/(prefix+'.TC')).write_bytes(previous_raw)
            if missions:
                check(prefix+':same-career-identity', previous_raw[40:] == identity_tail)
            else:
                identity_tail = previous_raw[40:]
            check(prefix+':durable-count', record['mission_count'] == mission)
            check(prefix+':durable-markers', {i for i, mark in enumerate(record['played_markers']) if mark} == visited)
            check(prefix+':career-status', record['career_status'] == (3 if mission == 8 else 0))
            missions.append({'mission': mission, 'scenario_resource_index': scenario, 'record': record,
                             'outcome': 'ordinary incomplete exit; no objective-victory claim'})
            print(f'PC_CAMPAIGN_TOUR_STAGE: {mission}/8, scenario {scenario}, status {record["career_status"]}', flush=True)
        check('all-eight-original-scenarios', visited == set(range(8)))
        client = BoundedClient(output/'campaign-saves', log)
        for index, (frames, keys) in enumerate(routes['continue'][:18]):
            packet = step(f'completed-career:continue-{index}', frames, keys)
        photograph(packet, 'completed-career-cold-continue')
        text = ' '.join(run.get('text', '') for run in packet.get('presentation', {}).get('text_runs', []))
        check('completed-career:original-START', packet['program']['name'] == 'START')
        check('completed-career:original-cold-rejection', 'NO ACTIVE PLAYERS TO CHOOSE FROM' in ' '.join(text.upper().split()))
        client.close(); client = None
        with zipfile.ZipFile(output/'campaign-saves/abrams-ref.pure.zip') as archive:
            check('completed-career:cold-record-unchanged', archive.read(campaign_member) == previous_raw)
    except Exception as exception:
        error = f'{type(exception).__name__}: {exception}'
    finally:
        if client:
            try:
                client.close()
            except Exception as exception:
                error = (error+'; ' if error else '')+str(exception)
        log.close()
        checks['original-sources-unchanged'] = source_hashes() == before
        report = {'passed': error is None and len(missions) == 8 and all(checks.values()),
                  'error': error, 'checks': checks, 'missions': missions, 'stages': stages,
                  'wall_seconds': time.monotonic()-started, 'source_hashes': before,
                  'core_manifest': json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text()),
                  'scope': 'Eight original campaign missions with ordinary incomplete exits, debriefs and disk saves; seven fresh-process Continues, original career status 3, and fresh-process rejection of the completed career. No objective victories, surviving combat, RAM restores or baseline-core parity claimed.'}
        (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'PC_CAMPAIGN_TOUR: {len(checks)} checks, {sum(not value for value in checks.values())} failed, {len(missions)}/8 missions, {"PASS" if report["passed"] else "FAIL"}', flush=True)
    if error:
        print(error, flush=True)
    return 0 if report['passed'] else 1


def run(output):
    before = source_hashes()
    checks, stages, timings, memory, checkpoint_results = {}, [], [], [], []
    client = None
    frames = 0
    error = None
    started = time.monotonic()
    log = (output/'native.log').open('w')

    def check(label, passed):
        checks[label] = bool(passed)
        if not passed:
            raise AssertionError(label)

    def step(label, count, keys=()):
        nonlocal frames
        then = time.monotonic()
        packet = client.step(count, keys)
        elapsed = time.monotonic()-then
        frames += count
        timings.append({'label': label, 'frames': count, 'seconds': elapsed})
        audit = packet.get('frame_audit', {})
        check(label+':complete-audit', audit.get('ram_bytes') == 655360 and audit.get('video_bytes') == 256000)
        program = (packet.get('program') or {}).get('name')
        if program != 'SIM':
            check(label+':no-stale-simulation', no_sim_geometry(packet))
        audio = packet.get('audio', {})
        check(label+':audio-boundary', all(event['frame'] <= audio['frame'] for event in audio.get('events', [])))
        stages.append({'label': label, 'sequence': packet['sequence'], 'program': program,
                       'station': (packet.get('state') or {}).get('station'), 'frame_audit': audit,
                       'audio_frame': audio.get('frame'), 'audio_events': len(audio.get('events', [])),
                       'max_event_age_frames': max([audio['frame']-e['frame'] for e in audio.get('events', [])], default=0)})
        return packet

    def checkpoint(label, cycles=2):
        for cycle in range(cycles):
            prefix = f'{label}:checkpoint-{cycle}'
            saved = client.request('save_state', slot=1)
            check(prefix+':save', saved['success'])
            audit = saved['restored']['frame_audit']
            for index in range(15):
                normal = step(prefix+f':normal-{index}', 1)
            restored = client.request('load_state', slot=1)
            check(prefix+':load', restored['success'] and restored['restored']['frame_audit'] == audit)
            for count in (1, 2, 4, 8):
                accelerated = step(prefix+f':accelerated-{count}', count)
            equal = accelerated['frame_audit'] == normal['frame_audit']
            check(prefix+':normal-fast-forward-RAM-video', equal)
            check(prefix+':complete-state', accelerated.get('state') == normal.get('state'))
            checkpoint_results.append({'label': prefix, 'normal': normal['frame_audit'], 'accelerated': accelerated['frame_audit']})
            restored = client.request('load_state', slot=1)
            check(prefix+':restore-route', restored['success'])
            client.last = restored['restored']
        memory.append({'label': label, 'native_tree_rss_kib': native_rss_kib(client.process.pid)})

    try:
        client = BoundedClient(output/'scenario-saves', log)
        visited = set()
        for item in scenario_steps(client):
            packet = step(item['label'], item['frames'], item['keys'])
            label = item['label']
            for station in ('commander', 'cupola', 'driver', 'gunner'):
                if label.endswith('-'+station):
                    check(label+':station', (packet.get('state') or {}).get('station') == station)
                    check(label+':paired', bool(packet.get('presentation', {}).get('draw_pass')))
            if label.endswith('-gunner'):
                visited.add(packet['state']['scenario_resource_index'])
                checkpoint(label)
            for suffix, enabled in (('-sound-off', False), ('-sound-on', True), ('-pause', False), ('-resume', True)):
                if label.endswith(suffix):
                    check(label+':original-audio-gate', packet.get('audio', {}).get('enabled') is enabled)
            if label.endswith('-debrief'):
                check(label+':END', (packet.get('program') or {}).get('name') == 'END')
            if label.endswith('-main-menu'):

                check(label+':START', (packet.get('program') or {}).get('name') == 'START')
                print(f'PC_ENDURANCE_STAGE: {label}, {frames} requested frames', flush=True)
        check('all-eight-scenarios', visited == set(range(8)))
        client.close(); client = None
        # Information routes use a new cold boot, never the former mission RAM.
        client = BoundedClient(output/'information-saves', log)
        for item in information_steps():
            packet = step('information:'+item['label'], item['frames'], item['keys'])
            if item['label'] in INFORMATION_PAGES:
                check('information:'+item['label']+':START', packet['program']['name'] == 'START')
                picture = Image.open(io.BytesIO(base64.b64decode(packet['png']))).convert('RGB')
                check('information:'+item['label']+':original-pixels', hashlib.sha256(picture.crop((0, 0, 320, 175)).tobytes()).hexdigest() == INFORMATION_PAGES[item['label']])
        client.close(); client = None
        routes = json.loads((ROOT/'godot/tests/fixtures/pc_campaign_steps.json').read_text())
        for route in ('new', 'continue'):
            client = BoundedClient(output/'campaign-saves', log)
            for index, (count, keys) in enumerate(routes[route]):
                packet = step(f'campaign:{route}:{index}', count, keys)
            if route == 'new':
                # Original source/RGB cells retain highlight semantics across palettes.
                for page in range(8):
                    choice = rnr_choice(packet)
                    if choice:
                        if choice == 'continue':
                            step('campaign:rest-select', 10, ['left'])
                            packet = step('campaign:rest-select-release', 90)
                        check('campaign:source-rest-selected', rnr_choice(packet) == 'rest')
                        step('campaign:rest-confirm', 10, ['return'])
                        packet = step('campaign:rest-menu', 600)
                        break
                    check(f'campaign:review-{page}:END', packet['program']['name'] == 'END')
                    step(f'campaign:review-{page}:press', 10, ['space'])
                    packet = step(f'campaign:review-{page}:release', 90)
                check('campaign-original-save-returned-menu', packet['program']['name'] == 'START')
                # Flush occurs during cooperative close before the next cold boot.
                client.close(); client = None
                with zipfile.ZipFile(output/'campaign-saves/abrams-ref.pure.zip') as archive:
                    check('campaign-original-disk-data', any(name.upper() != 'SHELL' for name in archive.namelist()))
            else:
                check('campaign-cold-continue-SIM', packet['program']['name'] == 'SIM' and bool(packet['state']))
                checkpoint('campaign-continue', 3)
            if client:
                client.close(); client = None
        check('terminal-native-completion', True)
    except Exception as exception:
        error = f'{type(exception).__name__}: {exception}'
    finally:
        if client:
            try:
                client.close()
            except Exception as exception:
                error = (error+'; ' if error else '')+str(exception)
        log.close()
        checks['original-sources-unchanged'] = source_hashes() == before
        durations = [row['seconds'] for row in timings]
        report = {'passed': error is None and all(checks.values()), 'error': error, 'checks': checks,
                  'frames_requested': frames, 'wall_seconds': time.monotonic()-started,
                  'stages': stages, 'requests': timings, 'memory_samples': memory,
                  'checkpoint_replays': checkpoint_results, 'source_hashes': before,
                  'request_latency_seconds': {'p50': percentile(durations, .5), 'p95': percentile(durations, .95), 'max': max(durations, default=None)},
                  'scope': 'Finite native host route: eight scenarios/four stations, original information menus, campaign disk save/cold continue, nineteen checkpoint normal/accelerated replays. Checkpoint RAM/video compares the trace core to itself; independent baseline parity is a separate gate. Bulk-step audio age and execution throughput are diagnostics, not real-time drift or gameplay divergence. No mission victory attempt or live RAM writes.'}
        (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f"PC_ENDURANCE: {len(checks)} checks, {sum(not v for v in checks.values())} failed, {frames} frames, {'PASS' if report['passed'] else 'FAIL'}", flush=True)
    if error:
        print(error, flush=True)
    return 0 if report['passed'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--campaign-tour', action='store_true', help='eight original incomplete campaign exits, durable saves and cold continuations; no objective-victory claim')
    args = parser.parse_args()
    target = args.output.resolve()
    if inside_source(target, ROOT):
        parser.error('output must be outside original source directories')
    target.mkdir(parents=True, exist_ok=False)
    return run_campaign_tour(target) if args.campaign_tour else run(target)


if __name__ == '__main__':
    raise SystemExit(main())
