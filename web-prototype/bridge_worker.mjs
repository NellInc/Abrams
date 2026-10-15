// One source-paired original frame per Godot bridge request. This is separate
// from the automatic EGA feasibility runner, so its pacing belongs to Play.
// Each emulator core runs in its own core_worker.mjs and is terminated when a
// checkpoint load replaces it: the pinned pthread core has no other teardown.
// This worker keeps one Pyodide runtime and builds a fresh observer per load.
import {loadObserverRuntime} from './browser_observer.mjs';

const keyCodes = Object.freeze({
  backspace: 8, tab: 9, return: 13, escape: 27, space: 32,
  up: 273, down: 274, right: 275, left: 276,
  shift: 304, ctrl: 306, alt: 308,
  ...Object.fromEntries(Array.from({length: 10}, (_, i) => [`kp${i}`, 256 + i])),
  ...Object.fromEntries(Array.from({length: 12}, (_, i) => [`f${i + 1}`, 282 + i])),
  ...Object.fromEntries(Array.from({length: 10}, (_, i) => [String(i), 48 + i])),
  ...Object.fromEntries(Array.from({length: 26}, (_, i) => [String.fromCharCode(97 + i), 97 + i])),
});
const FPS = 59.9227;
// Desktop Play hides the cold boot until original frame 241. Three observed
// frames reacquire all presented START cells without replaying 238 hidden
// frames through Pyodide. The displayed frame is still source-paired.
const HIDDEN_BOOT_FRAMES = 238;
const RAM_BYTES = 640 * 1024;
// The first retro_run after unserialize submits the stale native framebuffer.
// Like the desktop host, resend the held restore packet until two original
// frames have run on the restored timeline.
const RESTORE_PRIMING_FRAMES = 2;
const node = typeof process !== 'undefined' && process.versions?.node;
let core;
let observerRuntime;
let observer;
// RAM read after the latest frame. Desktop reads before-frame RAM before it
// applies held keys, so this is also the next frame's before-frame RAM.
let nextRam;
let zip;
let catalog;
let frames = 0;
let sequence = 0;
let held = new Set();
let busy = false;
// Sample JSON text of the presented frame, serialised once by the observer.
let lastSample;
let lastProgram = null;
let lastRgb;
let framesSinceRestore = RESTORE_PRIMING_FRAMES;
const slots = new Map();
const storedSlots = new Map();
// The row each save overwrote, as desktop keeps slot-N.previous.zip. Only
// rows this build can load are listed and offered for load_previous.
const previousSlots = new Map();
const previousKey = slot => `previous-${slot}`;
let undo;
let buildId;
let database;

function slotRows(recovery) {
  return Array.from({length: 6}, (_, slot) => {
    const saved = slot === 0 && recovery ? recovery : storedSlots.get(slot);
    const row = {slot, exists: !!saved,
      valid: slot === 0 ? !!(recovery || undo) : slots.has(slot),
      label: slot === 0 ? 'Before last load' : `Slot ${slot}`};
    if (saved?.savedAt) row.saved_at = saved.savedAt;
    if (saved?.sample?.program?.name) row.program = saved.sample.program.name;
    if (slot && previousSlots.get(slot)?.savedAt) row.previous_saved_at = previousSlots.get(slot).savedAt;
    return row;
  });
}

const DATABASE_OPEN_TIMEOUT_MS = 8000;

function storageError(detail, cause) {
  const reason = cause ? ` (${cause.name || 'Error'}: ${cause.message || cause})` : '';
  return new Error(`Local checkpoint storage ${detail}${reason}. Check browser storage permissions and free space; close other Abrams tabs and retry.`, {cause});
}

function openDatabase() {
  if (typeof indexedDB === 'undefined')
    return Promise.reject(storageError('is unavailable'));
  if (!database) {
    const opening = new Promise((resolve, reject) => {
      let settled = false;
      let blocked = false;
      const timer = setTimeout(() => finish(storageError(blocked
        ? 'is blocked by another tab' : 'did not open in time')), DATABASE_OPEN_TIMEOUT_MS);
      function finish(error, db) {
        if (settled) { db?.close(); return; }
        settled = true;
        clearTimeout(timer);
        if (error) reject(error);
        else resolve(db);
      }
      let request;
      try { request = indexedDB.open('abrams-remaster-local', 1); }
      catch (error) { finish(storageError('could not open', error)); return; }
      request.onblocked = () => { blocked = true; };
      request.onupgradeneeded = () => {
        if (settled) { request.transaction.abort(); return; }
        request.result.createObjectStore('checkpoints');
      };
      request.onsuccess = () => {
        const db = request.result;
        db.onversionchange = () => {
          db.close();
          if (database === opening) database = undefined;
        };
        finish(null, db);
      };
      request.onerror = () => finish(storageError('could not open', request.error));
    });
    database = opening;
    opening.catch(() => { if (database === opening) database = undefined; });
  }
  return database;
}

