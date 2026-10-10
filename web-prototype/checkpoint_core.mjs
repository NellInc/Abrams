// Local-only checkpoint adapter for the pinned DOSBox Pure overlay ABI.
const overlayPath = '/saves/abrams-ref.pure.zip';
const maxState = 128 * 1024 * 1024;
const maxOverlay = 32 * 1024 * 1024;

async function sha256(bytes) {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
}

function currentRam(core) {
  const pointer = core._abrams_web_ram_now();
  if (!pointer || core._abrams_web_paired_ram_size() !== 640 * 1024)
    throw new Error('The original RAM map is unavailable');
  return core.HEAPU8.slice(pointer, pointer + 640 * 1024);
}

export async function captureCheckpoint(core, frames) {
  if (core._abrams_web_flush_overlay() !== 1)
    throw new Error('The original game disk could not be flushed');
  const size = core._abrams_web_state_size();
  if (!size || size > maxState) throw new Error('Invalid original emulator state size');
  const pointer = core._malloc(size);
  if (!pointer) throw new Error('Unable to allocate checkpoint memory');
  let state;
  try {
    if (core._abrams_web_save_state(pointer, size) !== 1)
      throw new Error('The original emulator rejected this checkpoint');
    state = core.HEAPU8.slice(pointer, pointer + size);
  } finally {
    core._free(pointer);
  }
  const overlay = core.FS.analyzePath(overlayPath).exists
    ? core.FS.readFile(overlayPath) : new Uint8Array();
  if (overlay.byteLength > maxOverlay) throw new Error('Original game disk overlay is too large');
  return { version: 1, frames, state, overlay, ramSha256: await sha256(currentRam(core)) };
}

export async function restoreCheckpoint(core, checkpoint) {
  const { state, overlay, ramSha256, frames } = checkpoint || {};
  if (checkpoint?.version !== 1 || !(state instanceof Uint8Array) ||
      !(overlay instanceof Uint8Array) || !state.byteLength ||
      state.byteLength > maxState || overlay.byteLength > maxOverlay ||
      !Number.isSafeInteger(frames) || frames < 0 ||
      !/^[0-9a-f]{64}$/.test(ramSha256))
    throw new Error('Invalid local checkpoint');
  if (overlay.byteLength) core.FS.writeFile(overlayPath, overlay);
  else if (core.FS.analyzePath(overlayPath).exists) core.FS.unlink(overlayPath);
  const pointer = core._malloc(state.byteLength);
  if (!pointer) throw new Error('Unable to allocate restore memory');
  try {
    core.HEAPU8.set(state, pointer);
    if (core._abrams_web_restore_state(pointer, state.byteLength) !== 1)
      throw new Error('The original emulator rejected the checkpoint');
  } finally {
    core._free(pointer);
  }
  if (await sha256(currentRam(core)) !== ramSha256)
    throw new Error('Restored original RAM does not match the checkpoint');
  return frames;
}
