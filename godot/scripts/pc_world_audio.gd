extends RefCounted
## Quiet, centred presentation beds. No gameplay, event or positional inference.
## Admission reads the production painter mask after its draw, never guest RAM.
const Modern = preload("res://scripts/pc_modern_assets.gd")
const CowVisibility = preload("res://scripts/pc_cow_visibility.gd")
const BASE_CUES := ["river", "hind"]
const ENVIRONMENT_CUES := ["field", "cow"]
const SOVIET_CUES := ["t80"]
const T80_FRAME_COUNT := 1062930
const TANK_CUES := ["tank"]
const TANK_FRAME_COUNT := 1152000
# Intact original tanks only. Abrams already has its dedicated source motor;
# unverified F-ST and IFV identities are never substituted with this recording.
const TANK_SHAPES := [115, 117, 119, 121, 127]
const ALLIED_CUES := ["m113", "bradley"]
const ALLIED_FRAME_COUNTS := {"m113":1152000, "bradley":480817}
# Original class table: intact M113129 and M2 131; wrecks130/132 stay silent.
# These recording names never determine actor allegiance or original requests.
const ALLIED_SHAPES := {129:"m113", 131:"bradley"}
const GROUND_MOTOR_CUES := ["t80", "tank", "m113", "bradley"]
const DETAIL_CUES := ["woodland", "truck", "tracks"]
const CUES := ["river", "hind", "field", "cow", "t80", "tank", "m113", "bradley", "woodland", "truck", "tracks"]
const CUE_FACTORS := {"river":0.20, "hind":0.30, "field":0.08, "cow":0.80, "t80":0.30, "tank":0.30, "m113":0.30, "bradley":0.30, "woodland":0.08, "truck":0.30, "tracks":0.04}
const COW_EXPOSURE_FRAMES := 180
const COW_COOLDOWN_FRAMES := 2400
var directory: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/pc-world-effects-v1")
var environment_directory: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/pc-environment-effects-v1")
var environment_failure: String = ""
var soviet_directory: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/pc-soviet-effects-v1")
var soviet_failure: String = ""
var tank_directory: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/pc-tank-fallback-v1")
var tank_failure: String = ""
var allied_directory: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/pc-allied-effects-v1")
var allied_failure: String = ""
var detail_directory: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/pc-world-detail-v1")
var detail_failure: String = ""
var cow_visibility = CowVisibility.new()
var _cow_epoch: int = -1
var _cow_frame: int = -1
var _cow_exposure: int = -1
var _cow_fired: int = -1
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

func _read_bank(folder: String, kind: String, expected: Array) -> Dictionary:
	if folder.is_empty(): return {"streams":{}}
	var path: String = folder.path_join("manifest.json")
	if not FileAccess.file_exists(path): return {"streams":{}}
	if FileAccess.get_size(path) > 16384: return {"error":"manifest too large"}
	var bank: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bank is Dictionary or bank.get("schema") != 1 or bank.get("kind") != kind or not bank.get("cues") is Dictionary or bank.cues.size() != expected.size():
		return {"error":"invalid manifest"}
	var loaded: Dictionary = {}
	for cue: String in expected:
		var entry: Variant = bank.cues.get(cue)
		if not entry is Dictionary or entry.get("file") != cue + ".wav" or not entry.get("sha256") is String:
			return {"error":"invalid entry"}
		path = folder.path_join(cue + ".wav")
		if not FileAccess.file_exists(path) or FileAccess.get_size(path) > 3000000 or FileAccess.get_sha256(path) != entry.sha256:
			return {"error":"missing, oversized or changed PCM"}
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != 48000 or stream.stereo or stream.data.size() < 96000 or stream.data.size() % 2 != 0:
			return {"error":"invalid PCM format/duration"}
		if cue == "t80" and stream.data.size() != T80_FRAME_COUNT * 2:
			return {"error":"invalid T80 frame count"}
		if cue == "tank" and stream.data.size() != TANK_FRAME_COUNT * 2:
			return {"error":"invalid tank fallback frame count"}
		if cue in ALLIED_CUES and stream.data.size() != int(ALLIED_FRAME_COUNTS[cue]) * 2:
			return {"error":"invalid allied frame count"}
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED if cue == "cow" else AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		loaded[cue] = stream
	return {"streams":loaded}

