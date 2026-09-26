extends Node
## Event-driven presentation only. Never sends commands back to simulation.
var muted := false
var voice_enabled := true
var volume := 0.65
var engine: AudioStreamPlayer
var voice: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var cursor := 0
var last_voice := ""
var cache: Dictionary = {}
var playback_lifetimes: Array[WeakRef] = []

func _ready() -> void:
	engine = AudioStreamPlayer.new()
	add_child(engine)
	var stream := load("res://assets/audio/engine.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size()/2
	engine.stream = stream
	engine.volume_db = -28
	voice = AudioStreamPlayer.new()
	add_child(voice)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		effects.append(p)

func get_stream(cue: String) -> AudioStream:
	if not cache.has(cue):
		var path := "res://assets/audio/%s.wav" % cue
		if not ResourceLoader.exists(path):
			return null
		cache[cue] = load(path)
	return cache[cue]

func play(cue: String) -> void:
	if muted:
		return
	var stream := get_stream(cue)
	if stream == null:
		return
	var p := effects[cursor % effects.size()]
	cursor += 1
	p.stream = stream
	p.volume_db = linear_to_db(volume * 0.6)
	p.play()
	_remember_playback(p)

func speak(cue: String) -> void:
	last_voice = cue
	if muted or not voice_enabled:
		return
	var stream := get_stream("voice_"+cue)
	if stream == null:
		return
	voice.stream = stream
	voice.volume_db = linear_to_db(volume * 0.8)
	voice.play()
	_remember_playback(voice)

func update_engine(speed: float, active: bool) -> void:
	if muted or not active:
		engine.stop()
		return
	engine.pitch_scale = 0.85 + absf(speed)*0.032
	engine.volume_db = linear_to_db(volume*(0.055+minf(absf(speed)*0.003,0.09)))
	if not engine.playing:
		engine.play()
		_remember_playback(engine)

func _remember_playback(player: AudioStreamPlayer) -> void:
	playback_lifetimes = playback_lifetimes.filter(func(reference): return reference.get_ref() != null)
	if player.has_stream_playback():
		playback_lifetimes.append(weakref(player.get_stream_playback()))

func stop_all() -> void:
	for p in [engine, voice] + effects:
		_remember_playback(p)
		p.stop()

func release_streams() -> void:
	stop_all()
	engine.stream = null
	voice.stream = null
	for p in effects:
		p.stream = null
	cache.clear()

func drain_for_shutdown() -> bool:
	# AudioServer can retain stopped playback until its next mixing pass. Track
	# actual playback lifetime instead of relying on one fast scene-tree frame.
	muted = true
	release_streams()
	var deadline := Time.get_ticks_msec() + 1000
	while playback_lifetimes.any(func(reference): return reference.get_ref() != null):
		if Time.get_ticks_msec() >= deadline:
			push_error("Audio playback did not drain before the shutdown deadline")
			return false
		await get_tree().create_timer(0.01, true, false, true).timeout
	playback_lifetimes.clear()
	return true

func _exit_tree() -> void:
	release_streams()
