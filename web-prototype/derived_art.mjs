// Recognition data decoded in the visitor's browser from verified originals.
// The site never serves these decodes. Each path matches the desktop layout
// Godot already reads. JSON bytes equal the desktop builders' json.dumps(...,
// indent=2) output (source-shapes.json: the compact registry_bytes() form); plate PNGs carry the same RGB pixels, and Godot verifies
// decoded pixels for those because PNG compression differs between encoders.
// Working if: test_derived_art.mjs reproduces every local desktop decode.
import {decodeResource} from './claim_catalog.mjs';
import {crc32, sha256} from './zip_store.mjs';

// The observed SIM/START EGA palette, as recorded by the desktop extractors.
const PALETTE = [[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
  [170,0,0],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],[255,85,85],[0,0,170],
  [85,255,255],[255,255,255]];
const SOURCES = {
  'ATBASE.BIN': '7a2b2e763b37623f423c7f332c2a34d4bb810f5a457a3d8f55aec27e9262ac03',
  'CLIP.BMP': '496e4349840d934c42da24fc929b25869a0db050dd6a66ac68a9349af6b7e6ce',
  'FACES.BMP': 'e769b71bee8a40023e6ffdb3ac0fd5db0a7485148c1d2eb3fd4fe3b1da6ffa42',
  'SHAPE.TBL': '81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193',
};
// tools/extract_pc_ui.py names; Godot reads these five station plates.
const UI_PLATES = [['GPS.BIN', 'gps-bin'], ['TC.BIN', 'tc-bin'], ['AA.BIN', 'aa-bin'],
  ['DRIVER.BIN', 'driver-bin'], ['STATUS.BIN', 'status-bin']];
// tools/build_pc_graphics_catalog.py PLATES order for the stacked expected.png.
const EXPECTED_PLATES = ['GPS.BIN', 'TC.BIN', 'AA.BIN', 'DRIVER.BIN', 'STATUS.BIN', 'ATBASE.BIN'];
export const PC_DERIVED = Object.freeze([
  ...UI_PLATES.map(([, name]) => `local-art/pc-ui-v2/${name}.png`),
  'local-art/pc-graphics-native-v1/expected.png',
  'local-art/pc-portraits-v1/faces.json',
  'local-art/pc-motor-pool-v1/motor-pool.json',
  'local-art/pc-arming-panel-v1/arming-panel.json',
  'local-art/pc-modern/source-shapes.json',
]);
export const GENESIS_DERIVED = Object.freeze(['local-art/genesis/source/effects-v1/effects.json']);

