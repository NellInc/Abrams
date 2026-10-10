// Local integration gate for the browser-to-Godot packet contract. Original
// game bytes are read only from ignored developer inputs for this test.
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {buildClaimCatalog} from './claim_catalog.mjs';

const root = new URL('../', import.meta.url);
const manifest = JSON.parse(await readFile(new URL('.generated/game-inputs.json', import.meta.url)));
const originals = new Map();
for (const row of manifest.files)
  originals.set(row.name.toUpperCase(), new Uint8Array(await readFile(new URL(`GAME/${row.name}`, root))));
const zip = new Uint8Array(await readFile(new URL('.runtime/pc-core/abrams-ref.zip', root)));
const catalog = buildClaimCatalog(originals);
const build = JSON.parse(await readFile(new URL('.generated/build-info.json', import.meta.url)));
const realFetch = globalThis.fetch;
globalThis.fetch = async (resource, init) => {
  const url = new URL(resource);
  if (url.protocol === 'file:')
    return new Response(await readFile(fileURLToPath(url)), {status: 200});
  return realFetch(resource, init);
};
const packets = [];
globalThis.self = globalThis;
globalThis.postMessage = message => packets.push(message);
await import('./bridge_worker.mjs');
const request = async data => {
  packets.length = 0;
  await self.onmessage({data});
  if (packets.find(packet => packet.type === 'error'))
    throw new Error(packets.find(packet => packet.type === 'error').message);
  const packet = packets.find(item => item.type === 'packet');
  if (!packet) throw new Error('Original Web bridge did not answer');
  return packet;
};
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
console.log(JSON.stringify({stage: 'ready', program: ready.packet.program?.name,
  boot_ms: Date.now() - start, rgb: ready.rgb.length,
  audio_events: ready.packet.audio.events.length}));
const sample = await request({op: 'step', id: 0, frames: 2, keys: []});
if (sample.packet.type !== 'sample' || sample.packet.id !== 0 ||
    sample.packet.sequence !== 2 || sample.rgb.length !== ready.rgb.length)
  throw new Error('Original Web bridge step packet is out of sequence');
const empty = await request({op: 'load_state', id: 1, slot: 2});
if (empty.packet.type !== 'state_result' || empty.packet.success !== false ||
    empty.packet.slots[2]?.exists !== false)
  throw new Error('Empty local slot must be a recoverable menu result');
const saved = await request({op: 'save_state', id: 2, slot: 1});
if (saved.packet.type !== 'state_result' || saved.packet.success !== true ||
    saved.packet.slots[1]?.slot !== 1 || saved.packet.slots[1]?.valid !== true)
  throw new Error('Original Web bridge did not save locally');
const loaded = await request({op: 'load_state', id: 3, slot: 1});
if (loaded.packet.type !== 'state_result' || !loaded.packet.restored?.timeline_reset ||
    loaded.rgb.length !== ready.rgb.length || loaded.packet.slots[0]?.valid !== true)
  throw new Error('Original Web bridge did not restore a paired frame');
const continued = await request({op: 'step', id: 4, frames: 1, keys: []});
if (continued.packet.sequence !== 3 || !continued.packet.presentation)
  throw new Error('Original Web bridge did not continue after restore');
console.log(JSON.stringify({stage: 'step-save-load-step', sequence: continued.packet.sequence,
  total_ms: Date.now() - start}));
