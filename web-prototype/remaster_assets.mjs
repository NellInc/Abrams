// Install the locally staged authored pack into Godot's virtual filesystem.
// Entire verified part hashes authenticate payloads; inflated members are
// also checked against their recorded size and CRC-32.
import {crc32, sha256} from './zip_store.mjs';
import {GENESIS_DERIVED, PC_DERIVED} from './derived_art.mjs';

const MAX_PART_BYTES = 48_000_000; // Same bound as build_remaster_assets.py.
const ROSTER_CATALOG = 'local-art/pc-tactical-roster-v1/catalog.json';
const MAX_ROSTER_CATALOG_BYTES = 96 * 1024 * 1024; // Existing native catalogue bound.
const memberLimit = path => path === ROSTER_CATALOG ? MAX_ROSTER_CATALOG_BYTES : MAX_PART_BYTES;
const SETS = new Set(['common', 'genesis']);
// The browser derives these from the visitor's originals; the site never may.
const DERIVED = new Set([...PC_DERIVED, ...GENESIS_DERIVED]);
const validBytes = value => Number.isSafeInteger(value) && value >= 0 && value <= MAX_PART_BYTES;
const validHash = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const safePath = path => typeof path === 'string' && path.length <= 1024 &&
  /^[A-Za-z0-9_.\/-]+$/.test(path) &&
  path.split('/').every(segment => segment && segment !== '.' && segment !== '..') &&
  !/^(GAME|GENESIS)\//i.test(path);

// Stream one part, failing after `idleMs` without progress rather than after
// a fixed deadline, so slow but working connections still finish.
async function download(url, size, {signal, idleMs, onBytes}) {
  const controller = new AbortController();
  const forward = () => controller.abort(signal.reason);
  signal?.addEventListener('abort', forward, {once: true});
  let timer, stalled = false;
  const arm = () => {
    clearTimeout(timer);
    timer = setTimeout(() => { stalled = true; controller.abort(new Error('stalled')); }, idleMs);
  };
  // Settle a pending read on abort even if the body ignores the signal.
  const aborted = new Promise((_, reject) => controller.signal.addEventListener('abort',
    () => reject(controller.signal.reason), {once: true}));
  aborted.catch(() => {});
  try {
    arm();
    const response = await Promise.race([fetch(url, {signal: controller.signal}), aborted]);
    if (!response.ok) throw new Error('An authored Web presentation part is missing');
    const length = response.headers?.get('content-encoding') ? null : response.headers?.get('content-length');
    if (length !== null && length !== undefined && Number(length) !== size)
      throw new Error('An authored Web presentation part has the wrong size');
    const reader = response.body?.getReader?.();
    if (!reader) {
      const whole = new Uint8Array(await Promise.race([response.arrayBuffer(), aborted]));
      onBytes(whole.length);
      return whole;
    }
    controller.signal.addEventListener('abort', () => reader.cancel?.().catch?.(() => {}), {once: true});
    const archive = new Uint8Array(size);
    let received = 0;
    for (;;) {
      const {done, value} = await Promise.race([reader.read(), aborted]);
      if (done) break;
      if (received + value.length > size) throw new Error('An authored Web presentation part has the wrong size');
      archive.set(value, received);
      received += value.length;
      onBytes(received);
      arm();
    }
    return received === size ? archive : archive.subarray(0, received);
  } catch (error) {
    if (stalled && !signal?.aborted)
      throw new Error('The remaster artwork download stopped making progress. Check your connection, then reload to retry.', {cause: error});
    throw error;
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener('abort', forward);
  }
}

async function inflate(bytes, expanded) {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
  const result = new Uint8Array(expanded), reader = stream.getReader();
  let used = 0;
  for (;;) {
    const {done, value} = await reader.read();
    if (done) break;
    if (used + value.length > expanded) {
      await reader.cancel();
      throw new Error('An authored asset inflated to the wrong size');
    }
    result.set(value, used); used += value.length;
  }
  if (used !== expanded) throw new Error('An authored asset inflated to the wrong size');
  return result;
}

