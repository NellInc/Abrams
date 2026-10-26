extends RefCounted
## Quiet, centred presentation beds. No gameplay, event or positional inference.
## Admission reads the production painter mask after its draw, never guest RAM.
const Modern = preload("res://scripts/pc_modern_assets.gd")
const CUES := ["river", "hind"]
var directory: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/pc-world-effects-v1")
var streams: Dictionary = {}
var players: Dictionary = {}
var host: Node
var pending: Dictionary = {}
var armed: Dictionary = {}
var failure: String = ""
var reads: int = 0
var last_read_usec: int = 0
var admitted: Array[String] = []
var visibility_guard: Callable
var cache_hits: int = 0
var _proof_key: Array = []
var _proof_mask: Image
var _proof_inputs: Array = []
var _proof_cues: Array[String] = []

func setup(owner: Node) -> void:
	host = owner
	if OS.has_feature("web") or directory.is_empty(): return
	var path: String = directory.path_join("manifest.json")
	if not FileAccess.file_exists(path): return
	if FileAccess.get_size(path) > 16384: reject("manifest too large"); return
	var bank: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bank is Dictionary or bank.get("schema") != 1 or bank.get("kind") != "private visible-world beds" or not bank.get("cues") is Dictionary or bank.cues.size() != CUES.size():
		reject("invalid manifest"); return
	var loaded: Dictionary = {}
	for cue: String in CUES:
		var entry: Variant = bank.cues.get(cue)
		if not entry is Dictionary or entry.get("file") != cue + ".wav" or not entry.get("sha256") is String:
			reject("invalid entry"); return
		path = directory.path_join(cue + ".wav")
		if not FileAccess.file_exists(path) or FileAccess.get_size(path) > 3000000 or FileAccess.get_sha256(path) != entry.sha256:
			reject("missing, oversized or changed PCM"); return
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != 48000 or stream.stereo or stream.data.size() < 96000 or stream.data.size() % 2 != 0:
			reject("invalid PCM format/duration"); return
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		loaded[cue] = stream
	streams = loaded # atomic publication, no partially installed bank
	for cue: String in CUES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		host.add_child(player)
		player.stream = streams[cue]
		player.bus = host.presentation_bus
		players[cue] = player
	RenderingServer.frame_pre_draw.connect(before_draw)
	RenderingServer.frame_post_draw.connect(after_draw)

func reject(reason: String) -> void:
	failure = reason
	push_warning("Private world sounds ignored: " + reason)

func stop() -> void:
	pending.clear(); armed.clear(); admitted.clear()
	_proof_key.clear(); _proof_mask = null; _proof_inputs.clear(); _proof_cues.clear()
	for player: AudioStreamPlayer in players.values():
		host._remember_playback(player)
		player.stop()

func release() -> void:
	stop()
	for player: AudioStreamPlayer in players.values(): player.stream = null
	streams.clear()
	if RenderingServer.frame_pre_draw.is_connected(before_draw): RenderingServer.frame_pre_draw.disconnect(before_draw)
	if RenderingServer.frame_post_draw.is_connected(after_draw): RenderingServer.frame_post_draw.disconnect(after_draw)

func allowed() -> bool:
	return is_instance_valid(host) and not host.muted and not host.transport_muted and host.failure.is_empty() and (not visibility_guard.is_valid() or visibility_guard.call())

func maintain() -> void:
	if not allowed(): stop()

func begin_packet() -> void:
	# A new packet without a successful world presentation silences at postdraw.
	# No new packet between draws, however, is an ordinary retained source frame.
	if not streams.is_empty(): pending = {"clear": true}
	armed.clear()

