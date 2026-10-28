extends RefCounted
const PrivateAudio = preload("res://scripts/pc_private_audio.gd")
var private_audio_root: String = PrivateAudio.root_directory()
## Quiet, centred presentation beds. No gameplay, event or positional inference.
## Admission reads the production painter mask after its draw, never guest RAM.
const Modern = preload("res://scripts/pc_modern_assets.gd")
const CowVisibility = preload("res://scripts/pc_cow_visibility.gd")
const BASE_CUES := ["river", "hind"]
const ENVIRONMENT_CUES := ["field", "cow"]
const SOVIET_CUES := ["t80"]
const T80_FRAME_COUNT := 1062930
const T72_CUES := ["t72"]
const T72_FRAME_COUNT := 627720
const FLIGHT_CUES := ["missileflight"]
const FLIGHT_FRAME_COUNT := 384000
const FLIGHT_PHASES := {
	54:{"shape":186,"root":33786,"flags":8,"width":16,"height":11},55:{"shape":187,"root":33824,"flags":8,"width":16,"height":11},
	56:{"shape":186,"root":33788,"flags":8,"width":8,"height":7},57:{"shape":187,"root":33826,"flags":8,"width":8,"height":7},
	58:{"shape":186,"root":33790,"flags":8,"width":8,"height":3},59:{"shape":187,"root":33828,"flags":8,"width":8,"height":3},
	60:{"shape":186,"root":33784,"flags":8,"width":32,"height":23},61:{"shape":187,"root":33822,"flags":8,"width":32,"height":24},
	62:{"shape":186,"root":33782,"flags":8,"width":56,"height":45},63:{"shape":187,"root":33820,"flags":16,"width":56,"height":45}}
# Original PC EFFECTS.BMP, not optional Genesis-derived artwork.
# Fingerprints serialize pixel bytes then strict boolean opacity bytes.
const FLIGHT_PC_RESOURCE_SHA256 := "6f8db51638447d2c8a798c7885fcf469acd9aff21e9606343de6d199462dc3fd"
const FLIGHT_FINGERPRINTS := {
	54:"856892cac07102d921ebbf6b816ac2da5da5b292a492917bf956c304ec543590",
	55:"ac9bc4ec36c236b800b4514f530463660aed59c359e57e851186bc5e6ad5ab35",
	56:"fb4592039207ce985789e957b784a470956379208166ce2cee52ccadc098b5ac",
	57:"4c87b2f60a5ad464b97dd518161d17ea52c07a96c2ffa43f27079d24b54fe95e",
	58:"106ce850a54ec15cc27f9b485c742c52297ff3b3dd9fc07f87b567401000546c",
	59:"e8f301d13b9c29c1d2fe7f4f4d9d4c91d85ea1628af6df2d6637dc07f28f806d",
	60:"212efbeffcd00c1e31956fd175cbe5b500bc28ef554f642d47cbd9efbc04d33c",
	61:"1a8f41f4780e9da8f93e0b71071891a0c3ab8a9479be1c9e36582f99791636af",
	62:"e17527b961fc6246650fc9c79c9db5e31efb45bc13ceb4399e90c7a7062b0727",
	63:"e0f5f3053a23be9d0d952b5357926f9d4b24b55ca76c09f9f80d507a695073bf"}
const TANK_CUES := ["tank"]
const TANK_FRAME_COUNT := 1152000
# Intact original tanks only, including the manual's FST-I MBT category.
# Abrams has its source motor; IFVs have separately labelled family textures.
const TANK_SHAPES := [115, 117, 119, 121, 123, 127]
const ALLIED_CUES := ["m113", "bradley"]
const ALLIED_FRAME_COUNTS := {"m113":1152000, "bradley":480817}
# Original class table: intact M113129 and M2 131; wrecks130/132 stay silent.
# These recording names never determine actor allegiance or original requests.
const ALLIED_SHAPES := {129:"m113", 131:"bradley"}
# Generic textures, never claims of recordings from these original models.
# Replacement/wreck shapes remain excluded. Aliases share one physical donor
# player, so coexistence cannot sum identical waves or restart a live loop.
const FAMILY_SHAPES := {133:"trackedfallback",135:"trackedfallback",139:"trackedfallback",
	137:"wheeledfallback",141:"wheeledfallback",143:"wheeledfallback"}
