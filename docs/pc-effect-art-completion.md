# Complete source-bound effect atlas

## Implemented scope

The ordinary-palette presentation now has 20 authored Genesis-derived donors
covering all 64 source bitmap bindings. Seventeen new donors extend the earlier
three impact phases. These are built-in image-generation redraws, not source
extractions relabelled as finished art or filtered pixel upscales.

This work and the visual review were produced by the same assistant. Human art
acceptance and unchanged tactical readability have not been established.

`tools/audit_pc_effect_inventory.py` decodes every zero-vector `SHAPE.TBL`
selector and its exact `80 bitmap` command. Shapes 168 through 185 each define
three LOD variants: bitmap `shape-168`, that value plus 18, and plus 36, selected
at thresholds 16, 8 and 4. Shape 186 selects 62/60/54/56/58 and shape 187 selects
63/61/55/57/59 at thresholds 32/16/8/4/1. No bitmap is unmatched. This binding
comes from the PC executable's resource, rather than visual resemblance.

Source phase names are descriptive art labels; no new gameplay semantics are
inferred. Genesis and PC dimensions, all 28,960 indices and preservation-mask
bits still agree. The catalog records each frame's dimensions, exact root,
shape, selector, color indices, donor, native-scale alpha count and mask overlap.

## Visibility and fail-closed behavior

The original observed sprite remains authoritative for whether and when a draw
happens, phase, LOD, dimensions, origin, camera clip and painter position.
Unknown RGB palettes, flags, source identity, indices, masks or missing art retain
the original sprite. Original source packets remain unmodified.

The generated files retain their original RGBA data. At load time, a 5 by 4 atlas
packs 512-square presentation tiles with two transparent texels around each.
The existing linear, non-mipmapped, non-repeating sampler uses one effect shader
branch. UVs stay inside the assigned tile. No mipmapped neighboring donor can
bleed into it. All donors remain in the same ordered polygon/effect mesh.

Generated canvas padding is separately registered from source row padding.
The new donors use measured alpha-at-least-128 artwork bounds, mapped to each
original bitmap's opaque rectangle. Existing three curated donors retain their
previous source-relative registration. The original per-pixel mask is a source
identity gate, not a replacement clipping mask. Redrawn contours therefore
change visibility within the rectangle. The audit records those differences.

A first inventory used an area-reduction filter as a stand-in for GPU bilinear
sampling. That was the wrong model; the replacement computes the two-texel
pixel-center sample and uses the exact destination/source-bound mapping.
It exposed a real registration defect: extra generated padding could erase
small variants 32, 40 and 50 at 1x. Registering authored cutout bounds fixed all
three. Native tests now explicitly require a non-background rendered pixel
for every bitmap, rather than counting disappearance as a successful change.

## Authored candidates

Selected images and exact prompts live in ignored
`local-art/genesis/remastered/effects-v2/`. Its manifest pins hashes, dimensions,
alpha bounds, source identities and rejected candidates. Existing donors remain
in `effects-v1/` and are not overwritten.

The initial frame-nine candidate incorrectly introduced warm colors into a
monochrome smoke source. A source-only grey revision replaces it. Frame twelve
repeatedly acquired a glow in raw previews, including after changing strategy
to an established flat-color style reference. The selected second candidate
renders as a clean opaque cutout under the existing alpha-0.5 shader; native
RGB/alpha tests and its native screenshot cover that exact use. These files
are not approved for an alpha-blended particle renderer.

No HEAT illustration was retried or touched. No vehicle texture or model was
added. Original game resources, emulator and instruction paths were unchanged.

## Evidence and boundaries

Artifacts are under `artifacts/finish-20260928/`:

* `effects-inventory.json`: every source binding, palette indices and measured
  native-scale alpha difference, independently decoded from local originals.
* `effects-native-1x-final/`: all 64 variants retain visible rendered pixels,
  source bounds, independent authored RGB and transparent-background checks.