async function storedSlot(operation, slot, value) {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    let transaction;
    let request;
    try {
      transaction = db.transaction('checkpoints', operation === 'get' ? 'readonly' : 'readwrite');
      const store = transaction.objectStore('checkpoints');
      request = operation === 'get' ? store.get(slot) : store.put(value, slot);
    } catch (error) {
      reject(storageError('transaction could not start', error));
      return;
    }
    let result;
    request.onsuccess = () => { result = request.result; };
    transaction.oncomplete = () => resolve(result);
    transaction.onerror = () => reject(storageError('transaction failed', transaction.error));
    transaction.onabort = () => reject(storageError('transaction aborted', transaction.error));
  });
}

// Request/response client for one core_worker.mjs. A crashed or terminated
// worker rejects every outstanding and later call.
class CoreWorker {
  static async spawn() {
    const url = new URL('./core_worker.mjs', import.meta.url);
    const worker = node
      ? new (await import('node:worker_threads')).Worker(url)
      : new Worker(url, {type: 'module', name: 'abrams-original-core'});
    return new CoreWorker(worker);
  }

  constructor(worker) {
    this.worker = worker;
    this.calls = new Map();
    this.nextId = 0;
    this.failure = null;
    const receive = message => this.receive(message);
    const crash = error => this.crash(`Original PC core worker failed: ${error?.message || error}`);
    if (node) {
      worker.on('message', receive);
      worker.on('error', crash);
      worker.on('exit', () => this.crash('Original PC core worker exited'));
    } else {
      worker.onmessage = event => receive(event.data);
      worker.onerror = event => {
        event?.preventDefault?.();
        crash(event?.message || 'its script could not load');
      };
      worker.onmessageerror = () => crash('unreadable message');
    }
  }

  call(op, payload = {}) {
    if (this.failure) return Promise.reject(new Error(this.failure));
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.calls.set(id, {resolve, reject});
      try { this.worker.postMessage({...payload, id, op}); }
      catch (error) { this.calls.delete(id); reject(error); }
    });
  }

  receive(message) {
    const call = this.calls.get(message?.id);
    if (!call) { this.crash('unexpected reply'); return; }
    this.calls.delete(message.id);
    if (message.ok) call.resolve(message.result);
    else call.reject(new Error(String(message.message || 'Original PC core request failed')));
  }

  crash(reason) {
    if (this.failure) return;
    this.failure = reason;
    for (const call of this.calls.values()) call.reject(new Error(reason));
    this.calls.clear();
  }

  // Releases the core's pthread pool and shared heap with its worker.
  terminate() {
    this.crash('Original PC core worker was terminated');
    this.worker.terminate();
  }
}

async function spawnCore() {
  const instance = await CoreWorker.spawn();
  try {
    await instance.call('start', {zip, catalog});
    return instance;
  } catch (error) {
    instance.terminate();
    throw error;
  }
}

function ramView(reply) {
  return reply.heap.subarray(reply.ram, reply.ram + RAM_BYTES);
}

function rgbFrame(heap, pointer, width, height, pitch) {
  if (!pointer || width !== 320 || height !== 200 || pitch !== 1280)
    throw new Error('The original PC framebuffer is unavailable');
  const rgb = new Uint8Array(width * height * 3);
  for (let y = 0; y < height; y++) {
    let source = pointer + y * pitch;
    let target = y * width * 3;
    for (let x = 0; x < width; x++) {
      rgb[target++] = heap[source + 2];
      rgb[target++] = heap[source + 1];
      rgb[target++] = heap[source];
      source += 4;
    }
  }
  return rgb;
}

// Runs one observed original frame. Only a final frame builds the packet
// sample and RGB; earlier frames of a request still feed the observer.
async function pairedFrame(final) {
  // The observer synchronously copies this view into its own Pyodide heap.
  // The core worker stays paused until the next request.
  const mode = observer.beforeFrame(nextRam);
  const frame = await core.call('advance', {mode: mode.mode, loadSegment: mode.load_segment});
  frames++;
  const {heap} = frame;
  const span = ([pointer, size]) => heap.subarray(pointer, pointer + size);
  const [video, width, height, pitch] = frame.video;
  nextRam = heap.subarray(frame.current, frame.current + RAM_BYTES);
  const json = observer.afterFrame(span(frame.trace), span(frame.claims), frame.pairedRam,
    nextRam, heap.subarray(video, video + pitch * height), width, height, pitch, final);
  return final ? {json, rgb: rgbFrame(heap, video, width, height, pitch)} : null;
}

