# Presentation audio controls

Play's **Audio** menu has four independent levels: master, sound effects, crew
voices, and engine/turret motors. Each offers Off and 10% steps through 100%.
Restore default mix returns all four to 100%, preserving the previous authored
mix (including its existing 0.65 overall gain). No music control is exposed while
the music implementation remains unfinished.

macOS uses the system menu bar, leaving the game image untouched. The non-native
fallback reserves a small header above the largest complete 4:3 game view. No
new keyboard accelerator replaces an original game command. Menu-navigation
keys are withheld from the original, and a closing Enter/Escape must be released
before another game command can be forwarded. Source stepping policy remains
one frame at a time; no pause command, speed setting or gameplay value is sent
by the mix controls. Use the original game's pause when desired.

The presentation menu uses Godot's standard
[MenuBar](https://docs.godotengine.org/en/stable/classes/class_menubar.html) and
[PopupMenu](https://docs.godotengine.org/en/stable/classes/class_popupmenu.html)
APIs. Native OS typography is used outside the original game; source-faithful
cockpit/menu lettering is unchanged.

## Behaviour and persistence

Changing a level updates already-playing streams immediately. Off stops the
selected stream category. Source events are still consumed once while their
presentation gain is zero; raising gain cannot replay old effects or speech.
Continuous motors resume only while their original sound channels are active.
Original F5, pause, departed SIM epochs and invalid audio envelopes retain their
mute/fail-closed authority. User gain changes never clear that source gate.

Preferences live in Godot's `user://pc_audio.cfg`, separately from the original
PC filesystem overlay and campaign files. Missing preferences use the previous
mix. Invalid preferences use defaults and show a menu notice. A failed save
retains the chosen session levels and shows the failure. Diagnostic `--capture`
launches use defaults and do not read or write the user's preferences. Native UI
acceptance explicitly selects its own artifact-local config file.

The shared range audio base gains default to 1.0, preserving the separate
calibration range. Source-dependent motor control remains in `pc_audio.gd`.

## Verification

* `pc-audio-mix-unit-02/report.json`: 97 checks, zero errors. Covers pre-ready
  preference loading, exact default/live gains, zero-volume stop, no one-shot
  catchup, original gate priority, separate category controls, configuration
  reload/failure and menu-key release. Native stream construction is exercised.
* `pc-audio-mix-work-01/scheduling.log`: 82 checks, zero errors. The production
  scheduler continues neutral source input while presentation menus own keys,
  then resumes fresh original controls. No batching/catchup policy was changed.
* `pc-audio-mix-native-02/mix-report.json`: nine gain changes during the existing
  1,020-frame live native control route. All compared input requests and complete
  framebuffer-paired RAM/video records match `pc-play-final-controls-02`.
  `image-comparison.json` also proves every decoded pixel of the final original,
  paired, tandem and world images unchanged. Process exit 0, no script errors.
* `pc-audio-menu-native-04/menu-report.json`: all 15 checks pass after actual
  macOS menu clicks set effects to 40% and voices to 70%. The players change,
  saved configuration reloads exactly, and the diagnostic's frozen original
  frame/state remain unchanged. Native menu consumes no game pixels. A fresh
  non-native menu is also rendered above the intact 4:3 cockpit. This does not
  establish Windows/Linux backend support. The native menu was inspected through
  accessibility; its screenshot API was unavailable. The fallback image was
  captured and visually inspected.
* `validation-20260928T101218Z`: all 41 stages, 286 Python tests, 642 existing
  Godot audio checks, 97 mix checks and 82 scheduling checks pass, terminal 0.
  Original reference preservation remains exact.

The live mix run measured 47.53 fps, compared with 57.93 in the earlier matched
route. These different-time runs are not a controlled performance A/B. Sustained
pacing and historical speed calibration remain open; no 60 fps claim is made.

Working if: mix changes affect only audible presentation, leave original
input/state/render records unchanged for the same delivered controls, retain the
original sound gate, and persist separately from original game saves.
