# Remaster controls

Open `Abrams.app` and click **Play**, or use `Play.command` in an equipped
source checkout. The Audio, Session, Graphics and Help menus sit outside the original
display. On macOS they appear in the system menu bar. Tab toggles fast forward;
menu navigation is withheld from the game until keys are
released. The original continues running while a menu is open. Use its pause
control first when you need time to choose.

## Player references

**Help > Keyboard controls** opens the offline keyboard sheet. **Help > Scenarios
& vehicles** opens the searchable field guide, including all eight scenarios,
all sixteen manual vehicle entries and printable PDFs. These are also available
from setup. Pause the original game first if you want time to read.

## Keyboard shortcuts

| Action | macOS | Other platforms |
| --- | --- | --- |
| Quick save to slot 1 | **Cmd+S** | **Ctrl+Alt+S** |
| Quick load from slot 1 | **Cmd+L** | **Ctrl+Alt+L** |
| Undo last load | **Cmd+Shift+L** | **Ctrl+Alt+Shift+L** |
| Cycle available graphics modes | **Cmd+G** | **Ctrl+Alt+G** |
| Toggle 8x fast forward / normal speed | **Tab** | **Tab** |

Shortcuts work in Play, including fullscreen, menus and briefings. A brief
on-screen message confirms the action. Graphics changes immediately and skips
unavailable modes. Holding a shortcut never repeats saves or switches.
The chord is withheld from the original game until its keys are released; bare
S, L, G and the original function keys remain unchanged. Quick save writes an
empty slot 1 at once. If slot 1 already holds a save, the first press shows its
time; press the shortcut again within four seconds to overwrite it (the preceding
archive is retained). **Session > Save state** names the save each slot would
replace. Use Session for slots 2 to 5. On Windows, natively and in its browsers,
AltGr is reported as Ctrl+Alt: on keyboard layouts where AltGr+S, L or G types a
character (for example Polish ś or ł), those shortcuts are unavailable; use the
Session menu. Browsers on macOS are unaffected. The browser uses Ctrl+Alt on every
platform, because browsers intercept Command chords.

You can keep steering or firing while using a save/load shortcut. Only the
shortcut chord is withheld; unrelated held controls continue. A checkpoint
retains the original machine's held-key state, then reconciles it with your
current keys on the next frame. Releasing the trigger before loading therefore
does not leave it stuck down. Failed loads and Undo preserve this behavior.

Opening a native menu or leaving the window deliberately neutralizes game input.
After returning, release all keys once before steering or firing again. This
prevents an old key press from remaining active after focus loss. An already
sent fast-forward batch finishes unchanged; input changes apply to the next batch.

## Save states

Choose **Session > Save state > Slot 1 to 5**. Choose the corresponding entry under
**Load state** to return to it. Each checkpoint includes the native emulated
machine, original held-key state, displayed frame and writable campaign disk.
Loading therefore rewinds campaign files as well as the current mission.

Before loading, the current session is saved automatically. **Load state >
Undo last load** restores that recovery slot. A later load replaces the recovery
slot. Overwriting a numbered slot retains its preceding archive as
`slot-N.previous.zip`; when the host lists it, **Load state** also offers
**Overwritten slot N (time)**, which loads that archive (saving the current
session to Undo last load) without changing either slot file.

Checkpoint operations briefly stop source execution. A load mutes presentation
audio from the moment it is requested. A save keeps sound from frames already
played.
They run serially, report success or failure in the Session menu, and never queue
behind another checkpoint. Empty, corrupt and incompatible slots are unavailable.
A failed native restore attempts to return to the session captured immediately
before it. Catastrophic recovery failures keep temporary recovery files and stop
with a visible error rather than pretending the game continued.

Slots live in `states/` beneath the selected save directory. In the checkout,
the default is `artifacts/pc-boot-viewer/saves/states/`. The private packaged
launcher uses `~/Library/Application Support/Abrams/saves/states/`.
Preserve the whole save directory. Checkpoints are pinned to the game bytes,
native core, emulation options and platform; they are not portable interchange
files or a substitute for backups. A core update can make old states incompatible.
The core fingerprint is its pre-signing identity, so re-signing an unchanged
core keeps checkpoints compatible.
The original auto-save and Take R+R system remains available independently.