* `effects-native-5x-final/`: full donor atlas, transparent gutters, bounded UVs,
  all 64 draws, every donor at both clipped corners, independent bilinear RGB
  and cutout checks, both painter orders, unknown-palette fallback and clearing.
* `effects-python-final3.log`: source/resource, all binding identities, pinned
  donor hashes and actual-cutout registration checks.

The existing recorded replay still selects 51 at passes 165 through 167, 52 at
168 through 169 and 53 at 170 through 171. The same 261 captured render packets
are replayed without mutation. Other 61 bitmaps have source-command and native
fixture evidence, without a newly observed live mission animation sequence.
The observed thermal-on, thermal-off and STATUS damage contexts share the same
exact RGB palette and are supported by the existing effect path. Thermal changes
original world color indices, rather than recoloring effect pixels. STATUS owns
all 64,000 screen pixels and therefore covers every effect. Unknown RGB palettes
remain fail-closed. See [source mode evidence](pc-effect-display-modes.md).
Broader live effect occurrence and mission timing remain open.
The preceding 1,020-frame emulator boundary parity proof is historical evidence
for the earlier subset, not a new proof for this atlas.

Working if: original source selection and fallback gates remain authoritative,
all source identities and native rendering checks pass, every variant remains
visible at 1x, and no pixel outside original bounds or clip changes.

```sh
python3 tools/audit_pc_effect_inventory.py --output artifacts/effects-new.json
python3 -m unittest tests.test_pc_effect_inventory tests.test_genesis_effects -v
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_effect_art.gd -- \
  --native --native-scale 5 --output "$PWD/artifacts/effects-native-new"
```

Status: local only. No publication or redistribution authorization is inferred.

## Modern ownership refinement (2026-09-29)

All 20 existing authored donors were inspected against the complete original
contact sheet. Their contours already contain high-resolution artwork, so no
replacement PNG or new phase was introduced. The Modern ownership pass had
reapplied the original coarse pixel silhouette to every authored effect. The
previous native effect test exercised the ordinary presentation and therefore
missed this Modern-only restriction.

The ownership pass now retains original sprite coverage and unions the verified
donor's alpha-at-least-0.5 silhouette at the same object painter slot. Its quad
uses the mapping's original bounds, clipping, atlas registration and identity
gates. Later objects still overwrite ownership. Original coverage is retained
so an authored transparent hole cannot reveal a previously hidden Modern actor.
Round-command ownership keeps its separate flag. No simulation state or timing
is added, and the original bitmap fallback remains available.

The native effect test accepts `--modern` to exercise all 64 bindings with the
real Modern catalogue. It compares actual pixels with independent bilinear
samples, checks retained original coverage, and counts new contour pixels outside
the coarse source mask. Both painter orders, clipping, source packet preservation,
recorded phase selection and unknown-palette fallback remain covered.

The exact resource identities are established, while the gameplay names of every
bitmap are not. Shapes 186 and 187 own the two five-LOD starburst families;
SAGGER's catalogue shape 161 is the crew. A Sagger/AX missile label is not inferred
from visual resemblance. The correction applies to every verified bitmap.

```sh
./tools/godot.sh --audio-driver Dummy --disable-render-loop \
  --script res://tests/test_pc_effect_art.gd -- --native --native-scale 5 \
  --modern --output "$PWD/artifacts/modern-environment-polish-20260929/effects/native-modern-5x"
```

Local artifacts: `artifacts/modern-environment-polish-20260929/effects/`.
Working if: Modern exposes authored high-resolution contours within the same
source rectangle, preserves original ownership under alpha holes and later
occluders, and passes the existing source identity and phase checks.

Native validation completed for Modern at 1x and 5x and ordinary presentation at 5x.
All 64 variants remain visible. The Modern 5x run records 24,537 authored contour
pixels outside the coarse source mask, 206,550 retained original ownership pixels,
and maximum RGB error 1 across 628,987 independent samples, with zero errors.