const GENESIS_ROM = 'ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea';
const EFFECT_TABLE = 0x431be, EFFECT_COUNT = 64, EFFECT_DATA = 0x3c09e;
// [Inference] The 16 CRAM words at ROM 0x3e3c reproduce the effects-fire-01
// bank-3 capture exactly; the decoded file pin in pc_effect_art.gd proves it.
const EFFECT_PALETTE = 0x3e3c;
// Provenance fields of tools/extract_genesis_effects.py's desktop output.
// They are metadata (paths, offsets, hashes), never pixels.
const EFFECT_FIELDS = {
  source: 'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md',
  palette_capture: 'reference/genesis/effects-fire-01/f0024',
  palette_receipt_sha256: '77d9f63393a1e8bb6f1341a39b41b7c8af8fcdff23418c8cb3485e63cb554631',
  palette_bank: 3,
  scope: 'Native ROM pixels and explicit masks. Palette bank is an explicit extraction choice; native appearance requires separate visible-frame verification. No animation-timing or distribution claim.',
  files: {"contact-sheet.png":"6b0d1117fadf88a7a7a10b6f5b2c7abf081ec67a0f5947e013cf0b87c6d962a8","effect-00.png":"41c169fc898e9b4d9a25aaaf21b6df7e01ae7e2fbf74826b509cabe3263c21ea","effect-01.png":"a4558e51e590fc5682492a562f37a5ca54ba30258d5e327223247b71e88db58e","effect-02.png":"50eaa023f5eaa90019131e12b6ac3c06ee8c9dda52b187048672218ad615553e","effect-03.png":"cbb9e91f6d6b3715dab43a8ab0cfdcd6b28a1747a3ebea26da74a1fc33df2e40","effect-04.png":"2f81f7d10a697db565f45cc64a9605ed1481ab8602f6fd49f15132f1d39c1794","effect-05.png":"d6d3acd71dfe0e8d797d29fa8933a9b4d73eb419a0ebe397ba4ed181ec194065","effect-06.png":"f03f6cbda7c5e269a1e0cf82a4d49b3a4a30ecd47df6f35549cfa8541f9f410e","effect-07.png":"a09902429c2f14ceb26e113a0c1038558144f96985319b3ed4d215f9d6271fad","effect-08.png":"09178c3800ec5fdbd0bb0d8d817967603c31cbe43bb9eec0aaccc426f410feba","effect-09.png":"69942135ef8bb84fe78f77d110900e68454bd78bc29a4128d65e408a3511558d","effect-10.png":"8b60373d209ccdf18724ba137338fcd42679af9cc8eb42c107b4cfdcca701bbb","effect-11.png":"f3f72ff8d5244bf9291364b5b3b4edaf2db677af11becc523e1feed2d3245267","effect-12.png":"4eb1e4b63d9fb07e175505e9b26eda530c917ba904415630304ef8ac46a77021","effect-13.png":"79c7bfb8d28070ef770a0a9312d8229799cb66bf68bbbd318ef74dc6f2a85886","effect-14.png":"78b97b925d8738487661f4659460702d04325561d6613957059eaa5dcf725932","effect-15.png":"7ed7a2649f81028ecefa87d62e9ca7a0e4dafd7549cb1566e9478f81519f3dd3","effect-16.png":"9fd2240fd1d917857e9575cd67f0de13c805663bae526f874dc8054a87dee3f7","effect-17.png":"57c32962cf6a371d22552c0102b392901d8ca51e3b5c2ce4ba00b0c26c2812c3","effect-18.png":"8b6ce982ff8ca3e896e622ad96ba145bf525ab734322bd382b5bbd61721e6168","effect-19.png":"31904be760c1f8c55487b6a7dee27c2065af7423084840156f7972330b5d0287","effect-20.png":"a317ad114ffdf2905736bd3addaa64eab3c8f31037e26f14ed1f6dc737810f42","effect-21.png":"cf4e557ae081562bc7d34e0819c226fdb15e1cfe88c4ffdc1ad4cd8c9461b16c","effect-22.png":"e6c5fb793f55838011552b63f19edd8e6486c0c74e1ed0f3d9e674f68206fa15","effect-23.png":"1d84aece2ade235b32787d1918be900ab910a5f6714ae505866797c75d473dd0","effect-24.png":"75ab87c38214c13ead2f0822680ace760cf8264688460513aa5a517e65d557cc","effect-25.png":"e17b846eb1224bd5e2d0cb90d59c4de6b8704db75b59fb6ce9318d280d613cbc","effect-26.png":"57e1f1194d5bb41e4f412f08b4a4d94bf344fcb822533cd52c2db4d1bdf1cb8a","effect-27.png":"32a57f2fa0b9015eb7cb250da3a54c54ee98c073ef5fc6941c732c392f2a1aee","effect-28.png":"553e1167a370f89324f0ce33f588dbdb04292e0b3648d94386f5420910cf8822","effect-29.png":"cdb0d14790726afac10cd242398ef5bbda2a97e1ecf08448057c23cd181d8cab","effect-30.png":"65faaa3f4cf7086dc391b7a8a2ce8f35f0848fa12bbcdb2593f7ef3421c97e35","effect-31.png":"babe5b4d76e2157bcfbd592eed76d6b365244b75e6342a024da6df17a47d8328","effect-32.png":"ccd75db4572006af0c4010ad0cc4a78477a96f0a4b1f0e487843f44cd66c4a48","effect-33.png":"865e85a60a249c3605903492399932e8efc4970e6e504058860a624f46353b16","effect-34.png":"93a7aaaa6721e5b94c559ae5252dc4b04c177ca0f4e4588945d222b388fe1867","effect-35.png":"2311315a34ddc6c5383e142d5541fa9a7372eb29b42982c96fd8dc8568429c5a","effect-36.png":"1683e5978ef0e06cc694baadff53aceb971c9b58f4d60efff72dd63f5c1f0b66","effect-37.png":"3fac57abdfcab93f22b132a320e6f48a3f619a5e90744012afc4bdc6b8517643","effect-38.png":"8d0a04c2dd67ae7a0db83dc8e38bf11cb8d70ab55e0cde25f1ddd3d5cc5fdcb2","effect-39.png":"e328cb421f3243541d2e73334677b072201c4ff60d7faf873a85ba7c6f758fba","effect-40.png":"a0564954e666622b61fd7fba51ce477dac9189a10758f8594859d0ac61d20f05","effect-41.png":"ec627b08512426f4b2fbb117634e236ee8e497176b914694176deb18dd5863d6","effect-42.png":"6b1b58969688ee9db44be7bca2563721b449f606e18b4a6af0f1eab685b39850","effect-43.png":"3b63b45c0f00eb35a05cddc1fa7fa9fe1a0da4053676efea4beee4cf2d17f17a","effect-44.png":"3ade0a088f21c6a196c7e861f6e728ee9e55369927c42070debced186b27b786","effect-45.png":"1a292a48a9551fe453c60c8f43d858bcaf12380df7e063e73a4f4d9b464a7ff8","effect-46.png":"1cf005a8543798f50f3fe2218f5a5d2b63844b99bbddbcecf8e22628b8ae39f8","effect-47.png":"034a31e02c9714886f9b9f199d6c6858eaeb360ae149c91ae2a54bc770655ba2","effect-48.png":"c5b179d5ee4345ef4dbdf068969d9dbba26bcce4ec875243f4374f6acc7270be","effect-49.png":"3f999944b3f88506066687b67797e637e78a35342413e630c109bacdcd1e37a0","effect-50.png":"7861d9f552a63de45bbd05bbdfd34e01da1f0d96aad8bd1fb2e48992abaa5cf1","effect-51.png":"4410969ad974e62508d79240e402bb596f6f7c0fbc38f420cd9f83ec20c9682e","effect-52.png":"912094839a3a303134a480ff4919736561baf64986589d44e5e12b12f814e80b","effect-53.png":"1ca8ff27eb04866710435894e05df9e35daa49adc615a7d4744080009a4d2252","effect-54.png":"c944185990b4c6957ac24c72533246dbd47ce5f966ec03c40ac38da07f5b1567","effect-55.png":"1266f942ce2564788b2805fe07d3c27f8f1973eac23de55b03516aa967fc9640","effect-56.png":"207da41d8144860708cca5b00b06b3257bdba55a99a6a94bdc96c25a6dde967f","effect-57.png":"261a6e9ed9d002f5c4d0ce2092c4f0f1e34379ac600e52682aad9427d59010bb","effect-58.png":"1b3a997377ef0c213def349703ef185cb79a0ef40609c1b6f574c6c9cc0b1929","effect-59.png":"600b057e14006240b7bb388900fde4617b14e9e4d6570867b61b026e6fd3a0e4","effect-60.png":"aa7ef2ff8918fdb206737708300790aa23d2e609d4b3734887ae798fe3af6b25","effect-61.png":"c57abcdd18a4e8a3f5c36b076a91c5df228c63bb7ddfef7ff45cbe789a22f9b3","effect-62.png":"36fd8ac3bbd2f6e5758206abc023a6df278a843a3a98951390d860bd50ad4123","effect-63.png":"040f53f0f6fdacf856ff24f2288ddeb0fc8d7e92cb7d449759e4ce24871ff8a7"},
};

