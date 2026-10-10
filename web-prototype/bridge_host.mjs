// The Godot Web bridge has the same bounded request/response shape as the
// desktop pipe. Visitor game data stays inside this browser origin.
function base64(bytes) {
  let output = '';
  for (let at = 0; at < bytes.length; at += 0x6000)
    output += String.fromCharCode(...bytes.subarray(at, at + 0x6000));
  return btoa(output);
}

export function createBridgeHost(zip, catalog, buildId, onStatus, onControls) {
  const worker = new Worker(new URL('./bridge_worker.mjs', import.meta.url), {type: 'module'});
  const queue = [];
  const controls = [];
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
    queue.push({type: 'error', message: error});
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
      queue.push({type: 'error', message: message.message});
      firstReject(new Error(message.message));
      return;
    }
    if (message.type !== 'packet') return;
    const packet = message.packet;
    if (message.rgb) {
      if (message.rgb.byteLength !== 320 * 200 * 3) {
        failed = true;
        queue.push({type: 'error', message: 'Invalid original RGB frame'});
        firstReject(new Error('Invalid original RGB frame'));
        return;
      }
      const encoded = base64(message.rgb);
      if (packet.type === 'state_result') packet.restored.rgb = encoded;
      else packet.rgb = encoded;
    }
    queue.push(packet);
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
    take() { return queue.length ? JSON.stringify(queue.shift()) : ''; },
    queueControl(value) {
      if (!ready || failed || controls.length >= 8) return false;
      controls.push(JSON.stringify(value));
      return true;
    },
    takeControl() { return controls.shift() || ''; },
    updateControls(json) { onControls?.(JSON.parse(json)); return true; },
    close() { worker.terminate(); ready = false; queue.length = 0; controls.length = 0; return true; },
  };
}
