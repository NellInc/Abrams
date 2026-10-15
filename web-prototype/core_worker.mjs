// One pinned original PC emulator core per dedicated worker. The core is built
// with pthreads, a two-worker pool and a shared heap, and exposes no teardown.
// Terminating this worker is the only release of its threads and memory, so
// bridge_worker hosts every core here and terminates it when it is replaced.
// The worker is passive: it runs original frames only when the bridge asks.
import createCore from './.generated/core.js';
import {captureCheckpoint, restoreCheckpoint} from './checkpoint_core.mjs';

const RAM_BYTES = 640 * 1024;
const node = typeof process !== 'undefined' && process.versions?.node;
const port = node ? (await import('node:worker_threads')).parentPort : self;
let core;
let queue = Promise.resolve();

function ramPointer() {
  const pointer = core._abrams_web_ram_now();
  if (!pointer || core._abrams_web_paired_ram_size() !== RAM_BYTES)
    throw new Error('Original RAM is unavailable to the source observer');
  return pointer;
}

async function start({zip, catalog}) {
  if (core) throw new Error('This core worker already hosts an original game');
  if (!(zip instanceof Uint8Array) || !(catalog instanceof Uint8Array))
    throw new Error('Verified original PC files and source catalog are required');
  const instance = await createCore({
    locateFile: name => new URL(`./.generated/${name}`, import.meta.url).href,
  });
  instance.FS.mkdir('/game');
  instance.FS.mkdir('/saves');
  instance.FS.writeFile('/game/abrams-ref.zip', zip);
  // Sharing the heap with the bridge must never become a 256 MiB copy.
  if (!(instance.HEAPU8.buffer instanceof SharedArrayBuffer))
    throw new Error('The pinned original core lacks its shared heap');
  if (instance.ccall('abrams_web_start', 'number', ['string'], ['/game/abrams-ref.zip']) !== 1)
    throw new Error('The pinned original PC game did not boot');
  const pointer = instance._malloc(catalog.length);
  if (!pointer) throw new Error('Cannot allocate source catalog');
  try {
    instance.HEAPU8.set(catalog, pointer);
    if (instance._abrams_web_set_claim_catalog(pointer, catalog.length) !== 1)
      throw new Error('The verified original source catalog was rejected');
  } finally { instance._free(pointer); }
  core = instance;
  return {};
}

// Unobserved original frames: cold boot and the restore core's own boot.
function run({frames, failure}) {
  if (!Number.isInteger(frames) || frames < 1 || frames > 600)
    throw new Error('Invalid original-game frame request');
  for (let i = 0; i < frames; i++)
    if (core._abrams_web_step() !== 1) throw new Error(failure || 'The original PC game stopped');
  return {};
}

// The heap is a SharedArrayBuffer view: posting it shares, never copies. The
// core stays paused until the bridge's next request, so pointers stay valid.
function ram() {
  return {heap: core.HEAPU8, ram: ramPointer()};
}

function keys({changes}) {
  for (const [code, down] of changes)
    if (core._abrams_web_key(code, down ? 1 : 0) !== 1)
      throw new Error('The original game rejected a keyboard change');
  return {};
}

function advance({mode, loadSegment}) {
  if (mode === 'frontend' && core._abrams_web_trace_frontend() !== 1)
    throw new Error('Cannot attach the original frontend observer');
  if (mode === 'sim' && core._abrams_web_trace_sim(loadSegment) !== 1)
    throw new Error('Cannot attach the original SIM observer');
  if (core._abrams_web_step() !== 1) throw new Error('The original PC game stopped');
  if (core._abrams_web_trace_overflow())
    throw new Error('The original source trace exceeded its 64 MiB per-frame limit');
  if (core._abrams_web_claim_fault())
    throw new Error('The original source ownership claim rejected this frame');
  // abrams_web_step copied RAM immediately before retro_run, which submits the
  // framebuffer completed at that boundary: desktop last_video_ram. Copy it
  // before abrams_web_ram_now() reuses the same native buffer for current RAM.
  const paired = core._abrams_web_paired_ram();
  if (!paired || core._abrams_web_paired_ram_size() !== RAM_BYTES)
    throw new Error('The original PC frame lost its paired source');
  const pairedRam = core.HEAPU8.slice(paired, paired + RAM_BYTES);
  const current = ramPointer();
  const video = core._abrams_web_video();
  const width = core._abrams_web_video_width();
  const height = core._abrams_web_video_height();
  const pitch = core._abrams_web_video_pitch();
  if (!video || width !== 320 || height !== 200 || pitch !== 1280)
    throw new Error('The original PC frame lost its paired source');
  return {transfer: [pairedRam.buffer], result: {
    heap: core.HEAPU8, pairedRam, current,
    trace: [core._abrams_web_trace_events(), core._abrams_web_trace_size()],
    claims: [core._abrams_web_claim_receipts(), core._abrams_web_claim_receipts_size()],
    video: [video, width, height, pitch]}};
}

async function capture({frames}) {
  const checkpoint = await captureCheckpoint(core, frames);
  return {transfer: [checkpoint.state.buffer, checkpoint.overlay.buffer], result: checkpoint};
}

async function restore({checkpoint}) {
  const frames = await restoreCheckpoint(core, checkpoint);
  return {frames, ...ram()};
}

const operations = {start, run, ram, keys, advance, capture, restore};

async function handle(message) {
  const {id, op} = message || {};
  try {
    if (!Object.hasOwn(operations, op)) throw new Error('Unsupported original core request');
    if (op !== 'start' && !core) throw new Error('The original game has not booted');
    const value = await operations[op](message);
    port.postMessage({id, ok: true, result: value.transfer ? value.result : value},
      value.transfer || []);
  } catch (error) {
    port.postMessage({id, ok: false, message: String(error?.message || error)});
  }
}

// Requests are strictly sequential; an async restore never overlaps a step.
const receive = message => { queue = queue.then(() => handle(message)); };
if (node) port.on('message', receive);
else self.onmessage = event => receive(event.data);
