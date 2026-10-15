// The browser must derive exactly the recognition data the desktop builders
// produced, from the visitor's files, so the site never has to serve it.
// Exact-input checks need the local GAME/ and GENESIS/ inputs; nothing is saved.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash, webcrypto} from 'node:crypto';
import {readdir, readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {inflateSync} from 'node:zlib';

globalThis.crypto ??= webcrypto;
const {derivePcArt, deriveGenesisArt, encodeRgbPng, decodeBitmaps, shapeRegistry, PC_DERIVED, GENESIS_DERIVED} = await import('./derived_art.mjs');
const root = new URL('../', import.meta.url);
const hex = bytes => createHash('sha256').update(bytes).digest('hex');
// Pillow's view of a PNG (a path, or bytes on stdin): sha256 of its RGB pixels.
const PIXELS = 'import sys,hashlib,io\nfrom PIL import Image\ndata=open(sys.argv[1],"rb").read() if len(sys.argv)>1 else sys.stdin.buffer.read()\nprint(hashlib.sha256(Image.open(io.BytesIO(data)).convert("RGB").tobytes()).hexdigest())';
const pillowPixels = (input, path) => String(execFileSync('python3', ['-c', PIXELS, ...(path ? [path] : [])],
  {cwd: fileURLToPath(root), input, maxBuffer: 1024 * 1024})).trim();

function pngRgb(png) {
  // Our own encoder: IHDR, one IDAT of stored blocks, unfiltered rows.
  const view = new DataView(png.buffer, png.byteOffset, png.byteLength);
  const width = view.getUint32(16), height = view.getUint32(20), length = view.getUint32(33);
  const raw = inflateSync(png.subarray(41, 41 + length));
  const rgb = new Uint8Array(width * height * 3);
  for (let y = 0; y < height; y++) {
    assert.equal(raw[y * (width * 3 + 1)], 0);
    rgb.set(raw.subarray(y * (width * 3 + 1) + 1, (y + 1) * (width * 3 + 1)), y * width * 3);
  }
  return rgb;
}

// Encoder contract without original inputs: zlib, CRC and Pillow all accept it.
const sample = Uint8Array.from({length: 100 * 700 * 3}, (_, i) => (i * 37) & 255);
const png = encodeRgbPng(100, 700, sample); // Spans several stored blocks.
assert.deepEqual(pngRgb(png), sample);
assert.equal(pillowPixels(png), hex(sample));
assert.throws(() => encodeRgbPng(2, 2, new Uint8Array(3)), /Invalid derived image/);
assert.throws(() => decodeBitmaps(Uint8Array.of(1, 0, 0, 0, 1, 0)), /bitmap/);
assert.equal(new Set(PC_DERIVED).size, 10);

const originals = new Map();
let game = true;
try {
  for (const name of await readdir(new URL('GAME/', root)))
    originals.set(name.toUpperCase(), new Uint8Array(await readFile(new URL('GAME/' + name, root))));
} catch (error) { if (error.code !== 'ENOENT') throw error; game = false; }
if (game) {
  const derived = await derivePcArt(originals);
  assert.deepEqual([...derived.keys()], [...PC_DERIVED]);
  for (const [path, bytes] of derived) {
    let local;
    try { local = await readFile(new URL(path, root)); }
    catch (error) { if (error.code !== 'ENOENT') throw error; console.log(`SKIP: no local desktop decode ${path}`); continue; }
    if (path.endsWith('.json')) assert.equal(hex(bytes), hex(local), `${path} must be byte-identical`);
    else assert.equal(hex(pngRgb(bytes)), pillowPixels(undefined, fileURLToPath(new URL(path, root))), `${path} pixels`);
  }
  await assert.rejects(derivePcArt(new Map([...originals].filter(([name]) => name !== 'CLIP.BMP'))), /CLIP/);
  // Modern's SHAPE.TBL registry equals the Python decode (no local file needed)
  // and the hash catalog.json pins, which pc_modern_assets.gd gates on.
  const shapes = derived.get('local-art/pc-modern/source-shapes.json');
  const REGISTRY = 'import sys;from tools.build_pc_modern_assets import source_registry,registry_bytes\n'
    + 'sys.stdout.buffer.write(registry_bytes(source_registry(open("GAME/SHAPE.TBL","rb").read())))';
  const python = execFileSync('python3', ['-c', REGISTRY], {cwd: fileURLToPath(root), maxBuffer: 16 * 1024 * 1024});
  assert.equal(hex(shapes), hex(python), 'source-shapes.json must equal registry_bytes(source_registry(SHAPE.TBL))');
  try {
    const catalog = JSON.parse(await readFile(new URL('local-art/pc-modern/catalog.json', root), 'utf8'));
    assert.deepEqual([catalog.source_registry.file, catalog.source_registry.sha256], ['source-shapes.json', hex(shapes)]);
  } catch (error) { if (error.code !== 'ENOENT') throw error; console.log('SKIP: no local Modern catalogue pin'); }
  const foreign = new Map(originals); foreign.set('SHAPE.TBL', originals.get('SHAPE.TBL').slice(0, -1));
  await assert.rejects(derivePcArt(foreign), /Unsupported original SHAPE.TBL/);
  assert.throws(() => shapeRegistry(Uint8Array.of(2, 4, 0, 0, 0, 0)), /resource/);
  console.log(`PASS: ${derived.size} visitor-derived PC recognition files match the desktop decodes`);
} else console.log('SKIP: PC derivation integration requires local GAME inputs');

let rom;
try { rom = new Uint8Array(await readFile(new URL('GENESIS/M-1 Abrams Battle Tank (USA, Europe).md', root))); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
if (rom) {
  const derived = await deriveGenesisArt(rom);
  assert.deepEqual([...derived.keys()], [...GENESIS_DERIVED]);
  let local;
  try { local = await readFile(new URL(GENESIS_DERIVED[0], root)); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (local) assert.equal(hex(derived.get(GENESIS_DERIVED[0])), hex(local), 'effects.json must be byte-identical');
  else console.log('SKIP: no local desktop Genesis effects decode');
  await assert.rejects(deriveGenesisArt(rom.slice(1)), /Unsupported Genesis ROM/);
  console.log('PASS: visitor-derived Genesis effects match the desktop decode');
} else console.log('SKIP: Genesis derivation integration requires the local ROM');
