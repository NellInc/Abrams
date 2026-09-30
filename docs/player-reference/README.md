# Player references

Open **Help > Keyboard controls** or **Help > Scenarios & vehicles** during play.
The launcher also offers a Field guide shortcut. Both references work offline,
with searchable entries and printable PDFs.

* [Keyboard controls](keyboard-controls.html): original station and menu keys,
  remaster shortcuts, save slots and fast forward.
* [Scenarios and vehicles](field-guide.html): all eight scenarios, all sixteen
  manual vehicle entries, ATGW, ammunition, other units and crew stations.

The catalogues paraphrase the original DOS manual. Page references use its
printed numbering. Vehicle specifications and threat ratings retain its
original game-era values. Modern vehicle studies use the remaster's current
model geometry. M113, M1A1 Abrams, M2 Bradley and M60A3 are friendly units.

## Authoring

The reviewed text is in `manual-content.json`. Generate the static references
with `python3 tools/build_player_reference.py` using a Python environment with
ReportLab. The authoring step also needs the local Modern model catalogue and
bundled Barlow font. Those inputs and the generated HTML, SVG and PDF assets
are included through the reviewed private-package allowlist. The original
manual and original games are excluded.

Players need no ReportLab installation, local server or original manual. Pause
the game before opening a reference when you want the simulation to wait.