// The observer's JSON object is spliced after the envelope, so the per-frame
// sample is serialised once (as on desktop) and parsed only by Godot.
function sendSample(type, id, sample, rgb, extras = {}) {
  if (typeof sample !== 'string' || sample[0] !== '{' || sample.length < 3)
    throw new Error('Invalid original source sample');
  const envelope = {type, id, sequence, fps: FPS, ...extras};
  const json = JSON.stringify(envelope).slice(0, -1) + ',' + sample.slice(1);
  postMessage({type: 'packet', json, rgb,
    packet: {...envelope, program: lastProgram === null ? null : {name: lastProgram}}},
    [rgb.buffer]);
}

async function applyKeys(keys) {
  if (!Array.isArray(keys) || keys.length > 16 || new Set(keys).size !== keys.length ||
      keys.some(key => !Object.hasOwn(keyCodes, key)))
    throw new Error('Invalid original-game keyboard set');
  const next = new Set(keys);
  const changes = [];
  for (const key of held) if (!next.has(key)) changes.push([keyCodes[key], 0]);
  for (const key of next) if (!held.has(key)) changes.push([keyCodes[key], 1]);
  if (changes.length) await core.call('keys', {changes});
  held = next;
}

async function boot(message) {
  if (core) throw new Error('The original game is already open');
  if (!(message.zip instanceof Uint8Array) || !(message.catalog instanceof Uint8Array) ||
      message.catalog.byteLength !== 336060)
    throw new Error('Verified original PC files and source catalog are required');
  zip = message.zip;
  catalog = message.catalog;
  if (!/^[0-9a-f]{64}$/.test(message.buildId || ''))
    throw new Error('Browser core build identity is missing');
  buildId = message.buildId;
  let storageWarning;
  try {
    for (let slot = 0; slot <= 5; slot++) {
      const saved = await storedSlot('get', slot);
      if (saved) storedSlots.set(slot, saved);
      if (saved?.buildId === buildId) {
        if (slot === 0) undo = saved;
        else slots.set(slot, saved);
      }
      const previous = slot ? await storedSlot('get', previousKey(slot)) : undefined;
      if (previous?.buildId === buildId) previousSlots.set(slot, previous);
    }
  } catch (error) {
    // Gameplay can start without durable storage; checkpoint actions still
    // require successful IndexedDB transactions and never fall back to RAM.
    slots.clear();
    storedSlots.clear();
    previousSlots.clear();
    undo = undefined;
    storageWarning = String(error?.message || error);
  }
  core = await spawnCore();
  while (frames < HIDDEN_BOOT_FRAMES) {
    const count = Math.min(30 - frames % 30, HIDDEN_BOOT_FRAMES - frames);
    await core.call('run', {frames: count,
      failure: 'The original PC game stopped during hidden cold boot'});
    frames += count;
    if (frames % 30 === 0)
      postMessage({type: 'progress', frame: frames, total: 241});
  }
  observerRuntime = await loadObserverRuntime(zip);
  observer = observerRuntime.createObserver(HIDDEN_BOOT_FRAMES);
  nextRam = ramView(await core.call('ram'));
  let frame;
  for (let i = HIDDEN_BOOT_FRAMES; i < 241; i++) {
    frame = await pairedFrame(i === 240);
    if ((i + 1) % 30 === 0)
      postMessage({type: 'progress', frame: i + 1, total: 241});
  }
  lastSample = frame.json;
  lastProgram = observer.programName;
  lastRgb = frame.rgb;
  sendSample('ready', -1, lastSample, lastRgb.slice(), {protocol: 4, backend: 'trace',
    startup: 'original-cold-boot', slots: slotRows(),
    ...(storageWarning ? {storage_warning: storageWarning} : {})});
}

async function step(message) {
  if (!Number.isInteger(message.frames) || message.frames < 1 || message.frames > 600 ||
      !Number.isSafeInteger(message.id) || message.id < 0)
    throw new Error('Invalid original-game frame request');
  await applyKeys(message.keys);
  framesSinceRestore += message.frames;
  const live = framesSinceRestore >= RESTORE_PRIMING_FRAMES;
  let frame;
  for (let i = 0; i < message.frames; i++)
    frame = await pairedFrame(live && i === message.frames - 1);
  sequence += message.frames;
  if (!live) {
    // Held restore packet; the observer keeps these frames' audio events
    // queued for the first live sample.
    sendSample('sample', message.id, lastSample, lastRgb.slice(),
      {held_frame: true, timeline_reset: false});
    return;
  }
  lastSample = frame.json;
  lastProgram = observer.programName;
  lastRgb = frame.rgb;
  sendSample('sample', message.id, lastSample, lastRgb.slice());
}

function checkpointRow(checkpoint) {
  return {buildId, checkpoint, sample: JSON.parse(lastSample), rgb: lastRgb.slice(),
    sequence, savedAt: new Date().toISOString()};
}