func setup(owner: Node) -> void:
	host = owner
	if OS.has_feature("web"): return
	var bank: Dictionary = _read_bank(directory, "private visible-world beds", BASE_CUES)
	if bank.has("error"): reject(bank.error)
	else: streams.merge(bank.streams)
	# Optional new cues publish atomically and cannot disable the approved bank.
	bank = _read_bank(environment_directory, "private visible-environment cues", ENVIRONMENT_CUES)
	if bank.has("error"):
		environment_failure = bank.error
		push_warning("Private environment sounds ignored: " + environment_failure)
	else: streams.merge(bank.streams)
	bank = _read_bank(soviet_directory, "private visible-soviet cues", SOVIET_CUES)
	if bank.has("error"):
		soviet_failure = bank.error
		push_warning("Private Soviet sounds ignored: " + soviet_failure)
	else: streams.merge(bank.streams)
	bank = _read_bank(tank_directory, "private visible-tank fallback", TANK_CUES)
	if bank.has("error"):
		tank_failure = bank.error
		push_warning("Private tank fallback ignored: " + tank_failure)
	else: streams.merge(bank.streams)
	bank = _read_bank(allied_directory, "private visible-allied cues", ALLIED_CUES)
	if bank.has("error"):
		allied_failure = bank.error
		push_warning("Private allied sounds ignored: " + allied_failure)
	else: streams.merge(bank.streams)
	bank = _read_bank(detail_directory, "private visible-world detail", DETAIL_CUES)
	if bank.has("error"):
		detail_failure = bank.error
		push_warning("Private world detail ignored: " + detail_failure)
	else: streams.merge(bank.streams)
	if streams.is_empty(): return
	for cue: String in streams:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		host.add_child(player)
		player.stream = streams[cue]
		player.bus = host.presentation_bus
		players[cue] = player
	if streams.has("cow"): cow_visibility.setup(host)
	RenderingServer.frame_pre_draw.connect(before_draw)
	RenderingServer.frame_post_draw.connect(after_draw)

func reject(reason: String) -> void:
	failure = reason
	push_warning("Private world sounds ignored: " + reason)

func stop() -> void:
	cow_visibility.stop()
	_cow_exposure = -1
	pending.clear(); armed.clear(); admitted.clear()
	_proof_key.clear(); _proof_mask = null; _proof_inputs.clear(); _proof_cues.clear()
	for player: AudioStreamPlayer in players.values():
		host._remember_playback(player)
		player.stop()

func release() -> void:
	stop()
	cow_visibility.release()
	for player: AudioStreamPlayer in players.values(): player.stream = null
	streams.clear()
	if RenderingServer.frame_pre_draw.is_connected(before_draw): RenderingServer.frame_pre_draw.disconnect(before_draw)
	if RenderingServer.frame_post_draw.is_connected(after_draw): RenderingServer.frame_post_draw.disconnect(after_draw)

func allowed() -> bool:
	return is_instance_valid(host) and not host.muted and not host.transport_muted and host.failure.is_empty() and (not visibility_guard.is_valid() or visibility_guard.call())

func maintain() -> void:
	if not allowed(): stop()

func begin_packet() -> void:
	cow_visibility.begin_packet()
	# A new packet without a successful world presentation silences at postdraw.
	# No new packet between draws, however, is an ordinary retained source frame.
	if not streams.is_empty(): pending = {"clear": true}
	armed.clear()

static func exact_number(value: Variant, expected: int) -> bool:
	# JSON numbers are floats. Compare validated scalars, never nested literal
	# containers or truncated identities (48.5 is not source shape48).
	return (value is int or value is float) and is_finite(float(value)) and value == expected

static func positive_source_path(value: Variant) -> bool:
	return value == true if value is bool else (value is int or value is float) and is_finite(float(value)) and value > 0 and value == floorf(float(value))

static func field_candidate(object: Dictionary, polygons: Array) -> bool:
	var dynamic: Variant = object.get("dynamic_instance")
	if not ((dynamic is bool and not dynamic) or exact_number(dynamic, 0)) or not exact_number(object.get("shape_index"), 48) or not exact_number(object.get("root"), 5109) or polygons.size() != 1 or not polygons[0] is Dictionary: return false
	var polygon: Dictionary = polygons[0]
	var colors: Variant = polygon.get("colors")
	var vertices: Variant = polygon.get("camera_vertices")
	if not exact_number(polygon.get("primitive"), 5123) or not exact_number(polygon.get("fill_mode"), 1) or not colors is Array or colors.size() != 2 or not exact_number(colors[0], 8) or not exact_number(colors[1], 8) or not vertices is Array or vertices.size() < 3: return false
	for point: Variant in vertices:
		if not point is Array or point.size() != 3: return false
		for value: Variant in point:
			if not (value is int or value is float) or not is_finite(float(value)): return false
	if not object.has("draw_order"): return true
	var order: Variant = object.draw_order
	if not order is Array or order.size() != 1 or not order[0] is Dictionary: return false
	var command: Dictionary = order[0]
	return command.size() == 2 and command.get("kind") == "polygon" and exact_number(command.get("index"), 0)