const CUE_PLAYERS := {"trackedfallback":"m113","wheeledfallback":"truck"}
const GROUND_MOTOR_CUES := ["t80", "t72", "tank", "m113", "bradley", "trackedfallback"]
const DETAIL_CUES := ["woodland", "truck", "tracks"]
const CUES := ["river", "hind", "field", "cow", "t80", "t72", "tank", "m113", "bradley", "woodland", "truck", "tracks", "missileflight", "trackedfallback", "wheeledfallback"]
const CUE_FACTORS := {"river":0.20, "hind":0.30, "field":0.08, "cow":0.80, "t80":0.30, "t72":0.30, "tank":0.30, "m113":0.30, "bradley":0.30, "woodland":0.08, "truck":0.30, "tracks":0.04,"missileflight":0.30,"trackedfallback":0.30,"wheeledfallback":0.30}
const COW_EXPOSURE_FRAMES := 180
const COW_COOLDOWN_FRAMES := 2400
var directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-world-effects-v1")
var environment_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-environment-effects-v1")
var environment_failure: String = ""
var soviet_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-soviet-effects-v1")
var soviet_failure: String = ""
var t72_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-t72-effects-v1")
var t72_failure: String = ""
var flight_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-missile-flight-v1")
var flight_failure: String = ""
var flight_sources: Dictionary = {}
var tank_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-tank-fallback-v1")
var tank_failure: String = ""
var allied_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-allied-effects-v1")
var allied_failure: String = ""
var detail_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-world-detail-v1")
var detail_failure: String = ""
const ROCKET_SHAPES := {13:141,14:143,15:161,16:162}
var rocket_directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-rocket-effects-v1")
var rocket_stream: AudioStreamWAV
var rocket_failure: String = ""
var _rocket_proof: Dictionary = {}
var _rocket_epoch: int = -1
var _rocket_last: int = 0
var _rocket_seen: Array[int] = []
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
		if cue == "t72" and stream.data.size() != T72_FRAME_COUNT * 2:
			return {"error":"invalid T72 frame count"}
		if cue == "missileflight" and stream.data.size() != FLIGHT_FRAME_COUNT * 2:
			return {"error":"invalid flight frame count"}
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
	bank = _read_bank(t72_directory, "private visible-t72 cue", T72_CUES)
	if bank.has("error"):
		t72_failure = bank.error
		push_warning("Private T72 sound ignored: " + t72_failure)
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
	bank = _read_bank(flight_directory, "private visible-missile flight", FLIGHT_CUES)
	if bank.has("error"): flight_failure = bank.error
	elif not bank.streams.is_empty():
		flight_sources = read_flight_sources(ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir())
		if flight_sources.is_empty(): flight_failure = "unverified original flare resources"
		else: streams.merge(bank.streams)
	if not flight_failure.is_empty(): push_warning("Private missile flight ignored: " + flight_failure)
	bank = _read_bank(rocket_directory,"private source-qualified rocket attack",["rocketlaunch"])
	if bank.has("error"): rocket_failure=str(bank.error)
	elif bank.streams.has("rocketlaunch"):
		var stream: AudioStreamWAV=bank.streams.rocketlaunch
		if stream.data.size()!=115200*2: rocket_failure="invalid rocket attack frame count"
		else:
			stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
			rocket_stream=stream
	if not rocket_failure.is_empty(): push_warning("Private rocket attack ignored: "+rocket_failure)
	if streams.is_empty() and rocket_stream==null: return
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
	_rocket_proof.clear()
	for player: AudioStreamPlayer in players.values():
		host._remember_playback(player)
		player.stop()

