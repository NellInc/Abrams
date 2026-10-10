# Abrams Web remaster

This is the desktop Godot Play viewer running in a browser with the pinned,
patched DOSBox Pure core. The original PC game remains the gameplay authority.
The visitor must choose the supported 68-file PC game folder before Play starts.
A supported Genesis ROM is optional and enables the donor graphics and frontend
music. The browser verifies both inputs locally. Original PC files and the ROM
are absent from the site bundle and are never sent to the server.

The Web edition is packaged under `website/dist/play/` and linked from the
project site. GitHub Pages deployment status must be confirmed from served
bytes; see `docs/release-rights.md` for the publication boundary.

## Build and verify

The pinned DOSBox Pure source and native trace receipt must already exist under
ignored `.runtime/`, with Emscripten 6.0.10, Pyodide 0.29.5, Pillow and the
Godot 4.7.2 Web export templates installed there. The builder rejects source
hash drift. The Godot export stages only presentation resources and launches
`pc_bridge_viewer.gd` as a Web `MainLoop`; the development range is never the
Web entry point.

```sh
source .runtime/emsdk/emsdk_env.sh
python3 web-prototype/build_core.py
python3 web-prototype/build_observer.py
python3 web-prototype/build_remaster.py
python3 web-prototype/build_web_source.py
node web-prototype/test_core.mjs
node web-prototype/test_mission.mjs
node web-prototype/test_bridge.mjs
python3 web-prototype/package_site.py
python3 website/verify.py
python3 web-prototype/serve.py
```

Open `http://127.0.0.1:4174/remaster.html` for the build output, or serve
`website/dist` and open `/play/remaster.html` to check the actual site bundle.
The build emits no original game data. The site bundle includes corresponding
source for its modified GPL Web core, has a manifest of exact file hashes and
keeps every file below Git's 100 MB object limit. Its `THIRD_PARTY.txt` links
the version-matched Godot, Pyodide, CPython, Pillow and font notices.

## Browser architecture

`bridge_worker.mjs` keeps the original DOS game, source observer and checkpoints
in a worker. It executes 238 hidden boot frames without Python observation,
then observes the final three frames before presenting the first image. The
source callback and Python observer verify frontend text, RAM, video, audio
metadata, drawing ownership and SIM overlays before Godot receives a packet.
A normal mission frame can emit more than 16 MiB of source trace, so the Web
bound is 64 MiB per frame; overflow still stops the game. The Web bridge
retains the desktop viewer's graphics, sound and menu code. Its HTML controls
provide browser-accessible graphics mode, Restored or Tactical HUD style, slot,
speed and help actions. Tactical graphics adds the Calibration Range-inspired
olive and overcast treatment, clustered hedgerows and rooted trees without changing Modern, original geometry or
source visibility. Graphics and HUD Style can be selected independently.
Tactical uses a wider, source-paired Gunner optic when the original plate and every live instrument cell verify. Any unsupported overlay returns to the complete source layout, including Commander, Cupola, Driver and status screens. The browser canvas follows the chosen layout rather than filling the whole window.

Checkpoint slots 1 to 5 and the before-last-load recovery slot are stored in
origin-local IndexedDB. Reloading the page requires choosing the original PC
folder again. A checkpoint is accepted only with its exact WebAssembly build
identity. A static host without isolation headers is supported by the local
`remaster.service.worker.js`; the page waits for an isolated reload before it
enables the game picker. No original files are cached by that worker.

## Verified locally

* The WebAssembly mission fixture reaches original scenario 6, gunner station,
  with the expected position and ammunition. Fresh-core restore and continued
  RAM parity pass. The source draw packet replays through the desktop observer.
* Chromium loaded the visitor PC folder, presented the actual Godot Play
  joystick prompt and intro, entered the original mission and rendered the
  gunner cockpit and battlefield. EGA, Upscaled, Genesis, Modern and Tactical modes were
  selected in mission; Genesis required the matching optional ROM.
* Browser save, page reload, reselect-originals and load succeeded through
  IndexedDB. A source trace overflow discovered during mission Play was fixed,
  then the previously failing frame and 300 further original frames passed.
* The packaged `/play/` page booted on a static local server without COOP or
  COEP response headers after its service worker established isolation.

These checks establish working browser gameplay, not exhaustive 1:1 acceptance
for all eight campaigns, every audio path, every browser or human listening.
This local test does not establish a live deployment. `index.html` in this
folder is the older EGA diagnostic;
`remaster.html` is the Godot Web edition.
