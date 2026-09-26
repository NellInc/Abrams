# Supplied DOS reference: byte evidence

This report began with locally inspected bytes. Subsequent original-executable
checks are recorded below and in `pc-world-research.md`. Original files remain
unchanged. The baseline fingerprints cover
all 68 files inside `GAME`; the separately supplied PDF is outside that baseline.
Decoded reports remain local reference material.

## Reproduce

```sh
python3 tools/reference_inventory.py --verify
python3 tools/inspect_scenarios.py --extract
python3 -m unittest discover -s tests -p test_reference_tools.py -v
```

`reference/reports/game-manifest.json` is the deterministic baseline, sorted by
relative filename, with size and SHA-256. Creation refuses to overwrite an
existing baseline. Verification reports changed, missing, and unexpected files
without rewriting the baseline. No timestamps or machine-specific paths enter it.
`reference/reports/scenarios.json` contains the structured inspection, raw and
decoded hashes, byte offsets, strings, and undecoded field values. Generated
`*.decoded` files contain the decompressed bytes.
Report schema 2 replaces WLD's earlier opaque `values_u16le` with decoded entries,
source offsets, shape IDs and continuous raw positions.

## Evidence levels

* **Observed:** directly present bytes, lengths, strings, and fingerprints.
* **Structurally verified on this corpus:** a proposed layout parses every
  applicable supplied file, with bounded reads and exact lengths. This establishes
  consistency with these bytes, not behavioral identity with the original game.
* **Inferred:** plausible gameplay meaning requiring disassembly or original
  runtime comparison. Such fields are retained under neutral byte names.

All offsets below are hexadecimal and zero-based. A decoded offset refers to the
output of the resource decoder, not the compressed file offset.

## Type-2 resource compression

**Structurally verified:** all 48 supplied files beginning with `02` decode to the
exact little-endian 32-bit length at raw offsets `01..04`. Compressed bits begin at
raw offset `05`. Examples:

| File | Raw prefix | Decoded length |
|---|---|---:|
| SNARIO0.SSS | `02 3a 0b 00 00` | 2874 |
| SNARIO0.WLD | `02 e2 25 00 00` | 9698 |
| SHAPE.GI | `02 fc 1d 00 00` | 7676 |
| SHAPE.TBL | `02 26 84 00 00` | 33830 |

The working decoder is LZW with least-significant-bit-first code packing:

* Codes 0 through 255 are literal bytes; 256 resets; 257 is the first dictionary code.
* Width begins at 9 bits, increases when the next available dictionary index reaches
  the current power-of-two limit, and stops at 12 bits.
* Dictionary growth stops at 4096 entries. The special next-code case expands the
  previous entry followed by its first byte.
* Reset consumes padding through an eight-code block boundary, relative to the
  start of the current code width. The new block starts with 9-bit codes.
* Decoding stops at the declared output length. The corpus leaves zero through
  seven final padding bits. Padding values are not assigned semantic meaning.

The reset rule matters: `SHAPE.TBL`'s reset ends at payload bit 122332, followed by
36 padding bits; the next 9-bit block starts at bit 122368. Naively resetting at
that immediate bit position fails. `CO.BMP`, `INFO.BMP`, and `SCENE1.BIN` exercise
other reset locations. The bounded implementation rejects invalid codes,
truncation, output overrun, lengths above 16 MiB, and unexplained trailing bytes.

A matching declared length plus coherent messages is strong structural evidence.
The decoded SHAPE.TBL and SNARIO6.WLD now match their entire original-game
RAM buffers byte-for-byte (33,830 and 10,778 bytes respectively). This is an
independent original-decoder comparison for those two resources. Other resources
still have structural and regression evidence only; the comparison does not
extend automatically to all 48 files.

## WLD directory and lists

**Structurally verified across all eight scenarios:** decoded offsets
`0000..1fff` contain 4096 little-endian 16-bit offsets. Zero marks an absent list.
Every nonzero entry points to a sequential list beginning at or after `2000`.
The original loader confirms a count of one to four entries. Each entry begins
with a shape index in its low seven bits. A set high bit selects one packed
position byte; otherwise six bytes contain three signed coordinate words. All
6,163 entries in the supplied eight worlds use the packed form. Traversing the
directory consumes the files exactly, with no overlap, gaps or unreferenced tail.

Example, `SNARIO0.WLD`: directory offset `0016` has `00 20`, pointing to `2000`;
bytes at `2000` are `01 b2 88`, giving shape 50 (`b2 & 7f`) at packed position `88`. Directory offset `003c`
has `03 20`, pointing to the next list at `2003`, bytes `01 a6 88`.

