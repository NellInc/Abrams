# Abrams full-experience programme, 14 October 2026

## Assignment, scope and authority

Nell: "Proceed please. Make and execute the next long and detailed task list for improving Abrams in all aspects."

This is a new finite programme after the completed23-item reliability pass. Delivery remains local only, nothing published. Preserve original gameplay, timing, input, campaign/checkpoint authority, source visibility, all six graphics identities, Modernized visuals, original-colour EGA Upscaled and Genesis Upscaled. Keep quality defaults4x MSAA/16x anisotropy. No automatic quality reductions, new tactical knowledge or guest writes.

Checkout `/Users/nellwatson/Documents/GitHub/Abrams`, branch `codex/modern-lowpoly`, HEAD `6d6d749f9f23081ff5c285e7bb6acb59adac1194`, shared dirty source. Starting normal PCK7a14b802a9ab463474038e7d9ceb08d049d61028eb80cfcc3b4218725e08767f, BUNDLEde7eb915f8a62aa1e7485984da73bf9ac55ffdb5dfcc2d1ad7f7667667eb5e6f. Source backups/fingerprints: `artifacts/abrams-full-experience-20261014/`.

REA owns `pc_tactical_map.gdshader` and `pc_cockpit_edges.gd`, its map-variation/quiet-performance task and frozen epoch. Prepare unrelated candidates privately until actual release, then rebase onto its accepted outcome. Never install an unaccepted cache or alter its gates. Do not interrupt foreign processes. No heavy CPU/IO/browser during its subsequently named quiet tranche. No native Windows/Linux or human acoustic proof is implied by a Mac/browser check.

## Long detailed task list

### Presentation preferences and quality
1. **Remember the chosen graphics mode.** Save the explicit successful selection alongside existing HUD and quality preferences; retain legacy configuration compatibility and unchanged defaults.
2. **Keep command-line choices transient.** Original-art and explicit diagnostic graphics overrides must not overwrite the user's saved choice.
3. **Handle unavailable saved artwork gracefully.** A saved Genesis/Modern/Tactical choice must fall back to an available mode when its required import/assets are absent, while retaining the preference for a later compatible launch. Explicit invalid CLI requests still fail honestly.
4. **Reject malformed saved modes.** Accept only known string IDs, report invalid preferences, preserve strict existing sample-count validation and safe defaults.
5. **Preserve independent settings.** Changing mode, HUD, antialiasing or filtering must retain the other valid preference fields. A failed persistence write keeps the live choice and reports the failure.
6. **Expose antialiasing in browser controls.** Offer the existing0/2/4/8 levels, with current selection synchronized from Godot. Never invent a new renderer preset.
7. **Expose anisotropic filtering in browser controls.** Offer the existing0/2/4/8/16 levels and explain its grazing-angle purpose. Keep the full-quality default16.
8. **Keep quality changes presentation-only.** Validate all requested values; they must not alter original key sets, gameplay clocks or emulator request counts.

### Audio and accessible browser control
9. **Expose the presentation mixer.** Browser controls for Master, Effects, Crew, Engines/Turret and Music use the existing five Godot gains and defaults.
10. **Restore the default mix explicitly.** Reuse one native reset operation from both the native menu and browser, preserving original sound switches and source event dispatch.
11. **Explain mute/fast-forward accurately.** Show that8x transport mutes audio and original F5/pause controls remain authoritative; preserve selected gains while fast-forwarding.
12. **Report mixer/configuration persistence failures.** Keep those warnings distinct from campaign checkpoint status and retain live presentation settings.
13. **Make extended controls compact and optional.** A keyboard-accessible More controls disclosure contains audio/quality settings, avoiding a permanently oversized toolbar.
14. **Keep controls responsive and labelled.** Clear labels/current values, visible focus, readable compact layout and no horizontal overflow at desktop/640px/zoom-equivalent sizes.
15. **Recover a stopped runtime visibly.** A running bridge failure must reveal the clean reload path, preserve the actual error through engine exit and clear stale bridge state. Never leave a frozen frame presented as running.

### Desktop/portable setup and owned runtime lifecycle
16. **Recover thread-start failure.** Check `Thread.start`, restore usable buttons/busy state and show an actionable error without invoking the runtime.
17. **Handle a missing runtime immediately.** Keep the setup UI responsive and offer installation recheck rather than leaving a permanent verification spinner.
18. **Validate setup status types.** Only real boolean installation status can enable Play/Genesis import; malformed success data must not be described as verified.
19. **Add a recheck route.** Players can revalidate a repaired installation without relaunching the whole setup window, with consistent busy-state handling.
20. **Improve file-picker guidance.** PC folder versus optional-ROM modes, supported ROM extensions, readable instructions and correct switching between dialog modes.
21. **Fit setup at smaller windows.** Scrollable content, reachable action controls and sensible keyboard focus without removing existing art/credits or imposing a loading delay.
22. **Release transient About UI.** Closing or confirming About must free it; repeated opens must not accumulate hidden dialogs.
23. **Bound portable launcher output memory.** Replace unbounded `capture_output` for runtime invocation with bounded draining of stdout/stderr, retaining useful failure tails.
24. **Preserve owned process lifetime.** Setup's existing finite timeout remains; normal gameplay has no new timeout. Only the launcher's own finite child may be cleaned up on timeout, never a foreign controller/browser.