const text = new TextEncoder();
// Python json.dumps(value, indent=2) plus newline, for these ASCII catalogs.
const pythonJson = value => text.encode(JSON.stringify(value, null, 2) + '\n');
const word = (bytes, at) => bytes[at] | bytes[at + 1] << 8;
const nibbles = packed => {
  const pixels = new Uint8Array(packed.length * 2);
  for (let i = 0; i < packed.length; i++) { pixels[2 * i] = packed[i] >>> 4; pixels[2 * i + 1] = packed[i] & 15; }
  return pixels;
};
function base64(bytes) {
  let binary = '';
  for (let at = 0; at < bytes.length; at += 0x8000)
    binary += String.fromCharCode(...bytes.subarray(at, at + 0x8000));
  return btoa(binary);
}

// tools/pc_bitmaps.decode_bitmaps over a decoded type-2 resource.
export function decodeBitmaps(data) {
  if (data.length < 2) throw new Error('Truncated original bitmap directory');
  const count = word(data, 0);
  if (count < 1 || count > 256 || data.length < 2 + count * 4) throw new Error('Invalid original bitmap directory');
  const result = [];
  let at = 2 + count * 4;
  for (let index = 0; index < count; index++) {
    const halfWidth = word(data, 2 + index * 2), height = word(data, 2 + count * 2 + index * 2);
    if (halfWidth < 1 || halfWidth > 160 || height < 1 || height > 200) throw new Error('Unsupported original bitmap dimensions');
    const end = at + halfWidth * height;
    if (end > data.length) throw new Error('Truncated original bitmap pixels');
    result.push({index, width: halfWidth * 2, height, pixels: [...nibbles(data.subarray(at, end))], offset: at});
    at = end;
  }
  if (at !== data.length) throw new Error('Unparsed original bitmap tail');
  return result;
}