| Scenario | Decoded bytes | Nonzero directory entries |
|---|---:|---:|
| 0 | 9698 | 486 |
| 1 | 9970 | 560 |
| 2 | 9751 | 501 |
| 3 | 10348 | 690 |
| 4 | 11198 | 978 |
| 5 | 10770 | 826 |
| 6 | 10778 | 828 |
| 7 | 11195 | 977 |

**Original-CPU verified:** the directory is a 64 by 64 row-major grid, with
4096 raw units per cell, columns increasing east and rows south. Original loading
routines reproduce all 6,163 placements. Physical units and semantic terrain
names remain unresolved. See `pc-world-research.md` for the streaming origin,
compact/extended coordinates and independent execution receipts.

## SSS records and text

**Structurally verified across all eight scenarios:** a 30-byte header is followed
by 42-byte records. The little-endian 16-bit record count is at decoded offset
`001c`. Counts in scenario order are 45, 62, 35, 53, 73, 31, 21, and 52.

The subsequent message block starts at `30 + 42 * count`. It begins with a
16-bit message count, then that many three-byte entries (one flag byte and a
16-bit relative string offset), then a 16-bit total string-block size. The strings
are NUL-terminated ASCII. The remaining tail is presently unparsed.

Example, `SNARIO0.SSS` at `0780`:

```
03 00  04 00 00  00 27 00  00 3f 00  5b 00
```

This yields three messages, offsets 0, 39, 63 within a 91-byte string block.
The first string begins at decoded `078d`:
`Radar shows hind entering your sector!`

The repeated records expose `word_0`, `byte_22`, `byte_23`, `byte_30`, and `byte_31`
in the JSON. Example record 1 of scenario 0 begins at decoded `0048`, has first
word `0x001d`, and byte pairs `(22,26)` at relative offsets 22/23 and 30/31.
**Inferred:** the first word looks like a class identifier and these byte pairs
look like initial/current grid positions. Neither interpretation is established.
Do not label them tank classes, meters, or runtime coordinates without further
proof. Record zero has distinct initialization bytes and may be special.

Decoded crew messages reference clear-road, base-destruction, bridge-destruction,
convoy escort, and elimination conditions. They identify intended concepts but do
not reconstruct the trigger interpreter or victory logic.

## Shape resources

`SHAPE.TBL` begins with 188 strictly increasing little-endian 16-bit offsets,
followed by `ffff` at decoded `0178`. The first offset is `017a` (378), exactly the
end of the directory. Subsequent starts include `0255`, `0330`, `03a6`. The last
record begins at `8400` (33792) and occupies 38 bytes to EOF (33830).

**Structurally verified:** directory boundaries and record extents. **Unverified:**
vertex format, polygon commands, color indices, units, and the relation to WLD
values. A renderer must not interpret these extents as fully decoded meshes.

`SHAPE.GI` decompresses to 7676 bytes and begins `73 00 00 aa 00 aa 02 00 0e 01`.
Repeated ten-byte patterns are visible early in the buffer. This observation is
not a validated whole-file schema; its body remains unparsed.

## Executables and mission names

`SIM.EXE` begins with an MZ header. The inspector records raw header words and
printable ASCII offsets; it does not execute or unpack machine code. `SIM.ARM`
contains exactly `0a 00 06 00 12 00 00 00`, four observed little-endian words
`[10, 6, 18, 0]`. Ammunition or settings meanings are unverified.

`BRIEF.EXE` contains these titles in the following storage order:

| Raw offset | Exact text |
|---|---|
| `cd9a` | NUREMBURG HIGHWAY |
| `cdac` | MASS DESTRUCTION |
| `cdbd` | THE ROAD TO BONN |
| `cdce` | HANNOVER PUSH |
| `cddc` | CONVOY |
| `cde3` | THE MOSSEL INTERCEPT |
| `cdf8` | THE MOSSEL DEFENSE |
| `ce0b` | SIEGEN INFILTRATION |

The bytes and spellings are observed. Their correspondence to scenario indices
0 through 7 is inferred from contiguous storage order, not verified through the
selection routine. Preserve this distinction in any generated metadata.

## Remaining fidelity boundary

Still required for an exact reconstruction: identify scenario field semantics and
script/waypoint tail, decode shape records, establish world orientation and scale,
recover the original trigger interpreter and dynamics, and compare original
runtime behavior with the Godot implementation. These inspection tools establish
an auditable data foundation; they do not establish that the reconstruction plays
identically to the original.
