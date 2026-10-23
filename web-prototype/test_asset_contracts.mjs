import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
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
// The builder's real ZIP writer: one stored PNG and one deflated JSON member.
const text = '{"schema": 1, "rows": [' + Array(200).fill('"repeated text"').join(', ') + ']}\n';
const mixed = new Uint8Array(execFileSync('python3', ['-c',
  'import io,sys,zipfile\nb=io.BytesIO()\nz=zipfile.ZipFile(b,"w")\n' +
  'for n,d,m in [("local-art/a.png",bytes([1,2,3]),0),("local-art/b.json",sys.stdin.buffer.read(),8)]:\n' +
  ' i=zipfile.ZipInfo(n,(1980,1,1,0,0,0)); i.compress_type=m; z.writestr(i,d,compresslevel=9 if m else None)\n' +
  'z.close(); sys.stdout.buffer.write(b.getvalue())'], {input: text}));
const originalFetch = globalThis.fetch;
let calls = [], copies = [];
async function fixture(archive = valid, change = value => value, options = {}, respond) {
  const catalog = change({schema: 3, parts: [{name: 'remaster-assets-00.zip', bytes: archive.length, sha256: await sha256(archive), set: 'common'}],
    files: [{path, bytes: payload.length, sha256: await sha256(payload), set: 'common'}]});
  calls = []; copies = [];
  globalThis.fetch = async (url, init) => {
    calls.push({url, init});
    return respond?.(url, init) ?? {ok: true, headers: {get: () => null}, json: async () => catalog, arrayBuffer: async () => archive};
  };
  const progress = [];
  const count = await installRemasterAssets({copyToFS: (name, bytes) => copies.push([name, [...bytes]])}, (...args) => progress.push(args), options);
  return {count, progress};
}
try {
  const controller = new AbortController();
  assert.deepEqual(await fixture(valid, value => value, {signal: controller.signal}),
    {count: 1, progress: [[0, 1, valid.length, valid.length], [1, 1, valid.length, valid.length]]});
  assert.deepEqual(copies, [['/' + path, [1, 2, 3]]]);
  assert.equal(calls[0].init.signal, controller.signal); assert.equal(calls[0].init.cache, 'no-cache');
  for (const mutate of [c => ({...c, files: null}), c => ({...c, files: Array(10001).fill(c.files[0])}),
    c => ({...c, files: [{...c.files[0], path: '../escape'}]}), c => ({...c, parts: [...c.parts, ...c.parts]}),
    c => ({...c, parts: [{...c.parts[0], bytes: 48_000_001}]}), c => ({...c, files: [{...c.files[0], sha256: 'bad'}]}),
    c => ({...c, schema: 2}), c => ({...c, parts: [{...c.parts[0], set: 'other'}]})])
    await assert.rejects(fixture(valid, mutate), /manifest|part/);
  // Only the reviewed roster path gets its existing native96MiB expanded cap.
  const rosterPath = 'local-art/pc-tactical-roster-v1/catalog.json';
  await assert.rejects(fixture(valid, c => ({...c, files: [{...c.files[0], bytes: 48_000_001}]})), /manifest entry/);
  await assert.rejects(fixture(valid, c => ({...c, files: [{...c.files[0], path: rosterPath, bytes: 96 * 1024 * 1024 + 1}]})), /manifest entry/);
  // Accepted large-roster metadata still cannot authenticate a mismatched ZIP member.
  await assert.rejects(fixture(valid, c => ({...c, files: [{...c.files[0], path: rosterPath, bytes: 99_599_244}]})), /Unexpected authored asset path/);
  // A visitor-derived decode in the served catalog is refused outright.
  await assert.rejects(fixture(valid, c => ({...c, files: [{...c.files[0], path: 'local-art/pc-portraits-v1/faces.json'}]})), /original-derived/);
  for (const flags of [1, 8, 0x40]) {
    const archive = valid.slice(); new DataView(archive.buffer).setUint16(6, flags, true);
    await assert.rejects(fixture(archive), /Unsupported/); assert.equal(copies.length, 0);
  }
  const unknown = valid.slice(); new DataView(unknown.buffer).setUint16(8, 12, true);
  await assert.rejects(fixture(unknown), /Unsupported/);
  const relabelled = valid.slice(); new DataView(relabelled.buffer).setUint16(8, 8, true);
  await assert.rejects(fixture(relabelled), /Invalid|inflate|Unsupported/); assert.equal(copies.length, 0);
  for (const length of [10, 31, valid.length - 1]) {
    await assert.rejects(fixture(valid.slice(0, length)), /Truncated|completion|part/);
    assert.equal(copies.length, 0);
  }
  await assert.rejects(fixture(buildStoredZip([[path, payload], [path, payload]])), /Unexpected/);
  await assert.rejects(fixture(valid, c => ({...c, files: [...c.files, {...c.files[0], path: 'local-art/missing.png'}]})), /incomplete/);
  const aborted = new AbortController(); aborted.abort();
  await assert.rejects(fixture(valid, c => c, {signal: aborted.signal}), {name: 'AbortError'});

  // Deflated text members inflate and must match their recorded size and CRC.
  const rows = async () => [{path: 'local-art/a.png', bytes: 3, sha256: await sha256(Uint8Array.of(1, 2, 3)), set: 'common'},
    {path: 'local-art/b.json', bytes: text.length, sha256: await sha256(new TextEncoder().encode(text)), set: 'common'}];
  const files = await rows();
  assert.equal((await fixture(mixed, c => ({...c, files}))).count, 2);
  assert.equal(new TextDecoder().decode(Uint8Array.from(copies[1][1])), text);
  // Zero the deflated member's CRC in both its local and central records.
  const corrupt = mixed.slice(), edit = new DataView(corrupt.buffer);
  const signatures = value => [...corrupt.keys()].filter(at => at + 4 <= corrupt.length && edit.getUint32(at, true) === value);
  edit.setUint32(signatures(0x04034b50)[1] + 14, 0, true);
  edit.setUint32(signatures(0x02014b50)[1] + 16, 0, true);
  await assert.rejects(fixture(corrupt, c => ({...c, files})), /CRC check/);

  // Genesis-gated parts are fetched only for a verified ROM session.
  const genesisPart = buildStoredZip([['local-art/genesis/g.png', Uint8Array.of(9)]]);
  const twoSets = async c => ({...c, parts: [...c.parts, {name: 'remaster-assets-01.zip', bytes: genesisPart.length, sha256: await sha256(genesisPart), set: 'genesis'}],
    files: [...c.files, {path: 'local-art/genesis/g.png', bytes: 1, sha256: await sha256(Uint8Array.of(9)), set: 'genesis'}]});
  const catalogTwo = await twoSets({schema: 3, parts: [{name: 'remaster-assets-00.zip', bytes: valid.length, sha256: await sha256(valid), set: 'common'}],
    files: [{path, bytes: payload.length, sha256: await sha256(payload), set: 'common'}]});
  const serve = url => ({ok: true, headers: {get: () => null}, json: async () => catalogTwo,
    arrayBuffer: async () => url.endsWith('01.zip') ? genesisPart : valid});
  assert.equal((await fixture(valid, () => catalogTwo, {}, serve)).count, 1);
  assert.ok(!calls.some(call => call.url.endsWith('01.zip')), 'PC-only sessions skip Genesis parts');
  assert.equal((await fixture(valid, () => catalogTwo, {sets: ['common', 'genesis']}, serve)).count, 2);
  await assert.rejects(fixture(valid, c => c, {sets: ['genesis']}), /set/);

  // A stalled stream fails after the idle window, not a fixed total deadline.
  const stalledBody = {getReader: () => ({read: () => new Promise(() => {})})};
  await assert.rejects(fixture(valid, c => c, {idleMs: 20}, url => url.endsWith('.json')
    ? undefined : {ok: true, headers: {get: () => null}, body: stalledBody}), /stopped making progress/);
  // Streaming bodies report byte progress per chunk.
  const chunked = {getReader() { let sent = 0; return {read: async () => sent < valid.length
    ? {done: false, value: valid.subarray(sent, sent = Math.min(valid.length, sent + 40))} : {done: true}}; }};
  const streamed = await fixture(valid, c => c, {}, url => url.endsWith('.json') ? undefined : {ok: true, headers: {get: () => null}, body: chunked});
  assert.ok(streamed.progress.length >= Math.ceil(valid.length / 40));

  // Existing full-resolution authored parts must remain accepted byte-for-byte.
  let actual;
  try { actual = JSON.parse(await readFile(new URL('.generated/remaster-assets.json', source))); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (actual?.schema === 3) {
  globalThis.fetch = async url => ({ok: true, headers: {get: () => null}, json: async () => actual,
    arrayBuffer: async () => readFile(new URL(url.replace('./', ''), source))});
  let installed = 0, lastProgress;
  const total = actual.files.length;
  assert.equal(await installRemasterAssets({copyToFS: () => installed++}, (...args) => {lastProgress = args;}, {sets: ['common', 'genesis']}), total);
  assert.equal(installed, total); assert.equal(lastProgress[0], installed);
  } else console.log(actual ? 'SKIP: local generated assets predate schema 3; rebuild with build_remaster_assets.py'
    : 'SKIP: full authored pack integration requires local generated assets');
} finally {globalThis.fetch = originalFetch;}
console.log('PASS: authored/original loader contract checks; local exact-input integration is reported separately');