// Deterministic 8-bit RGB PNG: unfiltered rows in stored zlib blocks. Godot
// compares decoded pixels, so no particular deflate implementation is needed.
export function encodeRgbPng(width, height, rgb) {
  if (!(width > 0 && height > 0) || rgb.length !== width * height * 3) throw new Error('Invalid derived image');
  const stride = width * 3 + 1, raw = new Uint8Array(stride * height);
  for (let y = 0; y < height; y++) raw.set(rgb.subarray(y * width * 3, (y + 1) * width * 3), y * stride + 1);
  const blocks = Math.max(1, Math.ceil(raw.length / 65535));
  const zlib = new Uint8Array(2 + raw.length + blocks * 5 + 4);
  zlib[0] = 0x78; zlib[1] = 0x01;
  let out = 2;
  for (let block = 0; block < blocks; block++) {
    const start = block * 65535, length = Math.min(65535, raw.length - start);
    zlib[out] = block === blocks - 1 ? 1 : 0;
    zlib[out + 1] = length & 255; zlib[out + 2] = length >>> 8;
    zlib[out + 3] = ~length & 255; zlib[out + 4] = (~length >>> 8) & 255;
    zlib.set(raw.subarray(start, start + length), out + 5);
    out += 5 + length;
  }
  let a = 1, b = 0;
  for (const byte of raw) { a = (a + byte) % 65521; b = (b + a) % 65521; }
  new DataView(zlib.buffer).setUint32(out, ((b << 16) | a) >>> 0);
  const chunk = (type, data) => {
    const result = new Uint8Array(12 + data.length), view = new DataView(result.buffer);
    view.setUint32(0, data.length);
    result.set(text.encode(type), 4); result.set(data, 8);
    view.setUint32(8 + data.length, crc32(result.subarray(4, 8 + data.length)));
    return result;
  };
  const header = new Uint8Array(13), view = new DataView(header.buffer);
  view.setUint32(0, width); view.setUint32(4, height);
  header[8] = 8; header[9] = 2; // 8-bit truecolour, no interlace.
  const parts = [Uint8Array.of(137, 80, 78, 71, 13, 10, 26, 10), chunk('IHDR', header),
    chunk('IDAT', zlib), chunk('IEND', new Uint8Array())];
  const png = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let cursor = 0;
  for (const part of parts) { png.set(part, cursor); cursor += part.length; }
  return png;
}

function plateIndices(originals, name) {
  const source = originals.get(name);
  if (!source) throw new Error(`Missing original plate: ${name}`);
  const packed = decodeResource(source);
  if (packed.length !== 32000) throw new Error(`Unsupported original plate: ${name}`);
  return nibbles(packed);
}
function paletteRgb(indices, target = new Uint8Array(indices.length * 3), at = 0) {
  for (let i = 0; i < indices.length; i++) target.set(PALETTE[indices[i]], at + i * 3);
  return target;
}
async function pinnedSource(originals, name) {
  const bytes = originals.get(name);
  if (!bytes || await sha256(bytes) !== SOURCES[name]) throw new Error(`Unsupported original ${name}`);
  return bytes;
}