### Offline player guidance
25. **Wrap Tactical guide tabs naturally.** Fit all five sections at narrow widths, preserving Restored layout/theme when switching back.
26. **Improve Tactical multi-word search.** Match all query words across actual visible entry text/labels, so queries such as vehicle name plus weapon work; no invented or hidden data enters search.
27. **Show Tactical search result counts.** Distinguish empty results from missing guide data, keeping counts off the original game framebuffer.
28. **Add safe guide keyboard dismissal.** Escape closes the reader and is quarantined from original game input; clearing search/section changes retain predictable focus.
29. **Keep guide scrolling predictable.** Reset Tactical section/query scroll positions, retain existing texture release on section/close and avoid eager loading of unrelated illustrations.
30. **Keep guide provenance intact.** No manual specifications, scenario objectives, maps, images or original credits are rewritten. Missing content gets an honest recovery message.

### Distribution, fidelity and completion
31. **Validate distribution identities before replacement.** Check staged authored-part sizes/hashes and Web core build identity against the existing manifests, while retaining the accepted local bundle on mismatch.
32. **Reject inputs changed during packaging.** A source change during copying must not silently create a mixed bundle. Preserve the prior build and recovery data.
33. **Protect full-quality3D/HUD/art modes.** Prove untouched renderer/art resources exact; integrate only an actually accepted result from the separate map/performance owner. No extra FPS claim without an actual timing gate.
34. **Verify the changed contracts and real interactions.** Existing focused menu/quality/audio/reference/setup checks, small observed-regression tests, one bounded functional/visual batch and source/website/package safeguards. No new general test framework or repeat of unrelated green gates.
35. **Install the verified complete local candidate.** Both normal playable packs and owned web files must match the tested candidate; regenerate exact BUNDLE records, preserve rollback, exclude all diagnostic/original inputs.
36. **Update player guidance and record dispositions.** Document saved mode/fallback, browser audio/quality, setup recovery and guide search, with a per-item completion receipt and accurate local-only delivery status.

## Acceptance and proof

New behavior first, followed by minimum sufficient focused proof. Native settings round-trip/invalid config/failed save; browser audio and quality dispatch+reload persistence; startup/runtime failure recovery; portable thread/status/output/timeout regressions; Tactical guide narrow layout/search/Escape/Restored restoration; immutable original and renderer payload bookends; local BUNDLE integrity. Source-only safeguards remain intact. Runtime tests are source-paired normal original execution or clearly labelled UI-only fixtures, never conflated.

Working if: every numbered outcome has a confirming disposition, all intended local files match the verified candidate, full fidelity and Modernized remain protected, foreign tasks remain untouched, and no publication occurs.

## Status

**Complete, local only.** All36 items implemented and verified within the scoped Mac/Web/source acceptance. Both normal playablePCKs580ce332..., Godot audio loader efb917..., exact owned web files andBUNDLE3175224b.../45records independently verified. Modernized, six graphics IDs, both upscales, original gameplay/source visibility, and4x/16x full-quality defaults remain protected. Separate unaccepted Map/Edge work is excluded. Nothing published.

Root-authored/integrated work, including private worker changes and read-only Astra advice, was reconciled against the actual diff and checked by the root. Detailed receipts and retained failures: `artifacts/abrams-full-experience-20261014/`. Native Windows/Linux gameplay and human listening are unclaimed; portable-source and Mac UI checks are distinct. No newFPS/performance claim.

Nell's browser policy change is persistently applied at `/Users/nellwatson/.codex/AGENTS.md:190`: one automation browser per thread/chat, including subagents, independent profiles across threads, task-owned cleanup. The earlier exception question is superseded. Actual last own browser/context/server normally closed16:28:51.979UTC; all resource and source/package handbacks sent directly to related chats.

## Executed task dispositions

