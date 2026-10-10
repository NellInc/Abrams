import { packOriginals } from './zip_store.mjs';

const input = document.querySelector('#game-folder');
const status = document.querySelector('#status');
const canvas = document.querySelector('#screen');
const context = canvas.getContext('2d', { alpha: false });
const pause = document.querySelector('#pause');
const save = document.querySelector('#save');
const load = document.querySelector('#load');
const count = document.querySelector('#frame-count');
let worker;
let ready = false;
let paused = false;
let originalZip;
let claimCatalog;
let buildId;
const held = new Set();
const saveKey = 'original-pc-v1';
const observeSources = new URL(location.href).searchParams.get('observe') === '1';

function report(message) { status.textContent = message; }

function savedCheckpoint(mode, value) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('abrams-local-prototype', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('checkpoints');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction('checkpoints', mode === 'get' ? 'readonly' : 'readwrite');
      const operation = transaction.objectStore('checkpoints')[mode](
        ...(mode === 'get' ? [saveKey] : [value, saveKey]));
      operation.onsuccess = () => { if (mode === 'get') resolve(operation.result); };
      transaction.oncomplete = () => { db.close(); if (mode !== 'get') resolve(); };
      transaction.onerror = () => { db.close(); reject(transaction.error); };
    };
  });
}

async function updateLoad() {
  const stored = await savedCheckpoint('get');
  load.disabled = !ready || !originalZip || stored?.buildId !== buildId;
}

function stopWorker() {
  releaseAll();
  worker?.terminate();
  worker = undefined;
  ready = false;
  paused = false;
  pause.disabled = save.disabled = load.disabled = true;
  pause.textContent = 'Pause';
}

function startWorker(checkpoint = null) {
  stopWorker();
  worker = new Worker(new URL('./runner_worker.mjs', import.meta.url), { type: 'module' });
  worker.onerror = event => { stopWorker(); report(`Browser worker failed: ${event.message}`); };
  worker.onmessage = async event => {
    const message = event.data;
    if (message.type === 'ready') {
      ready = true;
      count.textContent = `FRAME ${message.frames}`;
      pause.disabled = save.disabled = false;
      try { await updateLoad(); }
      catch { load.disabled = true; }
      report(message.restored ? 'Local save restored. Original PC game running.' :
        'Original PC game running. Click the display to use its keyboard.');
    } else if (message.type === 'frame') {
      if (canvas.width !== message.width || canvas.height !== message.height) {
        canvas.width = message.width;
        canvas.height = message.height;
      }
      context.putImageData(new ImageData(message.pixels, message.width, message.height), 0, 0);
      if (message.frames % 120 === 0) count.textContent = `FRAME ${message.frames}`;
    } else if (message.type === 'presentation' && observeSources) {
      const paired = message.presentation.presentation;
      const source = paired?.draw_pass ? 'DRAW PASS' : paired?.ui_overlay ? 'SOURCE PAIRED' : 'OBSERVING';
      count.textContent = `FRAME ${message.frames} · ${source}`;
    } else if (message.type === 'checkpoint') {
      pause.disabled = false;
      try {
        await savedCheckpoint('put', { buildId, checkpoint: message.checkpoint });
        paused = true;
        pause.textContent = 'Resume';
        await updateLoad();
        report('Checkpoint saved in this browser. Original game paused.');
      } catch (error) {
        paused = true;
        pause.textContent = 'Resume';
        report(`Local save failed: ${error?.message || error}`);
      }
    } else if (message.type === 'save_error') {
      paused = true;
      pause.disabled = false;
      pause.textContent = 'Resume';
      try { await updateLoad(); } catch { load.disabled = true; }
      report(`Local save failed: ${message.message}. The current game can resume.`);
    } else if (message.type === 'error') {
      stopWorker();
      report(`The game stopped: ${message.message}`);
    }
  };
  const zip = originalZip.slice();
  const catalog = claimCatalog.slice();
  const transfers = [zip.buffer, catalog.buffer];
  if (checkpoint) transfers.push(checkpoint.state.buffer, checkpoint.overlay.buffer);
  worker.postMessage({ type: 'start', zip, catalog, checkpoint, observe: observeSources }, transfers);
}

