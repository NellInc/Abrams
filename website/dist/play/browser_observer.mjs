// Local-only Pyodide transport for the unchanged desktop source observers.
// No visitor file, trace or game state is sent to the hosting server.
export async function createObserver(gameZip, frameBase = 0) {
  const runtime = new URL('./.generated/pyodide/', import.meta.url);
  const node = typeof process !== 'undefined' && process.versions?.node;
  const {loadPyodide} = await import(node
    ? '../.runtime/pyodide/node_modules/pyodide/pyodide.mjs'
    : './.generated/pyodide/pyodide.mjs');
  const pyodide = await loadPyodide(node ? {} : {indexURL: runtime.href});
  await pyodide.loadPackage('pillow');
  const [source, manifestResponse] = await Promise.all([
    fetch(new URL('./.generated/python-source.zip', import.meta.url)),
    fetch(new URL('./.generated/game-inputs.json', import.meta.url)),
  ]);
  if (!source.ok || !manifestResponse.ok) throw new Error('Browser source observer package is incomplete');
  const manifest = await manifestResponse.json();
  pyodide.FS.mkdir('/repo');
  pyodide.FS.writeFile('/source.zip', new Uint8Array(await source.arrayBuffer()));
  pyodide.FS.writeFile('/original.zip', gameZip);
  pyodide.globals.set('manifest_json', JSON.stringify(manifest));
  pyodide.globals.set('frame_base', frameBase);
  pyodide.runPython(`
import json, sys, zipfile
from pathlib import Path
with zipfile.ZipFile('/source.zip') as source:
    source.extractall('/repo')
sys.path.insert(0, '/repo')
from browser_observer import BrowserObserver, install_originals
install_originals(Path('/original.zip').read_bytes(), json.loads(manifest_json))
observer = BrowserObserver()
observer.frame = frame_base
def observer_before_frame_js(ram):
    return json.dumps(observer.before_frame(ram.to_bytes()))
def observer_after_frame_js(packet, receipts, ram, video, width, height, pitch):
    return json.dumps(observer.after_frame(
        packet.to_bytes(), receipts.to_bytes(), ram.to_bytes(),
        video.to_bytes(), width, height, pitch))
`);
  const before = pyodide.globals.get('observer_before_frame_js');
  const after = pyodide.globals.get('observer_after_frame_js');
  return {
    beforeFrame(ram) {
      return JSON.parse(before(ram));
    },
    afterFrame(packet, receipts, ram, video, width, height, pitch) {
      return JSON.parse(after(packet, receipts, ram, video, width, height, pitch));
    },
  };
}
