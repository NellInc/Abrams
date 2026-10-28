import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import vm from 'node:vm';
const deployedSource = await readFile(new URL('../website/dist/play/remaster.mjs', import.meta.url), 'utf8');
const source = deployedSource.replace(/^import .*;\n/gm, '');
class Element {
  constructor() { this.listeners = {}; this.files = []; this.options = []; this.value = ''; this.hidden = false; this.disabled = false; this.dataset = {}; this.attrs = {}; this.textContent = ''; this.classList = {toggle() {}, add() {}, remove() {}}; }
  set value(value) { this._value = value; if (value === '') this.files = []; }
  get value() { return this._value; }
  addEventListener(type, fn) { this.listeners[type] = fn; }
  setAttribute(key, value) { this.attrs[key] = value; }
  removeAttribute(key) { delete this.attrs[key]; }
  getBoundingClientRect() { return {width: 800, height: 450}; }
  focus() { this.focused = true; }
  closest(selector) { return selector === 'label' ? this.parentLabel : (this.form ? this : null); }
  append(option) { this.options.push(option); option.remove = () => { this.options = this.options.filter(value => value !== option); }; }
}
// A fake service worker container: register(), ready, controller, controllerchange.
function fakeWorkers({active = false, controlled = false, rejects = false, claims = true} = {}) {
  const listeners = [];
  const container = {
    controller: controlled ? {} : null, registrations: 0,
    register: async () => {
      container.registrations++;
      if (rejects) throw new Error('SecurityError: site data blocked');
      const registration = active ? {active: {}} : {installing: {}};
      if (!active && claims) setTimeout(() => { container.controller = {}; listeners.forEach(fn => fn()); }, 0);
      return registration;
    },
    get ready() { return Promise.resolve({active: {}}); },
    addEventListener: (type, fn) => { if (type === 'controllerchange') listeners.push(fn); },
  };
  return container;
}
function fixture({missingManifest = false, engineFailure = false, capability = true, isolated = true,
                  workers, href = 'http://localhost/remaster.html', storage = {}, secure = true, timers = {setTimeout, clearTimeout}} = {}) {
  const elements = new Map();
  const el = key => { if (!elements.has(key)) elements.set(key, new Element()); return elements.get(key); };
  el('#web-graphics').options = ['ega', 'ega_upscaled', 'genesis', 'upscaled', 'modern', 'tactical'].map(value => new Element());
  el('#web-graphics').options.forEach((option, i) => option.value = ['ega', 'ega_upscaled', 'genesis', 'upscaled', 'modern', 'tactical'][i]);
  el('#reload-page').hidden = true; // As in remaster.html.
  el('#web-hud-style').options = ['restored', 'tactical'].map(value => Object.assign(new Element(), {value}));
  el('#web-load-slot').options = ['1', '2', '3', '4', '5', '0'].map(value => Object.assign(new Element(), {value}));
  el('#web-save-slot').options = ['1', '2', '3', '4', '5'].map(value => Object.assign(new Element(), {value}));
  el('#web-load-slot').value = el('#web-save-slot').value = '1';
  for (const [key, values] of Object.entries({msaa: [0,2,4,8], anisotropy: [0,2,4,8,16]}))
    el('#web-' + key).options = values.map(value => Object.assign(new Element(), {value: String(value)}));
  for (const key of ['master','effects','voice','motors','music','cannon','machinegun','impact','smoke','engine','turret']) {
    el('#web-audio-' + key).options = Array.from({length: 11}, (_, index) => Object.assign(new Element(), {value: String(index * 10)}));
    el('#web-audio-' + key).parentLabel = new Element();
  }
  const events = {}, sent = [], engines = [], hosts = [], replaced = [], copies = [];
  const document = {querySelector: el, createElement: () => new Element(), addEventListener: (type, fn) => events[type] = fn, body: new Element(), fullscreenEnabled: true,
    documentElement: {requestFullscreen: async () => { document.fullscreenElement = {}; events.fullscreenchange?.(); }},
    exitFullscreen: async () => { document.fullscreenElement = null; events.fullscreenchange?.(); }};
  class Engine {
    static isWebGLAvailable() { return capability; }
    constructor(config) { this.config = config; this.starts = 0; this.quits = 0; engines.push(this); }
    init() { return engineFailure ? Promise.reject(new Error('engine failed')) : Promise.resolve(); }
    preloadFile() { return Promise.resolve(); }
    copyToFS(path) { copies.push(path); }
    start() { this.starts++; copies.push('<engine.start>'); return Promise.resolve(); }
    requestQuit() { this.quits++; }
  }
  const installs = [];
  const ctx = vm.createContext({console, URL, Date, Set, Map, Number, WebAssembly: {}, Engine, document,
    location: {href, reload() { replaced.push('reload'); }, replace(url) { replaced.push(String(url)); }}, history: {replaceState() {}},
    isSecureContext: secure, crossOriginIsolated: isolated, navigator: workers ? {serviceWorker: workers} : {},
    sessionStorage: {getItem: key => storage[key] ?? null, setItem: (key, value) => { storage[key] = value; }, removeItem: key => { delete storage[key]; }},
    window: {addEventListener: (type, fn) => events[type] = fn, dispatchEvent() {}},
    ResizeObserver: class { observe() {} }, Event: class {}, AbortController, setTimeout: timers.setTimeout, clearTimeout: timers.clearTimeout,
    fetch: async () => ({ok: !missingManifest, json: async () => ({wasm_sha256: 'a'.repeat(64), bytes: 1, sha256: 'a'.repeat(64)})}),
    packOriginals: async () => ({zip: new Uint8Array(), catalog: new Uint8Array(), originalBytes: new Map()}),
    sha256: async () => 'a'.repeat(64), installRemasterAssets: async (_engine, _progress, options) => { installs.push(options); },
    derivePcArt: async () => new Map([['local-art/pc-portraits-v1/faces.json', new Uint8Array(1)], ['local-art/pc-modern/source-shapes.json', new Uint8Array(1)]]),
    deriveGenesisArt: async () => new Map([['local-art/genesis/source/effects-v1/effects.json', new Uint8Array(1)]]),
    createBridgeHost: (_zip, _catalog, _build, onStatus) => { const host = {first: Promise.resolve(), viewerReady: Promise.resolve(), queueControl: value => {sent.push(value); return true;}, close() {this.closed = true;}}; host.status = onStatus; hosts.push(host); return host; }});
  vm.runInContext(source + '\nglobalThis.testAPI = {updateToolbar, command};', ctx);
  return {ctx, el, events, sent, engines, hosts, replaced, storage, installs, copies, workers};
}
const settle = () => new Promise(resolve => setTimeout(resolve, 5));
const state = busy => ({busy, graphics: 'tactical', modes: ['ega', 'ega_upscaled', 'upscaled', 'modern', 'tactical'],
  hud_style: 'tactical', hud_styles: ['restored', 'tactical'], speed: 1,
  slots: [{slot: 1, exists: true, valid: true, program: 'SIM', saved_at: '2026-10-14T12:00:00Z'},
    {slot: 2, exists: true, valid: false}], message: busy ? 'Saving' : 'Saved'});