function originalKey(event) {
  const byCode = {
    ArrowUp: 273, ArrowDown: 274, ArrowRight: 275, ArrowLeft: 276,
    Backspace: 8, Tab: 9, Enter: 13, Escape: 27, Space: 32,
    ShiftLeft: 304, ShiftRight: 304, ControlLeft: 306, ControlRight: 306,
    AltLeft: 308, AltRight: 308,
  };
  if (Object.hasOwn(byCode, event.code)) return byCode[event.code];
  if (/^Numpad[0-9]$/.test(event.code)) return 256 + Number(event.code.slice(-1));
  if (/^F([1-9]|1[0-2])$/.test(event.code)) return 281 + Number(event.code.slice(1));
  if (/^Key[A-Z]$/.test(event.code)) return event.code.charCodeAt(3) + 32;
  if (/^Digit[0-9]$/.test(event.code)) return event.code.charCodeAt(5);
  return null;
}

function releaseAll() {
  for (const key of held) worker?.postMessage({ type: 'key', key, down: false });
  held.clear();
}

window.addEventListener('keydown', event => {
  if (!ready || paused || document.activeElement !== canvas) return;
  const key = originalKey(event);
  if (key === null) return;
  event.preventDefault();
  if (!held.has(key)) worker.postMessage({ type: 'key', key, down: true });
  held.add(key);
});
window.addEventListener('keyup', event => {
  const key = originalKey(event);
  if (key === null || !held.has(key)) return;
  event.preventDefault();
  worker?.postMessage({ type: 'key', key, down: false });
  held.delete(key);
});
window.addEventListener('blur', releaseAll);
canvas.addEventListener('blur', releaseAll);
canvas.addEventListener('click', () => canvas.focus());

pause.addEventListener('click', () => {
  if (!ready) return;
  releaseAll();
  worker.postMessage({ type: paused ? 'resume' : 'pause' });
  paused = !paused;
  pause.textContent = paused ? 'Resume' : 'Pause';
  save.disabled = paused;
  report(paused ? 'Original game paused.' : 'Original PC game running.');
});

save.addEventListener('click', () => {
  if (!ready || paused) return;
  releaseAll();
  paused = true;
  save.disabled = true;
  pause.disabled = load.disabled = true;
  worker.postMessage({ type: 'save' });
  report('Saving the original game and its disk locally…');
});

load.addEventListener('click', async () => {
  if (!ready || !originalZip) return;
  try {
    const stored = await savedCheckpoint('get');
    if (stored?.buildId !== buildId || !stored.checkpoint)
      throw new Error('This save needs the exact browser build that made it');
    report('Starting a fresh emulator for the local checkpoint…');
    startWorker(stored.checkpoint);
  } catch (error) {
    report(`Local load failed: ${error?.message || error}`);
  }
});

input.addEventListener('change', async () => {
  if (!input.files?.length) return;
  stopWorker();
  originalZip = undefined;
  claimCatalog = undefined;
  buildId = undefined;
  report('Checking the original PC game files locally…');
  try {
    if (!crossOriginIsolated) throw new Error('This page needs cross origin isolation for the emulator threads. Start it with serve.py.');
    const [response, build] = await Promise.all([
      fetch('./.generated/game-inputs.json', { cache: 'no-store' }),
      fetch('./.generated/build-info.json', { cache: 'no-store' }),
    ]);
    if (!response.ok || !build.ok) throw new Error('The browser build is incomplete. Run build_core.py first.');
    const prepared = await packOriginals(input.files, await response.json());
    originalZip = prepared.zip;
    claimCatalog = prepared.catalog;
    buildId = (await build.json()).wasm_sha256;
    if (!/^[0-9a-f]{64}$/.test(buildId)) throw new Error('Invalid browser build identity');
    report('Verified 68 original files. Starting the DOS emulator…');
    startWorker();
  } catch (error) {
    report(String(error?.message || error));
  } finally {
    input.value = '';
  }
});
