// Install the locally staged authored pack into Godot's virtual filesystem.
// The original GAME files are separately supplied and verified by the visitor.
import {sha256} from './zip_store.mjs';

export async function installRemasterAssets(engine, progress = () => {}) {
  const catalogResponse = await fetch('./.generated/remaster-assets.json');
  if (!catalogResponse.ok)
    throw new Error('The authored Web presentation pack is missing');
  const catalog = await catalogResponse.json();
  if (catalog.schema !== 2 || !Array.isArray(catalog.parts) || !catalog.parts.length)
    throw new Error('Unsupported authored Web presentation manifest');
  const expected = new Map(catalog.files.map(row => [row.path, row]));
  if (expected.size !== catalog.files.length) throw new Error('Repeated authored asset path');
  const decoder = new TextDecoder('utf-8', {fatal: true});
  let count = 0;
  for (const part of catalog.parts) {
    if (!/^remaster-assets-\d{2}\.zip$/.test(part.name))
      throw new Error('Invalid authored Web presentation part');
    const response = await fetch('./.generated/' + part.name);
    if (!response.ok) throw new Error('An authored Web presentation part is missing');
    const archive = new Uint8Array(await response.arrayBuffer());
    if (archive.byteLength !== part.bytes || await sha256(archive) !== part.sha256)
      throw new Error('An authored Web presentation part differs from its manifest');
    const view = new DataView(archive.buffer, archive.byteOffset, archive.byteLength);
    let at = 0;
    while (at + 4 <= archive.length && view.getUint32(at, true) === 0x04034b50) {
      if (at + 30 > archive.length) throw new Error('Truncated authored asset record');
      const flags = view.getUint16(at + 6, true);
      const method = view.getUint16(at + 8, true);
      const compressed = view.getUint32(at + 18, true);
      const expanded = view.getUint32(at + 22, true);
      const nameSize = view.getUint16(at + 26, true);
      const extraSize = view.getUint16(at + 28, true);
      if (flags & 8 || method !== 0 || compressed !== expanded)
        throw new Error('Unsupported authored asset archive entry');
      const start = at + 30 + nameSize + extraSize;
      const end = start + compressed;
      if (end > archive.length) throw new Error('Truncated authored asset');
      const path = decoder.decode(archive.subarray(at + 30, at + 30 + nameSize));
      if (!path || path.startsWith('/') || path.includes('..') || path.includes('\\') ||
          !expected.has(path) || expected.get(path).bytes !== compressed)
        throw new Error('Unexpected authored asset path');
      engine.copyToFS('/' + path, archive.subarray(start, end));
      expected.delete(path);
      count++;
      if (count % 32 === 0) progress(count, catalog.files.length);
      at = end;
    }
  }
  if (expected.size || count !== catalog.files.length)
    throw new Error('The authored Web presentation pack is incomplete');
  return count;
}
