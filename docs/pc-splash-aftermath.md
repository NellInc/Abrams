# Publisher splash and destroyed-tank plates

The authored high-resolution set covers the PC `US`, `SCENE1.BIN` and
`SCENE2.BIN` plates. `pc_splash_aftermath_art.gd` accepts a plate only when the
program identity and SHA-256 of all 64,000 RGB pixels match its pinned catalog.
A single changed pixel, wrong program, unknown palette, partial transition or
missing asset keeps original pixels visible. This layer has no animation clock,
input handling, native state writes or scene-selection logic. Original PC timing
and gameplay remain authoritative.

## Donor evidence

The PC publisher screen reads “A Dynamix Production”. It is present in the
original-baseline-compared START capture and independently reconstructs from US.
The supplied Genesis boot capture shows SEGA instead. The remaster therefore
retains the PC publisher identity, using the PC graphic as its composition donor.
This is a platform-specific content difference; the observed boot sequence does
not prove the absence of every possible publisher graphic elsewhere in the ROM.
Native mode retains the PC publisher screen.

The destroyed-tank scenes use Genesis artwork. The pinned Genesis ROM's sequence
at DA50 selects script 0 through dispatcher 9354; DA5E selects script 1. Their
scripts at 937E and 93A0 load tile banks 9 and 10, map records 21 and 22, and
palettes 58E42 and 58E68. Scene 2 also places map 23, a transparent 4 by 16 tile
smoke overlay, on the alternate plane. Its cropped plate rectangle is
`[160,16,32,128]`. Omitting this map would incorrectly remove the distant smoke.

`extract_genesis_aftermath.py` runs the untouched decoder at 9AFE in bounded
isolated M68000 RAM with read-only ROM. The extracted artwork is the Genesis
composition and palette, including green terrain and pale cyan sky. Scene 1 is
the close destroyed tank; scene 2 is the distant smouldering wreck. The derivative
illustrations retain those compositions with the project's hand-painted,
outlined treatment. Both were produced with the built-in image generator.

The decoder reconstruction covers the static plates. The later Genesis animation
route is separate and does not control these PC replacements. No live Genesis
animation parity is claimed. The PC display determines when each complete plate
matches and when it ceases to match.

## Local validation

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_pc_splash_aftermath
sh tools/godot.sh --headless --script res://tests/test_pc_splash_aftermath.gd
sh tools/godot.sh --script res://tests/test_pc_splash_aftermath.gd
```

The native-renderer test captures all three illustrations through a dedicated
1280 by 800 SubViewport, avoiding desktop window-size/stretch artefacts. It checks
complete-frame selection, all three identities, exact native donor behavior,
wrong-program rejection, one-pixel damage rejection, null input and clear-state
behavior. Working if: every matching static plate selects its intended art,
while changed or unmatched frames remain untouched and the original transition
duration is preserved by the enclosing player.

Source and generated files stay in ignored local-art directories. The catalog
records all source, native donor and generated-image hashes. This is local
presentation work; it establishes no publication or redistribution clearance.