func release() -> void:
	stop()
	cow_visibility.release()
	for player: AudioStreamPlayer in players.values(): player.stream = null
	streams.clear()
	rocket_stream=null
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
	if not streams.is_empty() or rocket_stream!=null: pending = {"clear": true}
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
	if not exact_number(polygon.get("primitive"), 5123) or not exact_number(polygon.get("fill_mode"), 1) or not colors is Array or colors.size() != 2 or not ((exact_number(colors[0],8) and exact_number(colors[1],8)) or (exact_number(colors[0],3) and exact_number(colors[1],3))) or not vertices is Array or vertices.size() < 3: return false
	for point: Variant in vertices:
		if not point is Array or point.size() != 3: return false
		for value: Variant in point:
			if not (value is int or value is float) or not is_finite(float(value)): return false
	if not object.has("draw_order"): return true
	var order: Variant = object.draw_order
	if not order is Array or order.size() != 1 or not order[0] is Dictionary: return false
	var command: Dictionary = order[0]
	return command.size() == 2 and command.get("kind") == "polygon" and exact_number(command.get("index"), 0)

static func audio_water_surface(object: Dictionary, polygon: Dictionary) -> bool:
	# Original normal4/thermal6 remaps preserve this exact water identity.
	# Audio only: renderer classification, masks and source mode remain untouched.
	var dynamic: Variant = object.get("dynamic_instance")
	if not ((dynamic is bool and not dynamic) or exact_number(dynamic,0)) or not positive_source_path(object.get("static_path")): return false
	var shape: int = -1
	for candidate: int in Modern.WATER:
		if exact_number(object.get("shape_index"),candidate): shape = candidate; break
	if shape < 0 or not exact_number(object.get("root"),int(Modern.WATER[shape][0])): return false
	if not Modern.WATER[shape][1].any(func(id):return exact_number(polygon.get("primitive"),int(id))) or not exact_number(polygon.get("fill_mode"),1): return false
	var colors: Variant = polygon.get("colors")
	if not colors is Array or colors.size()!=2: return false
	var vertices: Variant = polygon.get("camera_vertices")
	if not vertices is Array or vertices.size()<3: return false
	for point: Variant in vertices:
		if not point is Array or point.size()!=3: return false
		for value: Variant in point:
			if not (value is int or value is float) or not is_finite(float(value)): return false
	return (exact_number(colors[0],4) and exact_number(colors[1],4)) or (exact_number(colors[0],6) and exact_number(colors[1],6))

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
	if (shape not in TANK_SHAPES and not ALLIED_SHAPES.has(shape) and not FAMILY_SHAPES.has(shape) and shape != 159) or not ((dynamic is bool and dynamic) or exact_number(dynamic, 1)) or not exact_number(object.get("shape_index"), shape): return false
	if not (pointer is int or pointer is float) or not is_finite(float(pointer)) or pointer != floorf(float(pointer)) or pointer < 0 or pointer > 65535: return false
	var match: Variant = actors.get([int(pointer), shape])
	if match == null or match[1] != 1: return false
	var actor: Dictionary = match[0]
	if not exact_number(actor.get("shape_index"), shape) or not exact_number(actor.get("pointer"), int(pointer)): return false
	var speed: Variant = actor.get("speed_raw")
	return (speed is int or speed is float) and is_finite(float(speed)) and speed == floorf(float(speed)) and speed >= -32768 and speed <= 32767 and speed != 0

static func read_flight_sources(_base: String) -> Dictionary:
	# Legacy caller signature. Expectations are pinned from the PC decoder;
	# never read expected resources from the candidate packet or optional art.
	var result: Dictionary = {}
	for index: int in FLIGHT_PHASES: result[index] = {"sha256":FLIGHT_FINGERPRINTS[index]}
	return result

static func flight_signature(sprite: Dictionary) -> String:
	var pixels: Variant = sprite.get("pixels")
	var opaque: Variant = sprite.get("opaque")
	if not pixels is Array or not opaque is Array or pixels.size() != opaque.size() or pixels.is_empty(): return ""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(pixels.size()*2)
	for at: int in pixels.size():
		var value: Variant = pixels[at]
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)) or value < 0 or value > 15 or not opaque[at] is bool: return ""
		bytes[at] = int(value)
		bytes[pixels.size()+at] = 1 if opaque[at] else 0
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	return hash.finish().hex_encode()