| Item | Result | Confirming evidence |
| --- | --- | --- |
| 1 | Complete | Saved mode round-trip, successful/rejected choices: Godot quality531 + actual browser preference reload |
| 2 | Complete | Godot temporary choice preserves intent; viewer CLI branch source inspected, startup uses persist=false |
| 3 | Complete | Actual Genesis -> PC-only fallback -> Genesis import reinstates preference; quality/HUD writes retain intent |
| 4 | Complete | Godot invalid mode ID/types, strict quality config and browser numeric-value validation |
| 5 | Complete | Independent quality/HUD/mode persistence and failed-write retention: Godot531; browser reload |
| 6 | Complete | Real browser MSAA default4 and explicit8/2 acknowledgements; native display mode/sample matrix |
| 7 | Complete | Real browser anisotropy default16 and explicit8 acknowledgement; all original supported levels |
| 8 | Complete | Same original one-frame cadence364 requests during controls; source packets/visibility masks unchanged in Godot |
| 9 | Complete | Five gains acknowledged by actual Godot; reload persists exact values; native mix-change notification116 |
| 10 | Complete | Shared native reset exact defaults acknowledged in browser and tested in Godot116 |
| 11 | Complete | Real8x mute explanation, normal return retains gains; original gates/source event identities remain verified |
| 12 | Complete | Godot failed config writes retain live values; Node settings warning is separate from checkpoint status |
| 13 | Complete | Real keyboard disclosure open; collapsed default; native controls remain usable |
| 14 | Complete | Actual1440/640/720 captures, no horizontal overflow; visible focus and labels reviewed |
| 15 | Complete | Actual early worker failure -> engine exit0, exact cause, closed host, disabled start, hidden dead canvas. Two-function Godot audio teardown repair7 regressions |
| 16 | Complete | Godot setup fixture forced Thread.start failure -> busy/thread cleared, safe controls restored |
| 17 | Complete | Missing runtime fails immediately, no worker starts; recheck available; native UI capture |
| 18 | Complete | Wrong status bool/string/int/null/missing values cannot enable Play; failed recheck invalidates earlier proof |
| 19 | Complete | Godot recheck guard, successful/failed status and busy controls; actual setup UI render |
| 20 | Complete | PC versus supported raw ROM picker filters/titles switching regression; importer untouched |
| 21 | Complete | Actual600x420 screenshot, controls reachable, content scroll/focus; standard native UI244 |
| 22 | Complete | Confirmed/close/canceled About release fixture; no accumulating hidden dialogs |
| 23 | Complete | Synthetic real stdout/stderr beyond pipe capacity bounded to64KiB tails, UTF8/error forwarding verified |
| 24 | Complete | 300sec setup/unlimited gameplay dispatch; verified task-owned child graceful-first/bounded terminate+kill/reap;7 regressions |
| 25 | Complete | Tactical HFlow tabs/stacked rows at320/480/640, actual320/640/960 captures; Restored container/theme restoration |
| 26 | Complete | All-token matching across rendered text/labels/pages, hidden specs excluded;45 focused guide checks |
| 27 | Complete | Tactical counts distinguish no matches/missing section/credits; actual rendered guide count |
| 28 | Complete | Escape handled, closes once, existing quarantine signal; menu270 blocks reader/held inputs |
| 29 | Complete | Scroll resets, width-bucket rerender only, section/close release, current-section texture reuse: focused45 and reference211 |
| 30 | Complete | Original guide/data/credits/images untouched; eight maps and16 models covered by existing reference/player tests and inventory |
| 31 | Complete | Staged authored-part bytes/hash and core identity match manifests, mismatch retains old bundle;9 package regressions |
| 32 | Complete | Changed-during-copy regression refuses mixed package and retains prior bytes; guarded package swap |
| 33 | Complete | 1115 other presentation payloads and all unowned Godot source exact; full4x/16x defaults, both upscales/six IDs; unacceptedMap/Edge excluded |
| 34 | Complete | Godot1173 counted checks + setup, nativeUI244, browser29, Node24, package9, Python58(1skip), source125(10skips), site72; prior failures retained |
| 35 | Complete | Both normalPCKs580c, both audio loaders efb917, exact owned webfiles and45 BUNDLE records3175224b; rollback backups preserved |
| 36 | Complete | Player graphics/audio/browser/setup/guide guidance updated; per-item evidence and actual resource/source/package handback |

## Deviations and observed repairs

Verification caught pre-tree focus, fixed-orientation HBox and short-window spacing defects; they were corrected before native UI acceptance. Existing setup-smoke/source mock locators were updated to the changed functions without weakening their expected outputs. A snapshot omission aborted the first integration before any source mutation.

Two test-observer errors were corrected: the worker's actual validation error omits the bad-key value, and a global lexical Engine binding bypasses replacement of window.Engine. Direct observation then exposed a real pinned Godot audio teardown race. The narrowly anchored exporter repair keeps the context until driver cleanup, settles absent/rejected worklet closure, always attempts context close, preserves error logging and all normal startup/mixing/licence bytes. Seven regressions plus actual clean browser exit verify it. No forced callback, quality/audio downgrade, source-clock change or relaxed gate.

The final stopped-runtime capture exposed a stale dead canvas. Reset now hides it and startup reveals it before normal sizing; focused actual recovery and Node checks pass. This does not change an active Modernized/Tactical frame.

Working if: the36 confirming dispositions map to delivered behavior, both local builds match their tested bytes, protected renderer/art/input contracts stay exact, other tasks remain untouched, and no publication occurs.