static func t80_candidate(object: Dictionary, actors: Dictionary) -> bool:
	return moving_tank_candidate(object, actors, 121)

static func woodland_candidate(object: Dictionary, polygons: Array) -> bool:
	var dynamic: Variant = object.get("dynamic_instance")
	if not ((dynamic is bool and not dynamic) or exact_number(dynamic, 0)) or not exact_number(object.get("shape_index"), 103) or not exact_number(object.get("root"), 10523) or polygons.is_empty(): return false
	for polygon: Variant in polygons:
		if not polygon is Dictionary or not [10541, 10549, 10564, 10571].any(func(value): return exact_number(polygon.get("primitive"), value)): return false
		var points: Variant = polygon.get("camera_vertices")
		var expected: int = 3 if int(polygon.primitive) in [10549, 10564] else 4
		if not points is Array or points.size() != expected: return false
		for point: Variant in points:
			if not point is Array or point.size() != 3: return false
			for coordinate: Variant in point:
				if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)): return false
	return true

static func moving_tank_candidate(object: Dictionary, actors: Dictionary, shape: int) -> bool:
	return shape in TANK_SHAPES and moving_vehicle_candidate(object, actors, shape)

static func moving_vehicle_candidate(object: Dictionary, actors: Dictionary, shape: int) -> bool:
	# Movement qualifies this authored visible model texture, never idle engine,
	# allegiance, RPM, damage or any original sound-request identity.
	# Working if: only uniquely joined intact allowed vehicles qualify; reverse is
	# accepted, while hidden ownership and stopped/reused identities stay silent.
	var dynamic: Variant = object.get("dynamic_instance")
	var pointer: Variant = object.get("pointer")
	if (shape not in TANK_SHAPES and not ALLIED_SHAPES.has(shape) and shape != 159) or not ((dynamic is bool and dynamic) or exact_number(dynamic, 1)) or not exact_number(object.get("shape_index"), shape): return false
	if not (pointer is int or pointer is float) or not is_finite(float(pointer)) or pointer != floorf(float(pointer)) or pointer < 0 or pointer > 65535: return false
	var match: Variant = actors.get([int(pointer), shape])
	if match == null or match[1] != 1: return false
	var actor: Dictionary = match[0]
	if not exact_number(actor.get("shape_index"), shape) or not exact_number(actor.get("pointer"), int(pointer)): return false
	var speed: Variant = actor.get("speed_raw")
	return (speed is int or speed is float) and is_finite(float(speed)) and speed == floorf(float(speed)) and speed >= -32768 and speed <= 32767 and speed != 0

static func candidates(data: Dictionary, dedicated_t80: bool = true) -> Dictionary:
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
		elif t80_candidate(object, actors):
			# Availability chooses the recording, never a user mute or gain.
			cue = "t80" if dedicated_t80 else "tank"
		elif TANK_SHAPES.any(func(shape): return moving_tank_candidate(object, actors, shape)):
			cue = "tank"
		elif moving_vehicle_candidate(object, actors, 129):
			cue = "m113"
		elif moving_vehicle_candidate(object, actors, 131):
			cue = "bradley"
		elif moving_vehicle_candidate(object, actors, 159):
			cue = "truck" # Original Truck class, recording make/model unspecified.
		elif positive_source_path(object.get("static_path")) and not object.has("sprite") and object.get("round_forms", []).is_empty():
			if field_candidate(object, polygons):
				cue = "field" # Authored visible-field air, not original weather.
			elif woodland_candidate(object, polygons):
				cue = "woodland" # Scene-owned foliage air, no hidden bird actors.
			elif exact_number(object.get("shape_index"), 157) and exact_number(object.get("root"), 28643):
				cue = "cow" # Candidate only; whole-farm ownership NEVER admits it.
		if cue.is_empty(): continue
		result[i + 1] = {"cue": cue}
	return result