static func flight_candidate(object: Dictionary, actors: Dictionary, data: Dictionary, sources: Dictionary) -> bool:
	# Steady texture only. Visibility is never a launch/birth notification.
	# Working if: both original phases qualify strictly, while arbitrary sprites,
	# hidden owners and re-entry cannot create an ignition or positional cue.
	var world: Variant = data.get("world")
	if not world is Dictionary: return false
	var effects: Variant = world.get("presentation_effects")
	if not effects is Dictionary or not exact_number(effects.get("schema"),1) or not exact_number(effects.get("shape_base"),115): return false
	if object.get("kind") != "sprite" or object.get("sprite_status") != "observed": return false
	var dynamic: Variant = object.get("dynamic_instance")
	if not dynamic is bool or not dynamic: return false
	var index: Variant = object.get("bitmap_index")
	if not (index is int or index is float) or not is_finite(float(index)) or index != floorf(float(index)) or not FLIGHT_PHASES.has(int(index)): return false
	var phase: Dictionary = FLIGHT_PHASES[int(index)]
	if not exact_number(object.get("shape_index"),phase.shape) or not exact_number(object.get("root"),phase.root): return false
	var pointer: Variant = object.get("pointer")
	if not (pointer is int or pointer is float) or not is_finite(float(pointer)) or pointer != floorf(float(pointer)) or pointer <= 0 or pointer > 65535: return false
	var match: Variant = actors.get([int(pointer),phase.shape])
	if match == null or match[1] != 1: return false
	var actor: Dictionary = match[0]
	for pair: Array in [["pointer",pointer],["shape_index",phase.shape],["shape_header_word",100],["speed_raw",250]]:
		if not exact_number(actor.get(pair[0]),int(pair[1])): return false
	var sprite: Variant = object.get("sprite")
	var original: Variant = sources.get(int(index))
	if not sprite is Dictionary or not original is Dictionary: return false
	for pair: Array in [["index",index],["flags",phase.flags],["width",phase.width],["height",phase.height]]:
		if not exact_number(sprite.get(pair[0]),int(pair[1])): return false
	var size: int = int(phase.width)*int(phase.height)
	if not sprite.get("pixels") is Array or not sprite.get("opaque") is Array or sprite.pixels.size() != size or sprite.opaque.size() != size: return false
	if not original.get("sha256") is String or original.sha256.length() != 64: return false
	if flight_signature(sprite) != original.sha256: return false
	if not sprite.get("origin") is Array or sprite.origin.size() != 2 or not sprite.get("clip") is Array or sprite.clip.size() != 4: return false
	for value: Variant in sprite.origin:
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)) or value < -32768 or value > 32767: return false
	var clip: Variant = data.get("camera",{}).get("clip")
	if not clip is Array or clip.size() != 4: return false
	for at: int in 4:
		if not (clip[at] is int or clip[at] is float) or not is_finite(float(clip[at])) or clip[at] != floorf(float(clip[at])) or not exact_number(sprite.clip[at],int(clip[at])): return false
	return clip[0] >= 0 and clip[0] <= clip[2] and clip[2] < 320 and clip[1] >= 0 and clip[1] <= clip[3] and clip[3] < 200

