// Local integration smoke: original PC files are read from the ignored runtime.
// No game data is printed, uploaded or written into the tracked prototype.
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import createCore from './.generated/core.js';

const root = new URL('../', import.meta.url);
const game = await readFile(new URL('.runtime/pc-core/abrams-ref.zip', root));
const core = await createCore();
core.FS.mkdir('/game');
core.FS.mkdir('/saves');
core.FS.writeFile('/game/abrams-ref.zip', game);
if (core.ccall('abrams_web_start', 'number', ['string'], ['/game/abrams-ref.zip']) !== 1)
  throw new Error('WASM original game boot failed');
if (core._abrams_web_trace_frontend() !== 1)
  throw new Error('Cannot observe the original-game frontend');
const frontendKinds = new Set();
const replay = spawn('python3', ['web-prototype/frontend_replay.py'], {
  cwd: fileURLToPath(root), stdio: ['pipe', 'pipe', 'pipe'],
});
let replayOut = '', replayError = '';
replay.stdout.setEncoding('utf8');
replay.stderr.setEncoding('utf8');
replay.stdout.on('data', data => { replayOut += data; });
replay.stderr.on('data', data => { replayError += data; });
replay.stdin.on('error', () => {}); // Write callbacks surface early replay failure.
const send = bytes => new Promise((resolve, reject) =>
  replay.stdin.write(bytes, error => error ? reject(error) : resolve()));
for (let frame = 0; frame < 241; frame++) {
  if (core._abrams_web_step() !== 1) throw new Error(`WASM frame ${frame} failed`);
  if (core._abrams_web_trace_overflow()) throw new Error('Original frontend observer overflowed');
  const bytes = core.HEAPU8.slice(core._abrams_web_trace_events(),
    core._abrams_web_trace_events() + core._abrams_web_trace_size());
  const view = new DataView(bytes.buffer);
  let cursor = 0, count = 0;
  while (cursor < bytes.length) {
    if (cursor + 36 > bytes.length) throw new Error('Truncated frontend event header');
    frontendKinds.add(view.getUint32(cursor, true));
    cursor += 36 + view.getUint32(cursor + 8, true);
    count++;
  }
  if (cursor !== bytes.length || count !== core._abrams_web_trace_count())
    throw new Error('Frontend event packet boundaries are invalid');
  const record = Buffer.allocUnsafe(4 + bytes.length);
  record.writeUInt32LE(bytes.length, 0);
  record.set(bytes, 4);
  await send(record);
}
const width = core._abrams_web_video_width();
const height = core._abrams_web_video_height();
const pitch = core._abrams_web_video_pitch();
if (!width || !height || pitch < width * 4) throw new Error('No original framebuffer');
const video = core.HEAPU8.slice(core._abrams_web_video(), core._abrams_web_video() + pitch * height);
const ram = core.HEAPU8.slice(core._abrams_web_paired_ram(), core._abrams_web_paired_ram() + 640 * 1024);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const footer = Buffer.allocUnsafe(4 + 16 + video.length + ram.length);
footer.writeUInt32LE(0xFFFFFFFF, 0);
footer.writeUInt32LE(width, 4);
footer.writeUInt32LE(height, 8);
footer.writeUInt32LE(pitch, 12);
footer.writeUInt32LE(video.length, 16);
footer.set(video, 20);
footer.set(ram, 20 + video.length);
replay.stdin.end(footer);
const [exitCode] = await new Promise((resolve, reject) => {
  replay.once('error', reject);
  replay.once('close', (code, signal) => resolve([signal ? -1 : code]));
});
if (exitCode !== 0) throw new Error(`Desktop frontend replay failed: ${replayError.trim()}`);
const frontend = JSON.parse(replayOut);
if (frontend.frames !== 241 || frontend.program !== 'START' || !frontend.ui_overlay)
  throw new Error('Desktop frontend observer could not consume the browser callback trace');
console.log(JSON.stringify({ frames: 241, width, height, pitch, video_sha256: hash(video), ram_sha256: hash(ram), state_bytes: core._abrams_web_state_size() }));
console.log(JSON.stringify({ stage: 'frontend-observer', kinds: [...frontendKinds].sort((a, b) => a - b) }));
console.log(JSON.stringify({ stage: 'desktop-frontend-replay', ...frontend }));
if (!frontendKinds.has(12) || ![26, 28, 49, 53].some(kind => frontendKinds.has(kind)))
  throw new Error('No source-attributed original frontend was observed');
core._abrams_web_trace_stop();
if (process.env.ABRAMS_WEB_DUMP === '1')
  await writeFile(new URL('.runtime/web-core/wasm-ram.bin', root), ram);
process.exit(0);
