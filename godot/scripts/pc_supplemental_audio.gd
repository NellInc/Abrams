extends RefCounted
const PrivateAudio = preload("res://scripts/pc_private_audio.gd")
var private_audio_root: String = PrivateAudio.root_directory()
## Optional CC0 detail at already-qualified source events and visible scenes.
const CHANNELS := ["foley", "interface", "fire"]
const CUES := ["reload", "ui_accept", "ui_back", "ui_error", "debris", "pressure", "fire"]
const FACTORS := {"reload":0.35,"ui_accept":0.22,"ui_back":0.22,"ui_error":0.22,"debris":0.12,"pressure":0.10,"fire":0.12}
const SCENE1_RGB := "d695c1d5da1c39a6518729038d44888b4708babeabc5ef2a7c399c9bcb0d9805"
var directory: String = PrivateAudio.bank_directory(private_audio_root,"pc-supplemental-effects-v1")
var host: Node
var streams: Dictionary = {}
var players: Dictionary = {}
var warning_voices: Dictionary = {}
var failure: String = ""
var starts: Dictionary = {}
var fire_frame: int = -1
var fire_epoch: int = -1
var fire_visible: bool = false
var fire_guard: Callable

func setup(owner: Node) -> void:
	host = owner
	if OS.has_feature("web") or directory.is_empty(): return
	var path: String = directory.path_join("manifest.json")
	if not FileAccess.file_exists(path): return
	if FileAccess.get_size(path) > 16384:
		failure = "manifest too large"; return
	var bank: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bank is Dictionary or bank.get("schema") != 1 or bank.get("kind") != "private source-qualified detail" or not bank.get("cues") is Dictionary or bank.cues.size() != CUES.size():
		failure = "invalid manifest"; return
	var pending: Dictionary = {}
	for cue: String in CUES:
		var entry: Variant = bank.cues.get(cue)
		if not entry is Dictionary or entry.get("file") != cue + ".wav" or not entry.get("sha256") is String:
			failure = "invalid entry"; return
		path = directory.path_join(cue + ".wav")
		if not FileAccess.file_exists(path) or FileAccess.get_size(path) > 3000000 or FileAccess.get_sha256(path) != entry.sha256:
			failure = "missing, oversized or changed PCM"; return
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != 48000 or stream.stereo or stream.data.size() < 4800 or stream.data.size() % 2 != 0 or (cue != "fire" and stream.data.size() > 268800):
			failure = "invalid PCM format/duration"; return
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if cue == "fire" else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin = 0; stream.loop_end = stream.data.size() / 2
		pending[cue] = stream
	streams = pending
	warning_voices = JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_warning_voice_script.json")).cues
	for cue: String in CUES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		host.add_child(player); player.bus = host.presentation_bus; player.stream = streams[cue]
		players[cue] = player
	RenderingServer.frame_post_draw.connect(after_draw)

func allowed() -> bool:
	return is_instance_valid(host) and not host.muted and not host.transport_muted and host.failure.is_empty()

func gain(cue: String) -> float:
	var channel: String = "fire" if cue == "fire" else ("interface" if cue.begins_with("ui_") else "foley")
	return host.volume * host.effects_volume * float(host.mix.get(channel, 100)) / 100.0 * float(FACTORS[cue])

func play(cue: String) -> void:
	if not allowed() or not players.has(cue) or gain(cue) <= 0: return
	var player: AudioStreamPlayer = players[cue]
	player.volume_db = linear_to_db(gain(cue)); player.pitch_scale = 1.0
	player.play(); host._remember_playback(player)
	starts[cue] = int(starts.get(cue, 0)) + 1

func observe_event(event: Dictionary) -> void:
	# Called only after pc_audio validates the complete envelope, age, identity,
	# source gates and once-only sequence. No raw completion or key heuristic.
	# Working if: replay, mute, stale and invalid packets cannot add a start.
	if event.kind == "readiness_visible": play("reload")
	elif event.kind == "crew_visible" and warning_voices.has(event.get("voice")): play("ui_error")
	elif event.kind == "radio_visible":
		if event.get("voice") == "pc_radio_complete": play("ui_accept")
		elif event.get("voice") == "pc_radio_abort": play("ui_back")
	elif event.kind == "sound":
		if event.get("sample") == "impact": play("debris")
		elif event.get("sample") == "smoke": play("pressure")

func begin_packet() -> void:
	fire_visible = false

func observe_frame(source: Image, program: Dictionary, guard: Callable) -> void:
	fire_visible = false
	if not players.has("fire"): return
	if allowed() and guard.is_valid() and guard.call() and program.get("name") == "SIM" and source != null and source.get_size() == Vector2i(320, 200) and source.get_format() == Image.FORMAT_RGB8:
		var hash: HashingContext = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256); hash.update(source.get_data())
		fire_visible = hash.finish().hex_encode() == SCENE1_RGB
	fire_frame = host.last_frame; fire_epoch = host.epoch; fire_guard = guard
	if not fire_visible: players.fire.stop()

func after_draw() -> void:
	if not players.has("fire"): return
	# Saving restarts the worker, retaining its displayed source frame. Its
	# eventless primer changes counters, never pixels or the original sound gate.
	# Working if: save continuity retains fire; a new/nonmatching frame stops it.
	var same_source: bool = (fire_frame == host.last_frame and fire_epoch == host.epoch) or host.continuing_timeline
	var visible_now: bool = allowed() and fire_visible and same_source and fire_guard.is_valid() and fire_guard.call()
	if not visible_now or gain("fire") <= 0: players.fire.stop()
	elif not players.fire.playing: play("fire")

func refresh() -> void:
	for cue: String in players:
		var player: AudioStreamPlayer = players[cue]
		var level: float = gain(cue)
		player.volume_db = linear_to_db(maxf(0.00001, level))
		if not allowed() or level <= 0: player.stop()
	if fire_visible and (not fire_guard.is_valid() or not fire_guard.call()): players.fire.stop()

func stop() -> void:
	fire_visible = false; fire_guard = Callable()
	for player: AudioStreamPlayer in players.values():
		host._remember_playback(player); player.stop()

func release() -> void:
	stop()
	if RenderingServer.frame_post_draw.is_connected(after_draw): RenderingServer.frame_post_draw.disconnect(after_draw)
	for player: AudioStreamPlayer in players.values(): player.stream = null
	streams.clear()
