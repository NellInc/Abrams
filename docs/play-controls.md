# Remaster controls

Open `Abrams.app` and click **Play**, or use `Play.command` in an equipped
source checkout. The Audio, Session and Graphics menus sit outside the original
display. On macOS they appear in the system menu bar. They reserve no
original game keys; menu navigation is withheld from the game until keys are
released. The original continues running while a menu is open. Use its pause
control first when you need time to choose.

## Keyboard shortcuts

| Action | macOS | Other platforms |
| --- | --- | --- |
| Quick save to slot 1 | **Cmd+S** | **Ctrl+Alt+S** |
| Quick load from slot 1 | **Cmd+L** | **Ctrl+Alt+L** |
| Undo last load | **Cmd+Shift+L** | **Ctrl+Alt+Shift+L** |
| Cycle EGA → Genesis → Upscaled → Modern | **Cmd+G** | **Ctrl+Alt+G** |

Shortcuts work in Play, including fullscreen, menus and briefings. A brief
on-screen message confirms the action. Graphics changes immediately and skips
unavailable modes. Holding a shortcut never repeats saves or switches.
The chord is withheld from the original game until its keys are released; bare
S, L, G and the original function keys remain unchanged. Quick save overwrites
slot 1 while retaining its preceding archive. Use Session for slots 2 to 5.

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
`slot-N.previous.zip`; the normal menu shows the current version only.

Checkpoint operations briefly stop source execution and mute presentation audio.
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
The original auto-save and Take R+R system remains available independently.

New checkpoints preserve validated host-side EGA artwork ownership alongside
native state. Save/load, cross-process continuation and campaign rollback are
checked against uninterrupted original rendering. Fresh scanlines regenerate
display masks; pending audio and partially observed drawing candidates are not
replayed. Legacy same-core checkpoints without the ownership companion remain
loadable with conservative original-pixel fallback. Older core fingerprints
remain incompatible. Keyboard shortcuts use this same checkpoint path.

## Fast forward

Choose **Session > Fast forward > Normal speed, 2x, 4x or 8x**.
Every original frame still executes in order at the same emulated CPU settings.
The multiplier batches that many frames per presentation request, holding the
current keys through the batch. Actual acceleration depends on machine load.
This control is separate from the original Shift+3 speed setting.

Fast forward mutes effects, speech, motors and music. Event identities still
advance, so returning to normal does not play accumulated calls or gunshots.
Current motor loops and eligible frontend music can resume. Normal speed is
restored on a fresh launch; fast forward is not a sticky preference.

## Graphics

Choose **Graphics > EGA, Genesis, Upscaled or Modern** during play, menus or briefings.
The current frame is recomposed immediately from preloaded artwork, with no
restart, new game input or extra original frame.

* **EGA**: the untouched PC framebuffer and source lettering.
* **Genesis**: authentic extracted, original-resolution Genesis donor artwork
  wherever a verified counterpart exists. PC geometry, controls, values and
  unsupported imagery stay original. This does not run the Genesis game.
* **Upscaled**: the high-resolution remaster, including original-style outlines.
* **Modern**: refined low-poly scenery, illustrated trees and a muted battlefield
  palette, with the restored Upscaled interfaces. Available when its source-pinned
  resources are installed. Source sensor palettes retain conservative original rendering.

Upscaled is the default. Without an imported Genesis ROM, the standalone app
offers EGA, PC-only Upscaled and Modern when its assets are installed; the shortcut skips Genesis. In an equipped
checkout, `./Play.command --graphics ega` (or `genesis`, `upscaled` or `modern`) selects the
starting mode. Missing or invalid graphics resources leave the current mode
unchanged. See [graphics coverage](graphics-modes.md).

## Scenery quality

**Graphics > Antialiasing** selects Off, 2×, 4× or 8× MSAA. **Graphics > Anisotropic
filtering** selects Off, 2×, 4×, 8× or 16×. Defaults are 4× MSAA and 16× filtering.
Changes apply immediately and are saved for the next launch, separately from
campaigns and checkpoints. Lower MSAA if your GPU struggles with it.

Antialiasing affects the Upscaled and Modern 3D scenery, including the opening
menu preview. EGA and Genesis remain pixel-sharp. The cockpit text, source colour
tables and original visibility masks retain exact sampling. Filtering improves
the sampled road, water, building surfaces and illustrated trees; procedural
grass stays texture-free.

## Audio

The Audio menu provides Master, Sound effects, Crew voices, Engine and turret,
and Music controls. The mix persists separately from campaign saves. Original
F5 and pause still govern gameplay audio. Frontend music has its own Music and
Master gates, and stays silent on unrecognized screens and during simulation.
The four new arrangements use individual samples, including extracted Genesis
percussion. They are authored arrangements, not recovered original scores.

## Verification boundary

Local checkpoint tests cover native continuation, held/released keys,
cross-process reload, exact campaign-disk restoration, rejected corrupt or
incompatible states and recovery after native rejection. Graphics checks cover
158 original transition fixtures. Production-viewer integration separately checks
same-frame switching and identical original RAM/video after fifteen frames at
normal speed versus 1+2+4+8-frame requests. These are bounded checks, not a claim
that every mission or campaign has been completed.