The current local core writes version-9 native checkpoints, including the DOS
calendar date used by the original game's mission selection. New checkpoints
retain that date when restored on another day. Version-8 research snapshots
remain readable, but contain no date to restore. Player slots remain pinned to
their original core; this update does not migrate old slots or alter campaign
files. Retain the prior core with any older checkpoints you need to recover.

New checkpoints preserve validated host-side EGA artwork ownership alongside
native state. Save/load, cross-process continuation and campaign rollback are
checked against uninterrupted original rendering. Fresh scanlines regenerate
display masks; pending audio and partially observed drawing candidates are not
replayed. Legacy same-core checkpoints without the ownership companion remain
loadable with conservative original-pixel fallback. Older core fingerprints
remain incompatible. Keyboard shortcuts use this same checkpoint path.

## Fast forward

Press **Tab** to toggle **8x fast forward / normal speed**, or choose either
under **Session > Fast forward**. Holding Tab toggles once. Tab navigation in
menus, setup and references is unchanged.
Every original frame still executes in order at the same emulated CPU settings.
The multiplier batches that many frames per presentation request, holding the
current keys through the batch. Actual acceleration depends on machine load.
This control is separate from the original Shift+3 speed setting.

Fast forward mutes effects, speech, motors and music. Event identities still
advance, so returning to normal does not play accumulated calls or gunshots.
Current motor loops and eligible frontend music can resume. Normal speed is
restored on a fresh launch; fast forward is not a sticky preference.

## Graphics

Choose a mode under **Graphics** during play, menus or briefings. The current frame is recomposed immediately from preloaded artwork, with no restart, new game input or extra original frame.

* **EGA**: the untouched PC framebuffer and source lettering. Tactical HUD Style does not alter it, nor EGA Upscaled or Genesis.
* **EGA Upscaled**: larger, smoother contours using only the original PC colours, including its dark skin tones.
* **Genesis**: verified original-resolution donor artwork. PC geometry, controls, values and unmatched imagery stay original. This does not run the Genesis game. Its donor pack is built from captured Genesis screens, so only an equipped checkout offers it; native apps built after 15 October 2026 and the browser list it as unavailable.
* **Genesis Upscaled** (`upscaled`): the generated high-resolution remaster artwork and restored interfaces.
* **Modern** (Modernized in browser): refined source-bound low-poly scenery with the existing restored interfaces.
* **Tactical**: the separate textured, Range-inspired battlefield treatment. **HUD Style** independently selects Restored or Tactical instruments and layouts.

The first launch uses Genesis Upscaled. A successful explicit graphics selection is remembered with HUD style and scenery quality. If its required artwork/import is unavailable on a later launch, the viewer shows Genesis Upscaled and retains the saved preference. Restoring the supported import restores that preferred mode on the next launch. An equipped checkout can use `./Play.command --graphics ega` (or another mode ID) for a transient starting choice; this does not overwrite the preference. Explicit unavailable command-line requests report an error. See [graphics coverage](graphics-modes.md).

## Scenery quality

**Graphics > Antialiasing** selects Off, 2×, 4× or 8× MSAA. **Graphics > Anisotropic
filtering** selects Off, 2×, 4×, 8× or 16×. Defaults are 4× MSAA and 16× filtering.
Changes apply immediately and are saved for the next launch, separately from
campaigns and checkpoints. Lower MSAA if your GPU struggles with it.

Antialiasing affects Genesis Upscaled, Modern and Tactical 3D scenery, including the opening
menu preview. EGA and Genesis retain their source sampling. The cockpit text, source colour
tables and original visibility masks retain exact sampling. Filtering improves
the sampled road, water, building surfaces and illustrated trees; procedural
grass in Modern stays procedural; Tactical uses its own material treatment.

## Audio

