# Remaster controls

Open `Play.command`. The Audio, Session and Graphics menus sit outside the
original display. On macOS they appear in the system menu bar. They reserve no
original game keys; menu navigation is withheld from the game until keys are
released. The original continues running while a menu is open. Use its pause
control first when you need time to choose.

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

Choose **Graphics > EGA, Genesis or Upscaled** during play, menus or briefings.
The current frame is recomposed immediately from preloaded artwork, with no
restart, new game input or extra original frame.

* **EGA**: the untouched PC framebuffer and source lettering.
* **Genesis**: authentic extracted, original-resolution Genesis donor artwork
  wherever a verified counterpart exists. PC geometry, controls, values and
  unsupported imagery stay original. This does not run the Genesis game.
* **Upscaled**: the high-resolution remaster, including original-style outlines.
* **Modern**: disabled and explicitly labelled unavailable until new models and
  realistic assets exist.

Upscaled is the default. `./Play.command --graphics ega` (or `genesis` or
`upscaled`) selects the starting mode. Missing Genesis assets preserve the current
mode and report the failure. See [graphics coverage](graphics-modes.md).

## Audio

The Audio menu provides Master, Sound effects, Crew voices, Engine and turret,
and Music controls. The mix persists separately from campaign saves. Original
F5 and pause still govern gameplay audio. Frontend music has its own Music and
Master gates, and stays silent on unrecognized screens and during simulation.
The four new arrangements use individual samples, including extracted Genesis
percussion. They are authored arrangements, not recovered original scores.

Bearings retain complete generated sentences with digits spoken individually;
“niner” is accepted. No mixed gameplay recordings are used as live samples.

## Verification boundary

Local checkpoint tests cover native continuation, held/released keys,
cross-process reload, exact campaign-disk restoration, rejected corrupt or
incompatible states and recovery after native rejection. Graphics checks cover
158 original transition fixtures. Production-viewer integration separately checks
same-frame switching and identical original RAM/video after fifteen frames at
normal speed versus 1+2+4+8-frame requests. These are bounded checks, not a claim
that every mission or campaign has been completed.