static func candidates(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not data.get("objects") is Array or not data.get("camera") is Dictionary or not data.get("unsupported") is Array or not data.unsupported.is_empty(): return result
	var actors: Dictionary = Modern.dynamic_index(data)
	for i: int in data.objects.size():
		var object: Dictionary = data.objects[i]
		var cue: String = ""
		var polygons: Array = object.get("polygons", [])
		if polygons.is_empty(): continue
		# Whole-owner identity is required: one water face cannot qualify a
		# building/riverbank face that happens to share its object ID.
		if polygons.all(func(p): return p is Dictionary and Modern.water_surface(object, p)) and object.get("round_forms", []).is_empty() and not object.has("sprite"):
			cue = "river"
		elif object.get("dynamic_instance", false) and int(object.get("shape_index", -1)) == 163:
			var actor: Variant = actors.get([int(object.get("pointer", -1)), 163])
			if actor == null or actor[1] != 1: continue
			var speed: Variant = actor[0].get("speed_raw")
			if not (speed is int or speed is float) or not is_finite(float(speed)) or speed != floorf(float(speed)) or absf(float(speed)) > 32768 or speed == 0: continue
			# Authored visible-flight ambience, not an RPM/rotor-state decoder.
			cue = "hind"
		if cue.is_empty(): continue
		result[i + 1] = {"cue": cue}
	return result

func observe(data: Dictionary, ownership: SubViewport, ui: Image, source_frame: int, source_epoch: int, guard: Callable = Callable()) -> void:
	if streams.is_empty(): return
	visibility_guard = guard
	if not allowed() or RenderingServer.get_current_rendering_method() != "gl_compatibility" or source_frame != host.last_frame or source_epoch != host.epoch or data.is_empty() or ownership == null or ui == null or ui.get_size() != Vector2i(320, 200) or ui.get_format() != Image.FORMAT_L8:
		stop(); return
	var bits: PackedByteArray = ui.get_data()
	if bits.count(0) + bits.count(255) != 64000: stop(); return
	var selected: Dictionary = candidates(data)
	if selected.is_empty() or ownership.object_count != data.objects.size() or ownership.mesh_node.mesh == null:
		stop(); return
	var token: Dictionary = {"target": ownership, "mesh": ownership.mesh_node.mesh, "size": ownership.size,
		"clip": data.camera.clip.duplicate(), "selected": selected, "ui": bits,
		"epoch": host.epoch, "frame": host.last_frame, "camera": camera_key(ownership)}
	token.proof_key = [ownership, token.mesh, token.size, token.camera, token.clip]
	# prepare() creates a fresh immutable mesh/material. This narrowly scoped
	# cache must be invalidated if that ownership path gains in-place mutation.
	# Working if: UI-only changes reclassify, new meshes reread, and mute/reset
	# cancel queued cache hits exactly as they cancel fresh reads.
	if _proof_mask != null and token.proof_key == _proof_key:
		token.reuse_mask = _proof_mask
	else:
		# Fresh proofs explicitly schedule their target, independent of visibility
		# heuristics. No geometry, material or ownership pixels are changed.
		ownership.render_target_update_mode = SubViewport.UPDATE_ONCE
	pending = token

static func camera_key(target: SubViewport) -> Array:
	return [target.camera.transform, target.camera.size, target.camera.frustum_offset, target.camera.near, target.camera.far,
		target.mesh_node.transform, target.mesh_node.visible, target.mesh_node.layers]

func valid_token(token: Dictionary) -> bool:
	if token.is_empty() or token.has("clear") or not allowed(): return false
	var target: SubViewport = token.target
	return is_instance_valid(target) and target.size == token.size and target.mesh_node.mesh == token.mesh and camera_key(target) == token.camera and host.epoch == token.epoch and host.last_frame == token.frame

func before_draw() -> void:
	if pending.is_empty(): return
	if not valid_token(pending): stop(); return
	# The target is explicitly scheduled in this draw, not merely an old texture
	# observed during an unrelated frame_post_draw signal.
	if not pending.has("reuse_mask") and pending.target.render_target_update_mode != SubViewport.UPDATE_ONCE: stop(); return
	armed = pending
	pending = {}

static func visible_cues(mask: Image, token: Dictionary) -> Array[String]:
	var found: Array[String] = []
	if mask == null or mask.get_size() != token.size: return found
	var clip: Array = token.clip
	var extent: Vector2 = Vector2(float(clip[2] - clip[0] + 1), float(clip[3] - clip[1] + 1))
	var bytes: PackedByteArray = mask.get_data()
	var stride: int = 4 if mask.get_format() == Image.FORMAT_RGBA8 else 3 if mask.get_format() == Image.FORMAT_RGB8 else 0
	if stride == 0: return found
	var witnesses: Dictionary = {}
	var wanted: Array = []
	for candidate: Dictionary in token.selected.values():
		if candidate.cue not in wanted: wanted.append(candidate.cue)
	# A bounded regular grid reads actual owner texels. Polygon centroids can
	# all be offscreen even when a long river crosses the view. No independent
	# polygon projection/rasterizer or hidden world-distance query is needed.
	for y: int in range(int(clip[1]) + 2, int(clip[3]) + 1, 4):
		for x: int in range(int(clip[0]) + 2, int(clip[2]) + 1, 4):
			if token.ui[y * 320 + x] != 0: continue
			var pixel: Vector2i = Vector2i(((Vector2(x + 0.5, y + 0.5) - Vector2(clip[0], clip[1])) / extent * Vector2(mask.get_size())).floor())
			if pixel.x < 0 or pixel.y < 0 or pixel.x >= mask.get_width() or pixel.y >= mask.get_height(): continue
			var at: int = (pixel.y * mask.get_width() + pixel.x) * stride
			var id: int = bytes[at] + (bytes[at + 1] << 8)
			if id not in token.selected: continue
			var cue: String = token.selected[id].cue
			if cue in found or (stride == 4 and bytes[at + 3] != 255): continue
			if bytes[at + 2] not in ([0] if cue == "river" else [0, 8]): continue
			# Require separated original pixels of the SAME source owner. A lone
			# edge pixel or two separate tiny actors cannot announce a class.
			if id not in witnesses: witnesses[id] = Vector2i(x, y)
			elif Vector2(witnesses[id]).distance_squared_to(Vector2(x, y)) >= 16.0:
				found.append(cue)
				if found.size() == wanted.size(): return found
	return found

func after_draw() -> void:
	if armed.is_empty(): return
	var token: Dictionary = armed
	armed = {}
	if not valid_token(token): stop(); return
	var mask: Image
	if token.has("reuse_mask"):
		if token.reuse_mask != _proof_mask or token.proof_key != _proof_key: stop(); return
		mask = token.reuse_mask
		if [token.ui, token.selected] == _proof_inputs: admitted.assign(_proof_cues)
		else: admitted = visible_cues(mask, token)
		last_read_usec = 0
		cache_hits += 1
	else:
		var started: int = Time.get_ticks_usec()
		mask = token.target.get_texture().get_image()
		admitted = visible_cues(mask, token)
		last_read_usec = Time.get_ticks_usec() - started
		reads += 1
	# Cache hits still wait for postdraw and current source/visibility checks.
	if not valid_token(token): stop(); return
	_proof_key = token.proof_key.duplicate(true)
	_proof_mask = mask
	_proof_inputs = [token.ui.duplicate(), token.selected.duplicate(true)]
	_proof_cues = admitted.duplicate()
	refresh()

func refresh() -> void:
	for cue: String in players:
		var player: AudioStreamPlayer = players[cue]
		var gain: float = host.volume * host.effects_volume * float(host.mix.get(cue, 100)) / 100.0 * (0.20 if cue == "river" else 0.30)
		if not allowed() or cue not in admitted or gain <= 0:
			host._remember_playback(player); player.stop(); continue
		# A single mono, fixed-pitch bed. Count, direction, range, allegiance and
		# unseen motion never modulate it or create additional players.
		player.volume_db = linear_to_db(gain)
		player.pitch_scale = 1.0
		if not player.playing:
			player.play(); host._remember_playback(player)