export async function installRemasterAssets(engine, progress = () => {},
                                            {signal, sets = ['common'], idleMs = 60000} = {}) {
  const checkAbort = () => signal?.throwIfAborted();
  const wanted = new Set(sets);
  if (!wanted.has('common') || [...wanted].some(name => !SETS.has(name)))
    throw new Error('Unsupported authored Web presentation set');
  checkAbort();
  // Revalidate the small catalog so it never pairs with parts from another build.
  const catalogResponse = await fetch('./.generated/remaster-assets.json', {signal, cache: 'no-cache'});
  if (!catalogResponse.ok)
    throw new Error('The authored Web presentation pack is missing');
  const catalog = await catalogResponse.json();
  if (!catalog || catalog.schema !== 3 || !Array.isArray(catalog.parts) ||
      !catalog.parts.length || catalog.parts.length > 100 || !Array.isArray(catalog.files) ||
      !catalog.files.length || catalog.files.length > 10000)
    throw new Error('Unsupported authored Web presentation manifest');
  const partNames = new Set();
  for (const part of catalog.parts) {
    if (!part || !/^remaster-assets-\d{2}\.zip$/.test(part.name) || !SETS.has(part.set) ||
        partNames.has(part.name) || !validBytes(part.bytes) || part.bytes < 22 || !validHash(part.sha256))
      throw new Error('Invalid authored Web presentation part');
    partNames.add(part.name);
  }
  const expected = new Map();
  const seenPaths = new Set();
  let payloadBytes = 0;
  for (const row of catalog.files) {
    if (!row || !safePath(row.path) || !Number.isSafeInteger(row.bytes) || row.bytes < 0 || row.bytes > memberLimit(row.path) || !validHash(row.sha256) || !SETS.has(row.set))
      throw new Error('Invalid authored asset manifest entry');
    if (DERIVED.has(row.path)) throw new Error('The authored pack must not carry original-derived data');
    if (seenPaths.has(row.path)) throw new Error('Repeated authored asset path');
    seenPaths.add(row.path);
    if (wanted.has(row.set)) { expected.set(row.path, row); payloadBytes += row.bytes; }
  }
  const parts = catalog.parts.filter(part => wanted.has(part.set));
  const archiveBytes = parts.reduce((total, part) => total + part.bytes, 0);
  // Exactly one authenticated roster member can expand to the native96MiB cap.
  // Every other member and every downloaded archive retain the48MB bound.
  const roster = expected.get(ROSTER_CATALOG);
  const rosterExpansion = roster ? Math.max(0, roster.bytes - MAX_PART_BYTES) : 0;
  if (payloadBytes > parts.length * MAX_PART_BYTES + rosterExpansion)
    throw new Error('Authored asset manifest exceeds its archive parts');
  const totalFiles = expected.size;
  const decoder = new TextDecoder('utf-8', {fatal: true});
  let count = 0, done = 0;
  for (const part of parts) {
    checkAbort();
    const archive = await download('./.generated/' + part.name, part.bytes, {signal, idleMs,
      onBytes: received => progress(count, totalFiles, done + received, archiveBytes)});
    checkAbort();
    if (archive.byteLength !== part.bytes || await sha256(archive) !== part.sha256)
      throw new Error('An authored Web presentation part differs from its manifest');
    done += part.bytes;
    checkAbort();
    const view = new DataView(archive.buffer, archive.byteOffset, archive.byteLength);
    const records = [], seen = new Set();
    const fits = (at, length) => at >= 0 && at + length <= archive.length;
    let at = 0;
    while (fits(at, 4) && view.getUint32(at, true) === 0x04034b50) {
      if (!fits(at, 30)) throw new Error('Truncated authored asset record');
      const flags = view.getUint16(at + 6, true), method = view.getUint16(at + 8, true);
      const compressed = view.getUint32(at + 18, true), expanded = view.getUint32(at + 22, true);
      const nameSize = view.getUint16(at + 26, true), extraSize = view.getUint16(at + 28, true);
      // Only UTF-8 names may be flagged; encryption and descriptors are unsupported.
      if ((flags & ~0x800) || (method !== 0 && method !== 8) || (method === 0 && compressed !== expanded))
        throw new Error('Unsupported authored asset archive entry');
      const start = at + 30 + nameSize + extraSize, end = start + compressed;
      if (!fits(at + 30, nameSize + extraSize) || !fits(start, compressed))
        throw new Error('Truncated authored asset');
      const path = decoder.decode(archive.subarray(at + 30, at + 30 + nameSize));
      const row = expected.get(path);
      if (!safePath(path) || seen.has(path) || !row || row.set !== part.set || row.bytes !== expanded)
        throw new Error('Unexpected authored asset path');
      seen.add(path);
      records.push({path, offset: at, start, end, flags, method, expanded, crc: view.getUint32(at + 14, true)});
      at = end;
    }
    // Check the central directory and end record as well as payload records.
    const centralStart = at;
    for (const record of records) {
      if (!fits(at, 46) || view.getUint32(at, true) !== 0x02014b50)
        throw new Error('Truncated authored asset directory');
      const nameSize = view.getUint16(at + 28, true);
      const length = 46 + nameSize + view.getUint16(at + 30, true) + view.getUint16(at + 32, true);
      if (!fits(at, length) || view.getUint16(at + 8, true) !== record.flags ||
          view.getUint16(at + 10, true) !== record.method || view.getUint32(at + 16, true) !== record.crc ||
          view.getUint32(at + 20, true) !== record.end - record.start ||
          view.getUint32(at + 24, true) !== record.expanded ||
          view.getUint16(at + 34, true) !== 0 || view.getUint32(at + 42, true) !== record.offset ||
          decoder.decode(archive.subarray(at + 46, at + 46 + nameSize)) !== record.path)
        throw new Error('Invalid authored asset directory');
      at += length;
    }
    if (!records.length || !fits(at, 22) || view.getUint32(at, true) !== 0x06054b50 ||
        view.getUint16(at + 4, true) !== 0 || view.getUint16(at + 6, true) !== 0 ||
        view.getUint16(at + 8, true) !== records.length || view.getUint16(at + 10, true) !== records.length ||
        view.getUint32(at + 12, true) !== at - centralStart || view.getUint32(at + 16, true) !== centralStart ||
        at + 22 + view.getUint16(at + 20, true) !== archive.length)
      throw new Error('Invalid authored asset archive completion');
    for (const record of records) {
      checkAbort();
      let payload = archive.subarray(record.start, record.end);
      if (record.method === 8) {
        payload = await inflate(payload, record.expanded);
        if (crc32(payload) !== record.crc) throw new Error('An authored asset failed its CRC check');
      }
      engine.copyToFS('/' + record.path, payload);
      expected.delete(record.path);
      count++;
      if (count % 32 === 0) progress(count, totalFiles, done, archiveBytes);
    }
  }
  if (expected.size || count !== totalFiles)
    throw new Error('The authored Web presentation pack is incomplete');
  progress(count, totalFiles, done, archiveBytes);
  return count;
}
