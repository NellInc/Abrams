import {packOriginals, sha256} from './zip_store.mjs';
import {createBridgeHost} from './bridge_host.mjs';
import {installRemasterAssets} from './remaster_assets.mjs';

const input = document.querySelector('#game-folder');
const genesisInput = document.querySelector('#genesis-rom');
const startButton = document.querySelector('#start-game');
const status = document.querySelector('#status');
const canvas = document.querySelector('#game-canvas');
const toolbar = document.querySelector('#web-controls');
const graphics = document.querySelector('#web-graphics');
const hudStyle = document.querySelector('#web-hud-style');
const saveSlot = document.querySelector('#web-save-slot');
const loadSlot = document.querySelector('#web-load-slot');
const loadButton = document.querySelector('#web-load');
const speedButton = document.querySelector('#web-speed');
const controlStatus = document.querySelector('#web-control-status');
let started = false;
let host;
const report = message => { status.textContent = message; };
// The Web export's default policy fills the entire browser window, leaving
// empty bands around our player. Own the canvas extent instead, at 1 CSS
// pixel per render pixel so Tactical does not add a high-DPI GPU penalty.
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
let isolationReady = false;
input.disabled = true;
genesisInput.disabled = true;
input.addEventListener('change', () => { startButton.disabled = !isolationReady || !input.files.length; });
async function prepareIsolation() {
  const attempt = 'abrams-web-isolation-attempt';
  if (globalThis.crossOriginIsolated === true) {
    try { sessionStorage.removeItem(attempt); } catch { /* Storage may be disabled. */ }
    isolationReady = true;
    input.disabled = false;
    genesisInput.disabled = false;
    return;
  }
  let attempted = false;
  try { attempted = sessionStorage.getItem(attempt) === '1'; } catch { /* A reload still has a finite timeout. */ }
  if (!isSecureContext || !('serviceWorker' in navigator) || attempted) {
    report('This browser cannot provide the cross-origin isolation required by the original game. Use a current desktop browser.');
    return;
  }
  report('Preparing the browser for the original game…');
  try {
    try { sessionStorage.setItem(attempt, '1'); } catch { /* Some browsers disable session storage. */ }
    await navigator.serviceWorker.register('./remaster.service.worker.js', {scope: './'});
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller)
      await Promise.race([
        new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once: true})),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Service worker did not take control')), 10000)),
      ]);
    location.reload();
  } catch (error) {
    report(`The browser could not prepare the original game: ${error?.message || error}`);
  }
}
prepareIsolation();
const command = value => { if (started && !toolbar.hidden) host?.queueControl(value); };
function updateToolbar(state) {
    const modes = new Set(state.modes);
    for (const option of graphics.options) option.disabled = !modes.has(option.value);
    graphics.value = state.graphics;
    const hudStyles = new Set(state.hud_styles || ['restored']);
    for (const option of hudStyle.options) option.disabled = !hudStyles.has(option.value);
    hudStyle.value = state.hud_style || 'restored';
    canvas.classList.toggle('tactical', hudStyle.value === 'tactical');
    const available = new Set(state.slots.filter(row => row.exists && row.valid).map(row => String(row.slot)));
    for (const option of loadSlot.options) option.disabled = !available.has(option.value);
    if (!available.has(loadSlot.value)) loadSlot.value = [...available][0] || '1';
    loadButton.disabled = !available.has(loadSlot.value);
    speedButton.textContent = state.speed === 8 ? 'Normal speed' : '8× speed';
    controlStatus.textContent = state.message || '';
}
document.querySelector('#web-save').addEventListener('click', () =>
  command({op: 'save_state', slot: Number(saveSlot.value)}));
