# Finite crew portrait coverage

The crew artwork denominator is four roles. `FACES.BMP` contains four popup
portraits. `CREW.BMP` contains four crew-information portraits and one tank/seat
diagram; the diagram is a separate illustration.

| Role | FACES index | CREW index | Shared remaster donor |
|---|---:|---:|---|
| Commander | 0 | 3 | commander-v1.png |
| Gunner | 1 | 0 | gunner-v2.png |
| Driver | 2 | 1 | driver-v2.png |
| Loader | 3 | 2 | loader-v1.png |

All four roles have pinned Genesis-derived 1254x1254 artwork bound to the crew
information page and eligible original popup pixels. The two original resources
have small differences, respectively 7, 19, 4 and 4 palette-index pixels for the
four roles above. Their verification samples therefore remain separate.

Talking, injury and radio descriptions do not establish additional artwork.
The complete decoded resources above provide the finite source inventory.
Messages and speaker hints cannot select a replacement face by themselves:
every original opaque face pixel and its current UI-ownership bit must match.
Original transparency, surrounding text and world pixels remain untouched.

## First visible frame

The driver source capture contains a complete face from frame 3583 through
3689. Its crew caption begins at frame 3601, eighteen frames later. Current
portrait binding follows the complete face immediately and clears when the
original removes it at frame 3690. A caption delay cannot cause an old-face
flash or keep an erased face visible.

Current machine verification covers all four source-role fixtures, the exact
crew-information page and every frame of the 146-frame recorded driver
transition. Bounded native renders compare actual donor/filter samples and
all pixels outside original opaque coverage. Previously captured original
occurrences separately demonstrate the gunner and loader; the driver has a
production-viewer occurrence record. The commander is covered by exact source
fixtures, without claiming a newly triggered spontaneous gameplay occurrence.

```sh
python3 -m tools.audit_pc_portrait_coverage
python3 -m unittest tests.test_pc_portrait_coverage tests.test_pc_portraits -v
./tools/godot.sh --headless --script res://tests/test_pc_portrait_coverage.gd
./tools/godot.sh --rendering-method gl_compatibility \
  --script res://tests/test_pc_portrait_coverage.gd -- --native \
  --output "$PWD/artifacts/portrait-coverage-native-new"
```
