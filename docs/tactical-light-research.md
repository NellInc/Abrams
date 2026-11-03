# Tactical light: literature review and implementation

Nell asked (2 November 2026) for a review of the most resource-efficient ways to make
the game look its best through shaders, lighting and shadows, and for the chosen
techniques to be implemented. This file records the review, the choices made under this
project's constraints, the implementation and its evidence. The user-facing summary is
in [graphics-modes.md](graphics-modes.md#tactical-screen-space-light-local-2-november-2026).

## Constraints that decide the choice

- **Renderer.** Godot 4.7.2 Compatibility (OpenGL 3.3 / WebGL 2) natively and on the
  Web. There is no compute, there is one colour target per pass, and the scenery viewport
  exposes no depth texture as data. Scenery is one painter-ordered, unshaded triangle
  stream, gated per pixel by the original ownership mask (`modern-renderer.md`).
- **Fidelity.** Presentation must not reveal tactical information the original hides. An
  actor the original painter order concealed must contribute nothing. HUD, reticle and the
  EGA, Genesis, Upscaled and Modern modes stay exact.
- **What already exists in Tactical.** A fixed world sun with facet light, filtered
  material highlights, bounded aerial perspective, analytic sky reflections on water and
  glass, and baked vehicle cavities. There was no cast shadow, no contact occlusion and no
  sun direction in the plant grounding.
- **Budget.** The moving Modern route already measured below 60 Hz (39.53 replies/s,
  `modern-renderer.md`). Additions must be fixed-cost single passes with no new full
  geometry pass. The source-depth target below re-renders only the small ownership mesh.

Baseline captures (`artifacts/gorgeous-20261102/baseline-tactical/`) showed what was
missing in practice: flat, low-contrast ground, hills reading as uniform brown cards, and
near-field plants with no sun-consistent shadow.

## Review

Primary sources were fetched and read where marked *verified*. Items marked
`[Unverified]` rest on secondary summaries.

| Technique | Source | Cost | Fit here | Decision |
|---|---|---|---|---|
| Shadow maps / cascades | Williams 1978 `[Unverified]` | Extra light-view pass per cascade | Needs every caster's depth from the sun, including actors the original hides. Their shadows would reveal them | Rejected |
| Screen-space sun shadows | Bend Studio, Graham Aldridge: *Days Gone* (2019), SIGGRAPH 2023 deck and blog (*verified*) | 0.19 ms at 1440p on PS5 with 60 samples, using compute and LDS | Marches toward the projected light over the depth buffer, so it uses only visible depth and cannot see a concealed actor. The deck notes "individual samples should not fully shadow" | **Adopted** as a fragment version: 32 samples, quadratic spacing, per-pixel jitter |
| SSAO estimators | Mittring 2007 `[Unverified]`; Bavoil and Sainz 2008 (HBAO); McGuire et al. 2011, Alchemy AO (*verified* estimator); Jimenez et al. 2016, GTAO (*verified*: 0.5 ms at 1080p on PS4, using spatio-temporal filtering) | 8–16 depth taps; GTAO also needs temporal accumulation | Same visible-depth property. There is no TAA here, and captures must stay deterministic | **Adopted**: Alchemy estimator with 8 taps and no temporal pass |
| Unsharp-masked depth ("depth darkening") | Luft, Colditz and Deussen 2006, *ACM TOG* 25(3) (*verified*) | One blurred-depth comparison | Distance-independent crease cue, but it also darkens far terrain around near silhouettes (halos), and its pixel radius has no physical scale | Not adopted |
| Planar projected and blob shadows | Blinn 1988, "Me and My (Fake) Shadow" `[Unverified]` | Reuses existing geometry | The decorative plants already carry a soft ground footprint. Leaning it away from the sun gives grounding with no new pass and no overlap darkening | **Adopted** (plants only) |
| Forgiving diffuse (half-Lambert, ambient cube) | Mitchell, McTaggart and Green 2006, *Shading in Valve's Source Engine* (slides *verified* to exist) | ALU only | Tactical material light already has hemispheric fill. Retuning it would move every accepted material contract | Not changed |
| Large-scale sky visibility on slopes | Standard irradiance result: an unoccluded plane at slope θ sees (1+cos θ)/2 of the sky | ALU only | Hills read as flat cards; their feet should settle into the ground | **Adopted** as a bounded "relief" term |
| Tone mapping (ACES, AgX, Khronos PBR Neutral) | Lottes, GDC 2016 (session *verified*); Khronos and AgX comparisons (secondary) | ALU only | These map HDR scene light to the display. Scenery here is already display-referred 8-bit sRGB | **Adopted** only as a bounded, hue-preserving contrast and vibrance grade; strengthened at Nell's request |
| Bloom (pyramidal, dual filter) | Jimenez 2014, CoD: AW (*verified* abstract); Bjørge 2015, ARM (secondary) | 4–6 half-resolution passes | Spreads effect light over neighbouring pixels, including visible actors, lowering their contrast. The Tactical contract already excludes bloom | Rejected |
| Dither noise | Jimenez 2014, interleaved gradient noise. The constants are reproduced from widely circulated secondary code and were not checked against the deck | ALU only | Fixed per pixel, so captures stay deterministic. The constants only seed the jitter, so a wrong digit would change the noise pattern, not correctness | Used for ray and AO jitter only |
| Cloud shadows, gradient fog | *Firewatch* (Campo Santo, GDC 2015; secondary) | ALU only | Aerial perspective already exists. Cloud patches vary terrain contrast behind actors (a conspicuity change) | **Adopted** at Nell's request (2 November 2026): static, world-anchored patches on terrain only |
| Actor shadows | (any of the above) | — | Extends a vehicle's visual footprint beyond its original silhouette, a spotting aid of the same class as the effect-ownership union reverted on 15 October | **Adopted** at Nell's request (2 November 2026), screen-space only, so only visible vehicle pixels cast |

Bend's downloadable code was not used or transliterated. The shader was written from the
published description, so no third-party code licence applies (`release-rights.md`).

## Implementation

1. **Source-depth target** (`pc_tactical_light.gd`, `pc_tactical_depth.gdshader`). A
   second non-multisampled viewport redraws the existing ownership mesh, in the same
   original painter order and with the same camera. Each pixel's last writer is
   therefore the same visible original object as in the ID mask. It stores a 22-bit log2
   forward depth and a 2-bit light class:
   - static scenery casts;
   - source terrain casts and receives;
   - actor polygons cast but never receive;
   - sprites and round commands write nothing usable. Their runs are unprojected at a
     fixed 1024 depth, so their depth would be false. Bitmap-drawn vehicles therefore
     cast no shadow.

   The class comes from `UV2.y` of the ownership mesh, which the ID mask ignores. The
   shader pre-inverts Compatibility's
   `linear_to_srgb(srgb_to_linear_cubic(ALBEDO))` transfer (Godot 4.7.2
   `drivers/gles3/shaders/tonemap_inc.glsl`) so each byte lands exactly. The target
   follows the ownership mask's lifecycle: prepared with it, retained on exact-packet
   cache hits, and cleared with it.
2. **Shade quad** (`pc_tactical_light.gdshader`). A full-screen multiply-blend quad in the
   scenery viewport. In the alpha pass it is the last priority-1 item: after the
   decorative foliage, before the smoke and debris batch. It writes only on source
   terrain and the original ground background, and discards everywhere else. It applies
   five terms:
   - a 32-step screen-space sun shadow over visible scenery and vehicle depth;
   - an attached shadow on faces turned from the sun;
   - 8-tap contact occlusion within 96 raw units, from scenery and vehicles;
   - the slope relief term;
   - static cloud shadow. A three-octave value-noise field (5,200 raw-unit scale) sits
     at a fixed cloud height of 9,000 raw units in source-world coordinates and is
     projected down the sun direction. It removes up to 78% of the sun, never
     double-darkens ground already in shadow, and softens with distance. It has no
     clock, so it moves only as the camera does.

   Full sun loss multiplies by (0.70, 0.75, 0.86), so open-sky fill replaces direct sun.
   Local terms fade out between 9,000 and 24,000 raw units, and cloud shadow between
   40,000 and 110,000. The result is clamped at ≥ 0.5 and never brightens.
3. **Sun-leaning plant footprints** (`pc_tactical_foliage.gdshader`). Each footprint is
   stretched away from the shared sun by plant height × cot(sun elevation), anchored at
   the root, with opacity raised from 0.26 to 0.34. The quad, its alpha shape and its
   verified-grass gate are unchanged.
4. **Grade** (`pc_tactical_grade.gdshaderinc`, used by `pc_tandem_frame.gdshader`).
   Applied only inside the world rectangle, under the UI mask, while the light is active.
   It is a luminance S-curve `l − 0.22·sin(2πl)/2π`, whose slope stays within 0.78–1.22,
   strengthened from 0.10 at Nell's request. It also lifts muted colours by up to 30% and
   adds a warm-light, cool-shade split. The split tone carries no luminance and fades out
   toward white. An earlier draft let it clip near-white channels, which collapsed
   grey-ramp slope to 0.06; a numeric check caught this before any capture. Computed
   luminance slopes over grey, olive, sky, road, red and grass ramps are 0.77–1.225, and
   every channel is non-decreasing.
5. **Gating.** Only the Play viewer enables the light. It needs Tactical, the Modern
   catalogue and the observed daylight horizon (sky 5 over ground 8). Thermal and other
   palettes keep their preceding rendering. `--no-tactical-light` turns everything off
   and restores the preceding Tactical pixels. Standalone renderer tests keep it off. The
   setting is part of the mesh-cache key and of the retained-composition key. There is no
   clock and no use of `TIME`, so pause, menus, focus and captures need no hold rules.
   Startup prewarms both new programs; the shade quad is admitted only when it visibly
   darkens an opaque target.

## Evidence

Collected locally on 2 November 2026 (Apple GPU, gl_compatibility). Artefacts are in
`artifacts/gorgeous-20261102/`.

- `test_pc_tactical_light.gd` replays all 32 recorded scenario and station packets
  through the production viewer, without the emulator. It passed **252 checks with
  0 errors**. 27 cases are daylight-active; scenario 3 and the scenario 6 gunner view do
  not show the daylight horizon and stay byte-identical. Results:
  - the shade quad changed pixels only on terrain or ground background, and brightened
    none;
  - the plant footprints changed pixels only on source terrain or ground background;
  - depth coverage matched the ownership mask at every pixel;
  - the source-depth encoding round-tripped with a worst error of 0 codes across
    20–120,000 raw units;
  - inserting a dynamic actor, or static scenery, wholly concealed behind a later static
    object (0 visible ownership pixels) left the lit scenery **byte-identical**;
  - a visible vehicle-sized card standing on open ground in a real view changed only
    terrain pixels beside it, all of them darker. Its own pixels stay unshaded;
  - every shader copy of the Tactical sun matches;
  - the production grade function, rendered over five 8-bit ramps, has no channel
    reversal and stays within 0.76–1.24 luminance slope per 32-level stride, allowing one
    output step;
  - the retained final composition recomposes when the light is toggled on an identical
    packet, and switching back restores the frame byte for byte.
- Final Tactical captures differ from the pre-change baseline in exactly the 27 daylight
  views, and only inside the 3D view for all four stations. Cupola armour, the driver
  housing and instruments, the reticle, labels and HUD panels are unchanged.
- **Timing.** Whole-frame synchronised redraw at 1280×485, ABBA ×8 with the shade quad
  visible or hidden, in four runs: 2.14 vs 1.60, 2.20 vs 2.33, 1.82 vs 1.77 and
  1.96 vs 1.80 ms. The quad's cost is within whole-frame noise on this machine. This is not
  GPU-isolated, and it is not a moving-gameplay FPS measurement. After vehicle shadows
  (32 march steps) and horizon-wide cloud shadow were added, three further runs
  measured 5.25 vs 4.31, 5.91 vs 4.58 and 5.54 vs 4.72 ms: about +1 ms, with two
  other Godot processes running. Dropping back to 20 steps is the first lever if that
  matters. Startup prewarm adds
  the two programs at 165 ms (depth) and 220 ms (shade, two draws); before this change
  the Tactical prewarm rows took about 1.73 s.
- **Regression gates** (`artifacts/gorgeous-20261102/gates/summary.txt`), all with
  0 script or shader errors:
  - native: Modern startup prewarm (PASS, prewarmed=true, every row admitted), Modern
    (159,125 checks), graphics modes (10,254,550 checks, 158 frames), tandem frame
    (384,000 exact RGB checks), presentation reuse (1,470), cow visibility (128) and
    environment polish (63);
  - headless: draw pass, Tactical world, presentation reuse, river viewer, graphics
    modes, tandem frame, Modern, cow visibility and information art.

  The packaging suite (27 tests, including source closure) and the Git boundary check
  also pass.

## Limits

- Screen-space shadows cannot see off-screen or concealed casters. That is the intended
  fidelity property, not a defect, but it means shadows from scenery behind the camera
  never appear.
- At typical engagement ranges (thousands of raw units), a 96-unit contact radius is
  below one ground pixel, so distant contact shading is physically absent. The visible
  gains are the near-field plants, near hills and buildings, hill relief and the grade.
- Actors cast but are never darkened, so a tank under a building's shadow or a cloud
  patch stays sunlit. Making actors receivers is the next step if wanted.
- Vehicle shadows are screen-space, so they need the ground just beyond the vehicle
  (toward the sun) to be visible. Their reach is limited by the assumed thickness behind
  the visible surface (140 + t/2 raw units). Bitmap-drawn distant vehicles cast nothing.
  A flat test card's shadow shows faint per-pixel stipple from the jittered march.
- The Web edition and standalone builds were not rebuilt; nothing was published. The
  new shaders use `inverse(mat3)`, flat varyings and 22-bit float arithmetic, all valid
  GLSL ES 3.00, but they have not been compiled on WebGL 2.

Working if: the 32-case `test_pc_tactical_light.gd` replay reports 0 errors, including
terrain-only shade, no brightening, the byte-identical concealed actor and scenery, a
visible vehicle shading the terrain beside it, the grade-ramp bounds and composition
retention.
Modern and `--no-tactical-light` scenario captures are pixel-identical to their pre-change
baselines, and Tactical daylight frames show sun-leaning plant shadows and settled hill
feet.
