// Supply isolation on static hosts that cannot set response headers, and
// serve each published file at exactly the bytes BUNDLE.json names. Verified
// files are kept under their SHA-256, so a deploy re-downloads only files that
// changed and never pairs an old file with a newer build. The visitor's
// original files never pass through here: they are read locally, not fetched.
const CACHE = 'abrams-play-sha256-v1';
const scope = new URL(self.registration?.scope ?? self.location.href.replace(/[^/]*$/, ''));
let bundle; // Promise<Map<published path, sha256>>

self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));

function isolate(response) {
  const headers = new Headers(response.headers);
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  return new Response(response.body, {status: response.status, statusText: response.statusText, headers});
}
const hex = digest => Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
const cacheKey = sha => new Request(new URL('__sha256/' + sha, scope));

async function loadBundle() {
  const response = await fetch(new URL('BUNDLE.json', scope), {cache: 'no-cache'});
  if (!response.ok) throw new Error('Published bundle manifest unavailable');
  const files = new Map();
  for (const [path, row] of Object.entries((await response.json())?.files || {}))
    if (/^[0-9a-f]{64}$/.test(row?.sha256 || '')) files.set(path, row.sha256);
  return files;
}
async function prune(files) {
  // Keep only bytes the current build still names.
  const wanted = new Set(files.values());
  const cache = await caches.open(CACHE);
  for (const request of await cache.keys()) {
    const sha = new URL(request.url).pathname.split('/').pop();
    if (!wanted.has(sha)) await cache.delete(request);
  }
}
function currentBundle(refresh) {
  if (refresh || !bundle) {
    const pending = loadBundle();
    bundle = pending;
    pending.catch(() => { if (bundle === pending) bundle = undefined; });
  }
  return bundle;
}

async function serve(event) {
  const request = event.request;
  if (request.mode === 'navigate') {
    // Each page load revalidates the manifest that pins every subresource.
    event.waitUntil(currentBundle(true).then(prune).catch(() => {}));
    return isolate(await fetch(request));
  }
  const url = new URL(request.url);
  const path = url.pathname.startsWith(scope.pathname) ? decodeURIComponent(url.pathname.slice(scope.pathname.length)) : '';
  let sha;
  if (request.method === 'GET' && !url.search && !request.headers.has('range') && path) {
    try { sha = (await currentBundle(false)).get(path); } catch { /* Fall back to revalidation. */ }
  }
  if (!sha) return isolate(await fetch(request, request.method === 'GET' ? {cache: 'no-cache'} : undefined));
  let cache;
  try { cache = await caches.open(CACHE); } catch { /* Storage may be disabled. */ }
  const hit = await cache?.match(cacheKey(sha)).catch(() => undefined);
  if (hit) return isolate(hit);
  const response = await fetch(request, {cache: 'no-cache'});
  if (!response.ok || !response.body || !cache) return isolate(response);
  // Stream to the page as bytes arrive; the second branch is hashed and kept
  // only once complete, so a slow part still shows progress.
  const [page, copy] = response.body.tee();
  const type = response.headers.get('Content-Type') || 'application/octet-stream';
  event.waitUntil(keep(cache, sha, copy, type).catch(() => {}));
  return isolate(new Response(page, {status: response.status, statusText: response.statusText, headers: response.headers}));
}

async function keep(cache, sha, stream, type) {
  const reader = stream.getReader(), chunks = [];
  let size = 0;
  for (;;) {
    const {done, value} = await reader.read();
    if (done) break;
    chunks.push(value); size += value.byteLength;
  }
  const body = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
  chunks.length = 0;
  // A file from a different build (a deploy mid-load) is served but never kept.
  if (hex(await crypto.subtle.digest('SHA-256', body)) !== sha) return;
  await cache.put(cacheKey(sha), new Response(body, {headers: {'Content-Type': type}}));
}

self.addEventListener('fetch', event => {
  if (new URL(event.request.url).origin !== self.location.origin) return;
  event.respondWith(serve(event));
});
