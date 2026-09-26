# SHAPE.TBL: verified storage and bounded geometry recovery

This investigation extends the compression and directory work in
`docs/reference-formats.md`. The source is the user-supplied `GAME/SHAPE.TBL`.
No original executable was run, no original bytes were changed, and no assets
were uploaded. All offsets below are zero-based offsets into the **decoded**
SHAPE.TBL buffer.

## Deliverables and reproduction

```sh
python3 tools/inspect_shapes.py --export-cube
python3 -m unittest discover -s tests -p test_shapes.py -v
python3 tools/reference_inventory.py --verify
```

Generated local artifacts:

* `reference/reports/shape-structure.json`: all 188 records, signed triples,
  pointer graph, primitive bytes, opaque commands, and absolute offsets.
* `reference/reports/shape-166-cube.obj`: eight source vertices and six source
  index lists, exported only after topology checks.

The report and OBJ are deterministic. They are ignored local artifacts, and the
tests require the supplied local GAME data. The interpreter only reads bytes.

## Evidence standard

**Verified storage facts:** every claimed field extent and pointer boundary below
fits every applicable supplied record. The parser enforces an exact,
nonoverlapping partition of each control region and an exact vector-array tail.

**Strongly supported interpretation:** signed triples referenced by the low seven
bits of primitive bytes represent geometry positions. Shape 166 independently
forms a closed cube with the expected face and edge invariants.

**Unresolved semantics:** rendering command execution, flags, material indices,
original axis conventions and units, normal-vector representation, visibility
rules, dynamic geometry, and correspondence to game object classes. No visual
similarity is used as proof of these semantics.

## Record header and vector tail

For each record beginning at `S`:

| Relative offset | Stored field | Verified extent |
|---|---|---|
| `+0` | unknown unsigned 16-bit word | 2 bytes |
| `+2` | unknown byte | 1 byte |
| `+3` | vector count `N` | 1 byte |
| `+4` | absolute vector-array pointer `V` | 2-byte little-endian |
| `+6` onward | selector entries | word, pointer, repeated; `ffff` word terminator |

In **all 188 records**, `V + 6*N` equals the exact record end. There are 168 records
with nonzero vector counts and 20 with zero. Each vector is three signed
little-endian 16-bit components. Reading the entire array as mesh vertices would
be wrong: it includes vectors not referenced by primitives, including repeated
`(8,8,8)` values and normal-like auxiliary entries.

Examples:

* Record 0 at `017a`: `be 02 00 10 f5 01 ...`. There are 16 triples at `01f5`,
  occupying 96 bytes to the record end `0255`.
* Record 166 at `8120`: `37 00 00 10 74 81 ...`. There are 16 triples at `8174`,
  occupying 96 bytes to `81d4`.
* Record 170 at `823a`: count zero and pointer `8254`, exactly the record end.

Selector words are retained as unknown words. Their descending patterns suggest
scale or distance thresholds, but the reader does not call them LOD distances.

## Pointer graph for the 168 records with vectors

Each selector pointer leads to a root block:

```
root:
  byte_0, byte_1
  group_pointer:u16 ... ffff
  opaque_command_pointer:u16 ... ffff

group:
  byte_0, byte_1
  primitive_pointer:u16 ... ffff

primitive:
  prefix_byte_0, prefix_byte_1, prefix_byte_2
  encoded_index:u8 ... ff
```

Primitive termination is searched only after the three-byte prefix. The prefix
can itself contain `ff`, so searching from the primitive start would corrupt the
parse. Index interpretation currently exposes both original bytes and
`index & 0x7f`. Every low-seven-bit index is less than its record's vector count.
The high-bit meaning is unresolved.

The second root list references eleven four-byte opaque commands across six
records (111, 145, 153, 156, 161, and 162). Treating those targets as groups fails
pointer validation. Their extents are established by adjacent boundaries and
whole-region coverage; their execution semantics remain unknown.

The graph contains **992 distinct primitive lists**. Length distribution:

| Index count | Primitive count |
|---:|---:|
| 0 | 2 |
| 1 | 1 |
| 2 | 130 |
| 3 | 171 |
| 4 | 604 |
| 5 | 34 |
| 6 | 48 |
| 8 | 2 |

Empty lists, points, and two-index primitives must not be silently converted into
triangles. Longer lists may represent polygons, but fill rules and winding
semantics require the original renderer contract.

In the 20 zero-vector records, selector pointers address opaque two-byte pairs.
These also partition their control regions exactly. They may reference other
shapes; that interpretation has not been established.

## Independently checked cube, record 166

Storage evidence:

* Record start `8120`, size 180; vector array `8174`, count 16.
* Selector at `8126`: word 16, root pointer `812c`.
* Root bytes `40 8f`, one group at `8134`, no opaque commands.
* Group bytes `80 88`, primitive pointers `8144`, `814c`, `8154`, `815c`,
  `8164`, `816c`.
* First primitive at `8144`: `09 00 04 00 06 05 07 ff`.

The six primitive lists reference exactly the first eight vectors. Those vectors
are exactly all eight combinations of `(-32 or 32, -32 or 32, -32 or 32)`.
Each face has four distinct corners on one boundary plane. All six distinct
boundary planes occur. Every face edge has coordinate length 64, so no face
boundary accidentally uses a diagonal. There are exactly twelve undirected edges,
and each occurs in exactly two faces.

These checks establish a closed cube boundary independently of a screenshot.
The OBJ retains raw source coordinates and index order, with no scale or axis
conversion. It deliberately has no inferred materials or normals. Face winding
is preserved and is not claimed to match an ordinary one-sided OBJ renderer;
use two-sided rendering when inspecting it.

Vectors 8 through 15 are excluded from the OBJ because no primitive references
them as positions. Their values include `(8,8,8)` and six axis-aligned vectors of
magnitude 128. This supports an auxiliary-vector interpretation, but does not
prove a general normal or origin rule for all shapes.

## Why broader mesh export is withheld

All primitive storage can be inspected, but original renderer semantics remain
unresolved. In particular, applying one guessed normal rule across the corpus
produced contradictions. The present tool therefore exports only the cube whose
geometry and topology have independent checks. The JSON retains enough data for
further reconstruction without baking guessed behavior into generated meshes.

The checks prove internal consistency on this corpus. They are not independent
comparison against original renderer output or proof that all assets would look
identical in Godot.

## Finite next disassembly probes

1. Locate SHAPE.TBL loading and relocation in `SIM.EXE`, tracing the pointer at
   record `+4` and the byte at `+3`. Confirm the triple reader's signedness and
   component-to-axis mapping before assigning units or normals.
2. Trace the primitive index reader through its `ff` terminator and high-bit
   handling. Confirm which prefix bytes select colors, normals, or primitive
   modes. Test the observed zero-, one-, and two-index lists explicitly.
3. Trace root second-list dispatch using the six records above and their eleven
   four-byte commands. Determine whether they create sprites, references, or
   dynamic primitives without forcing them into polygon groups.
4. Trace zero-vector selector targets, then map SHAPE.GI and WLD values into
   SHAPE.TBL indices. Verify a specific object identity before assigning names
   such as Abrams, road, or building to recovered records.

Each probe has a concrete confirming read path. Broader speculative parsing is
outside this bounded lane.
