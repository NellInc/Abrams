# Original PC world recovery

## Verified representation

The supplied SIM.EXE remains the gameplay authority. `tools/pc_world_oracle.py`
executes its original unpacker and unmodified coordinate, static-object-loading,
streaming-shift and vertex-reading instructions in Unicorn 2.1.4. Synthetic RAM
inputs remain inside that isolated oracle. The live bridge only reads memory.

The WLD directory is 64 columns by 64 rows, with 4096 raw units per cell.
Each nonempty directory entry points to a byte count and one to four objects.
An object begins with a seven-bit SHAPE.TBL index; index 127 is unused.

* High bit set: one position byte follows, high nibble X and low nibble Y.
  Continuous east = column × 4096 + X × 256.
  Continuous south = (row + 1) × 4096 − Y × 256. Height is zero.
* High bit clear: three signed 16-bit words follow. East = column × 4096 +
  2048 + X; south = row × 4096 + 2048 − Y; height = Z.

The supplied worlds contain 6,163 packed entries. Their placement results match
the original loader across all eight files. This establishes static placement,
not mission trigger, enemy spawning, victory or campaign semantics.

## Moving coordinate origin

SIM keeps an 8 by 8 local window. Data-segment bytes `886a` and `776c` store
its column and row origin. Object coordinates are signed 16-bit local X/Y/Z.

```
east  = localX + (columnOrigin + 4) * 4096
south = (rowOrigin + 4) * 4096 - localY
height = localZ
```

The four original window-shift routines translate active objects by 4096 while
changing the origin. Continuous coordinates remain unchanged. Schema 1 of the
bridge incorrectly read unsigned local positions and omitted this rebasing.
Schema 2 repairs both; consumers must use `world_position_raw` for scene placement.

Static pool: 128 records of 23 bytes at DS `7ace`. Dynamic pool: 30 records of
58 bytes at DS `709e`. Flag bit 7 marks allocation. Static records retain their
WLD entry offset at `+12` hex and current window-cell index at `+14` hex.
The WLD offset, rather than reusable pool slot, identifies a static instance.
Shape index is byte `+1`; word `+2` comes from that shape's header.

## Primitive vertices

SIM `0b4d:1a5c` reads the low seven bits of a primitive reference as its vector
index. A clear high bit uses signed component words directly. A set high bit
converts each low component byte to `(byte * 256 - 2048)`, wraps to signed 16-bit,
then arithmetic-shifts by shape-header byte 2. Treating every vector as an
unscaled coordinate would shrink much of the terrain to tiny fragments.

The original reader and our conversion agree for all 1,894 distinct primitive
references in SHAPE.TBL, with identity camera and zero translation. This does not
establish primitive visibility, ordering, LOD, materials or opaque draw commands.

## Receipts

```
.runtime/pc-analysis-venv/bin/python tools/pc_world_oracle.py \
  --output artifacts/pc-world-oracle-NEW.json
python3 tools/verify_pc_bridge.py \
  --state reference/pc-live/mission-entry/reference.state \
  --output artifacts/pc-world-live-NEW
```

`artifacts/pc-world-oracle-02.json`, terminal exit zero:

* 192 cell-center conversions and original inverse conversions.
* All 16,384 packed positions (256 combinations in each of 64 window cells).
* 192 extended signed-coordinate cases, 6,163 source-world objects, 1,894
  primitive references, and all four original window-shift directions.
* Original live RAM matches all 33,830 decoded SHAPE.TBL bytes and all 10,778
  decoded SNARIO6.WLD bytes. All 37 active static objects match the current window.

`artifacts/pc-world-live-01/report.json`, terminal exit zero: two matching
978-sample runs, one live northward window rebase, continuous northward movement,
and zero static-placement mismatches at every sampled frame. This remains a
bounded same-core trace, not proof of atomic logic-tick sampling or all missions.

## Godot integration and remaining limits

`pc_world_view.gd` renders static primitive outlines at their original continuous
positions and updates/removes instances as the original streams its world.
It uses a 1:64 inspection scale, maps east/up/south into Godot axes and keeps the
first player position as its display anchor. The original PC simulation alone
continues to govern movement and combat. No gameplay collision is added.

The original-camera extension now restricts static outlines to the original draw
queue, selected detail root and accepted faces. The elevated survey and authored
calibration vehicle have been removed from this bridge view. See
`pc-camera-research.md` for original-instruction and native projection evidence.
Dynamic meshes, solid occlusion, materials, opaque commands, timing calibration
and physical units remain open. All decoded geometry and original RAM stay
local; none has been published or bundled for distribution.

Working if: original CPU and live replay receipts pass, crossing a window edge
does not jump the Godot position, and the survey remains separated from gameplay
until its visibility and camera fidelity are proven.