async function start(f) { f.el('#game-folder').files = [{name: 'ABRAMS.COM'}]; await f.el('#start-game').listeners.click(); }

test('feature checks precede import and file selection reports locally', () => {
  const f = fixture({capability: false});
  assert.equal(f.el('#game-folder').disabled, true);
  assert.match(f.el('#status').textContent, /WebGL 2/);
  const supported = fixture(); supported.el('#game-folder').files = [{name: 'file'}]; supported.el('#game-folder').listeners.change();
  assert.equal(supported.el('#start-game').disabled, false);
  assert.match(supported.el('#pc-selection').textContent, /1 files selected/);
});
test('one engine starts, busy slots reflect provenance and queue refuses state commands', async () => {
  const f = fixture(); await Promise.all([start(f), start(f)]);
  assert.equal(f.engines.length, 1); assert.equal(f.engines[0].starts, 1);
  f.ctx.testAPI.updateToolbar(state(true));
  assert.equal(f.el('#web-save').disabled, true); assert.equal(f.el('#web-load').disabled, true);
  assert.equal(f.ctx.testAPI.command({op: 'save_state', slot: 1}), false);
  assert.match(f.el('#web-load-slot').options[0].textContent, /SIM/);
  assert.match(f.el('#web-load-slot').options[1].textContent, /incompatible/);
  // The Save select names what a save would replace, as the in-canvas menu does.
  assert.match(f.el('#web-save-slot').options[0].textContent, /^Slot 1 \(overwrite SIM, /);
  assert.equal(f.el('#web-save-slot').options[1].textContent, 'Slot 2 (overwrite incompatible)');
  assert.equal(f.el('#web-save-slot').options[2].textContent, 'Slot 3 (empty)');
  f.ctx.testAPI.updateToolbar(state(false)); assert.equal(f.el('#web-save').disabled, false);
  assert.equal(f.el('#web-graphics').options[2].disabled, true);
  assert.match(f.el('#graphics-description').textContent, /textured terrain/);
});
test('form editing owns shortcuts; canvas shortcut, focus and fullscreen work', async () => {
  const f = fixture(); await start(f); f.ctx.testAPI.updateToolbar(state(false));
  let prevented = 0;
  const event = target => ({target, code: 'KeyS', ctrlKey: true, altKey: true, preventDefault() {prevented++;}, stopImmediatePropagation() {}});
  const form = Object.assign(new Element(), {form: true}); f.events.keydown(event(form)); assert.equal(prevented, 0);
  f.events.keydown(event(f.el('#game-canvas'))); assert.equal(prevented, 1); assert.equal(f.sent[0].op, 'save_state');
  await f.el('#web-fullscreen').listeners.click(); assert.equal(f.el('#web-fullscreen').attrs['aria-pressed'], 'true');
  await f.el('#web-fullscreen').listeners.click(); assert.equal(f.el('#web-fullscreen').attrs['aria-pressed'], 'false');
  f.el('#web-focus').listeners.click(); assert.equal(f.el('#game-canvas').focused, true);
});
test('pre-engine failure is retryable; partial engine failure requires clean reload', async () => {
  const early = fixture({missingManifest: true}); await start(early);
  assert.equal(early.engines.length, 0); assert.equal(early.el('#start-game').disabled, false); assert.match(early.el('#status').textContent, /connection/); assert.equal(early.el('#start-game').focused, true);
  const late = fixture({engineFailure: true}); await start(late);
  assert.equal(late.hosts[0].closed, true); assert.equal(late.engines[0].quits, 1);
  assert.equal(late.el('#reload-page').hidden, false); assert.equal(late.el('#start-game').disabled, true);
  late.engines[0].config.onExit(1); late.el('#game-folder').listeners.change();
  assert.equal(late.el('#start-game').disabled, true); assert.equal(late.ctx.AbramsWebHost, undefined);
});

test('extended quality and all five gains dispatch incumbent controls and report status', async () => {
  const f = fixture(); await start(f);
  const value = {...state(false), quality: {msaa: 4, anisotropy: 16}, quality_levels: {msaa: [0,2,4,8], anisotropy: [0,2,4,8,16]},
    audio: {master: 100, effects: 30, voice: 67, motors: 100, music: 70}, audio_error: 'Mix changed, but could not save it'};
  f.ctx.testAPI.updateToolbar(value);
  assert.equal(f.el('#web-reset-audio').disabled, false, 'the existing five-channel player retains its working reset');
  assert.equal(f.el('#web-msaa').value, '4'); assert.equal(f.el('#web-anisotropy').value, '16');
  assert.equal(f.el('#web-audio-voice').value, '67'); assert.match(f.el('#web-settings-status').textContent, /could not save/);
  f.el('#web-msaa').value = '8'; f.el('#web-msaa').listeners.change();
  assert.equal(f.sent.at(-1).op, 'quality'); assert.equal(f.sent.at(-1).samples, 8);
  f.el('#web-audio-voice').value = '70'; f.el('#web-audio-voice').listeners.change();
  assert.equal(f.sent.at(-1).op, 'audio'); assert.equal(f.sent.at(-1).channel, 'voice');
  f.el('#web-reset-audio').listeners.click(); assert.equal(f.sent.at(-1).op, 'reset_audio');
  f.el('#web-reset-quality').listeners.click(); assert.equal(f.sent.at(-1).op, 'reset_quality');
  assert.equal(f.el('#web-reset-quality').disabled, false);
  assert.equal(f.el('#web-audio-cannon').disabled, true);
  assert.equal(f.el('#web-audio-cannon').parentLabel.hidden, true, 'unsupported new channels stay hidden on the old pack');
  const individual = {cannon: 0, machinegun: 40, impact: 50, smoke: 60, engine: 70, turret: 80};
  f.ctx.testAPI.updateToolbar({...value, audio: {...value.audio, ...individual}});
  assert.equal(f.el('#web-reset-audio').disabled, false);
  for (const [key, percent] of Object.entries(individual)) {
    const select = f.el('#web-audio-' + key);
    assert.equal(select.disabled, false); assert.equal(select.parentLabel.hidden, false); assert.equal(select.value, String(percent));
  }
  f.ctx.testAPI.updateToolbar({...value, speed: 8}); assert.match(f.el('#web-audio-note').textContent, /muted during/);
  f.ctx.testAPI.updateToolbar(state(false)); assert.equal(f.el('#web-msaa').disabled, true); assert.equal(f.el('#web-reset-audio').disabled, true); assert.equal(f.el('#web-reset-quality').disabled, true);
});
test('runtime failure exposes reload and retains real error through engine exit', async () => {
  const f = fixture(); await start(f);
  f.hosts[0].status({type: 'error', message: 'source observer failed'});
  assert.equal(f.hosts[0].closed, true); assert.equal(f.engines[0].quits, 1);
  assert.equal(f.el('#web-controls').hidden, true); assert.equal(f.el('#game-canvas').hidden, true); assert.equal(f.el('#reload-page').hidden, false);
  assert.equal(f.el('.player').hidden, true); assert.equal(f.el('#reload-page').focused, true);
  f.engines[0].config.onExit(1); assert.match(f.el('#status').textContent, /source observer failed/);
  f.el('#game-folder').listeners.change(); assert.equal(f.el('#start-game').disabled, true);
});


test('unsupported optional ROM clears without losing PC files and retries PC-only', async () => {
  const f = fixture();
  assert.equal(f.el('#clear-genesis').disabled, true);
  f.el('#game-folder').files = [{name: 'ABRAMS.COM'}];
  f.el('#genesis-rom').files = [{name: 'wrong.bin', size: 2}];
  f.el('#genesis-rom').listeners.change();
  assert.equal(f.el('#clear-genesis').disabled, false);
  await f.el('#start-game').listeners.click();
  assert.equal(f.engines.length, 0); assert.match(f.el('#status').textContent, /Unsupported Genesis ROM size/);
  f.el('#clear-genesis').listeners.click();
  assert.equal(f.el('#genesis-rom').files.length, 0); assert.equal(f.el('#game-folder').files.length, 1);
  assert.equal(f.el('#genesis-rom').focused, true); assert.equal(f.el('#clear-genesis').disabled, true);
  assert.match(f.el('#status').textContent, /cleared.*PC folder is retained/);
  assert.equal(f.el('#start-game').disabled, false); await f.el('#start-game').listeners.click();
  assert.equal(f.engines.length, 1); assert.equal(f.el('#clear-genesis').disabled, true);
});

test('visitor-derived recognition data is copied into Godot; Genesis parts only with a ROM', async () => {
  const pc = fixture(); await start(pc);
  assert.deepEqual([...pc.installs[0].sets], ['common']);
  assert.ok(pc.copies.includes('/local-art/pc-portraits-v1/faces.json'));
  // Modern/Tactical's SHAPE.TBL registry is in Godot's FS before the engine starts.
  assert.ok(pc.copies.indexOf('/local-art/pc-modern/source-shapes.json') >= 0);
  assert.ok(pc.copies.indexOf('/local-art/pc-modern/source-shapes.json') < pc.copies.indexOf('<engine.start>'));
  assert.ok(!pc.copies.some(path => path.includes('effects.json')));
  const both = fixture(); both.el('#genesis-rom').files = [{name: 'rom.md', size: 1, arrayBuffer: async () => new ArrayBuffer(1)}];
  await start(both);
  assert.deepEqual([...both.installs[0].sets], ['common', 'genesis']);
  assert.ok(both.copies.includes('/local-art/genesis/source/effects-v1/effects.json'));
});

// The service-worker isolation path GitHub Pages visitors take.
test('first visit waits for the new worker to claim, then navigates once', async () => {
  const f = fixture({isolated: false, workers: fakeWorkers()}); await settle();
  assert.equal(f.workers.registrations, 1);
  assert.match(f.replaced[0], /abrams-isolation=1/);
  assert.equal(f.storage['abrams-web-isolation-attempt'], '1');
});
test('an existing controller replaces the location immediately', async () => {
  const f = fixture({isolated: false, workers: fakeWorkers({active: true, controlled: true})}); await settle();
  assert.match(f.replaced[0], /abrams-isolation=1/);
});
test('hard reload with an active but uncontrolling worker does not stall', async () => {
  const f = fixture({isolated: false, workers: fakeWorkers({active: true})}); await settle();
  assert.match(f.replaced[0], /abrams-isolation=1/);
  assert.doesNotMatch(f.el('#status').textContent, /did not become ready/);
});
test('registration failure reports, offers reload and leaves retries possible', async () => {
  const storage = {};
  const f = fixture({isolated: false, workers: fakeWorkers({rejects: true}), storage}); await settle();
  assert.match(f.el('#status').textContent, /could not prepare.*SecurityError/);
  assert.equal(f.el('#reload-page').hidden, false);
  assert.equal(storage['abrams-web-isolation-attempt'], undefined);
  const retry = fixture({isolated: false, workers: fakeWorkers(), storage}); await settle();
  assert.equal(retry.workers.registrations, 1, 'a manual reload registers again');
});
test('the loop guard never re-registers, and its reload starts a clean attempt', async () => {
  for (const options of [{href: 'http://localhost/remaster.html?abrams-isolation=1'}, {storage: {'abrams-web-isolation-attempt': '1'}}]) {
    const f = fixture({isolated: false, workers: fakeWorkers(), ...options}); await settle();
    assert.equal(f.workers.registrations, 0);
    assert.match(f.el('#status').textContent, /cannot provide the isolation/);
    assert.equal(f.el('#reload-page').hidden, false);
    f.el('#reload-page').listeners.click();
    assert.doesNotMatch(f.replaced.at(-1), /abrams-isolation/);
    assert.equal(f.storage['abrams-web-isolation-attempt'], undefined);
  }
});
test('insecure contexts and missing workers report without registering', async () => {
  for (const options of [{secure: false, workers: fakeWorkers()}, {}]) {
    const f = fixture({isolated: false, ...options}); await settle();
    assert.equal(f.workers?.registrations ?? 0, 0);
    assert.match(f.el('#status').textContent, /cannot provide the isolation/);
    assert.equal(f.el('#reload-page').hidden, true);
  }
});
test('a worker that never claims hits the bounded deadline', async () => {
  const pending = [];
  const timers = {setTimeout: (fn, ms) => { pending.push({fn, ms}); return pending.length; }, clearTimeout() {}};
  const f = fixture({isolated: false, workers: fakeWorkers({claims: false}), timers});
  await settle();
  const deadline = pending.find(timer => timer.ms === 15000);
  assert.ok(deadline); deadline.fn(); await settle();
  assert.match(f.el('#status').textContent, /did not become ready/);
  assert.equal(f.replaced.length, 0); assert.equal(f.el('#reload-page').hidden, false);
});

test('build templates match the deployed audio-capability controls', async () => {
  assert.equal(await readFile(new URL('./remaster.mjs', import.meta.url), 'utf8'), deployedSource);
  assert.equal(await readFile(new URL('./remaster.html', import.meta.url), 'utf8'), await readFile(new URL('../website/dist/play/remaster.html', import.meta.url), 'utf8'));
});
