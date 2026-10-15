// Local-only Pyodide transport for the unchanged desktop source observers.
// No visitor file, trace or game state is sent to the hosting server.
//
// One Pyodide runtime is loaded per worker: the interpreter, Pillow, the
// observer source tree and the manifest-verified originals are installed once.
// Each original timeline (cold boot or checkpoint restore) gets its own fresh
// BrowserObserver inside that runtime; destroy() releases the old one.
export async function loadObserverRuntime(gameZip) {
  const runtime = new URL('./.generated/pyodide/', import.meta.url);
  const node = typeof process !== 'undefined' && process.versions?.node;
  const {loadPyodide} = await import(node
    ? '../.runtime/pyodide/node_modules/pyodide/pyodide.mjs'
    : './.generated/pyodide/pyodide.mjs');
  const pyodide = await loadPyodide(node ? {} : {indexURL: runtime.href});
  await pyodide.loadPackage('pillow');
  const [source, manifestResponse, buildResponse] = await Promise.all([
    fetch(new URL('./.generated/python-source.zip', import.meta.url)),
    fetch(new URL('./.generated/game-inputs.json', import.meta.url)),
    // Declares the core's SIM event packet format (full RAM or window bundles).
    fetch(new URL('./.generated/build-info.json', import.meta.url)),
  ]);
  if (!source.ok || !manifestResponse.ok || !buildResponse.ok)
    throw new Error('Browser source observer package is incomplete');
  const manifest = await manifestResponse.json();
  const buildInfo = await buildResponse.text();
  pyodide.FS.mkdir('/repo');
  pyodide.FS.writeFile('/source.zip', new Uint8Array(await source.arrayBuffer()));
  pyodide.FS.writeFile('/original.zip', gameZip);
  pyodide.globals.set('manifest_json', JSON.stringify(manifest));
  pyodide.globals.set('build_info_json', buildInfo);
  pyodide.runPython(`
import json, os, sys, zipfile
from pathlib import Path
with zipfile.ZipFile('/source.zip') as source:
    source.extractall('/repo')
os.remove('/source.zip')
sys.path.insert(0, '/repo')
from browser_observer import BrowserObserver, install_originals
install_originals(Path('/original.zip').read_bytes(), json.loads(manifest_json))
os.remove('/original.zip')
del manifest_json
build_info = json.loads(build_info_json)
del build_info_json

class ObserverSession:
    def __init__(self, frame_base):
        self.observer = BrowserObserver(build_info)
        self.observer.frame = frame_base
        self.program_name = None

    def before(self, ram):
        return json.dumps(self.observer.before_frame(ram.to_bytes()))

    def after(self, packet, receipts, paired_ram, current_ram, video, width, height, pitch, final):
        sample = self.observer.after_frame(
            packet.to_bytes(), receipts.to_bytes(), paired_ram.to_bytes(),
            current_ram.to_bytes(), video.to_bytes(), width, height, pitch, final=bool(final))
        if sample is None:
            return None
        program = sample['program']
        self.program_name = program['name'] if program else None
        return json.dumps(sample, separators=(',', ':'))
`);
  const Session = pyodide.globals.get('ObserverSession');
  return {
    // Returns a fresh observer timeline that starts counting at frameBase.
    createObserver(frameBase = 0) {
      let session = Session(frameBase);
      // Bind the per-frame methods once; destroy() releases every proxy.
      let before = session.before;
      let after = session.after;
      return {
        beforeFrame(ram) {
          return JSON.parse(before(ram));
        },
        // Returns the sample JSON text on a final frame, otherwise undefined;
        // audio events of non-final frames stay queued for the next sample.
        afterFrame(packet, receipts, pairedRam, currentRam, video, width, height, pitch, final = true) {
          return after(packet, receipts, pairedRam, currentRam, video,
            width, height, pitch, final) ?? undefined;
        },
        get programName() { return session?.program_name ?? null; },
        destroy() {
          if (!session) return;
          before.destroy();
          after.destroy();
          session.destroy();
          session = before = after = null;
        },
      };
    },
  };
}

export async function createObserver(gameZip, frameBase = 0) {
  return (await loadObserverRuntime(gameZip)).createObserver(frameBase);
}