async function state(message) {
  if (!Number.isSafeInteger(message.id) || message.id < 0 ||
      !Number.isInteger(message.slot) || message.slot < 0 || message.slot > 5 ||
      (message.op !== 'load_state' && message.slot === 0))
    throw new Error('Invalid local state request');
  if (message.op === 'save_state') {
    const saved = checkpointRow(await core.call('capture', {frames}));
    const overwritten = storedSlots.get(message.slot);
    if (overwritten) {
      // Keep the overwritten row first: a failed slot write then leaves the
      // previous row equal to the unchanged slot.
      await storedSlot('put', previousKey(message.slot), overwritten);
      if (overwritten.buildId === buildId) previousSlots.set(message.slot, overwritten);
      else previousSlots.delete(message.slot);
    }
    await storedSlot('put', message.slot, saved);
    slots.set(message.slot, saved);
    storedSlots.set(message.slot, saved);
    postMessage({type: 'packet', packet: {type: 'state_result', id: message.id,
      success: true, slots: slotRows(), message: `Saved slot ${message.slot}`}});
    return;
  }
  // load_previous never rewrites the slot; like any load it captures undo.
  const previousLoad = message.op === 'load_previous';
  const saved = previousLoad ? previousSlots.get(message.slot)
    : message.slot === 0 ? undo : slots.get(message.slot);
  if (!saved) throw new Error(previousLoad ? `Local slot ${message.slot} has no previous save`
    : `Local slot ${message.slot} is empty`);
  const restoredSample = structuredClone(saved.sample);
  const restoredRgb = saved.rgb.slice();
  if (!(restoredRgb instanceof Uint8Array) || restoredRgb.byteLength !== 320 * 200 * 3 ||
      !restoredSample || !Number.isSafeInteger(saved.sequence) || saved.sequence < 0)
    throw new Error('Invalid local checkpoint presentation');
  const previous = checkpointRow(await core.call('capture', {frames}));
  // Prepare every fallible restore component before persisting undo or
  // swapping. A failure terminates the prepared core and keeps the session.
  let fresh;
  let freshObserver;
  let restored;
  let response;
  let responseRgb;
  try {
    fresh = await spawnCore();
    await fresh.call('run', {frames: 240, failure: 'The restore core could not boot'});
    restored = await fresh.call('restore', {checkpoint: saved.checkpoint});
    freshObserver = observerRuntime.createObserver(restored.frames);
    restoredSample.audio = {schema: 3, frame: restored.frames, epoch: 0, last_id: 0,
      events: [], active: false, enabled: false};
    responseRgb = restoredRgb.slice();
    response = {type: 'packet', packet: {type: 'state_result', id: message.id,
      sequence: saved.sequence, fps: FPS,
      restored: {type: 'sample', id: message.id, sequence: saved.sequence, fps: FPS,
        ...restoredSample, timeline_reset: true, held_frame: true},
      success: true, slots: slotRows(previous), message: `Loaded ${previousLoad ? 'previous ' : ''}slot ${message.slot}`},
      rgb: responseRgb};
    await storedSlot('put', 0, previous);
  } catch (error) {
    freshObserver?.destroy();
    fresh?.terminate();
    throw error;
  }
  storedSlots.set(0, previous);
  const retiredCore = core;
  const retiredObserver = observer;
  core = fresh;
  observer = freshObserver;
  nextRam = ramView(restored);
  held = new Set();
  frames = restored.frames;
  sequence = saved.sequence;
  undo = previous;
  lastSample = JSON.stringify(restoredSample);
  lastProgram = restoredSample.program?.name ?? null;
  lastRgb = restoredRgb;
  framesSinceRestore = 0;
  retiredObserver.destroy();
  retiredCore.terminate();
  try { postMessage(response, [responseRgb.buffer]); }
  catch (cause) {
    const error = new Error('Checkpoint loaded, but the bridge response could not be delivered', {cause});
    error.committedTransportFailure = true;
    throw error;
  }
}

self.onmessage = async event => {
  if (busy) {
    postMessage({type: 'error', message: 'Overlapping original-game bridge request'});
    return;
  }
  busy = true;
  try {
    const message = event.data;
    if (message.op === 'boot') await boot(message);
    else if (!core) throw new Error('The original game has not booted');
    else if (message.op === 'step') await step(message);
    else if (['save_state', 'load_state', 'load_previous'].includes(message.op)) {
      try { await state(message); }
      catch (error) {
        if (error.committedTransportFailure) throw error;
        postMessage({type: 'packet', packet: {type: 'state_result', id: message.id,
          success: false, slots: slotRows(),
          message: String(error?.message || error)}});
      }
    }
    else throw new Error('Unsupported original-game bridge request');
  } catch (error) {
    postMessage({type: 'error', message: String(error?.message || error)});
  } finally { busy = false; }
};
