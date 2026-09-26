# PC executable evidence

## Decode and independently compare

All four supplied MZ executables use a 16-byte EXEPACK header and the same
277-byte decompressor/error-string block. The header signature is `52 42`.
The block's SHA-256 is
`a146eddf8f6523a9b05e070f126a755e5b5c4444181258faa3939010fd2d61b3`.

`tools/unpack_pc_executables.py` accepts this observed variant only. It preserves
the originals and writes unrelocated load-image bytes plus address/relocation
metadata under `reference/pc-unpacked/decoded/`. Unknown stubs, truncated runs,
unread-input overwrites, inconsistent prefixes and invalid relocations fail.

| Program | Decoded bytes | Relocations | Original entry CS:IP |
|---|---:|---:|---|
| START | 115216 | 575 | `0000:47e2` |
| BRIEF | 62896 | 362 | `0000:0ffa` |
| SIM | 129712 | 671 | `0000:91f8` |
| END | 89008 | 386 | `0000:1b36` |

These load-image bytes, relocation targets, entry points and stack values were
compared with David Fifield's independent [exepack 1.4.0 implementation](https://www.bamsoftware.com/software/exepack/).
Its source is CC0 and remains a local research dependency. The downloaded source
tarball SHA-256 is
`212f3ec55822dc67763ab79534e5c9cd5fc2cf127a557a983a6b95ae4ad89ecf`.
All four comparisons are identical. This is storage evidence, not a complete
gameplay-equivalence claim.

```sh
python3 tools/unpack_pc_executables.py \
  --compare-dir reference/pc-unpacked/independent
```

Addresses below refer to the decoded load image, excluding the MZ header.
Near pointers use the named program's data segment. They must not be confused
with offsets in the packed source files.

## Execute original instructions

`tools/pc_bearing_oracle.py` uses [Unicorn's CPU emulation API](https://www.unicorn-engine.org/docs/tutorial.html),
pinned to version 2.1.4. It first executes each original decompression stub from
the packed EXE at load segment `1000`. Every resulting byte is compared with
the independent decode after applying the original relocation table. The
restored entry, stack and PSP segments are also checked. All four pass.

The oracle then executes two original SIM routines for every possible unsigned
byte input. It supplies RAM, registers, an isolated stack and the C runtime's
stack lower bound. The original stack-allocation helper and long-multiply helper
execute normally. No original instruction is patched, intercepted or replaced;
unexpected interrupts and failure to return within the limit fail the check.

```sh
python3 -m venv .runtime/pc-analysis-venv
.runtime/pc-analysis-venv/bin/python -m pip install 'unicorn==2.1.4'
.runtime/pc-analysis-venv/bin/python tools/pc_bearing_oracle.py \
  --check-fixture godot/tests/fixtures/pc_bearings.json
./tools/godot.sh --headless --script res://tests/test_pc_rules.gd
```

The committed fixture contains numerical outputs and provenance, no original
executable bytes. The normal validation gate compares the Godot port against
this fixture. The separate oracle command above re-executes the original code;
a fixture-only test must not be described as a fresh original execution.

This environment emulates isolated computation. DOS, graphics devices, elapsed
time, event cadence and whole missions remain outside its scope.

## Bearing conversion and hit-call formatting

SIM's data segment is load-relative `19e0`. The string at DS:`095d` reads
`We've been hit! Bearing `.

* Routine `0000:56ea` multiplies the unsigned input byte by 360, shifts the
  product right eight bits, subtracts the result from 360, and maps 360 to zero.
* Routine `0000:3d0e` uses that conversion, then calls `0000:527c` with width
  three and padding character `30` (ASCII zero). It copies the resulting
  NUL-terminated string to DS:`6472` for the hit-call.
* The formatter and conversion were both executed for all 256 inputs. The
  resulting three digits always agree with the numerical routine.

Examples: internal 0 gives `000`, 1 gives `359`, 57 gives `280`, 64 gives `270`,
192 gives `090`, 224 gives `045`, and 255 gives `002`.

`godot/scripts/pc_rules.gd` matches every result. It is deliberately separate
from the provisional range's floating-point angle convention. The full PC
movement/orientation pipeline must be recovered before connecting them.

The TTS normalizer is checked against all 256 original strings. It preserves
the caption and performs each digit separately, including the leading zeroes.
For example, `Bearing 045` becomes `Bearing zero four five`. This pass does not
invent an incoming-hit event in the authored range or generate 256 new samples.

## Further static leads, with limits

Both START and BRIEF contain an eight-entry near-pointer title table. The
decoded tables are START DS:`24da` (DS=`1505`) and BRIEF DS:`080a` (DS=`0c71`).
Their indexed order is Nuremburg Highway, Mass Destruction, The Road to Bonn,
Hannover Push, Convoy, The Mossel Intercept, The Mossel Defense, Siegen
Infiltration. BRIEF `0000:0230` indexes the table using the first byte read
from `shell`. This establishes the title lookup, not campaign order.

SIM `0000:7d52` transfers the fourth handoff byte to DS:`8d74`; `0000:7de6`
adds ASCII zero and writes it into `snario ` before the resource-loader call.
The handoff begins at physical `0000:0510`. The relationship between a campaign
slot, the shell first byte and the resource index still needs tracing. Do not
mark scenario/title correspondence or objective execution proven from this lead.

SIM `0000:7fb0` opens `sim.arm` and reads four 16-bit fields. It checks the sum
of the first three against 40. Its fallback at `0000:8005` writes values
`[20, 10, 10, 1]`. Field names, malformed-file handling and subsequent selection
behaviour remain to be traced before changing the range's loadout.

## Original display correction

The original was launched with `ABRAMS.COM EGA` and DOSBox-X 2024.07.01 configured
as `machine=ega`. Its OpenGL window showed an incorrect blue cast. A raw
320x200 framebuffer capture retained normal grayscale, red, yellow and blue
colors: `artifacts/pc-ega/title-raw.png`.

Switching Video > Output > Surface in the running emulator removed the cast.
The displayed menu then showed green terrain, gray road/frame, brown hills and
cyan sky. Nell confirmed the correction. The launch configuration now saves
`output=surface` in `.runtime/dosbox-x.conf`. The original files were unchanged.
This local remedy is verified; the underlying OpenGL implementation defect has
not been diagnosed. The misleading colors must not guide remastered artwork.

Working if: subsequent launches retain Surface output, the raw and displayed
palette agree, and the source fingerprint verification remains unchanged.
