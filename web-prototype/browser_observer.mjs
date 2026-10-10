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
`);
  const request = expression => JSON.parse(pyodide.runPython(`json.dumps(${expression})`));
  return {
    beforeFrame(ram) {
      pyodide.FS.writeFile('/before.bin', ram);
      return request("observer.before_frame(Path('/before.bin').read_bytes())");
    },
    afterFrame(packet, receipts, ram, video, width, height, pitch) {
      pyodide.FS.writeFile('/packet.bin', packet);
      pyodide.FS.writeFile('/receipts.bin', receipts);
      pyodide.FS.writeFile('/ram.bin', ram);
      pyodide.FS.writeFile('/video.bin', video);
      return request("observer.after_frame(Path('/packet.bin').read_bytes(), " +
        "Path('/receipts.bin').read_bytes(), Path('/ram.bin').read_bytes(), " +
        `Path('/video.bin').read_bytes(), ${width}, ${height}, ${pitch})`);
    },
  };
}
