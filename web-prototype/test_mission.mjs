// Local integration gate: original inputs reach the native mission fixture,
// and a checkpoint restores into an independent WebAssembly core instance.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import createCore from './.generated/core.js';
import { captureCheckpoint, restoreCheckpoint } from './checkpoint_core.mjs';

const root = new URL('../', import.meta.url);
const game = await readFile(new URL('.runtime/pc-core/abrams-ref.zip', root));
const fixture = JSON.parse(await readFile(new URL('godot/tests/fixtures/pc_boot_steps.json', root), 'utf8'));
const keys = { return: 13, escape: 27, space: 32 };
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
async function boot() {
  const core = await createCore();
  core.FS.mkdir('/game');
  core.FS.mkdir('/saves');
  core.FS.writeFile('/game/abrams-ref.zip', game);
  if (core.ccall('abrams_web_start', 'number', ['string'], ['/game/abrams-ref.zip']) !== 1)
    throw new Error('The original DOS game failed to boot');
  for (let frame = 0; frame < 240; frame++) step(core);
  return core;
}
function step(core) {
  if (core._abrams_web_step() !== 1) throw new Error('The original DOS frame failed');
}
function ram(core) {
  const pointer = core._abrams_web_ram_now();
  return core.HEAPU8.slice(pointer, pointer + 640 * 1024);
}
const first = await boot();
let frames = 240;
for (const [count, names] of fixture) {
  for (const [name, key] of Object.entries(keys)) first._abrams_web_key(key, names.includes(name) ? 1 : 0);
  for (let frame = 0; frame < count; frame++) step(first);
  frames += count;
}
for (const key of Object.values(keys)) first._abrams_web_key(key, 0);
const before = ram(first);
const inspect = `import json,sys
from pathlib import Path
from tools.pc_live_state import SimStateReader, active_program
raw=sys.stdin.buffer.read()
state=SimStateReader(Path('GAME/SIM.EXE')).read(raw)
print(json.dumps({'program':active_program(raw)['name'],'load_segment':active_program(raw)['load_segment'],'scenario':state['scenario_resource_index'],
  'station':state['station'],'position':state['world_position_raw'],'ammunition':state['ammunition']}))`;
const observed = JSON.parse(execFileSync('python3', ['-c', inspect], {
  cwd: fileURLToPath(root), input: Buffer.from(before), maxBuffer: 1024 * 1024,
}).toString());
console.log(JSON.stringify({ stage: 'mission', frames, ram_sha256: hash(before), ...observed }));
if (observed.program !== 'SIM' || observed.scenario !== 6 || observed.station !== 'gunner' ||
    JSON.stringify(observed.position) !== JSON.stringify([79872, 141312, 50]) ||
    JSON.stringify(observed.ammunition) !== JSON.stringify({COAX:80, HEAT:10, SABOT:6, AX:18}))
  throw new Error('WebAssembly did not reach the native original-game mission contract');
const checkpoint = await captureCheckpoint(first, frames);
const second = await boot();
const restoredFrames = await restoreCheckpoint(second, checkpoint);
if (restoredFrames !== frames || hash(ram(second)) !== hash(before))
  throw new Error('Fresh-core checkpoint restore differs from original mission RAM');
step(first);
step(second);
const nextA = ram(first), nextB = ram(second);
// The BIOS tick resumes from the same saved value in both cores.
if (hash(nextA) !== hash(nextB)) throw new Error('Original simulation diverged after restore');
console.log(JSON.stringify({ stage: 'checkpoint', restored_frames: restoredFrames,
  overlay_bytes: checkpoint.overlay.byteLength, state_bytes: checkpoint.state.byteLength,
  next_ram_sha256: hash(nextB) }));
// The browser core must expose the same source-attributed observer callbacks
// needed by the desktop remaster, rather than only its final EGA framebuffer.
if (first._abrams_web_trace_sim(observed.load_segment) !== 1 ||
    second._abrams_web_trace_sim(observed.load_segment) !== 1)
  throw new Error('Cannot attach the original-program draw observer');
