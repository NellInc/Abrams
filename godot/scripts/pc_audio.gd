extends "res://scripts/audio.gd"
## Original PC sound requests only. No keyboard, ammo-delta or range simulation.
## Batched diagnostic steps retain all events, but stale audio is never replayed.
const MAX_AGE_FRAMES := 6
const SAMPLES := ["cannon", "machinegun", "smoke", "impact", "switch", "radio", "pc_request_07", "pc_request_09", "pc_request_10", "pc_request_15", "pc_request_16"]
# Mirror the source-qualified Python dispatcher; names alone are not authority.
const REQUEST_CALLS := {1:[0x33c4],2:[0x32fa],3:[0x7c07],6:[0x6b25,0x74e5,0x7547],
	7:[0x19d1],8:[0x6b25,0x74e5,0x7547],9:[0x0527],10:[0x0974,0x7790],
	11:[0x3c97,0x3cdb],14:[0x15e4,0x15ff,0x1640,0x814d,0x81cf,0x81f3],
	15:[0x034f],16:[0x8219,0x8256]}
const REQUEST_SAMPLES := {1:"cannon",2:"machinegun",3:"smoke",6:"impact",7:"pc_request_07",
	8:"impact",9:"pc_request_09",10:"pc_request_10",11:"radio",14:"switch",15:"pc_request_15",16:"pc_request_16"}
const VOICES := {"cannon": "on_the_way", "smoke": "smoke"}
var crew_catalogue: Dictionary = {}
var last_crew_message := 0
var last_radio_message := 0
var radio_catalogue: Dictionary = {}
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
const FrontendMusic = preload("res://scripts/pc_frontend_music.gd")
var music_bank := FrontendMusic.new()
var music: AudioStreamPlayer
var music_mix := 70
var music_context := ""
var music_allowed := false
var music_starts := 0
var music_resume_position := 0.0
var transport_muted := false
var mix := {"master":100,"effects":100,"voice":100,"motors":100}
var motor_volume := 1.0
var current_loops: Dictionary = {}
const LIMITER_CEILING_DB := -1.0
var presentation_bus := ""

func _create_presentation_bus() -> void:
	# Limit only this PC presentation. Never modify Master or the range mixer.
	presentation_bus="PCPresentation_%s" % get_instance_id()
	AudioServer.add_bus()
	var index:=AudioServer.bus_count-1
	AudioServer.set_bus_name(index,presentation_bus)
	AudioServer.set_bus_send(index,"Master")
	var limiter:=AudioEffectHardLimiter.new()
	limiter.ceiling_db=LIMITER_CEILING_DB
	limiter.pre_gain_db=0.0
	limiter.release=0.1
	AudioServer.add_bus_effect(index,limiter)
	for player in [engine,voice,turret,music]+effects:
		player.bus=presentation_bus

func _exit_tree() -> void:
	super._exit_tree()
	var index:=AudioServer.get_bus_index(presentation_bus)
	if index>0: AudioServer.remove_bus(index)
	presentation_bus=""

func set_mix(settings: Dictionary) -> bool:
	if settings.keys().size() not in [4,5]: return false
	for key in settings:
		if key not in ["master","effects","voice","motors","music"]: return false
	for key in ["master","effects","voice","motors"]:
		if not _integer(settings.get(key)) or settings[key]<0 or settings[key]>100: return false
	if settings.has("music") and (not _integer(settings.music) or settings.music<0 or settings.music>100): return false
	if settings.has("music"): music_mix=int(settings.music)
	mix=settings.duplicate()
	volume=0.65*float(mix.master)/100.0
	effects_volume=float(mix.effects)/100.0
	voice_volume=float(mix.voice)/100.0
	motor_volume=float(mix.motors)/100.0
	if voice==null or turret==null: return true # launch preferences precede _ready
	# Adjust existing streams immediately, without replaying consumed events or
	# changing the original mute gate, frame sequence, source channels or clocks.
	for player in effects:
		player.volume_db=linear_to_db(maxf(0.00001,volume*effects_volume*0.6))
		if volume*effects_volume==0:
			_remember_playback(player)
			player.stop()
	voice.volume_db=linear_to_db(maxf(0.00001,volume*voice_volume*0.8))
	if volume*voice_volume==0:
		_remember_playback(voice)
		voice.stop()
	_sync_loops(current_loops)
	_sync_music()
	return true