func observe(data: Dictionary, ownership: SubViewport, ui: Image, source_frame: int, source_epoch: int, guard: Callable = Callable(), component_context: Dictionary = {}) -> void:
	if streams.is_empty(): return
	visibility_guard = guard
	if not allowed() or RenderingServer.get_current_rendering_method() != "gl_compatibility" or source_frame != host.last_frame or source_epoch != host.epoch or data.is_empty() or ownership == null or ui == null or ui.get_size() != Vector2i(320, 200) or ui.get_format() != Image.FORMAT_L8:
		stop(); return
	var bits: PackedByteArray = ui.get_data()
	if bits.count(0) + bits.count(255) != 64000: stop(); return
	var selected: Dictionary = candidates(data, streams.has("t80"))
	for id: int in selected.keys():
		if not streams.has(selected[id].cue) or cue_gain(selected[id].cue) <= 0: selected.erase(id)
	var cow_ready: bool = false
	if selected.values().any(func(item): return item.cue == "cow") and component_context.has_all(["view","assets","world","camera"]):
		var snapshot: Dictionary = component_context.view.cow_proof_snapshot(component_context.assets, data)
		cow_ready = cow_visibility.prepare(snapshot, component_context.world, component_context.camera, ownership, ui, data.camera.clip, source_frame, source_epoch,
			func(): return [host.last_frame, host.epoch], func(): return allowed() and cue_gain("cow") > 0)
	if not cow_ready:
		cow_visibility.stop()
		for id: int in selected.keys():
			if selected[id].cue == "cow": selected.erase(id)
	if selected.is_empty() or ownership.object_count != data.objects.size() or ownership.mesh_node.mesh == null:
		stop(); return
	var token: Dictionary = {"target": ownership, "mesh": ownership.mesh_node.mesh, "size": ownership.size,
		"clip": data.camera.clip.duplicate(), "selected": selected, "ui": bits,
		"epoch": host.epoch, "frame": host.last_frame, "camera": camera_key(ownership)}
	token.proof_key = [ownership, token.mesh, token.size, token.camera, token.clip]
	token.cow_only = selected.values().all(func(item): return item.cue == "cow")
	# prepare() creates a fresh immutable mesh/material. This narrowly scoped
	# cache must be invalidated if that ownership path gains in-place mutation.
	# Working if: UI-only changes reclassify, new meshes reread, and mute/reset
	# cancel queued cache hits exactly as they cancel fresh reads.
	if token.cow_only: pass
	elif _proof_mask != null and token.proof_key == _proof_key:
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
	cow_visibility.before_draw()
	if pending.is_empty(): return
	if not valid_token(pending): stop(); return
	# The target is explicitly scheduled in this draw, not merely an old texture
	# observed during an unrelated frame_post_draw signal.
	if not pending.cow_only and not pending.has("reuse_mask") and pending.target.render_target_update_mode != SubViewport.UPDATE_ONCE: stop(); return
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
		if candidate.cue != "cow" and candidate.cue not in wanted: wanted.append(candidate.cue)
	if wanted.is_empty(): return found
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
			if cue == "cow": continue
			if cue in found or (stride == 4 and bytes[at + 3] != 255): continue
			if bytes[at + 2] not in ([0] if cue in ["river", "field"] else [0, 8]): continue
			# Require separated original pixels of the SAME source owner. A lone
			# edge pixel or two separate tiny actors cannot announce a class.
			if id not in witnesses: witnesses[id] = Vector2i(x, y)
			elif Vector2(witnesses[id]).distance_squared_to(Vector2(x, y)) >= 16.0:
				found.append(cue)
				if found.size() == wanted.size(): return found
	for cue: String in ["field", "t80", "tank", "m113", "bradley", "woodland", "truck"]:
		if cue in wanted and cue not in found and narrow_visible(bytes,stride,token,cue): found.append(cue)
	return found