const observedKinds = new Set();
const tracePackets = [];
const browserFrames = [];
let recorded = 0;
for (let frame = 0; frame < 12; frame++) {
  const beforeFrame = process.env.ABRAMS_WEB_PYODIDE === '1' ? ram(first) : null;
  step(first);
  step(second);
  if (first._abrams_web_trace_overflow() || second._abrams_web_trace_overflow())
    throw new Error('The browser draw observer overflowed');
  const eventBytes = core => core.HEAPU8.slice(core._abrams_web_trace_events(),
    core._abrams_web_trace_events() + core._abrams_web_trace_size());
  const a = eventBytes(first), b = eventBytes(second);
  if (hash(a) !== hash(b)) throw new Error(`Restored draw trace diverged at frame ${frame}`);
  tracePackets.push(Buffer.from(a).toString('base64'));
  if (beforeFrame) {
    const width = first._abrams_web_video_width(), height = first._abrams_web_video_height();
    const pitch = first._abrams_web_video_pitch(), videoPointer = first._abrams_web_video();
    browserFrames.push({before: beforeFrame, packet: a, after: ram(first),
      video: first.HEAPU8.slice(videoPointer, videoPointer + pitch * height),
      width, height, pitch});
  }
  const view = new DataView(a.buffer);
  let cursor = 0, count = 0;
  while (cursor < a.length) {
    if (cursor + 36 > a.length) throw new Error('Truncated draw event header');
    const kind = view.getUint32(cursor, true);
    const length = view.getUint32(cursor + 8, true);
    observedKinds.add(kind);
    cursor += 36 + length;
    count++;
  }
  if (cursor !== a.length || count !== first._abrams_web_trace_count())
    throw new Error('Draw event packet boundaries are invalid');
  recorded += count;
}
first._abrams_web_trace_stop();
second._abrams_web_trace_stop();
if (!observedKinds.has(1) || !observedKinds.has(12))
  throw new Error('No source-attributed draw pass and presented framebuffer were observed');
console.log(JSON.stringify({ stage: 'draw-observer', frames: 12, events: recorded,
  kinds: [...observedKinds].sort((a, b) => a - b) }));
const width = first._abrams_web_video_width(), height = first._abrams_web_video_height();
const pitch = first._abrams_web_video_pitch();
const video = Buffer.from(first.HEAPU8.slice(first._abrams_web_video(),
  first._abrams_web_video() + pitch * height));
const replayInput = {packets: tracePackets, width, height, pitch, video: video.toString('base64')};
const replay = JSON.parse(execFileSync('python3', ['web-prototype/trace_replay.py'], {
  cwd: fileURLToPath(root), input: JSON.stringify(replayInput), maxBuffer: 1024 * 1024,
}).toString());
if (replay.events !== recorded || !replay.draw_pass || replay.objects < 1)
  throw new Error('Desktop collector could not consume the browser draw trace');