// `originals` maps upper-case PC names to the visitor's verified bytes.
export async function derivePcArt(originals) {
  const files = new Map();
  for (const [name, file] of UI_PLATES)
    files.set(`local-art/pc-ui-v2/${file}.png`, encodeRgbPng(320, 200, paletteRgb(plateIndices(originals, name))));
  const stacked = new Uint8Array(320 * 1200 * 3);
  EXPECTED_PLATES.forEach((name, id) => paletteRgb(plateIndices(originals, name), stacked, id * 64000 * 3));
  files.set('local-art/pc-graphics-native-v1/expected.png', encodeRgbPng(320, 1200, stacked));
  const faces = decodeBitmaps(decodeResource(await pinnedSource(originals, 'FACES.BMP')));
  if (faces.map(face => `${face.width}x${face.height}`).join() !== '56x47,56x48,56x48,56x48')
    throw new Error('Unsupported original portrait set');
  files.set('local-art/pc-portraits-v1/faces.json', pythonJson({schema: 1, source: 'FACES.BMP',
    source_sha256: SOURCES['FACES.BMP'], palette_rgb: PALETTE, images: faces}));
  const motor = decodeResource(await pinnedSource(originals, 'ATBASE.BIN'));
  if (motor.length !== 32000) throw new Error('Unsupported motor-pool dimensions');
  files.set('local-art/pc-motor-pool-v1/motor-pool.json', pythonJson({schema: 1, source: 'ATBASE.BIN',
    source_sha256: SOURCES['ATBASE.BIN'], width: 320, height: 200, packed_indices_base64: base64(motor),
    scope: 'Original PC indices for recognition only. Genesis supplies replacement artwork.'}));
  const clip = decodeBitmaps(decodeResource(await pinnedSource(originals, 'CLIP.BMP')));
  if (clip.length !== 1 || clip[0].width !== 88 || clip[0].height !== 113) throw new Error('Unsupported clipboard geometry');
  files.set('local-art/pc-arming-panel-v1/arming-panel.json', pythonJson({schema: 1, source: 'CLIP.BMP',
    source_sha256: SOURCES['CLIP.BMP'], origin: [239, 87], width: 88, height: 113,
    indices_base64: base64(Uint8Array.from(clip[0].pixels)), preserved_pixels: [[312, 199]],
    scope: 'Original clipboard recognition only. Genesis menu supplies rendered panel style. One intermittently overwritten bottom pixel remains original.'}));
  files.set('local-art/pc-modern/source-shapes.json', shapeRegistry(await pinnedSource(originals, 'SHAPE.TBL')));
  if ([...files.keys()].join() !== PC_DERIVED.join()) throw new Error('Derived PC recognition set changed');
  return files;
}

