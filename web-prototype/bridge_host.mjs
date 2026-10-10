// The Godot Web bridge has the same bounded request/response shape as the
// desktop pipe. Visitor game data stays inside this browser origin.

export function createBridgeHost(zip, catalog, buildId, onStatus, onControls) {
  const worker = new Worker(new URL('./bridge_worker.mjs', import.meta.url), {type: 'module'});
  const queue = [];
  const controls = [];
  let takenFrame = null;
  let ready = false;
  let failed = false;
  let firstResolve;
  let firstReject;
  const first = new Promise((resolve, reject) => { firstResolve = resolve; firstReject = reject; });
  let viewerResolve;
  const viewerReady = new Promise(resolve => { viewerResolve = resolve; });
  worker.onerror = event => {
    const error = `Original PC worker failed: ${event.message}`;
    failed = true;
    queue.push({packet: {type: 'error', message: error}, rgb: null});
    firstReject(new Error(error));
  };
  worker.onmessage = event => {
    const message = event.data;
    if (message.type === 'progress') {
      onStatus?.(message);
      return;
    }
    if (message.type === 'error') {
      failed = true;
      queue.push({packet: {type: 'error', message: message.message}, rgb: null});
      firstReject(new Error(message.message));
      return;
    }
    if (message.type !== 'packet') return;
    const packet = message.packet;
    if (message.rgb) {
      if (message.rgb.byteLength !== 320 * 200 * 3) {
        failed = true;
        queue.push({packet: {type: 'error', message: 'Invalid original RGB frame'}, rgb: null});
        firstReject(new Error('Invalid original RGB frame'));
        return;
      }
    }
    queue.push({packet, rgb: message.rgb || null});
    if (packet.type === 'ready') {
      ready = true;
      firstResolve();
    }
    onStatus?.(packet);
  };
  worker.postMessage({op: 'boot', zip, catalog, buildId}, [zip.buffer, catalog.buffer]);
  return {
    first,
    viewerReady,
    attach() { return ready && !failed; },
    presentationReady() { viewerResolve(); return true; },
    send(json) {
      if (!ready || failed || typeof json !== 'string' || json.length > 8192) return false;
      const message = JSON.parse(json);
      if (!['step', 'save_state', 'load_state'].includes(message.op)) return false;
      worker.postMessage(message);
      return true;
    },
    take() {
      if (!queue.length) return '';
      const item = queue.shift();
      takenFrame = item.rgb;
      return JSON.stringify(item.packet);
    },
    takeFrame() {
      const frame = takenFrame;
      takenFrame = null;
      return frame;
    },
    queueControl(value) {
      if (!ready || failed || controls.length >= 8) return false;
      controls.push(JSON.stringify(value));
      return true;
    },
    takeControl() { return controls.shift() || ''; },
    updateControls(json) { onControls?.(JSON.parse(json)); return true; },
    close() { worker.terminate(); ready = false; takenFrame = null; queue.length = 0; controls.length = 0; return true; },
  };
}
