// The isolation worker serves every published file at its BUNDLE.json bytes,
// keeps verified files by hash across deploys and isolates every response.
import assert from 'node:assert/strict';
import {createHash, webcrypto} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('./remaster.service.worker.js', import.meta.url), 'utf8');
const sha = text => createHash('sha256').update(text).digest('hex');
const scope = 'https://example.test/play/';

function worker(files) {
  const listeners = {}, network = [], store = new Map(), pending = [];
  const site = {...files};
  const caches = {open: async () => ({
    match: async request => store.get(request.url)?.clone(),
    put: async (request, response) => { store.set(request.url, response); },
    keys: async () => [...store.keys()].map(url => new Request(url)),
    delete: async request => store.delete(request.url),
  })};
  const fetch = async (input, init) => {
    const url = typeof input === 'string' || input instanceof URL ? String(input) : input.url;
    network.push({url, cache: init?.cache});
    const path = url.slice(scope.length);
    if (path === 'BUNDLE.json')
      return new Response(JSON.stringify({schema: 1, files: Object.fromEntries(Object.entries(site)
        .map(([name, body]) => [name, {bytes: body.length, sha256: sha(body.published ?? body)}]))}));
    const body = site[path];
    if (body === undefined) return new Response('missing', {status: 404});
    if (body.chunks) return new Response(new ReadableStream({async pull(controller) {
      await new Promise(resolve => setTimeout(resolve, body.delay));
      const chunk = body.chunks.shift();
      if (chunk === undefined) { body.done = true; controller.close(); }
      else controller.enqueue(typeof chunk === 'string' ? new TextEncoder().encode(chunk) : chunk);
    }}), {headers: {'Content-Type': 'application/zip'}});
    return new Response(body.served ?? body, {headers: {'Content-Type': 'application/wasm'}});
  };
  const self = {location: new URL('remaster.service.worker.js', scope), registration: {scope},
    addEventListener: (type, fn) => { listeners[type] = fn; }, skipWaiting() {}, clients: {claim() {}}};
  vm.runInNewContext(source, {self, caches, fetch, crypto: webcrypto, Request, Response, Headers, URL, Set, Map,
    Object, Array, Uint8Array, decodeURIComponent, Error});
  const respond = (path, init = {}) => {
    let response;
    const event = {request: new Request(new URL(path, scope)),
      respondWith: value => { response = value; }, waitUntil: value => pending.push(value)};
    if (init.navigate) Object.defineProperty(event.request, 'mode', {value: 'navigate'});
    listeners.fetch(event);
    return response;
  };
  const request = async (path, init = {}) => {
    const result = await respond(path, init);
    await Promise.all(pending.splice(0));
    return result;
  };
  const settled = () => Promise.all(pending.splice(0));
  return {site, network, store, request, respond, settled};
}

test('bundle files are verified, cached by hash and served without a second download', async () => {
  const w = worker({'.generated/godot/index.wasm': 'engine v1', 'remaster.mjs': 'shell v1'});
  await w.request('remaster.html', {navigate: true});
  const first = await w.request('.generated/godot/index.wasm');
  assert.equal(await first.text(), 'engine v1');
  assert.equal(first.headers.get('Cross-Origin-Embedder-Policy'), 'require-corp');
  assert.equal(first.headers.get('Cross-Origin-Opener-Policy'), 'same-origin');
  assert.ok(w.network.find(call => call.url.endsWith('index.wasm')).cache === 'no-cache');
  const before = w.network.length;
  const second = await w.request('.generated/godot/index.wasm');
  assert.equal(await second.text(), 'engine v1');
  assert.equal(second.headers.get('Content-Type'), 'application/wasm');
  assert.equal(w.network.length, before, 'served from the hash cache');
});

test('a deploy re-downloads only changed files and prunes superseded bytes', async () => {
  const w = worker({'a.zip': 'part a', 'b.zip': 'part b v1'});
  await w.request('remaster.html', {navigate: true});
  await w.request('a.zip'); await w.request('b.zip');
  w.site['b.zip'] = 'part b v2';
  await w.request('remaster.html', {navigate: true});
  const before = w.network.length;
  assert.equal(await (await w.request('a.zip')).text(), 'part a');
  assert.equal(w.network.length, before, 'unchanged part survives the deploy');
  assert.equal(await (await w.request('b.zip')).text(), 'part b v2');
  assert.ok(![...w.store.keys()].some(key => key.endsWith(sha('part b v1'))), 'old bytes pruned');
});