// tools/inspect_shapes.inspect_shapes plus build_pc_modern_assets.source_registry
// and registry_bytes: the per-shape SHAPE.TBL structure catalog.json omits, as
// compact JSON byte-identical to the desktop decode. pc_modern_assets.gd joins
// it only under the SHA-256 that catalog.json pins.
export function shapeRegistry(source) {
  const data = decodeResource(source), view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const u16 = at => view.getUint16(at, true);
  const hex = bytes => Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join(' ');
  // inspect_scenarios.parse_shape_table
  if (data.length < 4) throw new Error('shape table truncated');
  const first = u16(0);
  if (first < 4 || first % 2 || first > data.length) throw new Error('invalid shape directory boundary');
  if (u16(first - 2) !== 65535) throw new Error('missing shape directory sentinel');
  const offsets = Array.from({length: first / 2 - 1}, (_, i) => u16(i * 2));
  if (offsets[0] !== first || offsets.some((offset, i) => i && offsets[i - 1] >= offset) || offsets.at(-1) >= data.length)
    throw new Error('invalid shape offsets');
  const shapes = offsets.map((start, index) => {
    const end = index + 1 < offsets.length ? offsets[index + 1] : data.length;
    if (start + 8 > end) throw new Error('truncated shape header');
    const count = data[start + 3], vectorsStart = u16(start + 4);
    if (!(start + 8 <= vectorsStart && vectorsStart <= end) || vectorsStart + count * 6 !== end)
      throw new Error('vector array does not exactly fill shape tail');
    const vectors = Array.from({length: count}, (_, i) => [0, 2, 4].map(k => view.getInt16(vectorsStart + i * 6 + k, true)));
    const shift = data[start + 2];
    // inspect_shapes.primitive_vertices (SIM 0b4d:1a5c).
    const vertices = encoded => encoded.map(code => {
      if (shift > 15) throw new Error('unsupported packed-vector shift');
      const vector = vectors[code & 127];
      if (!vector) throw new Error('vertex reference exceeds vector count');
      if (!(code & 128)) return [...vector];
      return vector.map(v => ((((v & 255) * 256 - 2048 + 32768) % 65536) - 32768) >> shift);
    });
    const regions = new Map();
    const region = (a, z, kind) => {
      if (!(start <= a && a < z && z <= vectorsStart)) throw new Error(`${kind} outside control region`);
      const previous = regions.get(a);
      if (previous && (previous[0] !== z || previous[1] !== kind)) throw new Error('conflicting pointer target interpretation');
      regions.set(a, [z, kind]);
    };
    const pointerList = at => {
      const result = [];
      while (at + 2 <= vectorsStart) {
        const pointer = u16(at); at += 2;
        if (pointer === 65535) return [result, at];
        if (!(start <= pointer && pointer < vectorsStart)) throw new Error('pointer outside control region');
        result.push(pointer);
      }
      throw new Error('unterminated pointer list');
    };
    const selectors = [];
    let at = start + 6;
    for (;;) {
      if (at + 2 > vectorsStart) throw new Error('unterminated selector directory');
      const word = u16(at);
      if (word === 65535) { at += 2; break; }
      if (at + 4 > vectorsStart) throw new Error('truncated selector entry');
      const target = u16(at + 2);
      if (!(start <= target && target < vectorsStart)) throw new Error('selector target outside control region');
      selectors.push({offset: at, word, target});
      at += 4;
    }
    region(start, at, 'header');
    // Maps keep Python's first-insertion order when a span is referenced twice.
    const roots = new Map(), groups = new Map(), primitives = new Map(), commands = new Map();
    if (count) {
      for (const {target: root} of selectors) {
        const [groupPointers, afterGroups] = pointerList(root + 2);
        const [commandPointers, after] = pointerList(afterGroups);
        region(root, after, 'root');
        roots.set(root, {offset: root, byte_0: data[root], byte_1: data[root + 1],
          group_pointers: groupPointers, command_pointers: commandPointers});
        for (const command of commandPointers) {
          region(command, command + 4, 'opaque_command');
          commands.set(command, {offset: command, hex: hex(data.subarray(command, command + 4))});
        }
        for (const group of groupPointers) {
          const [primitivePointers, afterPrimitives] = pointerList(group + 2);
          region(group, afterPrimitives, 'group');
          groups.set(group, {offset: group, byte_0: data[group], byte_1: data[group + 1], primitive_pointers: primitivePointers});
          for (const primitive of primitivePointers) {
            if (primitive + 4 > vectorsStart) throw new Error('truncated primitive');
            const terminator = data.subarray(0, vectorsStart).indexOf(255, primitive + 3);
            if (terminator < 0) throw new Error('unterminated primitive');
            const encoded = [...data.subarray(primitive + 3, terminator)];
            if (encoded.some(code => (code & 127) >= count)) throw new Error('primitive index exceeds vector count');
            region(primitive, terminator + 1, 'primitive');
            primitives.set(primitive, {id: primitive, prefix_bytes: [...data.subarray(primitive, primitive + 3)],
              vertices: vertices(encoded)});
          }
        }
      }
    } else {
      for (const {target} of selectors) {
        region(target, target + 2, 'opaque_pair');
        commands.set(target, {offset: target, hex: hex(data.subarray(target, target + 2))});
      }
    }
    let cursor = start;
    for (const [a, [z]] of [...regions].sort(([a], [b]) => a - b)) {
      if (a !== cursor) throw new Error('control regions overlap or leave a gap');
      cursor = z;
    }
    if (cursor !== vectorsStart) throw new Error('unparsed control-region tail');
    const opaque = [...commands.values()];
    // build_pc_modern_assets.visual_commands: decoded round-form records.
    const visual = opaque.filter(command => command.hex.length === 11).map(command => {
      const bytes = data.subarray(command.offset, command.offset + 4);
      return {kind: 'source_projected_round_form', command_offset: command.offset, command_bytes: [...bytes],
        sort_vector_encoded: bytes[0], radius_raw: bytes[1], color_index: bytes[2], center_vertex_encoded: bytes[3],
        center_raw: vertices([bytes[3]])[0], raster_entry: '0f8d:123e', projection_entry: '0b4d:31a6',
        runtime_binding: 'Observe original raster radius,x,y at SS:SP+4,+6,+8; radius clamp102 and source clip remain authoritative.',
        status: 'source_visual_command_requires_paired_raster'};
    });
    return {shape_index: index, selectors, roots: [...roots.values()], groups: [...groups.values()],
      source_primitives: [...primitives.values()], opaque_commands: opaque, visual_commands: visual};
  });
  return text.encode(JSON.stringify({schema: 1, source: 'SHAPE.TBL', source_sha256: SOURCES['SHAPE.TBL'], shapes}) + '\n');
}

