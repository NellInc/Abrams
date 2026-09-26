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

func update_engine(speed: float, active: bool) -> void:
	if muted or not active:
		engine.stop()
		return
	engine.pitch_scale = 0.85 + absf(speed)*0.032
	engine.volume_db = linear_to_db(volume*(0.055+minf(absf(speed)*0.003,0.09)))
	if not engine.playing:
		engine.play()

func stop_all() -> void:
	engine.stop()
	voice.stop()
	for p in effects:
		p.stop()

func _exit_tree() -> void:
	# Release playback and cached stream references before audio-server teardown.
	stop_all()
	engine.stream = null
	voice.stream = null
	for p in effects:
		p.stream = null
	cache.clear()
