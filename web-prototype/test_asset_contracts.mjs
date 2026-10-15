import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {webcrypto} from 'node:crypto';

// Dependency-free loader regressions. Exact private inputs are optional integration checks.
globalThis.crypto ??= webcrypto;
const root = new URL('../', import.meta.url);
const source = new URL('web-prototype/', root);
const {packOriginals, buildStoredZip, sha256} = await import('./zip_store.mjs');
const {installRemasterAssets} = await import('./remaster_assets.mjs');
const manifest = JSON.parse(await readFile(new URL('tools/package/game-inputs.json', root)));
let reads = 0;
let originalsAvailable = true;
const files = await Promise.all(manifest.files.map(async row => {
  let bytes;
  try { bytes = await readFile(new URL('GAME/' + row.name, root)); }
  catch (error) { if (error.code !== 'ENOENT') throw error; originalsAvailable = false; bytes = new Uint8Array(1); }
  return {name: row.name, size: bytes.length, arrayBuffer: async () => {reads++; return bytes;}};
}));
await assert.rejects(packOriginals(files, null), /manifest/);
await assert.rejects(packOriginals(files, {...manifest, files: [{...manifest.files[0], name: '../BAD'}, ...manifest.files.slice(1)]}), /manifest entry/);
await assert.rejects(packOriginals(files, {...manifest, files: [manifest.files[0], ...manifest.files.slice(0, 67)]}), /manifest entry/);
await assert.rejects(packOriginals([{...files[0], size: 1024 * 1024 + 1}, ...files.slice(1)], manifest), /Wrong size/);
await assert.rejects(packOriginals(files, {...manifest, files: [{...manifest.files[0], bytes: files[0].size + 1}, ...manifest.files.slice(1)]}), /Wrong size/);
assert.equal(reads, 0, 'Invalid inputs must reject before any original read');
await assert.rejects(packOriginals([...files, {...files[0], name: files[0].name.toLowerCase()}], manifest), /Ambiguous/);
const extras = ['notes.txt', 'NOTES.TXT'].map(name => ({name, size: 1, arrayBuffer: async () => {throw new Error('Unrelated file was read');}}));
// Required-file validation still runs when unrelated collisions are present.
await assert.rejects(packOriginals([...files.slice(1), ...extras], manifest), /Missing original PC file/);

if (originalsAvailable) {
const originalProgress = [];
const prepared = await packOriginals(files, manifest, (...values) => originalProgress.push(values));
assert.equal(await sha256(prepared.zip), 'c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05');
assert.deepEqual(originalProgress.at(-1), [68, 68]);
const withExtras = await packOriginals([...files, ...extras], manifest);
assert.equal(await sha256(withExtras.zip), await sha256(prepared.zip));
assert.deepEqual([...withExtras.originalBytes.keys()], [...prepared.originalBytes.keys()]);


} else console.log('SKIP: exact original ZIP integration requires local GAME inputs');

const path = 'local-art/test.png', payload = Uint8Array.of(1, 2, 3);
const valid = buildStoredZip([[path, payload]]);
const originalFetch = globalThis.fetch;
let calls = [], copies = [];
async function fixture(archive = valid, change = value => value, options = {}) {
  const catalog = change({schema: 2, parts: [{name: 'remaster-assets-00.zip', bytes: archive.length, sha256: await sha256(archive)}],
    files: [{path, bytes: payload.length, sha256: await sha256(payload)}]});
  calls = []; copies = [];
  globalThis.fetch = async (url, init) => {
    calls.push({url, init});
    return {ok: true, headers: {get: () => null}, json: async () => catalog, arrayBuffer: async () => archive};
  };
  const progress = [];
  const count = await installRemasterAssets({copyToFS: (name, bytes) => copies.push([name, [...bytes]])}, (...args) => progress.push(args), options);
  return {count, progress};
}
try {
  const controller = new AbortController();
  assert.deepEqual(await fixture(valid, value => value, {signal: controller.signal}), {count: 1, progress: [[1, 1]]});
  assert.deepEqual(copies, [['/' + path, [1, 2, 3]]]);
  assert.ok(calls.every(call => call.init.signal === controller.signal));
  for (const mutate of [c => ({...c, files: null}), c => ({...c, files: Array(10001).fill(c.files[0])}),
    c => ({...c, files: [{...c.files[0], path: '../escape'}]}), c => ({...c, parts: [...c.parts, ...c.parts]}),
    c => ({...c, parts: [{...c.parts[0], bytes: 48_000_001}]}), c => ({...c, files: [{...c.files[0], sha256: 'bad'}]})])
    await assert.rejects(fixture(valid, mutate), /manifest|part/);
  for (const flags of [1, 8, 0x40]) {
    const archive = valid.slice(); new DataView(archive.buffer).setUint16(6, flags, true);
    await assert.rejects(fixture(archive), /Unsupported/); assert.equal(copies.length, 0);
  }
  const compressed = valid.slice(); new DataView(compressed.buffer).setUint16(8, 8, true);
  await assert.rejects(fixture(compressed), /Unsupported/);
  for (const length of [10, 31, valid.length - 1]) {
    await assert.rejects(fixture(valid.slice(0, length)), /Truncated|completion|part/);
    assert.equal(copies.length, 0);
  }
  await assert.rejects(fixture(buildStoredZip([[path, payload], [path, payload]])), /Unexpected/);
  await assert.rejects(fixture(valid, c => ({...c, files: [...c.files, {...c.files[0], path: 'local-art/missing.png'}]})), /incomplete/);
  const aborted = new AbortController(); aborted.abort();
  await assert.rejects(fixture(valid, c => c, {signal: aborted.signal}), {name: 'AbortError'});

  // Existing full-resolution authored parts must remain accepted byte-for-byte.
  let actual;
  try { actual = JSON.parse(await readFile(new URL('.generated/remaster-assets.json', source))); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (actual) {
  globalThis.fetch = async url => ({ok: true, headers: {get: () => null}, json: async () => actual,
    arrayBuffer: async () => readFile(new URL(url.replace('./', ''), source))});
  let installed = 0, lastProgress;
  assert.equal(await installRemasterAssets({copyToFS: () => installed++}, (...args) => {lastProgress = args;}), actual.files.length);
  assert.equal(installed, actual.files.length); assert.deepEqual(lastProgress, [installed, installed]);
  } else console.log('SKIP: full authored pack integration requires local generated assets');
} finally {globalThis.fetch = originalFetch;}
console.log('PASS: authored/original loader contract checks; local exact-input integration is reported separately');
