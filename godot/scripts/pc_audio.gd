extends "res://scripts/audio.gd"
## Original PC sound requests only. No keyboard, ammo-delta or range simulation.
## Batched diagnostic steps retain all events, but stale audio is never replayed.
const MAX_AGE_FRAMES := 6
const SAMPLES := ["cannon", "machinegun", "smoke", "impact", "switch"]
const VOICES := {"cannon": "on_the_way", "smoke": "smoke"}
var crew_catalogue: Dictionary = {}
var last_crew_message := 0
var turret: AudioStreamPlayer
var loop_transitions: Array[Dictionary] = []
var loop_states := {"engine":false,"turret":false}
var last_event_id := 0
var last_frame := -1
var epoch := 0
var failure := ""
var delivered := 0
var suppressed := 0
var receipts: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	crew_catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_crew_voice_script.json")).cues
	turret = AudioStreamPlayer.new()
	add_child(turret)
	var stream := load("res://assets/audio/turret.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Imported WAV data can be QOA, so byte count is not a PCM frame count.
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	turret.stream = stream

func stop_all() -> void:
	super.stop_all()
	if is_instance_valid(turret):
		_remember_playback(turret)
		turret.stop()

func release_streams() -> void:
	super.release_streams()
	if is_instance_valid(turret): turret.stream = null

func _valid_loops(loops) -> bool:
	if not loops is Dictionary: return false
	for name in loops:
		if name not in ["engine", "turret"]: return false
		var loop = loops[name]
		if not loop is Dictionary or not loop.get("active") is bool: return false
		for key in ["channel", "ticks", "program", "period", "amplitude", "idle_period", "amplitude_reference"]:
			if not _integer(loop.get(key)) or int(loop[key]) < 0 or int(loop[key]) > 65535: return false
		if int(loop.channel) > 3 or int(loop.idle_period) < 1 or int(loop.amplitude_reference) < 1: return false
		if loop.active and (int(loop.ticks) == 0 or int(loop.period) == 0 or int(loop.amplitude) == 0): return false
	return true

func _sync_loops(loops: Dictionary) -> void:
	for name in ["engine", "turret"]:
		var player: AudioStreamPlayer = engine if name == "engine" else turret
		var source: Dictionary = loops.get(name,{})
		var active := not muted and bool(source.get("active",false))
		if active != bool(loop_states[name]):
			loop_transitions.append({"name":name,"active":active,"frame":last_frame,"epoch":epoch})
			if loop_transitions.size() > 64: loop_transitions.pop_front()
		loop_states[name] = active
		if not active:
			_remember_playback(player)
			player.stop()
			continue
		# Presentation-only timbre: actual original tone period and amplitude,
		# never speed, input keys, tank pose or substitute acceleration rules.
		player.pitch_scale = clampf(float(source.idle_period)/float(source.period),0.25,4.0)
		var level := clampf(float(source.amplitude)/float(source.amplitude_reference),0.0,1.0)
		player.volume_db = linear_to_db(maxf(0.00001,volume*level*(0.08 if name == "engine" else 0.10)))
		if not player.playing:
			player.play()
			_remember_playback(player)

func _integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func _valid_readiness(event: Dictionary) -> bool:
	for key in ["completion_frame", "text_sequence", "text_draw_sequence", "text_return_ip", "text_pointer"]:
		if not _integer(event.get(key)) or int(event[key]) < 0: return false
	if int(event.ip) != 0x35ee or int(event.value) != 0 or int(event.text_return_ip) != 0x55df or int(event.text_pointer) != 0x0aca:
		return false
	if int(event.text_draw_sequence) <= int(event.text_sequence): return false
	var delay := int(event.frame)-int(event.completion_frame)
	if delay < 0 or delay > MAX_AGE_FRAMES: return false
	var digest = event.get("text_pixel_sha256")
	if not digest is String or digest.length() != 64: return false
	for i in digest.length():
		if digest[i] not in "0123456789abcdef": return false
	return true

func _valid_crew(event: Dictionary) -> bool:
	if not _integer(event.get("message_id")) or int(event.message_id) < 1: return false
	if not _integer(event.get("speaker")) or int(event.speaker) != 3: return false
	if event.get("voice") not in crew_catalogue: return false
	if event.get("text") != crew_catalogue[event.voice].caption: return false
	var bearing: bool = event.voice.begins_with("pc_hit_")
	if int(event.ip) != (0x3d6a if bearing else 0x3dd2) or int(event.return_ip) != 0 or int(event.value) != 0:
		return false
	var parts = event.get("parts")
	if not parts is Array or parts.size() != 2: return false
	var previous: Array = []
	for part in parts:
		if not part is Dictionary: return false
		for field in ["draw_sequence", "source_pointer"]:
			if not _integer(part.get(field)) or int(part[field]) < 1: return false
		if int(part.source_pointer) > 65535: return false
		var rect = part.get("rect")
		if not rect is Array or rect.size() != 4: return false
		for value in rect:
			if not _integer(value) or int(value) < 0: return false
		if int(rect[2]) < 1 or int(rect[3]) < 1 or int(rect[0])+int(rect[2]) > 320 or int(rect[1])+int(rect[3]) > 200:
			return false
		if not previous.is_empty() and (int(rect[0]) != int(previous[0])+int(previous[2]) or int(rect[1]) != int(previous[1]) or int(rect[3]) != int(previous[3])):
			return false
		previous = rect
		var digest = part.get("pixel_sha256")
		if not digest is String or digest.length() != 64: return false
		for i in digest.length():
			if digest[i] not in "0123456789abcdef": return false
	return true

func _reject(reason: String) -> bool:
	failure = reason
	muted = true
	stop_all()
	return false

func apply_audio(packet: Dictionary) -> bool:
	if not failure.is_empty(): return false
	# Validate the entire envelope before allowing any audible side effect.
	for key in ["schema", "frame", "epoch", "last_id"]:
		if not _integer(packet.get(key)) or int(packet[key]) < 0: return _reject("Invalid audio envelope: " + key)
	if int(packet.schema) != 3 or not packet.get("active") is bool or not packet.get("enabled") is bool:
		return _reject("Unsupported original audio envelope")
	if not packet.get("events") is Array or packet.events.size() > 4096:
		return _reject("Invalid original audio event list")
	if not _valid_loops(packet.get("loops", {})): return _reject("Invalid original sound-channel state")
	var next_id := last_event_id
	var next_crew_id := last_crew_message if int(packet.epoch) == epoch else 0
	var prior_frame := -1
	var prior_id := -1
	for event in packet.events:
		if not event is Dictionary: return _reject("Invalid audio event")
		for key in ["id", "frame", "epoch", "ip", "return_ip", "value", "backend"]:
			if not _integer(event.get(key)) or int(event[key]) < 0: return _reject("Invalid audio event: " + key)
		if int(event.id) <= prior_id or int(event.frame) < prior_frame or int(event.frame) > int(packet.frame):
			return _reject("Unordered original audio events")
		if int(event.epoch) > int(packet.epoch) or not event.get("enabled") is bool:
			return _reject("Invalid original audio epoch or gate")
		if event.get("kind") not in ["sound", "gate", "reload_complete", "engine_parameter", "readiness_visible", "crew_visible"]:
			return _reject("Unknown original audio event kind")
		var sample = event.get("sample")
		var speech = event.get("voice")
		if sample != null and (event.kind != "sound" or sample not in SAMPLES):
			return _reject("Unknown remastered sample")
		if event.kind == "readiness_visible":
			if sample != null or speech != "loaded" or not _valid_readiness(event):
				return _reject("Invalid visible original readiness")
		elif event.kind == "crew_visible":
			if sample != null or not _valid_crew(event): return _reject("Invalid visible original crew message")
			if int(event.id) > last_event_id and int(event.epoch) == int(packet.epoch):
				if int(event.message_id) <= next_crew_id: return _reject("Repeated original crew assignment")
				next_crew_id = int(event.message_id)
		elif speech != null and speech != VOICES.get(sample, ""):
			return _reject("Unknown original-event crew voice")
		prior_frame = int(event.frame)
		prior_id = int(event.id)
		if int(event.id) > last_event_id:
			if int(event.id) != next_id + 1: return _reject("Missing original audio event")
			next_id = int(event.id)
	if int(packet.last_id) > last_event_id and next_id != int(packet.last_id):
		return _reject("Incomplete original audio delivery")
	if next_id > maxi(last_event_id, int(packet.last_id)):
		return _reject("Audio event exceeds acknowledged sequence")
	# Old envelopes cannot reset gates, epochs or replay voices.
	if int(packet.frame) <= last_frame:
		if int(packet.last_id) > last_event_id: return _reject("New audio in an old frame")
		return true
	if int(packet.epoch) < epoch or int(packet.last_id) < last_event_id:
		return _reject("Original audio timeline moved backwards")
	if int(packet.epoch) != epoch or not packet.active or not packet.enabled: stop_all()
	epoch = int(packet.epoch)
	last_frame = int(packet.frame)
	muted = not packet.active or not packet.enabled
	for event in packet.events:
		if int(event.id) <= last_event_id: continue
		if event.kind == "gate" and not event.enabled: stop_all()
		var reason := ""
		if int(event.epoch) != epoch: reason = "previous-program"
		elif not packet.active or not packet.enabled or not event.enabled: reason = "original-sound-gate"
		elif last_frame - int(event.frame) > MAX_AGE_FRAMES: reason = "stale-diagnostic-step"
		elif event.kind not in ["readiness_visible", "crew_visible"] and (event.kind != "sound" or event.get("sample") == null): reason = "unmapped-original-request"
		if reason.is_empty():
			if event.get("sample") != null: play(event.sample)
			if event.get("voice") != null: speak(event.voice)
			delivered += 1
		else:
			suppressed += 1
		var receipt := {"id": event.id, "frame": event.frame, "epoch": event.epoch,
			"sample": event.get("sample"), "voice": event.get("voice"), "reason": reason,
			"kind": event.kind, "message_id": event.get("message_id")}
		receipts.append(receipt)
		if receipts.size() > 64: receipts.pop_front()
	last_event_id = next_id
	last_crew_message = next_crew_id
	_sync_loops(packet.get("loops",{}))
	return true
