import {packOriginals, sha256} from './zip_store.mjs';
import {createBridgeHost} from './bridge_host.mjs';
import {installRemasterAssets} from './remaster_assets.mjs';
import {deriveGenesisArt, derivePcArt} from './derived_art.mjs';

const input = document.querySelector('#game-folder');
const genesisInput = document.querySelector('#genesis-rom');
const clearGenesisButton = document.querySelector('#clear-genesis');
const startButton = document.querySelector('#start-game');
const reloadButton = document.querySelector('#reload-page');
const status = document.querySelector('#status');
const canvas = document.querySelector('#game-canvas');
const player = document.querySelector('.player');
const toolbar = document.querySelector('#web-controls');
const graphics = document.querySelector('#web-graphics');
const hudStyle = document.querySelector('#web-hud-style');
const saveSlot = document.querySelector('#web-save-slot');
const saveButton = document.querySelector('#web-save');
const loadSlot = document.querySelector('#web-load-slot');
const loadButton = document.querySelector('#web-load');
const speedButton = document.querySelector('#web-speed');
const fullscreenButton = document.querySelector('#web-fullscreen');
const controlStatus = document.querySelector('#web-control-status');
const extended = document.querySelector('#web-extended');
const settingsStatus = document.querySelector('#web-settings-status');
const audioNote = document.querySelector('#web-audio-note');
const qualityControls = {msaa: document.querySelector('#web-msaa'), anisotropy: document.querySelector('#web-anisotropy')};
const audioControls = Object.fromEntries(['master', 'effects', 'voice', 'motors', 'music']
  .map(channel => [channel, document.querySelector('#web-audio-' + channel)]));