console.log(JSON.stringify({ stage: 'desktop-replay', ...replay }));
if (process.env.ABRAMS_WEB_PYODIDE === '1') {
  const {loadPyodide} = await import(new URL('../.runtime/pyodide/node_modules/pyodide/pyodide.mjs', import.meta.url));
  const pyodide = await loadPyodide();
  await pyodide.loadPackage('pillow');
  pyodide.FS.mkdir('/repo');
  pyodide.FS.mount(pyodide.FS.filesystems.NODEFS, {root: fileURLToPath(root)}, '/repo');
  pyodide.globals.set('payload_json', JSON.stringify(replayInput));
  const wasmReplay = JSON.parse(pyodide.runPython(`
import importlib.util, json, sys
sys.path.insert(0, '/repo')
spec = importlib.util.spec_from_file_location('abrams_web_trace_replay', '/repo/web-prototype/trace_replay.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
json.dumps(module.replay_to_summary(json.loads(payload_json)))
`));
  if (JSON.stringify(wasmReplay) !== JSON.stringify(replay))
    throw new Error('Pyodide source-attributed draw pass differs from desktop Python');
  console.log(JSON.stringify({stage: 'pyodide-replay', ...wasmReplay}));
  pyodide.runPython(`
sys.path.insert(0, '/repo/web-prototype')
from browser_observer import BrowserObserver
from pathlib import Path
web_observer = BrowserObserver()
`);
  let browserSample;
  const started = performance.now();
  const observedDurations = [];
  for (const [index, frame] of browserFrames.entries()) {
    const frameStarted = performance.now();
    pyodide.FS.writeFile('/before.bin', frame.before);
    const mode = pyodide.runPython("web_observer.before_frame(Path('/before.bin').read_bytes())['mode']");
    if (mode !== 'sim' && mode !== 'unchanged') throw new Error('Browser observer did not attach to SIM');
    pyodide.FS.writeFile('/packet.bin', frame.packet);
    pyodide.FS.writeFile('/receipts.bin', new Uint8Array());
    pyodide.FS.writeFile('/ram.bin', frame.after);
    pyodide.FS.writeFile('/video.bin', frame.video);
    const expression = `web_observer.after_frame(
      Path('/packet.bin').read_bytes(), Path('/receipts.bin').read_bytes(),
      Path('/ram.bin').read_bytes(), Path('/video.bin').read_bytes(),
      ${frame.width}, ${frame.height}, ${frame.pitch})`;
    if (process.env.ABRAMS_WEB_PROFILE === '1' && index === browserFrames.length - 1) {
      const result = JSON.parse(pyodide.runPython(`
import cProfile, pstats, io
profile = cProfile.Profile()
profile.enable()
sample = ${expression}
profile.disable()
stream = io.StringIO()
pstats.Stats(profile, stream=stream).sort_stats('cumtime').print_stats(25)
json.dumps({'sample': sample, 'profile': stream.getvalue()}, separators=(',', ':'))`));
      browserSample = result.sample;
      console.log(result.profile);
    } else {
      browserSample = JSON.parse(pyodide.runPython(`json.dumps(${expression}, separators=(',',':'))`));
    }
    observedDurations.push(Math.round(performance.now() - frameStarted));
  }
  const browserReplay = {draw_pass: !!browserSample.presentation.draw_pass,
    objects: browserSample.presentation.draw_pass?.objects?.length || 0,
    text_runs: browserSample.presentation.text_runs?.length || 0,
    ui_overlay: !!browserSample.presentation.ui_overlay};
  if (!browserReplay.draw_pass || browserReplay.objects !== replay.objects ||
      browserReplay.text_runs !== replay.text_runs || browserReplay.ui_overlay !== replay.ui_overlay)
    throw new Error('Browser presentation differs from desktop collector sample');
  console.log(JSON.stringify({stage: 'browser-observer', frames: browserFrames.length,
    elapsed_ms: Math.round(performance.now() - started),
    ...(process.env.ABRAMS_WEB_PROFILE === '1' ? {frame_ms: observedDurations} : {}),
    objects: browserReplay.objects, text_runs: browserReplay.text_runs,
    ui_overlay: browserReplay.ui_overlay}));
}
if (process.env.ABRAMS_WEB_PROBE_CLAIMS === '1') {
  const catalog = execFileSync('python3', ['web-prototype/claim_catalog.py', 'GAME'], {
    cwd: fileURLToPath(root), maxBuffer: 1024 * 1024,
  });
  const catalogPointer = first._malloc(catalog.length);
  first.HEAPU8.set(catalog, catalogPointer);
  const catalogAccepted = first._abrams_web_set_claim_catalog(catalogPointer, catalog.length);
  first._free(catalogPointer);
  if (catalogAccepted !== 1) throw new Error('Original claim catalog was rejected');
  if (first._abrams_web_trace_sim(observed.load_segment) !== 1)
    throw new Error('Cannot observe the station transition');
  const claimKinds = new Set();
  const allKinds = new Set();
  let claims = 0, allEvents = 0;
  let nativeClaims = 0;
  const claimFrames = [];
  first._abrams_web_key(284, 1); // Original F3 cupola station command.
  for (let frame = 0; frame < 90; frame++) {
    if (frame === 3) first._abrams_web_key(284, 0);
    if (first._abrams_web_step() !== 1 || first._abrams_web_claim_fault())
      throw new Error(`Native original-source claim rejected at cupola frame ${frame}`);
    if (first._abrams_web_trace_overflow()) throw new Error('Station observer overflowed');
    const events = first.HEAPU8.slice(first._abrams_web_trace_events(),
      first._abrams_web_trace_events() + first._abrams_web_trace_size());
    const receiptSize = first._abrams_web_claim_receipts_size();
    if (receiptSize) {
      const pointer = first._abrams_web_claim_receipts();
      const receipt = first.HEAPU8.slice(pointer, pointer + receiptSize);
      let at = 0;
      const view = new DataView(receipt.buffer);
      while (at < receiptSize) {
        if (at + 8 > receiptSize) throw new Error('Truncated native claim receipt');
        const plate = view.getUint32(at + 4, true);
        at += plate ? 8008 : 8;
        nativeClaims++;
      }
      if (at !== receiptSize) throw new Error('Invalid native claim receipt');
    }
    const view = new DataView(events.buffer);
    const sourceEvents = [];
    for (let at = 0; at < events.length;) {
      if (at + 36 > events.length) throw new Error('Truncated station event');
      const kind = view.getUint32(at, true), length = view.getUint32(at + 8, true);
      allKinds.add(kind); allEvents++;
      if (kind === 29 || kind === 30 || kind === 32) {
        claimKinds.add(kind); claims++;
        sourceEvents.push(Buffer.from(events.subarray(at, at + 36 + length)));
      }
      at += 36 + length;
      if (at > events.length) throw new Error('Truncated station event data');
    }
    if (sourceEvents.length || receiptSize) {
      const pointer = first._abrams_web_claim_receipts();
      const receipt = receiptSize ? first.HEAPU8.slice(pointer, pointer + receiptSize) : new Uint8Array();
      claimFrames.push({packet: Buffer.concat(sourceEvents).toString('base64'),
        receipts: Buffer.from(receipt).toString('base64')});
    }
  }
  first._abrams_web_trace_stop();
  if (nativeClaims < 1) throw new Error('Cupola transition did not produce native claims');
  if (process.env.ABRAMS_DEBUG_CLAIMS === '1')
    await writeFile(new URL('.runtime/web-core/claim-frames.json', root), JSON.stringify(claimFrames));
  const checked = JSON.parse(execFileSync('python3', ['web-prototype/claim_replay.py'], {
    cwd: fileURLToPath(root), input: JSON.stringify(claimFrames), maxBuffer: 1024 * 1024,
  }).toString());
  if (checked.claims !== nativeClaims)
    throw new Error('Native source claims differ from desktop Python verification');
  const station = JSON.parse(execFileSync('python3', ['-c', inspect], {
    cwd: fileURLToPath(root), input: Buffer.from(ram(first)), maxBuffer: 1024 * 1024,
  }).toString()).station;
  console.log(JSON.stringify({stage: 'claim-probe', frames: 90, events: claims,
    native_claims: nativeClaims, verified_claims: checked.claims,
    kinds: [...claimKinds].sort((a, b) => a - b), station, allEvents,
    allKinds: [...allKinds].sort((a, b) => a - b)}));
  if (process.env.ABRAMS_WEB_TAMPER_CLAIMS === '1') {
    const changed = Buffer.from(catalog);
    let at = 8 + 5 * 64000;
    for (let index = 0; index < 5; index++) {
      const width = changed.readUInt16LE(at), height = changed.readUInt16LE(at + 2);
      at += 4 + width * height;
    }
    const width = changed.readUInt16LE(at), height = changed.readUInt16LE(at + 2);
    if (width !== 168 || height !== 7) throw new Error('Unexpected original cupola bitmap');
    at += 4;
    const nonzero = changed.subarray(at, at + width * height).findIndex(value => value !== 0);
    if (nonzero < 0) throw new Error('No original cupola pixels to alter');
    changed[at + nonzero] = changed[at + nonzero] === 15 ? 14 : changed[at + nonzero] + 1;
    const pointer = second._malloc(changed.length);
    second.HEAPU8.set(changed, pointer);
    const accepted = second._abrams_web_set_claim_catalog(pointer, changed.length);
    second._free(pointer);
    if (accepted !== 1 || second._abrams_web_trace_sim(observed.load_segment) !== 1)
      throw new Error('Tampered source fixture could not enter SIM');
    second._abrams_web_key(284, 1);
    let rejected = false;
    for (let frame = 0; frame < 90; frame++) {
      if (frame === 3) second._abrams_web_key(284, 0);
      if (second._abrams_web_step() !== 1 || second._abrams_web_claim_fault()) {
        rejected = second._abrams_web_claim_fault() === 1;
        break;
      }
    }
    if (!rejected) throw new Error('Altered original strut source did not fail closed');
    console.log(JSON.stringify({stage: 'tampered-claim-rejected'}));
  }
}
process.exit(0);
