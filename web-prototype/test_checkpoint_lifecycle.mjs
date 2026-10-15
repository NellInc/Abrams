import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {test} from 'node:test';
import {createBridgeHost} from './bridge_host.mjs';

class FakeWorker {
  static last;
  constructor() { FakeWorker.last = this; this.sent = []; this.stops = 0; }
  postMessage(value) { this.sent.push(value); }
  terminate() { this.stops++; }
  emit(data) { this.onmessage?.({data}); }
}
globalThis.Worker = FakeWorker;
const host = () => createBridgeHost(new Uint8Array(1), new Uint8Array(1), 'a'.repeat(64));

test('close settles startup promises, clears data, and ignores captured late handlers', async () => {
  const bridge = host();
  const worker = FakeWorker.last;
  const late = worker.onmessage;
  bridge.close(); bridge.close();
  await assert.rejects(bridge.first, /closed/);
  await assert.rejects(bridge.viewerReady, /closed/);
  late({data: {type: 'packet', packet: {type: 'ready'}, rgb: new Uint8Array(192000)}});
  assert.equal(worker.stops, 1);
  assert.equal(bridge.attach(), false);
  assert.equal(bridge.presentationReady(), false);
  assert.equal(bridge.take(), '');
  assert.equal(bridge.takeFrame(), null);
});

test('malformed sends/controls refuse safely, only one request is outstanding, queues bounded', async () => {
  const bridge = host();
  FakeWorker.last.emit({type: 'packet', packet: {type: 'ready'}});
  await bridge.first;
  bridge.take();
  for (const json of ['{', 'null', '[]', '"step"']) {
    assert.equal(bridge.send(json), false);
    assert.equal(bridge.updateControls(json), false);
  }
  const request = JSON.stringify({op: 'step', id: 1, frames: 1, keys: []});
  assert.equal(bridge.send(request), true);
  assert.equal(bridge.send(request), false);
  FakeWorker.last.emit({type: 'packet', packet: {type: 'sample', id: 1}});
  assert.equal(bridge.send(request), true);
  const cyclic = {}; cyclic.self = cyclic;
  assert.equal(bridge.queueControl(cyclic), false);
  for (let i = 0; i < 8; i++) assert.equal(bridge.queueControl({op: 'pause'}), true);
  assert.equal(bridge.queueControl({op: 'pause'}), false);
  for (let i = 0; i < 8; i++) FakeWorker.last.emit({type: 'packet', packet: {type: 'sample'}});
  assert.equal(bridge.attach(), false);
  assert.match(bridge.take(), /queue is full/);
  await assert.rejects(bridge.viewerReady, /queue is full/);
  bridge.close();
});

test('worker startup/send failures reject viewer readiness too', async () => {
  const bridge = host();
  FakeWorker.last.onerror({message: 'crashed'});
  await assert.rejects(bridge.first, /crashed/);
  await assert.rejects(bridge.viewerReady, /crashed/);
  assert.equal(bridge.send('{}'), false);
  bridge.close();
  assert.equal(FakeWorker.last.stops, 1);
});

const workerSource = (await readFile(new URL('./bridge_worker.mjs', import.meta.url), 'utf8'))
  .replace(/^import .*;\n/gm, '').replaceAll('import.meta.url', '"file:///worker.mjs"');
function workerContext(overrides = {}) {
  const context = vm.createContext({Uint8Array, Set, Map, URL, structuredClone, console,
    setTimeout, clearTimeout, self: {}, postMessage() {}, ...overrides});
  vm.runInContext(workerSource + `\nself.inspect = () => ({core, observer, frames, sequence, held, lastSample, lastRgb, undo});
self.seed = (active, observed, saved) => {
core = active; observer = observed; frames = 50; sequence = 8; held = new Set(['a']);
lastSample = {program: {name: 'current'}, audio: {events: []}};
lastRgb = new Uint8Array(192000); zip = new Uint8Array(1); catalog = new Uint8Array(1);
buildId = 'a'.repeat(64); slots.set(1, saved);
}; self.state = state; self.openDatabase = openDatabase; self.storedSlot = storedSlot;`, context);
  return context;
}
function fakeStorage(failWrite = false) {
  const writes = [];
  const db = {closeCount: 0, close() { this.closeCount++; }, transaction() {
    const tx = {objectStore() { return {put(value, slot) {
      const request = {};
      queueMicrotask(() => {
        if (failWrite) { tx.error = new Error('quota'); tx.onabort(); }
        else { writes.push({value, slot}); tx.oncomplete(); }
      });
      return request;
    }}; }};
    return tx;
  }};
  const indexedDB = {open() { const request = {result: db}; queueMicrotask(() => request.onsuccess()); return request; }};
  return {indexedDB, db, writes};
}
function restoreContext({observerFail = false, presentationFail = false, writeFail = false} = {}) {
  const storage = fakeStorage(writeFail);
  const fresh = {FS: {mkdir() {}, writeFile() {}}, ccall() { return 1; },
    _malloc() { return 1; }, _free() {}, HEAPU8: new Uint8Array(10),
    _abrams_web_set_claim_catalog() { return 1; }, _abrams_web_step() { return 1; }};
  const freshObserver = {};
  const ctx = workerContext({indexedDB: storage.indexedDB,
    createCore: async () => fresh,
    createObserver: async () => { if (observerFail) throw new Error('observer failed'); return freshObserver; },
    captureCheckpoint: async () => ({frames: 50}), restoreCheckpoint: async () => 20});
  const saved = {checkpoint: {}, sample: {program: {name: 'saved'}}, rgb: new Uint8Array(192000), sequence: 4};
  if (presentationFail) saved.sample.bad = () => {};
  ctx.self.seed({}, {}, saved);
  return {ctx, storage, fresh, freshObserver};
}