const resetAudioButton = document.querySelector('#web-reset-audio');
const resetQualityButton = document.querySelector('#web-reset-quality');
let runtimeFailure = '';
let started = false;
let isolationReady = false;
let isolationRetry = false;
let busy = false;
let reloadRequired = false;
let storageWarning = '';
let host;
let engine;
let startup;
let lastControls;
const report = message => { if (status.textContent !== message) status.textContent = message; };
const notice = message => { controlStatus.textContent = message; };
const descriptions = {
  ega: 'Exact original PC EGA artwork and palette.',
  ega_upscaled: 'EGA Upscaled: crisp original artwork, original palette and skin colours.',
  genesis: 'Original-resolution Genesis artwork. Unavailable in the Web edition: its captured Genesis screens are not published.',
  upscaled: 'Genesis Upscaled: generated high-resolution remaster artwork and lettering.',
  modern: 'Modernized 3D: the existing remaster presentation.',
  tactical: 'Tactical 3D: textured terrain, grounded vegetation and source-driven effects.',
};
// Preserve the accepted CSS-pixel render extent, with no resolution/detail cuts.
const syncCanvasSize = () => {
  const bounds = canvas.getBoundingClientRect();
  const width = Math.max(640, Math.round(bounds.width));
  const height = Math.max(360, Math.round(bounds.height));
  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
    window.dispatchEvent(new Event('resize'));
  }
};
new ResizeObserver(syncCanvasSize).observe(canvas);
function deadline(promise, milliseconds, message, onTimeout) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => { onTimeout?.(); reject(new Error(message)); }, milliseconds);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}
function selectionChanged() {
  document.querySelector('#pc-selection').textContent = input.files.length
    ? `${input.files.length} files selected. Exact original files are verified when you start.`
    : 'No PC folder selected.';
  document.querySelector('#genesis-selection').textContent = genesisInput.files.length
    ? `Selected: ${genesisInput.files[0].name}` : 'Optional. PC-only play is fully supported.';
  startButton.disabled = started || reloadRequired || !!engine || !isolationReady || !input.files.length;
  clearGenesisButton.disabled = started || reloadRequired || !!engine || !isolationReady || !genesisInput.files.length;
}
input.disabled = true;
genesisInput.disabled = true;
input.addEventListener('change', selectionChanged);
genesisInput.addEventListener('change', selectionChanged);
clearGenesisButton.addEventListener('click', () => {
  if (clearGenesisButton.disabled) return;
  genesisInput.value = '';
  selectionChanged();
  report(input.files.length
    ? 'Genesis ROM cleared. Your PC folder is retained. Start PC-only, or choose another supported ROM.'
    : 'Genesis ROM cleared. Choose your original PC folder for PC-only play.');
  genesisInput.focus();
});
reloadButton.addEventListener('click', () => {
  if (!isolationRetry) { location.reload(); return; }
  // Clear the automatic-attempt guards so this reload registers again.
  try { sessionStorage.removeItem('abrams-web-isolation-attempt'); } catch { /* Storage may be disabled. */ }
  const url = new URL(location.href);
  url.searchParams.delete('abrams-isolation');
  location.replace(url);
});
async function prepareIsolation() {
  const attempt = 'abrams-web-isolation-attempt';
  const url = new URL(location.href);
  if (globalThis.crossOriginIsolated === true) {
    try { sessionStorage.removeItem(attempt); } catch { /* Storage may be disabled. */ }
    if (url.searchParams.has('abrams-isolation')) {
      url.searchParams.delete('abrams-isolation');
      history.replaceState(null, '', url);
    }
    if (typeof Engine === 'undefined') {
      report('The remaster engine script is missing. Check your connection, then reload this page.');
      reloadButton.hidden = false;
      return;
    }
    if (typeof WebAssembly !== 'object' || !Engine.isWebGLAvailable(2)) {
      report('This remaster requires WebAssembly and WebGL 2. Enable hardware acceleration or use a supported desktop browser.');
      return;
    }
    isolationReady = true;
    input.disabled = false;
    genesisInput.disabled = false;
    report('Choose your original PC folder to begin. Your optional Genesis ROM unlocks the Genesis remaster artwork.');
    selectionChanged();
    return;
  }
  let attempted = url.searchParams.get('abrams-isolation') === '1';
  try { attempted ||= sessionStorage.getItem(attempt) === '1'; } catch { /* URL marker also bounds reloads. */ }
  const unsupported = !isSecureContext || !('serviceWorker' in navigator);
  if (unsupported || attempted) {
    report('This browser cannot provide the isolation required by the original game. Use HTTPS or localhost in a current desktop browser; allow this site’s service worker.');
    // After the one automatic attempt, a deliberate retry starts clean.
    if (!unsupported) { isolationRetry = true; reloadButton.hidden = false; }
    return;
  }
  report('Preparing the browser for the original game…');
  try {
    await deadline((async () => {
      const registration = await navigator.serviceWorker.register('./remaster.service.worker.js', {scope: './'});
      const installing = !!(registration?.installing || registration?.waiting);
      await navigator.serviceWorker.ready;
      // A hard reload bypasses an already active worker, which never claims
      // again; a normal navigation is controlled. Wait only for a new worker.
      if (!navigator.serviceWorker.controller && installing)
        await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once: true}));
    })(), 15000, 'The isolation worker did not become ready. Check site permissions, then reload.');
    // The marker bounds only this automatic navigation, never a failed registration.
    try { sessionStorage.setItem(attempt, '1'); } catch { /* Bounded by the URL marker. */ }
    url.searchParams.set('abrams-isolation', '1');
    location.replace(url);
  } catch (error) {
    try { sessionStorage.removeItem(attempt); } catch { /* Storage may be disabled. */ }
    report(`The browser could not prepare the original game: ${error?.message || error}`);
    reloadButton.hidden = false;
  }
}
prepareIsolation();
const command = value => {
  if (!started || toolbar.hidden) return false;
  if ((busy && ['save_state', 'load_state', 'speed'].includes(value.op)) ||
      (storageWarning && ['save_state', 'load_state'].includes(value.op))) return false;
  if (!host?.queueControl(value)) {
    notice('The game could not accept this action. Wait for the current operation, then try again.');
    return false;
  }
  return true;
};
function updateExtended(state) {
  const warnings = [];
  let audioReady = true;
  let qualityReady = true;
  for (const [key, select] of Object.entries(qualityControls)) {
    const levels = state.quality_levels?.[key];
    const value = state.quality?.[key];
    const valid = Array.isArray(levels) && levels.includes(value) && Number.isInteger(value) &&
      [...select.options].some(option => Number(option.value) === value);
    select.disabled = !valid;
    qualityReady &&= valid;
    if (valid) {
      for (const option of select.options) option.disabled = !levels.includes(Number(option.value));
      select.value = String(value);
    }
  }
  for (const [key, select] of Object.entries(audioControls)) {
    const value = state.audio?.[key];
    const valid = Number.isInteger(value) && value >= 0 && value <= 100;
    select.disabled = !valid;
    audioReady &&= valid;
    if (valid) {
      for (const option of [...select.options])
        if (option.dataset.current === '1' && Number(option.value) !== value) option.remove();
      // Config files support every integer gain, including values between menu steps.
      if (![...select.options].some(option => Number(option.value) === value)) {
        const option = document.createElement('option');
        option.value = String(value); option.textContent = value + '%'; option.dataset.current = '1'; select.append(option);
      }
      select.value = String(value);
    }
  }
  resetAudioButton.disabled = !audioReady;
  resetQualityButton.disabled = !qualityReady;
  if (state.quality_error) warnings.push(state.quality_error);
  if (state.audio_error) warnings.push(state.audio_error);
  settingsStatus.textContent = warnings.join(' ');
  audioNote.textContent = state.speed === 8
    ? 'Audio is muted during 8× fast forward. Your mix is retained. Original F5 and pause still control sound.'
    : (state.audio?.master === 0 ? 'Master volume is muted. ' : '') +
      'Presentation mix. Original F5 and pause still control sound.';
}
function updateToolbar(state) {
  if (!state || !Array.isArray(state.modes) || !Array.isArray(state.slots)) {
    notice('The game returned unavailable control information.');
    return;
  }
  lastControls = state;
  canvas.dataset.presentationRuntime = JSON.stringify(state.presentation_runtime || {});
  updateExtended(state);
  busy = state.busy === true;
  const modes = new Set(state.modes);
  for (const option of graphics.options) {
    option.disabled = !modes.has(option.value);
    option.title = descriptions[option.value] || '';
  }
  graphics.value = state.graphics;
  graphics.title = descriptions[graphics.value] || '';
  document.querySelector('#graphics-description').textContent = graphics.title;
  const hudStyles = new Set(state.hud_styles || ['restored']);
  for (const option of hudStyle.options) option.disabled = !hudStyles.has(option.value);
  hudStyle.value = state.hud_style || 'restored';
  canvas.classList.toggle('tactical', hudStyle.value === 'tactical');
  const available = new Set();
  for (const option of loadSlot.options) {
    const row = state.slots.find(row => String(row.slot) === option.value);
    const valid = row?.exists && row.valid;
    if (valid) available.add(option.value);
    const label = option.value === '0' ? 'Undo last load' : `Slot ${option.value}`;
    let detail = row?.exists ? (valid ? row.program || 'saved' : 'incompatible') : 'empty';
    if (valid && row.saved_at && Number.isFinite(Date.parse(row.saved_at)))
      detail += `, ${new Date(row.saved_at).toLocaleString()}`;
    option.textContent = `${label} (${detail})`;
    option.disabled = busy || !valid;
  }
  // Saving over an occupied slot replaces it, so say what is there.
  for (const option of saveSlot.options) {
    const row = state.slots.find(row => String(row.slot) === option.value);
    let detail = 'empty';
    if (row?.exists) {
      detail = 'overwrite ' + (row.valid ? (row.program || 'saved') : 'incompatible');
      if (row.valid && row.saved_at && Number.isFinite(Date.parse(row.saved_at)))
        detail += `, ${new Date(row.saved_at).toLocaleString()}`;
    }
    option.textContent = `Slot ${option.value} (${detail})`;
  }
  if (!available.has(loadSlot.value)) loadSlot.value = [...available][0] || '1';
  loadButton.disabled = busy || !!storageWarning || !available.has(loadSlot.value);
  loadSlot.disabled = busy || !!storageWarning || !available.size;
  saveButton.disabled = saveSlot.disabled = busy || !!storageWarning;
  speedButton.disabled = busy;
  toolbar.setAttribute('aria-busy', String(busy));
  speedButton.textContent = state.speed === 8 ? 'Normal speed' : '8× speed';
  speedButton.setAttribute('aria-pressed', String(state.speed === 8));
  notice(state.message || '');
}
for (const [setting, select] of Object.entries(qualityControls))
  select.addEventListener('change', () => command({op: 'quality', setting, samples: Number(select.value)}));