func _ready() -> void:
	super._ready()
	radio_catalogue=JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_radio_voice_script.json")).cues
	crew_catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_crew_voice_script.json")).cues
	crew_catalogue.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_bearing_voice_script.json")).cues)
	crew_catalogue.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_damage_voice_script.json")).cues)
	crew_catalogue.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_warning_voice_script.json")).cues)
	crew_catalogue.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_remaining_voice_script.json")).cues)
	turret = AudioStreamPlayer.new()
	add_child(turret)
	var stream := load("res://assets/audio/turret.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Imported WAV data can be QOA, so byte count is not a PCM frame count.
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	turret.stream = stream
	music=AudioStreamPlayer.new()
	add_child(music)
	_create_presentation_bus()
	set_mix(mix)

func _stop_source_audio() -> void:
	super.stop_all()
	if is_instance_valid(turret):
		_remember_playback(turret)
		turret.stop()

func stop_all() -> void:
	_stop_source_audio()
	if is_instance_valid(music):
		_remember_playback(music)
		music.stop()

func set_music_mix(value: int) -> bool:
	if value<0 or value>100: return false
	music_mix=value
	if mix.has("music"): mix.music=value
	_sync_music()
	return true

func music_context_for_frame(source: Image, program: Dictionary, presentation: Dictionary) -> String:
	return music_bank.context_for_frame(source,program,presentation)

func apply_music_context(context: String, enabled: bool, paused: bool=false) -> void:
	# Caller supplies only a currently source-qualified frontend, never guessed
	# from input, queued text, combat outcome or remaster wall-clock pacing.
	var selected := context if context in FrontendMusic.CONTEXTS else ""
	if selected!=music_context:
		if is_instance_valid(music):
			_remember_playback(music)
			music.stop()
		music_context=selected
		music_resume_position=0.0
	music_allowed=enabled and not paused and not selected.is_empty()
	_sync_music()

func _sync_music() -> void:
	if not is_instance_valid(music): return
	var active := music_allowed and not transport_muted and failure.is_empty() and volume*music_mix>0
	if not active:
		if music.playing:
			music_resume_position=music.get_playback_position()
			_remember_playback(music)
			music.stop()
		return
	music.volume_db=linear_to_db(maxf(0.00001,volume*float(music_mix)/100.0*0.30))
	if music.playing: return
	var stream := music_bank.get_stream(music_context)
	if stream==null: return
	music.stream=stream
	music.play(fmod(music_resume_position,stream.get_length()))
	_remember_playback(music)
	music_starts+=1

func set_transport_muted(value: bool) -> void:
	if transport_muted==value: return
	transport_muted=value
	if value:
		_stop_source_audio()
	_sync_loops(current_loops)
	_sync_music()

func reset_timeline() -> void:
	# Use only after a successful host restore, before applying its first packet.
	stop_all()
	last_event_id=0
	last_frame=-1
	epoch=0
	last_crew_message=0
	last_radio_message=0
	last_voice=""
	delivered=0
	suppressed=0
	receipts.clear()
	loop_transitions.clear()
	loop_states={"engine":false,"turret":false}
	current_loops={}
	muted=true
	music_context=""
	music_allowed=false
	music_resume_position=0.0
	# A protocol failure remains latched. Restore is not a validation bypass.

func play(cue: String) -> void:
	if not transport_muted: super.play(cue)

func speak(cue: String) -> void:
	if not transport_muted: super.speak(cue)

func release_streams() -> void:
	super.release_streams()
	if is_instance_valid(turret): turret.stream = null
	if is_instance_valid(music): music.stream=null
	music_allowed=false
	music_context=""
	music_bank.streams.clear()

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
	current_loops=loops
	for name in ["engine", "turret"]:
		var player: AudioStreamPlayer = engine if name == "engine" else turret
		var source: Dictionary = loops.get(name,{})
		var active := not muted and not transport_muted and volume*motor_volume>0 and bool(source.get("active",false))
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
		player.volume_db = linear_to_db(maxf(0.00001,volume*motor_volume*level*(0.08 if name == "engine" else 0.10)))
		if not player.playing:
			player.play()
			_remember_playback(player)

func _integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func _valid_sound(event: Dictionary) -> bool:
	if int(event.ip)!=0x9107: return false
	var request:=int(event.value)
	var mapped: bool = request in REQUEST_CALLS and int(event.return_ip) in REQUEST_CALLS[request]
	var expected = REQUEST_SAMPLES[request] if mapped else null
	return event.get("sample")==expected and event.get("voice")==VOICES.get(expected)

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
	if event.get("voice") not in crew_catalogue: return false
	var cue: Dictionary=crew_catalogue[event.voice]
	var warning := cue.has("assignment_ip")
	if not _integer(event.get("speaker")) or int(event.speaker)!=(int(cue.speaker) if warning else 3): return false
	if event.get("text") != cue.caption: return false
	var bearing: bool = event.voice.begins_with("pc_hit_")
	var expected_ip: int=int(cue.assignment_ip) if warning else (0x3d6a if bearing else 0x3dd2)
	if int(event.ip) != expected_ip or int(event.return_ip) != 0 or int(event.value) != 0:
		return false
	var count: int=int(cue.get("parts_count",2))
	if warning and cue.has("source_variants"): count=cue.source_variants[0].size()
	return _valid_message_parts(event.get("parts"),count,cue.get("source_variants"))

func _valid_radio(event: Dictionary) -> bool:
	if not _integer(event.get("message_id")) or int(event.message_id)<1: return false
	if event.get("voice") not in radio_catalogue or event.get("speaker")!=null: return false
	var cue: Dictionary=radio_catalogue[event.voice]
	if event.get("text")!=cue.caption or not cue.assignment_ips.any(func(ip):return int(ip)==int(event.ip)): return false
	if int(event.return_ip)!=0 or int(event.value)!=0: return false
	return _valid_message_parts(event.get("parts"),1,cue.get("source_variants"))

func _valid_message_parts(parts, count: int, variants) -> bool:
	if not parts is Array or parts.size()!=count: return false
	var previous: Array = []
	var pointers: Array = []
	for part in parts:
		if not part is Dictionary: return false
		for field in ["draw_sequence", "source_pointer"]:
			if not _integer(part.get(field)) or int(part[field]) < 1: return false
		if int(part.source_pointer) > 65535: return false
		pointers.append(int(part.source_pointer))
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
	if variants!=null and not variants.any(func(variant): return variant.map(func(p): return int(p))==pointers): return false
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
	var next_radio_id := last_radio_message if int(packet.epoch)==epoch else 0
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
		if event.get("kind") not in ["sound", "gate", "reload_complete", "engine_parameter", "readiness_visible", "crew_visible", "radio_visible"]:
			return _reject("Unknown original audio event kind")
		var sample = event.get("sample")
		var speech = event.get("voice")
		if sample != null and (event.kind != "sound" or sample not in SAMPLES):
			return _reject("Unknown remastered sample")
		if event.kind == "sound" and not _valid_sound(event):
			return _reject("Invalid original sound request identity")
		if event.enabled and int(event.backend) not in [0,1]:
			return _reject("Unsupported enabled original sound backend")
		if event.kind == "readiness_visible":
			if sample != null or speech != "loaded" or not _valid_readiness(event):
				return _reject("Invalid visible original readiness")
		elif event.kind == "radio_visible":
			if sample != null or not _valid_radio(event): return _reject("Invalid visible original radio message")
			if int(event.id)>last_event_id and int(event.epoch)==int(packet.epoch):
				if int(event.message_id)<=next_radio_id: return _reject("Repeated original radio assignment")
				next_radio_id=int(event.message_id)
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
	if int(packet.epoch) != epoch or not packet.active or not packet.enabled: _stop_source_audio()
	if packet.active: apply_music_context("",false) # gameplay remains musically quiet
	epoch = int(packet.epoch)
	last_frame = int(packet.frame)
	muted = not packet.active or not packet.enabled
	for event in packet.events:
		if int(event.id) <= last_event_id: continue
		if event.kind == "gate" and not event.enabled: _stop_source_audio()
		var reason := ""
		if int(event.epoch) != epoch: reason = "previous-program"
		elif not packet.active or not packet.enabled or not event.enabled: reason = "original-sound-gate"
		elif transport_muted: reason = "presentation-transport-muted"
		elif last_frame - int(event.frame) > MAX_AGE_FRAMES: reason = "stale-diagnostic-step"
		elif event.kind not in ["readiness_visible", "crew_visible", "radio_visible"] and (event.kind != "sound" or event.get("sample") == null): reason = "unmapped-original-request"
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
	last_radio_message = next_radio_id
	_sync_loops(packet.get("loops",{}))
	return true