loadButton.addEventListener('click', () => command({op: 'load_state', slot: Number(loadSlot.value)}));
loadSlot.addEventListener('change', () => { loadButton.disabled = loadSlot.selectedOptions[0].disabled; });
graphics.addEventListener('change', () => command({op: 'graphics', mode: graphics.value}));
hudStyle.addEventListener('change', () => command({op: 'hud_style', style: hudStyle.value}));
speedButton.addEventListener('click', () => command({op: 'speed'}));
document.querySelector('#web-help').addEventListener('click', () => command({op: 'help'}));
window.addEventListener('keydown', event => {
  if (!started || toolbar.hidden || !['KeyS', 'KeyL', 'KeyG'].includes(event.code)) return;
  const modifier = (event.metaKey && !event.ctrlKey && !event.altKey) ||
    (event.ctrlKey && event.altKey && !event.metaKey);
  if (!modifier || (event.shiftKey && event.code !== 'KeyL')) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  if (event.repeat) return;
  if (event.code === 'KeyG') command({op: 'cycle_graphics'});
  else command({op: event.code === 'KeyS' ? 'save_state' : 'load_state',
    slot: event.shiftKey ? 0 : 1});
}, true);

startButton.addEventListener('click', async () => {
  if (started) return;
  started = true;
  input.disabled = true;
  genesisInput.disabled = true;
  startButton.disabled = true;
  try {
    report('Verifying your original PC files locally…');
    const [response, buildResponse, genesisResponse] = await Promise.all([
      fetch('./.generated/game-inputs.json'), fetch('./.generated/build-info.json'),
      fetch('./.generated/genesis-input.json')]);
    if (!response.ok || !buildResponse.ok || !genesisResponse.ok)
      throw new Error('The supported original-game or browser build manifest is missing');
    const build = await buildResponse.json();
    if (!/^[0-9a-f]{64}$/.test(build.wasm_sha256 || ''))
      throw new Error('The original-game browser core has no valid build identity');
    const {zip, catalog, originalBytes} = await packOriginals(input.files, await response.json());
    let genesisEnabled = false;
    if (genesisInput.files.length) {
      if (genesisInput.files.length !== 1) throw new Error('Choose one original Genesis ROM');
      const genesis = await genesisResponse.json();
      const rom = new Uint8Array(await genesisInput.files[0].arrayBuffer());
      if (rom.byteLength !== genesis.bytes || await sha256(rom) !== genesis.sha256)
        throw new Error('Unsupported Genesis ROM. The selected file was not imported.');
      genesisEnabled = true;
    }
    report('Starting the original game and loading the remaster…');
    host = createBridgeHost(zip, catalog, build.wasm_sha256, message => {
      if (message.type === 'progress')
        report(`Starting the original PC game ${message.frame}/${message.total}…`);
      if (message.type === 'ready' || message.type === 'sample') {
        canvas.dataset.originalSequence = String(message.sequence);
        canvas.dataset.originalProgram = message.program?.name || '';
      }
    }, updateToolbar);
    globalThis.AbramsWebHost = host;
    syncCanvasSize();
    const engine = new Engine({canvas, executable: 'index', canvasResizePolicy: 0,
      focusCanvas: true, ensureCrossOriginIsolationHeaders: true,
      onPrintError: line => console.error('Godot:', line)});
    await Promise.all([
      host.first,
      engine.init('./.generated/godot/index'),
      engine.preloadFile('./.generated/godot/index.pck', 'index.pck'),
    ]);
    await installRemasterAssets(engine, (done, total) =>
      report(`Loading remaster artwork ${done}/${total}…`));
    for (const [name, bytes] of originalBytes)
      engine.copyToFS('/GAME/' + name, bytes);
    report('Starting the remastered Godot presentation…');
    await engine.start({args: ['--main-pack', 'index.pck', '--', '--boot', '--play',
      ...(genesisEnabled ? [] : ['--pc-only'])]});
    await Promise.race([host.viewerReady, new Promise((_, reject) =>
      setTimeout(() => reject(new Error('The remastered viewer did not present an original game frame')), 30000))]);
    report('Original PC game running in the remastered Godot viewer. Click the game to use its keyboard.');
    toolbar.hidden = false;
    document.body.classList.add('playing');
    canvas.focus();
  } catch (error) {
    host?.close();
    report(`The Web integration could not start: ${error?.message || error}`);
    input.disabled = false;
    genesisInput.disabled = false;
    startButton.disabled = !input.files.length;
    toolbar.hidden = true;
    document.body.classList.remove('playing');
    host = undefined;
    started = false;
  }
});