for (const [channel, select] of Object.entries(audioControls))
  select.addEventListener('change', () => command({op: 'audio', channel, percent: Number(select.value)}));
resetAudioButton.addEventListener('click', () => command({op: 'reset_audio'}));
resetQualityButton.addEventListener('click', () => command({op: 'reset_quality'}));
saveButton.addEventListener('click', () => command({op: 'save_state', slot: Number(saveSlot.value)}));
loadButton.addEventListener('click', () => command({op: 'load_state', slot: Number(loadSlot.value)}));
loadSlot.addEventListener('change', () => { if (lastControls) updateToolbar(lastControls); });
graphics.addEventListener('change', () => command({op: 'graphics', mode: graphics.value}));
hudStyle.addEventListener('change', () => command({op: 'hud_style', style: hudStyle.value}));
speedButton.addEventListener('click', () => command({op: 'speed'}));
document.querySelector('#web-help').addEventListener('click', () => command({op: 'help'}));
document.querySelector('#web-focus').addEventListener('click', () => {
  canvas.focus();
  notice('Game keyboard active. Tab toggles fast forward; use the controls above for remaster settings.');
});
function syncFullscreen() {
  const active = !!document.fullscreenElement;
  fullscreenButton.textContent = active ? 'Leave fullscreen' : 'Fullscreen';
  fullscreenButton.setAttribute('aria-pressed', String(active));
}
fullscreenButton.hidden = !document.fullscreenEnabled;
fullscreenButton.addEventListener('click', async () => {
  try {
    if (document.fullscreenElement) await document.exitFullscreen();
    else await document.documentElement.requestFullscreen();
    syncFullscreen();
    canvas.focus();
  } catch (error) { notice(`Fullscreen unavailable: ${error?.message || error}`); }
});
document.addEventListener('fullscreenchange', syncFullscreen);
window.addEventListener('keydown', event => {
  if (!started || toolbar.hidden || !['KeyS', 'KeyL', 'KeyG'].includes(event.code)) return;
  if (event.target?.closest?.('input, select, textarea, button, [contenteditable="true"]')) return;
  const modifier = (event.metaKey && !event.ctrlKey && !event.altKey) ||
    (event.ctrlKey && event.altKey && !event.metaKey);
  if (!modifier || (event.shiftKey && event.code !== 'KeyL')) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  if (event.repeat) return;
  if (event.code === 'KeyG') command({op: 'cycle_graphics'});
  else command({op: event.code === 'KeyS' ? 'save_state' : 'load_state', slot: event.shiftKey ? 0 : 1});
}, true);
function closeHost() {
  host?.close();
  if (globalThis.AbramsWebHost === host) delete globalThis.AbramsWebHost;
  host = undefined;
}
function resetPlayer() {
  closeHost();
  started = false;
  busy = false;
  lastControls = undefined;
  extended.open = false;
  settingsStatus.textContent = '';
  storageWarning = '';
  document.querySelector('#web-storage-status').textContent = '';
  toolbar.hidden = true;
  canvas.hidden = true;
  player.hidden = true;
  document.body.classList.remove('playing');
  input.disabled = genesisInput.disabled = !isolationReady;
  selectionChanged();
}
window.addEventListener('pagehide', () => { startup?.abort(); closeHost(); engine?.requestQuit(); });
startButton.addEventListener('click', async () => {
  if (started || reloadRequired || engine || !isolationReady) return;
  started = true;
  input.disabled = genesisInput.disabled = startButton.disabled = true;
  clearGenesisButton.disabled = true;
  document.querySelector('.setup').setAttribute('aria-busy', 'true');
  startup = new AbortController();
  runtimeFailure = '';
  let engineStarted = false;
  try {
    report('Verifying your original PC files locally…');
    const fetchManifest = async name => {
      const response = await fetch(`./.generated/${name}`, {signal: startup.signal, cache: 'no-cache'});
      if (!response.ok) throw new Error(`Missing browser manifest: ${name}. Reload to get a complete build.`);
      return response.json();
    };
    const [manifest, build, genesis] = await deadline(Promise.all([
      fetchManifest('game-inputs.json'), fetchManifest('build-info.json'), fetchManifest('genesis-input.json'),
    ]), 120000, 'The browser build could not download. Check your connection, then try again.', () => startup.abort());
    if (!/^[0-9a-f]{64}$/.test(build.wasm_sha256 || ''))
      throw new Error('The original-game browser core has no valid build identity');
    const {zip, catalog, originalBytes} = await packOriginals(input.files, manifest,
      (done, total) => report(`Verifying original PC files ${done}/${total}…`));
    let genesisEnabled = false;
    let rom;
    if (genesisInput.files.length) {
      if (genesisInput.files.length !== 1) throw new Error('Choose one original Genesis ROM');
      const file = genesisInput.files[0];
      if (!Number.isSafeInteger(genesis.bytes) || file.size !== genesis.bytes || !/^[0-9a-f]{64}$/.test(genesis.sha256))
        throw new Error('Unsupported Genesis ROM size. Choose the supported original ROM, or clear this optional selection.');
      rom = new Uint8Array(await file.arrayBuffer());
      if (await sha256(rom) !== genesis.sha256)
        throw new Error('Unsupported Genesis ROM. The selected file was not imported.');
      genesisEnabled = true;
    }
    // Recognition data decoded here, from the visitor's verified files, is
    // never fetched from the site. A decode failure only leaves original
    // pixels in place; Godot verifies every derived file before using it.
    const derived = new Map();
    for (const [label, derive] of [['PC', () => derivePcArt(originalBytes)],
        ...(genesisEnabled ? [['Genesis', () => deriveGenesisArt(rom)]] : [])]) {
      try { for (const [path, bytes] of await derive()) derived.set(path, bytes); }
      catch (error) { console.error(`${label} recognition data could not be derived:`, error); }
    }
    rom = undefined;
    report('Starting the original game and downloading the remaster…');
    host = createBridgeHost(zip, catalog, build.wasm_sha256, message => {
      if (message.type === 'progress') report(`Starting the original PC game ${message.frame}/${message.total}…`);
      if (message.type === 'ready' || message.type === 'sample') {
        canvas.dataset.originalSequence = String(message.sequence);
        canvas.dataset.originalProgram = message.program?.name || '';
      }
      if (message.type === 'ready' && message.storage_warning) {
        storageWarning = message.storage_warning;
        document.querySelector('#web-storage-status').textContent = 'Checkpoint saving is unavailable in this session. ' + storageWarning;
        if (lastControls) updateToolbar(lastControls);
      }
      if (message.type === 'error') {
        runtimeFailure = `Original game stopped: ${message.message}. Reload to restart; saved slots are retained.`;
        notice(runtimeFailure);
        if (!toolbar.hidden) {
          reloadRequired = true;
          startup?.abort();
          engine?.requestQuit();
          resetPlayer();
          reloadButton.hidden = false;
          reloadButton.focus();
          startButton.disabled = true;
          report(runtimeFailure);
        }
      }
    }, updateToolbar);
    globalThis.AbramsWebHost = host;
    canvas.hidden = false;
    player.hidden = false;
    syncCanvasSize();
    engine = new Engine({canvas, executable: 'index', canvasResizePolicy: 0,
      focusCanvas: true, ensureCrossOriginIsolationHeaders: true,
      onProgress: (done, total) => {
        if (total) report(`Downloading remaster engine ${Math.min(100, Math.floor(done / total * 10) * 10)}%…`);
      },
      onExit: code => {
        engine = undefined;
        reloadRequired = true;
        resetPlayer();
        reloadButton.hidden = false;
        reloadButton.focus();
        startButton.disabled = true;
        report(runtimeFailure || `The game has closed${code ? ` (code ${code})` : ''}. Reload to start a fresh session. Saved slots are retained.`);
      },
      onPrintError: line => console.error('Godot:', line)});
    await deadline(Promise.all([
      host.first, engine.init('./.generated/godot/index'),
      engine.preloadFile('./.generated/godot/index.pck', 'index.pck'),
    ]), 300000, 'The original game or remaster engine did not become ready. Reload to retry safely.', () => startup.abort());
    // Genesis-gated artwork downloads only for a verified ROM. The
    // loader fails on a stalled connection rather than a fixed deadline.
    const megabytes = bytes => (bytes / 1e6).toFixed(0);
    await installRemasterAssets(engine, (done, total, received, size) =>
      report(`Loading remaster artwork ${megabytes(received)} of ${megabytes(size)} MB (${done}/${total} files)…`),
      {signal: startup.signal, sets: genesisEnabled ? ['common', 'genesis'] : ['common']});
    for (const [name, bytes] of originalBytes) engine.copyToFS('/GAME/' + name, bytes);
    for (const [path, bytes] of derived) engine.copyToFS('/' + path, bytes);
    report('Starting the remastered Godot presentation…');
    engineStarted = true;
    await deadline(engine.start({args: ['--main-pack', 'index.pck', '--', '--boot', '--play',
      ...(genesisEnabled ? [] : ['--pc-only'])]}), 30000, 'The remaster could not start its viewer. Reload to retry safely.');
    await deadline(host.viewerReady, 30000, 'The remastered viewer did not present an original game frame. Reload to retry safely.');
    report('Original PC game running. Choose Game keyboard to return focus after using browser controls.');
    toolbar.hidden = false;
    document.body.classList.add('playing');
    canvas.focus();
  } catch (error) {
    startup.abort();
    const needsReload = !!engine || engineStarted;
    engine?.requestQuit();
    resetPlayer();
    if (needsReload) { reloadRequired = true; startButton.disabled = true; reloadButton.hidden = false; }
    report(`The remaster could not start: ${error?.message || error}${needsReload ? ' Use Reload page to start a clean engine; saved slots are retained.' : ' Correct the selection or connection, then try again.'}`);
    (needsReload ? reloadButton : startButton).focus();
  } finally {
    document.querySelector('.setup').setAttribute('aria-busy', 'false');
  }
});
