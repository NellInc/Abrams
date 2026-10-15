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
  // Slot 0 is the undo row: load_state may read it, nothing else may name it.
  for (const op of ['save_state', 'load_previous'])
    assert.equal(bridge.send(JSON.stringify({op, id: 1, slot: 0})), false, op);
  assert.equal(bridge.send(JSON.stringify({op: 'unknown_state', id: 1, slot: 1})), false);
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

test('pre-serialised sample JSON passes through take() unchanged; malformed JSON fails closed', async () => {
  const statuses = [];
  const bridge = createBridgeHost(new Uint8Array(1), new Uint8Array(1), 'a'.repeat(64), value => statuses.push(value));
  const json = '{"type":"ready","id":-1,"sequence":0,"program":{"name":"START"},"state":null}';
  FakeWorker.last.emit({type: 'packet', packet: {type: 'ready', id: -1, sequence: 0, program: {name: 'START'}},
    json, rgb: new Uint8Array(192000)});
  await bridge.first;
  assert.equal(statuses[0].program.name, 'START');
  assert.equal(bridge.take(), json);
  assert.equal(bridge.takeFrame().byteLength, 192000);
  FakeWorker.last.emit({type: 'packet', packet: {type: 'sample', id: 0}, json: 42});
  assert.equal(bridge.attach(), false);
  assert.match(bridge.take(), /Invalid original worker packet/);
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

const RAM = 640 * 1024;
const VIDEO = RAM + 4096;
// A core worker double speaking the core_worker.mjs protocol. Its heap marks
// current RAM with 2; the separately returned VGA-paired RAM is marked 1.
function fakeCores(failures = {}) {
  const cores = [];
  class FakeCoreWorker {
    constructor(url, options) {
      cores.push(this);
      Object.assign(this, {url: String(url), options, ops: [], terminated: 0});
      this.heap = new Uint8Array(VIDEO + 320 * 200 * 4);
      this.heap.fill(2, 0, RAM);
      this.heap.fill(9, VIDEO);
    }
    postMessage(message) {
      this.ops.push(message);
      queueMicrotask(() => {
        if (this.terminated) return;
        const failure = failures[message.op];
        if (failure) { this.onmessage({data: {id: message.id, ok: false, message: failure}}); return; }
        const ram = {heap: this.heap, ram: 0};
        const result = {
          start: {}, run: {}, keys: {}, ram,
          capture: {version: 1, frames: message.frames},
          restore: {frames: 20, ...ram},
          advance: {heap: this.heap, pairedRam: new Uint8Array(RAM).fill(1), current: 0,
            trace: [0, 0], claims: [0, 0], video: [VIDEO, 320, 200, 1280]},
        }[message.op];
        this.onmessage({data: {id: message.id, ok: true, result}});
      });
    }
    terminate() { this.terminated++; }
  }
  return {cores, FakeCoreWorker};
}
function fakeObservers(failure = false) {
  const observers = [];
  const runtime = {createObserver(frameBase) {
    if (failure) throw new Error('observer failed');
    const observer = {frameBase, destroyed: 0, before: [], after: [], programName: 'SIM',
      destroy() { this.destroyed++; },
      beforeFrame(ram) { this.before.push(ram[0]); return {mode: 'unchanged'}; },
      afterFrame(trace, claims, paired, current, video, width, height, pitch, final) {
        this.after.push({paired: paired[0], current: current[0], video: video[0], final});
        return final ? JSON.stringify({program: {name: 'SIM'}, state: {frame: this.after.length},
          presentation: {}, audio: {schema: 3, events: []}, events: 0}) : undefined;
      }};
    observers.push(observer);
    return observer;
  }};
  return {observers, runtime};
}

function workerContext(overrides = {}) {
  const context = vm.createContext({Uint8Array, Set, Map, URL, structuredClone, console,
    setTimeout, clearTimeout, queueMicrotask, self: {}, postMessage() {}, ...overrides});
  vm.runInContext(workerSource + `
self.inspect = () => ({core, observer, frames, sequence, held, lastSample, lastRgb, undo,
  framesSinceRestore});
self.seed = (runtime, saved) => {
core = new CoreWorker(new Worker('seed')); observerRuntime = runtime;
observer = runtime.createObserver(50); frames = 50; sequence = 8; held = new Set(['a']);
nextRam = new Uint8Array(640 * 1024).fill(2);
lastSample = JSON.stringify({program: {name: 'current'}, audio: {events: []}});
lastProgram = 'current'; lastRgb = new Uint8Array(192000).fill(7);
zip = new Uint8Array(1); catalog = new Uint8Array(1);
buildId = 'a'.repeat(64); slots.set(1, saved);
}; self.state = state; self.boot = boot; self.openDatabase = openDatabase; self.storedSlot = storedSlot;
self.storedSlots = storedSlots;`, context);
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
function restoreContext({observerFail = false, presentationFail = false, writeFail = false,
  coreFailures = {}} = {}) {
  const storage = fakeStorage(writeFail);
  const {cores, FakeCoreWorker} = fakeCores();
  const {observers, runtime} = fakeObservers();
  const replies = [];
  const ctx = workerContext({indexedDB: storage.indexedDB, Worker: FakeCoreWorker,
    postMessage: message => replies.push(message)});
  const saved = {checkpoint: {version: 1}, sample: {program: {name: 'saved'}},
    rgb: new Uint8Array(192000).fill(5), sequence: 4};
  if (presentationFail) saved.sample.bad = () => {};
  ctx.self.seed(runtime, saved);
  const seeded = cores[0];
  // Failures apply only to cores and observers prepared by the load.
  if (observerFail) runtime.createObserver = () => { throw new Error('observer failed'); };
  if (Object.keys(coreFailures).length) {
    const fail = fakeCores(coreFailures);
    ctx.Worker = class extends fail.FakeCoreWorker {
      constructor(...args) { super(...args); cores.push(this); }
    };
  }
  return {ctx, storage, cores, seeded, observers, replies, saved};
}
// Worker-realm objects have their own prototypes; compare their JSON shape.
const plain = value => JSON.parse(JSON.stringify(value));
const step = (ctx, id, frames = 1) => ctx.self.onmessage({data: {op: 'step', id, frames, keys: []}});

test('every pre-commit restore failure keeps the session and terminates the prepared core', async () => {
  for (const failure of [{coreFailures: {start: 'core boot failed'}},
    {coreFailures: {run: 'The restore core could not boot'}},
    {coreFailures: {restore: 'Restored original RAM does not match the checkpoint'}},
    {observerFail: true}, {presentationFail: true}, {writeFail: true}]) {
    const {ctx, storage, cores, seeded, observers} = restoreContext(failure);
    const before = ctx.self.inspect();
    await assert.rejects(ctx.self.state({op: 'load_state', id: 1, slot: 1}),
      failure.writeFail ? /quota/ : undefined);
    const after = ctx.self.inspect();
    for (const key of ['core', 'observer', 'frames', 'sequence', 'held', 'lastSample', 'lastRgb', 'undo'])
      assert.equal(after[key], before[key], key);
    assert.equal(storage.writes.length, 0);
    assert.equal(seeded.terminated, 0, 'active core retained');
    const prepared = cores.filter(core => core !== seeded);
    assert.equal(prepared.length, failure.presentationFail ? 0 : 1, JSON.stringify(failure));
    for (const core of prepared) assert.equal(core.terminated, 1, `prepared core released: ${JSON.stringify(failure)}`);
    assert.equal(observers[0].destroyed, 0, 'active observer retained');
    for (const observer of observers.slice(1)) assert.equal(observer.destroyed, 1, 'prepared observer released');
  }
});

test('successful loads retire the old core and observer, so repeated loads stay bounded', async () => {
  const {ctx, storage, cores, seeded, observers} = restoreContext();
  for (let load = 1; load <= 5; load++) {
    const previousCore = ctx.self.inspect().core;
    await ctx.self.state({op: 'load_state', id: load, slot: 1});
    const current = ctx.self.inspect();
    assert.notEqual(current.core, previousCore);
    assert.equal(cores.filter(core => !core.terminated).length, 1, `load ${load}: one live core`);
    assert.equal(observers.filter(observer => !observer.destroyed).length, 1, `load ${load}: one live observer`);
    assert.equal(current.observer, observers.at(-1));
    assert.equal(current.observer.frameBase, 20);
  }
  assert.equal(seeded.terminated, 1);
  assert.ok(cores.every(core => core.terminated <= 1), 'no core terminated twice');
  assert.equal(cores.at(-1).options.type, 'module');
  assert.match(cores.at(-1).url, /core_worker\.mjs$/);
  // The load restores into a freshly booted core: start, 240 frames, restore.
  assert.deepEqual(cores.at(-1).ops.map(message => message.op), ['start', 'run', 'restore']);
  assert.equal(cores.at(-1).ops[1].frames, 240);
  const current = ctx.self.inspect();
  assert.equal(current.frames, 20);
  assert.equal(current.sequence, 4);
  assert.equal(current.held.size, 0);
  assert.equal(JSON.parse(current.lastSample).audio.enabled, false);
  assert.equal(storage.writes.at(-1).slot, 0);
  assert.equal(current.undo, storage.writes.at(-1).value);
  assert.equal(storage.writes[0].value.sample.program.name, 'current');
});

test('after a load the stale first framebuffer is held, as on desktop', async () => {
  const {ctx, observers, replies, saved} = restoreContext();
  await ctx.self.state({op: 'load_state', id: 1, slot: 1});
  replies.length = 0;
  await step(ctx, 2);
  const held = replies.find(message => message.type === 'packet');
  const heldPacket = JSON.parse(held.json);
  assert.equal(heldPacket.held_frame, true);
  assert.equal(heldPacket.timeline_reset, false);
  assert.equal(heldPacket.sequence, 5);
  assert.equal(heldPacket.program.name, 'saved');
  assert.deepEqual(held.rgb, saved.rgb);
  const observer = observers.at(-1);
  assert.deepEqual(observer.after.map(frame => frame.final), [false]);
  replies.length = 0;
  await step(ctx, 3);
  const live = JSON.parse(replies.find(message => message.type === 'packet').json);
  assert.equal(live.held_frame, undefined);
  assert.equal(live.program.name, 'SIM');
  assert.equal(live.sequence, 6);
  assert.deepEqual(observer.after.map(frame => frame.final), [false, true]);
  assert.equal(replies[0].rgb[0], 9, 'live RGB comes from the core framebuffer');
});

test('frames pair VGA RAM with their framebuffer and hand current RAM to audio', async () => {
  const {ctx, observers, replies} = restoreContext();
  await step(ctx, 1, 3);
  const observer = observers[0];
  // Pre-retro_run (paired) RAM is marked 1; RAM read after the frame is 2.
  assert.deepEqual(observer.after.map(({paired, current, final}) => [paired, current, final]),
    [[1, 2, false], [1, 2, false], [1, 2, true]]);
  assert.deepEqual(observer.before, [2, 2, 2]);
  const message = replies.find(item => item.type === 'packet');
  const packet = JSON.parse(message.json);
  assert.deepEqual([packet.type, packet.id, packet.sequence, packet.fps], ['sample', 1, 11, 59.9227]);
  assert.deepEqual(packet.state, {frame: 3});
  assert.deepEqual(plain(message.packet), {type: 'sample', id: 1, sequence: 11, fps: 59.9227, program: {name: 'SIM'}});
});

test('save_state persists the parsed presented sample; key changes reach the core in order', async () => {
  const {ctx, storage, seeded, replies} = restoreContext();
  await ctx.self.onmessage({data: {op: 'step', id: 1, frames: 1, keys: ['space', 'up']}});
  await ctx.self.onmessage({data: {op: 'step', id: 2, frames: 1, keys: ['up']}});
  assert.deepEqual(seeded.ops.filter(message => message.op === 'keys').map(message => plain(message.changes)),
    [[[97, 0], [32, 1], [273, 1]], [[32, 0]]]);
  replies.length = 0;
  await ctx.self.onmessage({data: {op: 'save_state', id: 3, slot: 2}});
  const result = replies[0].packet;
  assert.equal(result.success, true);
  assert.equal(result.slots[2].valid, true);
  assert.equal(result.slots[2].program, 'SIM');
  assert.equal(storage.writes[0].slot, 2);
  assert.equal(storage.writes[0].value.sample.program.name, 'SIM');
  assert.equal(storage.writes[0].value.checkpoint.frames, 52);
});

test('saving over a slot keeps its row for load_previous, which restores without rewriting the slot', async () => {
  const {ctx, storage, replies, saved} = restoreContext();
  Object.assign(saved, {buildId: 'a'.repeat(64), savedAt: '2026-10-01T00:00:00.000Z'});
  ctx.self.storedSlots.set(1, saved);
  await ctx.self.onmessage({data: {op: 'save_state', id: 1, slot: 1}});
  // The overwritten row is written first, so a failed slot write keeps both equal.
  assert.deepEqual(storage.writes.map(write => write.slot), ['previous-1', 1]);
  assert.equal(storage.writes[0].value, saved);
  const rows = replies.at(-1).packet.slots;
  assert.equal(rows[1].previous_saved_at, saved.savedAt);
  assert.equal(rows.filter(row => 'previous_saved_at' in row).length, 1);
  replies.length = 0;
  await ctx.self.onmessage({data: {op: 'load_previous', id: 2, slot: 1}});
  const result = replies.at(-1).packet;
  assert.equal(result.success, true);
  assert.equal(result.restored.program.name, 'saved');
  assert.match(result.message, /Loaded previous slot 1/);
  // Only the undo row is written; slot 1 still holds the newer save.
  assert.deepEqual(storage.writes.slice(2).map(write => write.slot), [0]);
  assert.equal(ctx.self.inspect().undo, storage.writes[2].value);
  assert.equal(ctx.self.storedSlots.get(1), storage.writes[1].value);
  replies.length = 0;
  await ctx.self.onmessage({data: {op: 'load_previous', id: 3, slot: 0}});
  assert.equal(replies.at(-1).packet.success, false);
  assert.match(replies.at(-1).packet.message, /Invalid local state request/);
});

test('a previous row from another build is kept on disk but never offered', async () => {
  const {ctx, storage, replies, saved} = restoreContext();
  Object.assign(saved, {buildId: 'b'.repeat(64), savedAt: '2026-10-01T00:00:00.000Z'});
  ctx.self.storedSlots.set(2, saved);
  await ctx.self.onmessage({data: {op: 'save_state', id: 1, slot: 2}});
  assert.deepEqual(storage.writes.map(write => write.slot), ['previous-2', 2]);
  assert.equal(replies.at(-1).packet.slots.some(row => 'previous_saved_at' in row), false);
  await ctx.self.onmessage({data: {op: 'load_previous', id: 2, slot: 2}});
  assert.equal(replies.at(-1).packet.success, false);
  assert.match(replies.at(-1).packet.message, /no previous save/);
  assert.equal(storage.writes.length, 2);
});

test('invalid keys and overlapping requests are rejected without touching the core', async () => {
  const {ctx, seeded, replies} = restoreContext();
  await ctx.self.onmessage({data: {op: 'step', id: 1, frames: 1, keys: ['not-a-key']}});
  assert.match(replies.at(-1).message, /Invalid original-game keyboard set/);
  assert.equal(seeded.ops.length, 0);
  replies.length = 0;
  const first = step(ctx, 2);
  await step(ctx, 3);
  await first;
  assert.deepEqual(replies.map(message => message.type), ['error', 'packet']);
  assert.match(replies[0].message, /Overlapping/);
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
  const {ctx, storage, cores, seeded} = restoreContext();
  const replies = [];
  ctx.postMessage = message => {
    if (message.packet?.type === 'state_result' && message.packet.success)
      throw new Error('transport unavailable');
    replies.push(message);
  };
  await ctx.self.onmessage({data: {op: 'load_state', id: 1, slot: 1}});
  assert.equal(ctx.self.inspect().core.worker, cores.at(-1));
  assert.equal(seeded.terminated, 1);
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
    const {cores, FakeCoreWorker} = fakeCores();
    const {runtime} = fakeObservers();
    const overrides = {Worker: FakeCoreWorker, loadObserverRuntime: async () => runtime,
      postMessage: message => replies.push(message)};
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
    await ctx.self.boot({zip: new Uint8Array(1), catalog: new Uint8Array(336060), buildId: 'a'.repeat(64)});
    const ready = JSON.parse(replies.find(message => message.packet?.type === 'ready').json);
    assert.match(ready.storage_warning, blocked ? /blocked by another tab/ : /unavailable/);
    assert.equal(ready.protocol, 4);
    assert.equal(ready.slots.every(slot => !slot.exists && !slot.valid), true);
    // 238 hidden frames run in progress-sized chunks before three observed frames.
    const ops = cores[0].ops;
    assert.deepEqual(ops.filter(message => message.op === 'run').map(message => message.frames),
      [30, 30, 30, 30, 30, 30, 30, 28]);
    assert.equal(ops.filter(message => message.op === 'advance').length, 3);
    assert.deepEqual(replies.filter(message => message.type === 'progress').map(message => message.frame),
      [30, 60, 90, 120, 150, 180, 210, 240]);
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
