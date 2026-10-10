// Browser-side copy of the bounded type-2 resource reader in
// tools/inspect_scenarios.py. Input is the manifest-verified visitor's game.
// The resulting pixels stay in memory and are never fetched from the site.
const word = (bytes, at) => bytes[at] | bytes[at + 1] << 8;

export function decodeResource(bytes) {
  if (bytes.length < 5 || bytes[0] !== 2) throw new Error('Unsupported original resource header');
  const expected = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(1, true);
  if (expected > 16 * 1024 * 1024) throw new Error('Original resource exceeds safety bound');
  const payload = bytes.subarray(5), output = new Uint8Array(expected);
  let dictionary = Array.from({length: 256}, (_, n) => Uint8Array.of(n));
  let nextCode = 257, width = 9, bitpos = 0, blockStart = 0, previous = null, written = 0;
  while (written < expected) {
    if (bitpos + width > payload.length * 8) throw new Error('Truncated original resource');
    const at = bitpos >>> 3;
    const bits = payload[at] | (payload[at + 1] || 0) << 8 | (payload[at + 2] || 0) << 16;
    const code = bits >>> (bitpos & 7) & ((1 << width) - 1);
    bitpos += width;
    if (code === 256) {
      const blockBits = 8 * width;
      bitpos = blockStart + Math.ceil((bitpos - blockStart) / blockBits) * blockBits;
      blockStart = bitpos;
      dictionary = Array.from({length: 256}, (_, n) => Uint8Array.of(n));
      nextCode = 257; width = 9; previous = null;
      continue;
    }
    let entry = dictionary[code];
    if (!entry && code === nextCode && previous) {
      entry = new Uint8Array(previous.length + 1);
      entry.set(previous); entry[previous.length] = previous[0];
    }
    if (!entry || written + entry.length > expected) throw new Error('Invalid original resource code');
    output.set(entry, written); written += entry.length;
    if (previous && nextCode < 4096) {
      const extension = new Uint8Array(previous.length + 1);
      extension.set(previous); extension[previous.length] = entry[0];
      dictionary[nextCode++] = extension;
    }
    previous = entry;
    if (nextCode === 1 << width && width < 12) { width++; blockStart = bitpos; }
  }
  if (payload.length * 8 - bitpos > 7) throw new Error('Original resource has an unsupported tail');
  return output;
}

function splitNibbles(packed) {
  const pixels = new Uint8Array(packed.length * 2);
  for (let i = 0; i < packed.length; i++) {
    pixels[i * 2] = packed[i] >>> 4;
    pixels[i * 2 + 1] = packed[i] & 15;
  }
  return pixels;
}

export function buildClaimCatalog(originals) {
  const plates = [];
  for (const name of ['GPS.BIN', 'TC.BIN', 'AA.BIN', 'DRIVER.BIN', 'ATBASE.BIN']) {
    const source = originals.get(name);
    if (!source) throw new Error(`Missing source plate: ${name}`);
    const pixels = splitNibbles(decodeResource(source));
    if (pixels.length !== 64000) throw new Error(`Invalid source plate: ${name}`);
    plates.push(pixels);
  }
  const strutSource = originals.get('STRUTS.BMP');
  if (!strutSource) throw new Error('Missing original strut bitmaps');
  const decoded = decodeResource(strutSource);
  if (decoded.length < 2) throw new Error('Truncated original strut directory');
  const count = word(decoded, 0);
  if (count < 1 || count > 256 || decoded.length < 2 + count * 4)
    throw new Error('Invalid original strut directory');
  const parts = [Uint8Array.of(65, 66, 67, 76, 1, 0, count & 255, count >>> 8), ...plates];
  let at = 2 + count * 4;
  for (let index = 0; index < count; index++) {
    const halfWidth = word(decoded, 2 + index * 2);
    const height = word(decoded, 2 + count * 2 + index * 2);
    if (!halfWidth || halfWidth > 160 || !height || height > 200)
      throw new Error('Unsupported original strut dimensions');
    const size = halfWidth * height;
    if (at + size > decoded.length) throw new Error('Truncated original strut pixels');
    parts.push(Uint8Array.of((halfWidth * 2) & 255, halfWidth >>> 7, height & 255, height >>> 8));
    parts.push(splitNibbles(decoded.subarray(at, at + size)));
    at += size;
  }
  if (at !== decoded.length) throw new Error('Original strut resource has trailing data');
  const length = parts.reduce((sum, part) => sum + part.length, 0);
  if (length > 1024 * 1024) throw new Error('Original claim catalog exceeds Web bound');
  const result = new Uint8Array(length);
  let cursor = 0;
  for (const part of parts) { result.set(part, cursor); cursor += part.length; }
  return result;
}