// tools/extract_genesis_vdp.color_rgb565 for one 9-bit BGR CRAM colour.
function genesisRgb(cram) {
  const packed = ((cram >> 1) & 7) | (((cram >> 5) & 7) << 3) | (((cram >> 9) & 7) << 6);
  const [r, g, b] = [0, 3, 6].map(shift => (packed >> shift & 7) * 2);
  const pixel = r << 12 | (r >> 3) << 11 | g << 7 | (g >> 2) << 5 | b << 1 | b >> 3;
  return [Math.floor((pixel >> 11 & 31) * 255 / 31), Math.floor((pixel >> 5 & 63) * 255 / 63),
    Math.floor((pixel & 31) * 255 / 31)];
}

// tools/extract_genesis_effects.decode_effects plus its manifest, from the
// visitor's hash-verified ROM. Screen-capture donors cannot be derived here.
export async function deriveGenesisArt(rom) {
  if (!(rom instanceof Uint8Array) || await sha256(rom) !== GENESIS_ROM) throw new Error('Unsupported Genesis ROM');
  const view = new DataView(rom.buffer, rom.byteOffset, rom.byteLength);
  const images = [];
  let next = EFFECT_DATA;
  for (let index = 0; index < EFFECT_COUNT; index++) {
    const width = view.getUint16(EFFECT_TABLE + index * 8), height = view.getUint16(EFFECT_TABLE + index * 8 + 2);
    const offset = view.getUint32(EFFECT_TABLE + index * 8 + 4);
    if (width < 1 || width > 320 || width % 4 || height < 1 || height > 224)
      throw new Error('Unsupported Genesis effect dimensions');
    const size = width * height; // Four pixels per four-byte colour/mask pair.
    if (offset !== next || offset + size > rom.length) throw new Error('Unexpected Genesis effect layout');
    next += size;
    const pixels = [], opaque = [];
    for (let at = offset; at < offset + size; at += 4) {
      const colour = view.getUint16(at), preserve = view.getUint16(at + 2);
      for (const shift of [12, 8, 4, 0]) {
        const pixel = colour >> shift & 15, mask = preserve >> shift & 15;
        if ((mask !== 0 && mask !== 15) || (mask && pixel)) throw new Error('Unsupported Genesis effect mask');
        pixels.push(pixel); opaque.push(mask === 0);
      }
    }
    images.push({index, width, height, offset, byte_count: size,
      sha256: await sha256(rom.subarray(offset, offset + size)), pixels, opaque,
      image: `effect-${String(index).padStart(2, '0')}.png`});
  }
  if (next !== EFFECT_TABLE) throw new Error('Genesis effect resource does not end at its directory');
  const palette = Array.from({length: 16}, (_, i) => genesisRgb(view.getUint16(EFFECT_PALETTE + i * 2)));
  return new Map([[GENESIS_DERIVED[0], pythonJson({source: EFFECT_FIELDS.source, rom_sha256: GENESIS_ROM,
    directory_offset: EFFECT_TABLE, data_offset: EFFECT_DATA, data_bytes: EFFECT_TABLE - EFFECT_DATA,
    format: 'BE u16 width, u16 height, u32 pointer; row-major color/preserve u16 pairs; high nibble left',
    palette_capture: EFFECT_FIELDS.palette_capture, palette_receipt_sha256: EFFECT_FIELDS.palette_receipt_sha256,
    palette_bank: EFFECT_FIELDS.palette_bank, palette_rgb: palette, scope: EFFECT_FIELDS.scope,
    images, files: EFFECT_FIELDS.files})]]);
}