test('observer, presentation, and durable undo failures leave the active session unchanged', async () => {
  for (const failure of [{observerFail: true}, {presentationFail: true}, {writeFail: true}]) {
    const {ctx, storage} = restoreContext(failure);
    const before = ctx.self.inspect();
    await assert.rejects(ctx.self.state({op: 'load_state', id: 1, slot: 1}),
      failure.writeFail ? /quota/ : undefined);
    const after = ctx.self.inspect();
    for (const key of ['core', 'observer', 'frames', 'sequence', 'held', 'lastSample', 'lastRgb', 'undo'])
      assert.equal(after[key], before[key], key);
    assert.equal(storage.writes.length, 0);
  }
});

test('successful load persists undo and swaps prepared snapshot with reset input/audio', async () => {
  const {ctx, storage, fresh, freshObserver} = restoreContext();
  await ctx.self.state({op: 'load_state', id: 1, slot: 1});
  const current = ctx.self.inspect();
  assert.equal(current.core, fresh);
  assert.equal(current.observer, freshObserver);
  assert.equal(current.frames, 20);
  assert.equal(current.sequence, 4);
  assert.equal(current.held.size, 0);
  assert.equal(current.lastSample.audio.enabled, false);
  assert.equal(storage.writes[0].slot, 0);
  assert.equal(current.undo, storage.writes[0].value);
});

test('storage unavailable rejects, blocked open is bounded and late success closes', async () => {
  await assert.rejects(workerContext().self.openDatabase(), /unavailable/);
  let timeout;
  const request = {};
  const db = {closed: 0, close() { this.closed++; }};
  const ctx = workerContext({indexedDB: {open() { return request; }},
    setTimeout(fn, ms) { assert.equal(ms, 8000); timeout = fn; return 1; }, clearTimeout() {}});
  const opening = ctx.self.openDatabase();
  request.onblocked(); timeout();
  await assert.rejects(opening, /blocked by another tab/);
  request.result = db; request.onsuccess();
  assert.equal(db.closed, 1);
});

test('version change closes database and a subsequent operation reopens it', async () => {
  const storage = fakeStorage();
  let opens = 0;
  const open = storage.indexedDB.open;
  storage.indexedDB.open = () => { opens++; return open(); };
  const ctx = workerContext({indexedDB: storage.indexedDB});
  await ctx.self.openDatabase();
  storage.db.onversionchange();
  assert.equal(storage.db.closeCount, 1);
  await ctx.self.openDatabase();
  assert.equal(opens, 2);
});

test('postcommit reply failure is fatal transport error, never a recoverable load rejection', async () => {
  const {ctx, storage, fresh} = restoreContext();
  const replies = [];
  ctx.postMessage = message => {
    if (message.packet?.type === 'state_result' && message.packet.success)
      throw new Error('transport unavailable');
    replies.push(message);
  };
  await ctx.self.onmessage({data: {op: 'load_state', id: 1, slot: 1}});
  assert.equal(ctx.self.inspect().core, fresh);
  assert.equal(storage.writes.length, 1);
  assert.equal(replies.length, 1);
  assert.equal(replies[0].type, 'error');
  assert.match(replies[0].message, /loaded.*could not be delivered/);
  assert.equal(replies.some(message => message.packet?.success === false), false);
});

test('missing and bounded blocked storage permit ready with explicit durable warning', async () => {
  for (const blocked of [false, true]) {
    const replies = [];
    let timeout;
    const overrides = {createObserver: async () => ({}), postMessage: message => replies.push(message)};
    if (blocked) {
      overrides.setTimeout = (callback, ms) => { assert.equal(ms, 8000); timeout = callback; return 1; };
      overrides.clearTimeout = () => {};
      overrides.indexedDB = {open() {
        const request = {};
        queueMicrotask(() => { request.onblocked(); timeout(); });
        return request;
      }};
    }
    const ctx = workerContext(overrides);
    // Substitute only core/observer rendering for this startup-storage test.
    vm.runInContext(`makeCore = async () => ({_abrams_web_step: () => 1});
      pairedFrame = () => ({audio: {events: []}});
      rgbFrame = () => new Uint8Array(192000); self.boot = boot;`, ctx);
    await ctx.self.boot({zip: new Uint8Array(1), catalog: new Uint8Array(336060), buildId: 'a'.repeat(64)});
    const ready = replies.find(message => message.packet?.type === 'ready').packet;
    assert.match(ready.storage_warning, blocked ? /blocked by another tab/ : /unavailable/);
    assert.equal(ready.protocol, 4);
    assert.equal(ready.slots.every(slot => !slot.exists && !slot.valid), true);
    await assert.rejects(ctx.self.storedSlot('put', 1, {}), /Local checkpoint storage/);
  }
});

test('fatal host errors reach status callback once', async () => {
  const statuses = [];
  const bridge = createBridgeHost(new Uint8Array(1), new Uint8Array(1), 'a'.repeat(64), value => statuses.push(value));
  const lateError = FakeWorker.last.onerror;
  lateError({message: 'failed'});
  lateError({message: 'late failure'});
  await assert.rejects(bridge.first, /failed/);
  await assert.rejects(bridge.viewerReady, /failed/);
  assert.equal(statuses.length, 1);
  assert.equal(statuses[0].type, 'error');
  assert.match(statuses[0].message, /failed/);
  bridge.close();
});