static func narrow_visible(bytes: PackedByteArray, stride: int, token: Dictionary, cue: String) -> bool:
	# Fields and small vehicle silhouettes can fall between the sparse grid rows.
	# Working if: two separated actual same-owner/UI-clear pixels admit, while
	# closer fragments, protected lines and other owners stay silent. No mask
	# pixels or distance threshold change; Hind/river keep their incumbent grid.
	var width: int = token.size.x
	var height: int = token.size.y
	var clip: Array = token.clip
	var extent: Vector2 = Vector2(clip[2]-clip[0]+1,clip[3]-clip[1]+1)
	for owner_id: int in token.selected:
		if token.selected[owner_id].cue != cue: continue
		var first: Vector2i = Vector2i(-1,-1)
		var witnesses: Array[Vector2i] = []
		var cursor: int = 0
		var search_hits: int = 0
		while cursor < bytes.size():
			var hit: int = bytes.find(owner_id & 255,cursor)
			if hit < 0: break
			search_hits += 1
			if search_hits > 8192: break # ambiguous dense byte collisions stay quiet
			cursor = hit+1
			if hit%stride != 0 or bytes[hit+1] != (owner_id >> 8) or bytes[hit+2] not in ([0] if cue == "field" else [0,8]) or (stride==4 and bytes[hit+3] != 255): continue
			var index: int = hit/stride
			var pixel: Vector2i = Vector2i(index%width,index/width)
			if pixel.y >= height: continue
			var source: Vector2i = Vector2i(clip[0]+floori((pixel.x+0.5)*extent.x/width),clip[1]+floori((pixel.y+0.5)*extent.y/height))
			if source.x<0 or source.x>=320 or source.y<0 or source.y>=200 or token.ui[source.y*320+source.x] != 0: continue
			if cue in GROUND_MOTOR_CUES or cue == "truck":
				# Every endpoint is an actual observed pixel, never a bounding-box
				# corner or a sum across actors. Before a pair succeeds, all points
				# fit within <4 pixels of the first: at most49 lattice positions.
				for witness: Vector2i in witnesses:
					if Vector2(witness).distance_squared_to(Vector2(source))>=16.0: return true
				if source not in witnesses: witnesses.append(source)
				if witnesses.size()>49: return false
			else:
				if first.x<0: first=source
				elif Vector2(first).distance_squared_to(Vector2(source))>=16.0: return true
	return false

func after_draw() -> void:
	cow_visibility.after_draw()
	if armed.is_empty(): return
	var token: Dictionary = armed
	armed = {}
	if not valid_token(token): stop(); return
	var mask: Image
	if token.cow_only:
		admitted.clear()
		last_read_usec = 0
	elif token.has("reuse_mask"):
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
	if not token.cow_only:
		_proof_key = token.proof_key.duplicate(true)
		_proof_mask = mask
		_proof_inputs = [token.ui.duplicate(), token.selected.duplicate(true)]
		_proof_cues = admitted.duplicate()
	for id: int in cow_visibility.admitted:
		if token.selected.has(id) and token.selected[id].cue == "cow" and "cow" not in admitted: admitted.append("cow")
	refresh()

func cue_gain(cue: String) -> float:
	return host.volume * host.effects_volume * float(host.mix.get(cue, 100)) / 100.0 * float(CUE_FACTORS[cue])

func reset_source_timeline() -> void:
	_cow_epoch = -1; _cow_frame = -1; _cow_exposure = -1; _cow_fired = -1

func _refresh_cow(player: AudioStreamPlayer, gain: float) -> void:
	# Authored sparse moo: eligibility advances only on accepted source frames.
	# Working if: held frames/re-entry/mute cannot replay a call or catch up.
	var frame: int = host.last_frame
	var epoch: int = host.epoch
	if epoch != _cow_epoch or frame < _cow_frame:
		reset_source_timeline()
		_cow_epoch = epoch
	if not allowed() or "cow" not in admitted or gain <= 0:
		_cow_exposure = -1
		host._remember_playback(player); player.stop()
		return
	player.volume_db = linear_to_db(gain); player.pitch_scale = 1.0
	if frame == _cow_frame: return
	if _cow_exposure < 0 or (_cow_frame >= 0 and frame - _cow_frame > 120): _cow_exposure = frame
	_cow_frame = frame
	if frame - _cow_exposure < COW_EXPOSURE_FRAMES or (_cow_fired >= 0 and frame - _cow_fired < COW_COOLDOWN_FRAMES) or player.playing: return
	player.play(); host._remember_playback(player)
	_cow_fired = frame

func refresh() -> void:
	for cue: String in players:
		var player: AudioStreamPlayer = players[cue]
		var gain: float = cue_gain(cue)
		if cue == "cow":
			_refresh_cow(player, gain)
			continue
		var present: bool = cue in admitted
		# Chain texture follows the same already-visible, source-moving tracked
		# owners. Original idle channels, trucks and hidden motion cannot start it.
		if cue == "tracks": present = admitted.any(func(item): return item in GROUND_MOTOR_CUES and cue_gain(item) > 0)
		if not allowed() or not present or gain <= 0:
			host._remember_playback(player); player.stop(); continue
		# A single mono, fixed-pitch bed. Count, direction, range, allegiance and
		# unseen motion never modulate it or create additional players.
		player.volume_db = linear_to_db(gain)
		player.pitch_scale = 1.0
		if not player.playing:
			player.play(); host._remember_playback(player)
