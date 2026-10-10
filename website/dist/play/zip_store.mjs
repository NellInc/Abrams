// Recreate tools/package_setup.py's exact, uncompressed original-game ZIP.
// Source files are read by the browser and never sent to a server.
import { buildClaimCatalog } from './claim_catalog.mjs';
const text = new TextEncoder();
const DOS_TIME = (22 << 11) | (55 << 5) | (24 >> 1);
const DOS_DATE = ((2026 - 1980) << 9) | (9 << 5) | 26;
const CONFIG = '[dosbox]\nmachine=ega\nmemsize=16\n[cpu]\ncore=normal\ncputype=386\ncycles=fixed 3000\n[autoexec]\n@echo off\nc:\nABRAMS.COM EGA\n';
const CONTENT_SHA = 'c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05';

const crcTable = Uint32Array.from({ length: 256 }, (_, index) => {
  let value = index;
  for (let bit = 0; bit < 8; bit++) value = (value >>> 1) ^ (value & 1 ? 0xedb88320 : 0);
  return value >>> 0;
});

function crc32(bytes) {
  let result = 0xffffffff;
  for (const byte of bytes) result = crcTable[(result ^ byte) & 255] ^ (result >>> 8);
  return (result ^ 0xffffffff) >>> 0;
}

export function sha256(bytes) {
  return crypto.subtle.digest('SHA-256', bytes).then(digest =>
    Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join(''));
}

export function buildStoredZip(entries) {
  if (entries.length > 65535) throw new Error('Too many ZIP entries');
  const locals = [], central = [];
  let offset = 0;
  for (const [name, raw] of entries) {
    const filename = text.encode(name);
    const data = raw instanceof Uint8Array ? raw : new Uint8Array(raw);
    if (!filename.length || filename.length > 65535 || data.length > 0xffffffff)
      throw new Error('Invalid ZIP entry');
    const checksum = crc32(data);
    const local = new Uint8Array(30 + filename.length);
    const l = new DataView(local.buffer);
    l.setUint32(0, 0x04034b50, true);
    l.setUint16(4, 20, true);
    l.setUint16(10, DOS_TIME, true);
    l.setUint16(12, DOS_DATE, true);
    l.setUint32(14, checksum, true);
    l.setUint32(18, data.length, true);
    l.setUint32(22, data.length, true);
    l.setUint16(26, filename.length, true);
    local.set(filename, 30);
    locals.push(local, data);

    const record = new Uint8Array(46 + filename.length);
    const c = new DataView(record.buffer);
    c.setUint32(0, 0x02014b50, true);
    c.setUint16(4, (3 << 8) | 20, true);
    c.setUint16(6, 20, true);
    c.setUint16(12, DOS_TIME, true);
    c.setUint16(14, DOS_DATE, true);
    c.setUint32(16, checksum, true);
    c.setUint32(20, data.length, true);
    c.setUint32(24, data.length, true);
    c.setUint16(28, filename.length, true);
    c.setUint32(38, 0o600 << 16, true);
    c.setUint32(42, offset, true);
    record.set(filename, 46);
    central.push(record);
    offset += local.length + data.length;
    if (offset > 0xffffffff) throw new Error('ZIP is too large');
  }
  const centralSize = central.reduce((sum, part) => sum + part.length, 0);
  const end = new Uint8Array(22);
  const e = new DataView(end.buffer);
  e.setUint32(0, 0x06054b50, true);
  e.setUint16(8, entries.length, true);
  e.setUint16(10, entries.length, true);
  e.setUint32(12, centralSize, true);
  e.setUint32(16, offset, true);
  const zip = new Uint8Array(offset + centralSize + end.length);
  let cursor = 0;
  for (const part of [...locals, ...central, end]) {
    zip.set(part, cursor);
    cursor += part.length;
  }
  return zip;
}

export async function packOriginals(files, manifest) {
  const selected = new Map();
  for (const file of files) {
    const path = file.webkitRelativePath || file.name;
    const parts = path.split('/');
    if (parts.length > 2 || parts.some(part => !part || part === '.' || part === '..')) continue;
    const name = parts.at(-1).toUpperCase();
    if (selected.has(name)) throw new Error(`Ambiguous original filename: ${name}`);
    selected.set(name, file);
  }
  const entries = [];
  const originalBytes = new Map();
  for (const record of manifest.files) {
    const file = selected.get(record.name.toUpperCase());
    if (!file) throw new Error(`Missing original PC file: ${record.name}`);
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (await sha256(bytes) !== record.sha256)
      throw new Error(`Unsupported or changed original PC file: ${record.name}`);
    entries.push([record.name, bytes]);
    originalBytes.set(record.name.toUpperCase(), bytes);
  }
  entries.push(['dosbox.conf', text.encode(CONFIG)]);
  const zip = buildStoredZip(entries);
  if (await sha256(zip) !== CONTENT_SHA)
    throw new Error('Original-game ZIP did not match the pinned content');
  return { zip, catalog: buildClaimCatalog(originalBytes), originalBytes };
}