The Audio menu provides Master, Sound effects, Crew voices, Engine and turret,
and Music controls. The mix persists separately from campaign saves. Original
F5 and pause still govern gameplay audio. Frontend music has its own Music and
Master gates, and stays silent on unrecognized screens and during simulation.
The four new arrangements use individual samples, including extracted Genesis
percussion. They are authored arrangements, not recovered original scores. Native
apps built after 15 October 2026 do not include them, because the percussion
samples' redistribution rights are not established; equipped checkouts and the
browser edition keep them, once a Genesis ROM is imported or verified.

## Verification boundary

Local checkpoint tests cover native continuation, held/released keys,
cross-process reload, exact campaign-disk restoration, rejected corrupt or
incompatible states and recovery after native rejection. Graphics checks cover
158 original transition fixtures. Production-viewer integration separately checks
same-frame switching and identical original RAM/video after fifteen frames at
normal speed versus seven 1x requests and one 8x request. These are bounded checks, not a claim
that every mission or campaign has been completed.

## Browser play and recovery

Choose your original PC folder, then Start remaster. The file picker shows your selection before verification. An optional Genesis ROM unlocks the Genesis-based remaster artwork and frontend music, and the browser derives the Genesis effects from your verified ROM. Since 15 October 2026 the browser edition publishes no captured Genesis screens, so its Genesis mode, Genesis newspaper, map frame and clipboard restorations and Genesis vehicle colours keep original PC pixels (see [release rights](release-rights.md)). EGA Upscaled preserves the original PC palette and skin colours; Genesis Upscaled retains the generated high-resolution artwork. Graphics and HUD Style remain independent.

Use **Game keyboard** after interacting with browser controls to return keyboard focus to the game. **Fullscreen** keeps the browser controls available; Escape leaves browser fullscreen. Editing a browser selector does not trigger quick-save/load or graphics shortcuts.

Save slots show their saved date and original programme. Empty and incompatible slots cannot be loaded. During saving/loading, the browser disables competing checkpoint and speed actions. Undo last load retains the before-load session.

Checkpoints require browser storage permission and sufficient free space. When storage is unavailable, the original game still starts, a persistent warning explains the problem, and browser checkpoint actions are disabled for that session. No temporary in-memory checkpoint is presented as a durable save. Browser data clearing or changing origin can remove checkpoints; a page reload requires reselecting your original PC files.

Wrong original files can be corrected and retried before engine startup. A partially initialized or closed engine requires **Reload page** for a clean restart. Reloading preserves existing origin-local checkpoints; it does not keep the selected original files. Slow/missing build downloads produce bounded, actionable errors. All imported original files remain local and no original game data is uploaded.

Working if: selection and focus are visible; all six graphics options retain their identities; saved dates and storage warnings are accurate; failed loads preserve the active session until a successful commit; no public deployment occurs.

## Extended browser controls

Open **More controls: audio and graphics quality** for the same five presentation gains, antialiasing and anisotropic filtering as the native menu. The disclosure supports keyboard focus and Enter/Space; its controls wrap on compact windows. **Restore default mix** sets Master, Effects, Crew and Motors to 100%, Music to 70%. Full-quality defaults remain 4× MSAA and 16× filtering. Changes persist separately from checkpoints; a settings-save warning appears in this section, separately from campaign status.

At 8×, audio is muted while your mix is retained. Original F5 and pause remain authoritative. A stopped original worker reveals **Reload page**, preserving its actual failure message and clearing the dead bridge. Reload requires reselecting originals and retains existing origin-local durable checkpoints.

The Tactical reference reader wraps its tabs, stacks narrow rows, matches every search word across displayed text and shows entry counts. Escape closes it without forwarding that key to the original game. Clear search or choose another section to reset its scroll position. Restored retains its original styling and contiguous-query search.

## Reference clarification, 14 October 2026

The keyboard HTML and three-page printable sheet now distinguish desktop macOS Command chords from the browser's Ctrl+Alt chords. All six graphics options remain documented: EGA, EGA Upscaled (original colours), Genesis (optional ROM), Genesis Upscaled, Modern (Modernized) and Tactical. HUD style is independent. Restore full-quality defaults returns to 4× MSAA/16× anisotropic filtering while retaining mode, HUD and mix. The original 35 keyboard controls, station behavior and manual provenance are unchanged.