test('bytes from another build are served but never cached', async () => {
  const w = worker({'core.wasm': {published: 'core v2', served: 'core v1', length: 7}});
  await w.request('remaster.html', {navigate: true});
  assert.equal(await (await w.request('core.wasm')).text(), 'core v1');
  assert.equal(w.store.size, 0);
});

test('unlisted, queried and failed requests revalidate and stay isolated', async () => {
  const w = worker({'remaster.mjs': 'shell'});
  const unlisted = await w.request('notes.txt');
  assert.equal(unlisted.status, 404); assert.equal(unlisted.headers.get('Cross-Origin-Opener-Policy'), 'same-origin');
  await w.request('remaster.mjs?x=1');
  assert.equal(w.network.at(-1).cache, 'no-cache');
  assert.equal(w.store.size, 0);
});

test('a cache miss streams to the page before the download completes, then is kept', async () => {
  const chunks = ['part ', 'one ', 'of ', 'five ', 'chunks'];
  const w = worker({'part.zip': {chunks: [...chunks], delay: 150, published: chunks.join(''), length: 0}});
  await w.request('remaster.html', {navigate: true});
  const site = w.site['part.zip'];
  const response = await w.respond('part.zip');
  assert.ok(!site.done, 'respondWith settles before the body has downloaded');
  const reader = response.body.getReader();
  const first = await reader.read();
  assert.equal(new TextDecoder().decode(first.value), 'part ');
  assert.ok(!site.done, 'the first chunk reaches the page while the rest is in flight');
  assert.equal(w.store.size, 0, 'not cached before the hash can be checked');
  let text = new TextDecoder().decode(first.value);
  for (let next = await reader.read(); !next.done; next = await reader.read()) text += new TextDecoder().decode(next.value);
  assert.equal(text, chunks.join(''));
  await w.settled();
  assert.equal(w.store.size, 1, 'verified stream is cached by hash');
  const before = w.network.length;
  assert.equal(await (await w.request('part.zip')).text(), chunks.join(''));
  assert.equal(w.network.length, before);
});

test('a slow part downloads through the worker without tripping the loader idle timeout', async () => {
  globalThis.crypto ??= webcrypto;
  const {buildStoredZip, sha256} = await import('./zip_store.mjs');
  const {installRemasterAssets} = await import('./remaster_assets.mjs');
  const payload = new Uint8Array(4000).map((_, index) => index % 251);
  const part = buildStoredZip([['local-art/slow.png', payload]]);
  const pieces = [];
  for (let at = 0; at < part.length; at += 100) pieces.push(part.slice(at, at + 100));
  const chunkCount = pieces.length;
  const catalog = JSON.stringify({schema: 3,
    parts: [{name: 'remaster-assets-00.zip', bytes: part.length, sha256: await sha256(part), set: 'common'}],
    files: [{path: 'local-art/slow.png', bytes: payload.length, sha256: await sha256(payload), set: 'common'}]});
  // The whole part takes several idle windows; each chunk arrives within one.
  const w = worker({'.generated/remaster-assets-00.zip': {chunks: [...pieces], delay: 50, published: part, length: part.length},
    '.generated/remaster-assets.json': catalog});
  await w.request('remaster.html', {navigate: true});
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async url => w.respond(new URL(url, scope).href);
  const progress = [];
  try {
    const copied = [];
    const count = await installRemasterAssets({copyToFS: (...args) => copied.push(args)},
      (...values) => progress.push(values), {idleMs: 600});
    assert.equal(count, 1);
    assert.ok(chunkCount * 50 > 3 * 600, 'the download outlasts several idle windows');
    assert.ok(new Set(progress.map(values => values[2])).size >= chunkCount, 'byte progress moves within the part');
  } finally { globalThis.fetch = originalFetch; }
  await w.settled();
  assert.ok(w.store.has(new URL('__sha256/' + sha(part), scope).href), 'the streamed part is kept by hash');
});
