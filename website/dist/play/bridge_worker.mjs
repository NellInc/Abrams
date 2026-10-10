// One source-paired original frame per Godot bridge request. This is separate
// from the automatic EGA feasibility runner, so its pacing belongs to Play.
import createCore from './.generated/core.js';
import {createObserver} from './browser_observer.mjs';
import {captureCheckpoint, restoreCheckpoint} from './checkpoint_core.mjs';

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
let core;
let observer;
let zip;
let catalog;
let frames = 0;
let sequence = 0;
let held = new Set();
let busy = false;
let lastSample;
let lastRgb;
const slots = new Map();
const storedSlots = new Map();
let undo;
let buildId;
let database;

function slotRows() {
  return Array.from({length: 6}, (_, slot) => {
    const saved = storedSlots.get(slot);
    const row = {slot, exists: !!saved,
      valid: slot === 0 ? !!undo : slots.has(slot),
      label: slot === 0 ? 'Before last load' : `Slot ${slot}`};
    if (saved?.savedAt) row.saved_at = saved.savedAt;
    if (saved?.sample?.program?.name) row.program = saved.sample.program.name;
    return row;
  });
}

function openDatabase() {
  if (typeof indexedDB === 'undefined') return Promise.resolve(null);
  if (!database) database = new Promise((resolve, reject) => {
    const request = indexedDB.open('abrams-remaster-local', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('checkpoints');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  return database;
}

async function storedSlot(operation, slot, value) {
  const db = await openDatabase();
  if (!db) {
    if (operation === 'get') return storedSlots.get(slot);
    storedSlots.set(slot, value);
    return undefined;
  }
  return new Promise((resolve, reject) => {
    const transaction = db.transaction('checkpoints', operation === 'get' ? 'readonly' : 'readwrite');
    const store = transaction.objectStore('checkpoints');
    const request = operation === 'get' ? store.get(slot) : store.put(value, slot);
    let result;
    request.onsuccess = () => { result = request.result; };
    transaction.oncomplete = () => resolve(result);
    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () => reject(transaction.error || new Error('Local checkpoint transaction aborted'));
  });
}

async function makeCore() {
  const instance = await createCore({
    locateFile: name => new URL(`./.generated/${name}`, import.meta.url).href,
  });
  instance.FS.mkdir('/game');
  instance.FS.mkdir('/saves');
  instance.FS.writeFile('/game/abrams-ref.zip', zip);
  if (instance.ccall('abrams_web_start', 'number', ['string'], ['/game/abrams-ref.zip']) !== 1)
    throw new Error('The pinned original PC game did not boot');
  const pointer = instance._malloc(catalog.length);
  if (!pointer) throw new Error('Cannot allocate source catalog');
  try {
    instance.HEAPU8.set(catalog, pointer);
    if (instance._abrams_web_set_claim_catalog(pointer, catalog.length) !== 1)
      throw new Error('The verified original source catalog was rejected');
  } finally { instance._free(pointer); }
  return instance;
}

function rgbFrame() {
  const width = core._abrams_web_video_width();
  const height = core._abrams_web_video_height();
  const pitch = core._abrams_web_video_pitch();
  const pointer = core._abrams_web_video();
  if (!pointer || width !== 320 || height !== 200 || pitch !== 1280)
    throw new Error('The original PC framebuffer is unavailable');
  const rgb = new Uint8Array(width * height * 3);
  for (let y = 0; y < height; y++) {
    let source = pointer + y * pitch;
    let target = y * width * 3;
    for (let x = 0; x < width; x++) {
      rgb[target++] = core.HEAPU8[source + 2];
      rgb[target++] = core.HEAPU8[source + 1];
      rgb[target++] = core.HEAPU8[source];
      source += 4;
    }
  }
  return rgb;
}

function pairedFrame() {
  const before = core._abrams_web_ram_now();
  if (!before || core._abrams_web_paired_ram_size() !== 640 * 1024)
    throw new Error('Original RAM is unavailable to the source observer');
  // The observer synchronously copies this view into its own Pyodide heap.
  // No core step or memory growth can occur until that copy has completed.
  const mode = observer.beforeFrame(core.HEAPU8.subarray(before, before + 640 * 1024));
  if (mode.mode === 'frontend' && core._abrams_web_trace_frontend() !== 1)
    throw new Error('Cannot attach the original frontend observer');
  if (mode.mode === 'sim' && core._abrams_web_trace_sim(mode.load_segment) !== 1)
    throw new Error('Cannot attach the original SIM observer');
  if (core._abrams_web_step() !== 1) throw new Error('The original PC game stopped');
  frames++;
  if (core._abrams_web_trace_overflow())
    throw new Error('The original source trace exceeded its 64 MiB per-frame limit');
  if (core._abrams_web_claim_fault())
    throw new Error('The original source ownership claim rejected this frame');
  const memory = core._abrams_web_ram_now();
  const video = core._abrams_web_video();
  const width = core._abrams_web_video_width();
  const height = core._abrams_web_video_height();
  const pitch = core._abrams_web_video_pitch();
  if (!memory || !video || width !== 320 || height !== 200 || pitch !== 1280)
    throw new Error('The original PC frame lost its paired source');
  const trace = core._abrams_web_trace_events();
  const claim = core._abrams_web_claim_receipts();
  const sample = observer.afterFrame(
    core.HEAPU8.subarray(trace, trace + core._abrams_web_trace_size()),
    core.HEAPU8.subarray(claim, claim + core._abrams_web_claim_receipts_size()),
    core.HEAPU8.subarray(memory, memory + 640 * 1024),
    core.HEAPU8.subarray(video, video + pitch * height), width, height, pitch);
  return sample;
}

function sendSample(type, id, sample, rgb, extras = {}) {
  const packet = {type, id, sequence, fps: FPS, ...sample, ...extras};
  postMessage({type: 'packet', packet, rgb}, [rgb.buffer]);
}

function applyKeys(keys) {
  if (!Array.isArray(keys) || keys.length > 16 || new Set(keys).size !== keys.length ||
      keys.some(key => !Object.hasOwn(keyCodes, key)))
    throw new Error('Invalid original-game keyboard set');
  const next = new Set(keys);
  for (const key of held) if (!next.has(key)) core._abrams_web_key(keyCodes[key], 0);
  for (const key of next) if (!held.has(key)) core._abrams_web_key(keyCodes[key], 1);
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
  for (let slot = 0; slot <= 5; slot++) {
    const saved = await storedSlot('get', slot);
    if (saved) storedSlots.set(slot, saved);
    if (saved?.buildId === buildId) {
      if (slot === 0) undo = saved;
      else slots.set(slot, saved);
    }
  }
  core = await makeCore();
  for (let i = 0; i < HIDDEN_BOOT_FRAMES; i++) {
    if (core._abrams_web_step() !== 1)
      throw new Error('The original PC game stopped during hidden cold boot');
    frames++;
    if (frames % 30 === 0)
      postMessage({type: 'progress', frame: frames, total: 241});
  }
  observer = await createObserver(zip, HIDDEN_BOOT_FRAMES);
  let sample;
  let audioEvents = [];
  for (let i = HIDDEN_BOOT_FRAMES; i < 241; i++) {
    sample = pairedFrame();
    audioEvents.push(...sample.audio.events);
    if ((i + 1) % 30 === 0)
      postMessage({type: 'progress', frame: i + 1, total: 241});
  }
  sample.audio.events = audioEvents;
  lastSample = sample;
  lastRgb = rgbFrame();
  sendSample('ready', -1, sample, lastRgb.slice(), {protocol: 4, backend: 'trace',
    startup: 'original-cold-boot', slots: slotRows()});
}

function step(message) {
  if (!Number.isInteger(message.frames) || message.frames < 1 || message.frames > 600 ||
      !Number.isSafeInteger(message.id) || message.id < 0)
    throw new Error('Invalid original-game frame request');
  applyKeys(message.keys);
  let sample;
  const events = [];
  for (let i = 0; i < message.frames; i++) {
    sample = pairedFrame();
    events.push(...sample.audio.events);
  }
  sequence += message.frames;
  sample.audio.events = events;
  lastSample = sample;
  lastRgb = rgbFrame();
  sendSample('sample', message.id, sample, lastRgb.slice());
}

async function state(message) {
  if (!Number.isSafeInteger(message.id) || message.id < 0 ||
      !Number.isInteger(message.slot) || message.slot < 0 || message.slot > 5 ||
      (message.op === 'save_state' && message.slot === 0))
    throw new Error('Invalid local state request');
  if (message.op === 'save_state') {
    const saved = {buildId, checkpoint: await captureCheckpoint(core, frames),
      sample: structuredClone(lastSample), rgb: lastRgb.slice(), sequence,
      savedAt: new Date().toISOString()};
    await storedSlot('put', message.slot, saved);
    slots.set(message.slot, saved);
    storedSlots.set(message.slot, saved);
    postMessage({type: 'packet', packet: {type: 'state_result', id: message.id,
      success: true, slots: slotRows(), message: `Saved slot ${message.slot}`}});
    return;
  }
  const saved = message.slot === 0 ? undo : slots.get(message.slot);
  if (!saved) throw new Error(`Local slot ${message.slot} is empty`);
  const previous = {buildId, checkpoint: await captureCheckpoint(core, frames),
    sample: structuredClone(lastSample), rgb: lastRgb.slice(), sequence,
    savedAt: new Date().toISOString()};
  const fresh = await makeCore();
  for (let i = 0; i < 240; i++) {
    if (fresh._abrams_web_step() !== 1) throw new Error('The restore core could not boot');
  }
  const restoredFrames = await restoreCheckpoint(fresh, saved.checkpoint);
  // A successful load must keep its previous session recoverable after reload,
  // just like desktop slot 0. Persist before changing the active core.
  await storedSlot('put', 0, previous);
  storedSlots.set(0, previous);
  core = fresh;
  observer = await createObserver(zip, restoredFrames);
  held = new Set();
  frames = restoredFrames;
  sequence = saved.sequence;
  undo = previous;
  lastSample = structuredClone(saved.sample);
  lastRgb = saved.rgb.slice();
  lastSample.audio = {schema: 3, frame: frames, epoch: 0, last_id: 0,
    events: [], active: false, enabled: false};
  sendSample('state_result', message.id, {}, lastRgb.slice(), {
    restored: {type: 'sample', id: message.id, sequence, fps: FPS,
      ...lastSample, timeline_reset: true, held_frame: true},
    success: true, slots: slotRows(), message: `Loaded slot ${message.slot}`});
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
    else if (message.op === 'step') step(message);
    else if (message.op === 'save_state' || message.op === 'load_state') {
      try { await state(message); }
      catch (error) {
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