static func candidates(data: Dictionary, dedicated_t80: bool = true, dedicated_t72: bool = false, flight_resources: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if not data.get("objects") is Array or not data.get("camera") is Dictionary or not data.get("unsupported") is Array or not data.unsupported.is_empty(): return result
	var actors: Dictionary = Modern.dynamic_index(data)
	for i: int in data.objects.size():
		var object: Dictionary = data.objects[i]
		var cue: String = ""
		var polygons: Array = object.get("polygons", [])
		if not flight_resources.is_empty() and flight_candidate(object,actors,data,flight_resources):
			result[i+1] = {"cue":"missileflight"}
			continue
		if polygons.is_empty(): continue
		# Whole-owner identity is required: one water face cannot qualify a
		# building/riverbank face that happens to share its object ID.
		if polygons.all(func(p): return p is Dictionary and audio_water_surface(object, p)) and object.get("round_forms", []).is_empty() and not object.has("sprite"):
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
		elif dedicated_t72 and moving_tank_candidate(object, actors, 119):
			cue = "t72"
		elif TANK_SHAPES.any(func(shape): return moving_tank_candidate(object, actors, shape)):
			cue = "tank"
		elif moving_vehicle_candidate(object, actors, 129):
			cue = "m113"
		elif moving_vehicle_candidate(object, actors, 131):
			cue = "bradley"
		elif moving_vehicle_candidate(object, actors, 159):
			cue = "truck" # Original Truck class, recording make/model unspecified.
		elif FAMILY_SHAPES.has(int(object.get("shape_index", -1))) and moving_vehicle_candidate(object, actors, int(object.shape_index)):
			cue = FAMILY_SHAPES[int(object.shape_index)]
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
	if streams.is_empty() and rocket_stream==null: return
	visibility_guard = guard
	if not allowed() or RenderingServer.get_current_rendering_method() != "gl_compatibility" or source_frame != host.last_frame or source_epoch != host.epoch or data.is_empty() or ownership == null or ui == null or ui.get_size() != Vector2i(320, 200) or ui.get_format() != Image.FORMAT_L8:
		stop(); return
	var bits: PackedByteArray = ui.get_data()
	if bits.count(0) + bits.count(255) != 64000: stop(); return
	var selected: Dictionary = candidates(data, streams.has("t80"), streams.has("t72"), flight_sources)
	var rockets: Dictionary = rocket_owners(data) if rocket_stream!=null else {}
	for id: int in selected.keys():
		if not streams.has(CUE_PLAYERS.get(selected[id].cue,selected[id].cue)) or cue_gain(selected[id].cue) <= 0: selected.erase(id)
	var cow_ready: bool = false
	if selected.values().any(func(item): return item.cue == "cow") and component_context.has_all(["view","assets","world","camera"]):
		var snapshot: Dictionary = component_context.view.cow_proof_snapshot(component_context.assets, data)
		cow_ready = cow_visibility.prepare(snapshot, component_context.world, component_context.camera, ownership, ui, data.camera.clip, source_frame, source_epoch,
			func(): return [host.last_frame, host.epoch], func(): return allowed() and cue_gain("cow") > 0)
	if not cow_ready:
		cow_visibility.stop()
		for id: int in selected.keys():
			if selected[id].cue == "cow": selected.erase(id)
	if (selected.is_empty() and rockets.is_empty()) or ownership.object_count != data.objects.size() or ownership.mesh_node.mesh == null:
		stop(); return
	var token: Dictionary = {"target": ownership, "mesh": ownership.mesh_node.mesh, "size": ownership.size,
		"clip": data.camera.clip.duplicate(), "selected": selected, "ui": bits,
		"epoch": host.epoch, "frame": host.last_frame, "camera": camera_key(ownership)}
	token.rocket_owners=rockets
	token.rocket_source=component_context.get("source",{}).duplicate(true)
	if not rockets.is_empty():
		var ui_hash: String=""
		if not _rocket_proof.is_empty() and token.ui==_rocket_proof.ui: ui_hash=str(_rocket_proof.source.get("ui_sha256",""))
		else:
			var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(token.ui)
			ui_hash=digest.finish().hex_encode()
		if ui_hash!=token.rocket_source.get("ui_sha256"): token.rocket_source={}
	token.proof_key = [ownership, token.mesh, token.size, token.camera, token.clip]
	token.cow_only = rockets.is_empty() and selected.values().all(func(item): return item.cue == "cow")
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
	for cue: String in ["field", "t80", "t72", "tank", "m113", "bradley", "woodland", "truck", "trackedfallback", "wheeledfallback"]:
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
			if cue in GROUND_MOTOR_CUES or cue in ["truck","wheeledfallback"]:
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
		if rocket_stream!=null:
			_rocket_proof={"target":token.target,"mesh":token.mesh,"size":token.size,"camera":token.camera,
				"clip":token.clip.duplicate(),"ui":token.ui.duplicate(),"epoch":token.epoch,"mask":mask,
				"owners":token.get("rocket_owners",{}).duplicate(true),"source":token.get("rocket_source",{}).duplicate(true)}
	for id: int in cow_visibility.admitted:
		if token.selected.has(id) and token.selected[id].cue == "cow" and "cow" not in admitted: admitted.append("cow")
	refresh()

func cue_gain(cue: String) -> float:
	return host.volume * host.effects_volume * float(host.mix.get(cue, 100)) / 100.0 * float(CUE_FACTORS[cue])

func reset_source_timeline() -> void:
	_cow_epoch = -1; _cow_frame = -1; _cow_exposure = -1; _cow_fired = -1
	reset_rocket_timeline()

func reset_rocket_timeline() -> void:
	_rocket_proof.clear();_rocket_seen.clear();_rocket_epoch=-1;_rocket_last=0

static func source_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floorf(float(value))

static func same_rocket_pose(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary: return false
	for key: String in ["position","orientation"]:
		if not left.get(key) is Array or not right.get(key) is Array or left[key].size()!=3 or right[key].size()!=3: return false
		for at: int in 3:
			if not source_integer(left[key][at]) or not source_integer(right[key][at]) or int(left[key][at])!=int(right[key][at]): return false
	return true

static func rocket_owners(data: Dictionary) -> Dictionary:
	var result: Dictionary={}
	if not data.get("objects") is Array or not data.get("unsupported") is Array or not data.unsupported.is_empty(): return result
	var actors: Dictionary=Modern.dynamic_index(data)
	for index: int in data.objects.size():
		var object: Variant=data.objects[index]
		if not object is Dictionary or object.get("dynamic_instance")!=true or object.get("kind")=="sprite" or object.get("polygons",[]).is_empty(): continue
		var shape: Variant=object.get("shape_index")
		var pointer: Variant=object.get("pointer")
		if not source_integer(shape) or int(shape) not in ROCKET_SHAPES.values() or not source_integer(pointer): continue
		var pair: Variant=actors.get([int(pointer),int(shape)])
		if pair==null or pair[1]!=1: continue
		var actor: Dictionary=pair[0]
		if not source_integer(actor.get("flags")) or (int(actor.flags)&0x90)!=0x80: continue
		var position: Variant=actor.get("world_position_raw")
		var orientation: Variant=actor.get("orientation_u8")
		if not position is Array or not orientation is Array or position.size()!=3 or orientation.size()!=3: continue
		if not position.all(source_integer) or not orientation.all(func(v):return source_integer(v) and v>=0 and v<=255): continue
		result[index+1]={"pointer":int(pointer),"shape":int(shape),"pose":{"position":position.duplicate(),"orientation":orientation.duplicate()}}
	return result

func rocket_variant(value: Variant, frame: int, epoch: int, player_target: bool, enabled: bool=true) -> AudioStreamWAV:
	# Working if: one source token uses only an already drawn exact owner proof;
	# misses are consumed, never delayed, and no original shot/ID is added.
	if not value is Dictionary or not source_integer(value.get("token")) or not source_integer(value.get("epoch")) or int(value.epoch)!=epoch: return null
	var id: int=int(value.token)
	if id<=0 or id>2147483647: return null
	if _rocket_epoch!=epoch: _rocket_epoch=epoch;_rocket_last=0;_rocket_seen.clear()
	if id in _rocket_seen or id<=_rocket_last-128: return null
	_rocket_last=maxi(id,_rocket_last);_rocket_seen.append(id)
	if _rocket_seen.size()>128: _rocket_seen.pop_front()
	if not enabled or rocket_stream==null or not allowed() or host.effect_gain("rocketlaunch")<=0: return null
	for key: String in ["schema","frame","class_index","shape_index","actor_pointer","backend","gate"]:
		if not source_integer(value.get(key)): return null
	if int(value.schema)!=1 or int(value.frame)!=frame or value.get("player_target") is not bool or value.player_target!=player_target or int(value.backend) not in [0,1] or int(value.gate)!=1: return null
	if not ROCKET_SHAPES.has(int(value.class_index)) or int(value.shape_index)!=ROCKET_SHAPES[int(value.class_index)]: return null
	if _rocket_proof.is_empty() or _rocket_proof.epoch!=epoch or not value.get("source") is Dictionary: return null
	var source: Dictionary=value.source
	if not source_integer(source.get("owner")) or int(source.owner)<=0: return null
	if not source_integer(source.get("pass_sequence")) or int(source.pass_sequence)<=0: return null
	for key: String in ["start_ram_sha256","video_sha256","ui_sha256"]:
		if not source.get(key) is String or source[key].length()!=64: return null
		for character: String in source[key]:
			if character not in "0123456789abcdef": return null
	for key: String in ["pass_sequence","start_ram_sha256","video_sha256","ui_sha256"]:
		if not source.has(key) or source[key]!=_rocket_proof.source.get(key): return null
	var target: Variant=_rocket_proof.target
	if not is_instance_valid(target) or target.size!=_rocket_proof.size or target.mesh_node.mesh!=_rocket_proof.mesh or camera_key(target)!=_rocket_proof.camera: return null
	var owner_id: int=int(source.owner)
	var actor: Variant=_rocket_proof.owners.get(owner_id)
	if not actor is Dictionary or actor.pointer!=int(value.actor_pointer) or actor.shape!=int(value.shape_index) or not same_rocket_pose(actor.pose,value.get("display_pose")): return null
	var token: Dictionary={"size":_rocket_proof.size,"clip":_rocket_proof.clip,"ui":_rocket_proof.ui,"selected":{owner_id:{"cue":"rocketlaunch"}}}
	var mask: Image=_rocket_proof.mask
	if "rocketlaunch" not in visible_cues(mask,token):
		var stride: int=4 if mask.get_format()==Image.FORMAT_RGBA8 else 3 if mask.get_format()==Image.FORMAT_RGB8 else 0
		if stride==0 or not narrow_visible(mask.get_data(),stride,token,"rocketlaunch"): return null
	return rocket_stream

func _refresh_cow(player: AudioStreamPlayer, gain: float) -> void:
	# Authored sparse moo: eligibility advances only on accepted source frames.
	# Working if: held frames/re-entry/mute cannot replay a call or catch up.
	var frame: int = host.last_frame
	var epoch: int = host.epoch
	if epoch != _cow_epoch or frame < _cow_frame:
		# Cow scheduling initializes independently of the same-draw rocket proof.
		# Working if: first cow refresh cannot erase a qualified launch cache.
		_cow_frame = -1; _cow_exposure = -1; _cow_fired = -1
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
		# Working if: independent enabled owners request a maximum, never a sum;
		# donor-to-fallback handoff keeps position, both absent/Off stops normally.
		gain = gain if present else 0.0
		for alias: String in CUE_PLAYERS:
			if CUE_PLAYERS[alias] == cue and alias in admitted:
				present = true
				gain = maxf(gain,cue_gain(alias))
		# Chain texture follows the same already-visible, source-moving tracked
		# owners. Original idle channels, trucks and hidden motion cannot start it.
		if cue == "tracks":
			present = admitted.any(func(item): return item in GROUND_MOTOR_CUES and cue_gain(item) > 0)
			gain = cue_gain(cue) if present else 0.0
		if not allowed() or not present or gain <= 0:
			host._remember_playback(player); player.stop(); continue
		# A single mono, fixed-pitch bed. Count, direction, range, allegiance and
		# unseen motion never modulate it or create additional players.
		player.volume_db = linear_to_db(gain)
		player.pitch_scale = 1.0
		if not player.playing:
			player.play(); host._remember_playback(player)
