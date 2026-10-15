// The Godot Web bridge has the same bounded request/response shape as the
// desktop pipe. Visitor game data stays inside this browser origin.
const MAX_QUEUE = 8;
const MAX_JSON = 8192;

function parseObject(json) {
  if (typeof json !== 'string' || json.length > MAX_JSON) return null;
  try {
    const value = JSON.parse(json);
    return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
  } catch { return null; }
}

export function createBridgeHost(zip, catalog, buildId, onStatus, onControls) {
  const worker = new Worker(new URL('./bridge_worker.mjs', import.meta.url), {type: 'module'});
  const queue = [];
  const controls = [];
  let takenFrame = null;
  let ready = false;
  let failed = false;
  let closed = false;
  let pending = null;
  let firstResolve;
  let firstReject;
  const first = new Promise((resolve, reject) => { firstResolve = resolve; firstReject = reject; });
  let viewerResolve;
  let viewerReject;
  const viewerReady = new Promise((resolve, reject) => { viewerResolve = resolve; viewerReject = reject; });
  // Consumers may attach startup handlers after creation or never await viewerReady.
  first.catch(() => {});
  viewerReady.catch(() => {});
  function fail(message) {
    if (closed || failed) return;
    failed = true;
    ready = false;
    pending = null;
    takenFrame = null;
    queue.length = 0;
    controls.length = 0;
    queue.push({packet: {type: 'error', message}, rgb: null});
    firstReject(new Error(message));
    viewerReject(new Error(message));
    worker.terminate();
    onStatus?.({type: 'error', message});
  }
  worker.onerror = event => {
    if (closed || failed) return;
    fail(`Original PC worker failed: ${event.message}`);
  };
  worker.onmessage = event => {
    if (closed || failed) return;
    const message = event.data;
    if (!message || typeof message !== 'object') { fail('Invalid original worker message'); return; }
    if (message.type === 'progress') { onStatus?.(message); return; }
    if (message.type === 'error') { fail(String(message.message || 'Original PC worker failed')); return; }
    if (message.type !== 'packet') return;
    const packet = message.packet;
    if (!packet || typeof packet !== 'object' || typeof packet.type !== 'string') {
      fail('Invalid original worker packet'); return;
    }
    if (message.rgb && (!(message.rgb instanceof Uint8Array) || message.rgb.byteLength !== 320 * 200 * 3)) {
      fail('Invalid original RGB frame'); return;
    }
    // Sample packets arrive already serialised once by the observer; packet is
    // then only their small envelope for status and request matching.
    if (message.json !== undefined && (typeof message.json !== 'string' || message.json[0] !== '{')) {
      fail('Invalid original worker packet'); return;
    }
    if (queue.length >= MAX_QUEUE) { fail('Original bridge response queue is full'); return; }
    queue.push({packet, json: message.json ?? null, rgb: message.rgb || null});
    if (pending === packet.id) pending = null;
    if (packet.type === 'ready') { ready = true; firstResolve(); }
    onStatus?.(packet);
  };
  try { worker.postMessage({op: 'boot', zip, catalog, buildId}, [zip.buffer, catalog.buffer]); }
  catch (error) { fail(`Original PC worker could not start: ${error.message}`); }
  return {
    first,
    viewerReady,
    attach() { return ready && !failed && !closed; },
    presentationReady() {
      if (!ready || failed || closed) return false;
      viewerResolve(); return true;
    },
    send(json) {
      if (!ready || failed || closed || pending !== null || queue.length >= MAX_QUEUE) return false;
      const message = parseObject(json);
      if (!message || !['step', 'save_state', 'load_state', 'load_previous'].includes(message.op) ||
          !Number.isSafeInteger(message.id) || message.id < 0) return false;
      if (message.op === 'step') {
        if (!Number.isInteger(message.frames) || message.frames < 1 || message.frames > 600 ||
            !Array.isArray(message.keys) || message.keys.length > 16 ||
            message.keys.some(key => typeof key !== 'string') || new Set(message.keys).size !== message.keys.length) return false;
      } else if (!Number.isInteger(message.slot) || message.slot < 0 || message.slot > 5 ||
                 (message.op !== 'load_state' && message.slot === 0)) return false;
      try { worker.postMessage(message); pending = message.id; return true; }
      catch (error) { fail(`Original PC worker send failed: ${error.message}`); return false; }
    },
    take() {
      if (closed || !queue.length) return '';
      const item = queue.shift();
      try {
        const json = item.json ?? JSON.stringify(item.packet);
        takenFrame = item.rgb;
        return json;
      } catch { fail('Invalid original bridge response'); return ''; }
    },
    takeFrame() { const frame = takenFrame; takenFrame = null; return frame; },
    queueControl(value) {
      if (!ready || failed || closed || controls.length >= MAX_QUEUE) return false;
      try {
        const json = JSON.stringify(value);
        if (!parseObject(json)) return false;
        controls.push(json); return true;
      } catch { return false; }
    },
    takeControl() { return closed ? '' : controls.shift() || ''; },
    updateControls(json) {
      if (closed || failed) return false;
      const value = parseObject(json);
      if (!value) return false;
      onControls?.(value); return true;
    },
    close() {
      if (closed) return true;
      closed = true;
      if (!failed) worker.terminate();
      worker.onmessage = null;
      worker.onerror = null;
      ready = false;
      pending = null;
      takenFrame = null;
      queue.length = 0;
      controls.length = 0;
      const error = new Error('Original PC bridge closed before startup completed');
      firstReject(error);
      viewerReject(error);
      return true;
    },
  };
}
