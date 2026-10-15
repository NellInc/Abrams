// Local integration gate for the browser-to-Godot packet contract. Original
// game bytes are read only from ignored developer inputs for this test.
import {execFileSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {readFile} from 'node:fs/promises';
import {syncBuiltinESMExports} from 'node:module';
import {fileURLToPath} from 'node:url';
import workerThreads from 'node:worker_threads';
import {buildClaimCatalog} from './claim_catalog.mjs';

const root = new URL('../', import.meta.url);
const required = ['GAME/SIM.EXE', '.runtime/pc-core/abrams-ref.zip',
  '.runtime/pyodide/node_modules/pyodide/pyodide.mjs', 'web-prototype/.generated/core.js',
  'web-prototype/.generated/game-inputs.json', 'web-prototype/.generated/build-info.json'];
const missing = required.filter(name => !existsSync(new URL(name, root)));
if (missing.length) {
  console.log(`SKIP: local inputs absent (${missing.join(', ')})`);
  process.exit(0);
}
const manifest = JSON.parse(await readFile(new URL('.generated/game-inputs.json', import.meta.url)));
const originals = new Map();
for (const row of manifest.files)
  originals.set(row.name.toUpperCase(), new Uint8Array(await readFile(new URL(`GAME/${row.name}`, root))));
const zip = new Uint8Array(await readFile(new URL('.runtime/pc-core/abrams-ref.zip', root)));
const catalog = buildClaimCatalog(originals);
const build = JSON.parse(await readFile(new URL('.generated/build-info.json', import.meta.url)));
// Exercise the working-tree observer, not a previously generated archive.
const pythonSource = execFileSync('python3', ['web-prototype/build_observer.py', '--source-zip-stdout'],
  {cwd: fileURLToPath(root), maxBuffer: 16 * 1024 * 1024});
const realFetch = globalThis.fetch;
globalThis.fetch = async (resource, init) => {
  const url = new URL(resource);
  if (url.protocol === 'file:' && url.pathname.endsWith('/.generated/python-source.zip'))
    return new Response(pythonSource, {status: 200});
  if (url.protocol === 'file:')
    return new Response(await readFile(fileURLToPath(url)), {status: 200});
  return realFetch(resource, init);
};
// Count the core workers the bridge spawns; each load must retire its old one.
const NodeWorker = workerThreads.Worker;
const coreWorkers = {live: 0, spawned: 0, exited: 0};
workerThreads.Worker = class extends NodeWorker {
  constructor(...args) {
    super(...args);
    coreWorkers.live++;
    coreWorkers.spawned++;
    this.once('exit', () => { coreWorkers.live--; coreWorkers.exited++; });
  }
};
syncBuiltinESMExports();
// Node has no IndexedDB. This explicit test-only adapter models transaction
// acknowledgement; persistence across page/process restarts is a browser gate.
const checkpointRows = new Map();
globalThis.indexedDB = {open() {
  const request = {};
  request.result = {close() {}, transaction() {
    const tx = {objectStore() { return {
      get(slot) { const result = {}; queueMicrotask(() => { result.result = checkpointRows.get(slot); result.onsuccess?.(); tx.oncomplete?.(); }); return result; },
      put(value, slot) { const result = {}; queueMicrotask(() => { checkpointRows.set(slot, structuredClone(value)); result.onsuccess?.(); tx.oncomplete?.(); }); return result; },
    }; }};
    return tx;
  }};
  queueMicrotask(() => request.onsuccess());
  return request;
}};
const packets = [];
globalThis.self = globalThis;
globalThis.postMessage = message => packets.push(message);
await import('./bridge_worker.mjs');
const request = async data => {
  packets.length = 0;
  await self.onmessage({data});
  if (packets.find(packet => packet.type === 'error'))
    throw new Error(packets.find(packet => packet.type === 'error').message);
  const message = packets.find(item => item.type === 'packet');
  if (!message) throw new Error('Original Web bridge did not answer');
  // Godot receives exactly the text bridge_host.take() returns.
  const packet = JSON.parse(message.json ?? JSON.stringify(message.packet));
  if (message.json && (message.packet.type !== packet.type || message.packet.id !== packet.id ||
      message.packet.sequence !== packet.sequence ||
      (message.packet.program?.name ?? null) !== (packet.program?.name ?? null)))
    throw new Error('Original Web bridge envelope differs from its packet');
  return {packet, rgb: message.rgb};
};
const sameBytes = (a, b) => a?.length === b?.length && a.every((value, index) => value === b[index]);
const start = Date.now();
const ready = await request({op: 'boot', zip, catalog, buildId: build.wasm_sha256});
if (ready.packet.type !== 'ready' || ready.packet.protocol !== 4 ||
    ready.packet.audio?.schema !== 3 || ready.rgb?.length !== 320 * 200 * 3 ||
    ready.packet.presentation == null ||
    ready.packet.presentation.ui_overlay == null ||
    ready.packet.slots?.length !== 6 ||
    ready.packet.slots[1]?.slot !== 1 || ready.packet.slots[1]?.exists !== false ||
    ready.packet.presentation.text_runs?.map(run => run.text).join('|') !==
      'DO YOU WANT TO USE A JOYSTICK?|YES|NO')
  throw new Error('Original Web bridge ready packet lacks Play data');
if (coreWorkers.live !== 1) throw new Error(`Expected one original core worker, found ${coreWorkers.live}`);
console.log(JSON.stringify({stage: 'ready', program: ready.packet.program?.name,
  boot_ms: Date.now() - start, rgb: ready.rgb.length,
  audio_events: ready.packet.audio.events.length}));
const sample = await request({op: 'step', id: 0, frames: 2, keys: []});
if (sample.packet.type !== 'sample' || sample.packet.id !== 0 ||
    sample.packet.sequence !== 2 || sample.rgb.length !== ready.rgb.length ||
    sample.packet.held_frame)
  throw new Error('Original Web bridge step packet is out of sequence');
const empty = await request({op: 'load_state', id: 1, slot: 2});
if (empty.packet.type !== 'state_result' || empty.packet.success !== false ||
    empty.packet.slots[2]?.exists !== false)
  throw new Error('Empty local slot must be a recoverable menu result');
const saved = await request({op: 'save_state', id: 2, slot: 1});
if (saved.packet.type !== 'state_result' || saved.packet.success !== true ||
    saved.packet.slots[1]?.slot !== 1 || saved.packet.slots[1]?.valid !== true)
  throw new Error('Original Web bridge did not save locally');
let id = 3;
const LOADS = Number(process.env.ABRAMS_WEB_LOADS || 4);
const memory = [];
for (let load = 0; load < LOADS; load++) {
  const loadStarted = Date.now();
  const loaded = await request({op: 'load_state', id: id++, slot: 1});
  if (loaded.packet.type !== 'state_result' || !loaded.packet.restored?.timeline_reset ||
      loaded.rgb.length !== ready.rgb.length || loaded.packet.slots[0]?.valid !== true)
    throw new Error('Original Web bridge did not restore a paired frame');
  const loadMs = Date.now() - loadStarted;
  // The first native framebuffer after a restore is stale; desktop holds the
  // restored packet until two original frames have run.
  const heldStep = await request({op: 'step', id: id++, frames: 1, keys: []});
  if (heldStep.packet.sequence !== 3 || heldStep.packet.held_frame !== true ||
      heldStep.packet.timeline_reset !== false || !sameBytes(heldStep.rgb, loaded.rgb))
    throw new Error('Original Web bridge showed the stale post-restore framebuffer');
  const continued = await request({op: 'step', id: id++, frames: 1, keys: []});
  if (continued.packet.sequence !== 4 || continued.packet.held_frame || !continued.packet.presentation)
    throw new Error('Original Web bridge did not continue after restore');
  // Each load retires the previous core worker with its pthread pool and heap.
  await new Promise(resolve => setTimeout(resolve, 200));
  if (coreWorkers.live !== 1 || coreWorkers.exited !== load + 1)
    throw new Error(`Checkpoint load leaked original core workers: ${JSON.stringify(coreWorkers)}`);
  globalThis.gc?.();  // Run with --expose-gc for a settled RSS reading.
  memory.push(Math.round(process.memoryUsage().rss / 1048576));
  console.log(JSON.stringify({stage: 'load', load: load + 1, load_ms: loadMs,
    rss_mib: memory.at(-1), core_workers: coreWorkers.live}));
}
console.log(JSON.stringify({stage: 'step-save-load-step', loads: LOADS,
  core_workers: coreWorkers, rss_mib: memory, total_ms: Date.now() - start}));
process.exit(0);
