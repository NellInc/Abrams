// Install the locally staged authored pack into Godot's virtual filesystem.
// Entire verified part hashes authenticate payloads; no redundant file hashing.
import {sha256} from './zip_store.mjs';

const MAX_PART_BYTES = 48_000_000; // Same bound as build_remaster_assets.py.
const validBytes = value => Number.isSafeInteger(value) && value >= 0 && value <= MAX_PART_BYTES;
const validHash = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const safePath = path => typeof path === 'string' && path.length <= 1024 &&
  /^[A-Za-z0-9_.\/-]+$/.test(path) &&
  path.split('/').every(segment => segment && segment !== '.' && segment !== '..') &&
  !/^(GAME|GENESIS)\//i.test(path);

export async function installRemasterAssets(engine, progress = () => {}, {signal} = {}) {
  const checkAbort = () => signal?.throwIfAborted();
  checkAbort();
  const catalogResponse = await fetch('./.generated/remaster-assets.json', {signal});
  if (!catalogResponse.ok)
    throw new Error('The authored Web presentation pack is missing');
  const catalog = await catalogResponse.json();
  if (!catalog || catalog.schema !== 2 || !Array.isArray(catalog.parts) ||
      !catalog.parts.length || catalog.parts.length > 100 || !Array.isArray(catalog.files) ||
      !catalog.files.length || catalog.files.length > 10000)
    throw new Error('Unsupported authored Web presentation manifest');
  const partNames = new Set();
  for (const part of catalog.parts) {
    if (!part || !/^remaster-assets-\d{2}\.zip$/.test(part.name) ||
        partNames.has(part.name) || !validBytes(part.bytes) || part.bytes < 22 || !validHash(part.sha256))
      throw new Error('Invalid authored Web presentation part');
    partNames.add(part.name);
  }
  const expected = new Map();
  let payloadBytes = 0;
  for (const row of catalog.files) {
    if (!row || !safePath(row.path) || !validBytes(row.bytes) || !validHash(row.sha256))
      throw new Error('Invalid authored asset manifest entry');
    if (expected.has(row.path)) throw new Error('Repeated authored asset path');
    expected.set(row.path, row);
    payloadBytes += row.bytes;
  }
  if (payloadBytes > catalog.parts.reduce((total, part) => total + part.bytes, 0))
    throw new Error('Authored asset manifest exceeds its archive parts');
  const decoder = new TextDecoder('utf-8', {fatal: true});
  let count = 0;
  for (const part of catalog.parts) {
    checkAbort();
    const response = await fetch('./.generated/' + part.name, {signal});
    if (!response.ok) throw new Error('An authored Web presentation part is missing');
    const length = response.headers?.get('content-encoding') ? null : response.headers?.get('content-length');
    if (length !== null && length !== undefined && Number(length) !== part.bytes)
      throw new Error('An authored Web presentation part has the wrong size');
    const archive = new Uint8Array(await response.arrayBuffer());
    checkAbort();
    if (archive.byteLength !== part.bytes || await sha256(archive) !== part.sha256)
      throw new Error('An authored Web presentation part differs from its manifest');
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
      if ((flags & ~0x800) || method !== 0 || compressed !== expanded)
        throw new Error('Unsupported authored asset archive entry');
      const start = at + 30 + nameSize + extraSize, end = start + compressed;
      if (!fits(at + 30, nameSize + extraSize) || !fits(start, compressed))
        throw new Error('Truncated authored asset');
      const path = decoder.decode(archive.subarray(at + 30, at + 30 + nameSize));
      if (!safePath(path) || seen.has(path) || !expected.has(path) || expected.get(path).bytes !== compressed)
        throw new Error('Unexpected authored asset path');
      seen.add(path);
      records.push({path, offset: at, start, end, flags, crc: view.getUint32(at + 14, true)});
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
          view.getUint16(at + 10, true) !== 0 || view.getUint32(at + 16, true) !== record.crc ||
          view.getUint32(at + 20, true) !== record.end - record.start ||
          view.getUint32(at + 24, true) !== record.end - record.start ||
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
      engine.copyToFS('/' + record.path, archive.subarray(record.start, record.end));
      expected.delete(record.path);
      count++;
      if (count % 32 === 0) progress(count, catalog.files.length);
    }
  }
  if (expected.size || count !== catalog.files.length)
    throw new Error('The authored Web presentation pack is incomplete');
  progress(count, catalog.files.length);
  return count;
}
