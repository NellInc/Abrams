import createCore from './.generated/core.js';
import { captureCheckpoint, restoreCheckpoint } from './checkpoint_core.mjs';

let core;
let timer;
let frames = 0;
let running = false;
let observer;

function sample() {
  const pointer = core._abrams_web_video();
  const width = core._abrams_web_video_width();
  const height = core._abrams_web_video_height();
  const pitch = core._abrams_web_video_pitch();
  if (!pointer || !width || !height || pitch < width * 4) return;
  const source = core.HEAPU8;
  const pixels = new Uint8ClampedArray(width * height * 4);
  for (let row = 0; row < height; row++) {
    let from = pointer + row * pitch;
    let to = row * width * 4;
    for (let column = 0; column < width; column++) {
      pixels[to++] = source[from + 2];
      pixels[to++] = source[from + 1];
      pixels[to++] = source[from];
      pixels[to++] = 255;
      from += 4;
    }
  }
  postMessage({ type: 'frame', pixels, width, height, frames }, [pixels.buffer]);
}

function step() {
  if (!running) return;
  try {
    if (observer) {
      const before = core._abrams_web_ram_now();
      if (!before) throw new Error('Original RAM is unavailable to the source observer');
      const mode = observer.beforeFrame(core.HEAPU8.slice(before, before + 640 * 1024));
      if (mode.mode === 'frontend' && core._abrams_web_trace_frontend() !== 1)
        throw new Error('Cannot attach the original frontend source observer');
      if (mode.mode === 'sim' && core._abrams_web_trace_sim(mode.load_segment) !== 1)
        throw new Error('Cannot attach the original SIM source observer');
    }
    if (core._abrams_web_step() !== 1) throw new Error('The original game stopped or its memory map changed');
    frames++;
    if (observer) {
      if (core._abrams_web_trace_overflow() || core._abrams_web_claim_fault())
        throw new Error('The original source observer rejected this frame');
      const trace = core._abrams_web_trace_events(), traceSize = core._abrams_web_trace_size();
      const claim = core._abrams_web_claim_receipts(), claimSize = core._abrams_web_claim_receipts_size();
      // The step copied RAM just before retro_run submitted this framebuffer
      // (desktop last_video_ram). Copy it before ram_now() reuses the buffer.
      const pairedPointer = core._abrams_web_paired_ram();
      const paired = pairedPointer && core.HEAPU8.slice(pairedPointer, pairedPointer + 640 * 1024);
      const memory = core._abrams_web_ram_now();
      const video = core._abrams_web_video();
      const width = core._abrams_web_video_width(), height = core._abrams_web_video_height();
      const pitch = core._abrams_web_video_pitch();
      if (!paired || !memory || !video || !width || !height)
        throw new Error('The original game has no paired source frame');
      const presentation = JSON.parse(observer.afterFrame(
        core.HEAPU8.slice(trace, trace + traceSize),
        core.HEAPU8.slice(claim, claim + claimSize), paired,
        core.HEAPU8.slice(memory, memory + 640 * 1024),
        core.HEAPU8.slice(video, video + pitch * height), width, height, pitch));
      postMessage({type: 'presentation', presentation, frames});
    }
    sample();
    timer = setTimeout(step, 1000 / 59.92);
  } catch (error) {
    running = false;
    postMessage({ type: 'error', message: String(error?.message || error) });
  }
}

async function start(zip, catalog, checkpoint, observe) {
  if (core) throw new Error('A game is already open in this browser worker');
  core = await createCore({
    locateFile: name => new URL(`./.generated/${name}`, import.meta.url).href,
  });
  core.FS.mkdir('/game');
  core.FS.mkdir('/saves');
  core.FS.writeFile('/game/abrams-ref.zip', zip);
  if (core.ccall('abrams_web_start', 'number', ['string'], ['/game/abrams-ref.zip']) !== 1)
    throw new Error('The pinned original game did not boot');
  if (!(catalog instanceof Uint8Array) || catalog.length < 8 || catalog.length > 1024 * 1024)
    throw new Error('The original game source catalog is missing');
  const pointer = core._malloc(catalog.length);
  try {
    core.HEAPU8.set(catalog, pointer);
    if (core._abrams_web_set_claim_catalog(pointer, catalog.length) !== 1)
      throw new Error('The original game source catalog was rejected');
  } finally { core._free(pointer); }
  if (observe) {
    const {createObserver} = await import('./browser_observer.mjs');
    observer = await createObserver(zip);
  }
  if (checkpoint) {
    for (let frame = 0; frame < 240; frame++) {
      if (core._abrams_web_step() !== 1) throw new Error('Original emulator restore boot failed');
    }
    frames = await restoreCheckpoint(core, checkpoint);
  }
  running = true;
  postMessage({ type: 'ready', restored: !!checkpoint, frames });
  step();
}

self.onmessage = async event => {
  const message = event.data;
  if (message.type === 'start') {
    start(message.zip, message.catalog, message.checkpoint, message.observe)
      .catch(error => postMessage({ type: 'error', message: String(error?.message || error) }));
  } else if (message.type === 'key' && core && running) {
    core._abrams_web_key(message.key, message.down ? 1 : 0);
  } else if (message.type === 'save' && core && running) {
    running = false;
    clearTimeout(timer);
    try {
      const checkpoint = await captureCheckpoint(core, frames);
      postMessage({ type: 'checkpoint', checkpoint },
        [checkpoint.state.buffer, checkpoint.overlay.buffer]);
    } catch (error) {
      postMessage({ type: 'save_error', message: String(error?.message || error) });
    }
  } else if (message.type === 'pause') {
    running = false;
    clearTimeout(timer);
    postMessage({ type: 'paused', frames });
  } else if (message.type === 'resume' && core && !running) {
    running = true;
    step();
  }
};
