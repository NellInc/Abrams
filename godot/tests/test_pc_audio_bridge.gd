extends SceneTree
## Actual child-process PC core, one-frame transport, native sample playback.
const Bridge = preload("res://scripts/pc_bridge.gd")
const PcAudio = preload("res://scripts/pc_audio.gd")
var bridge = Bridge.new()
var audio: Node
var commands: Array = []
var index := 0
var started := 0
var stopping := false
var stop_started := 0
var finished := false
var drained := false
var errors: Array[String] = []
var events: Array = []
var heard: Array = []
var readiness_events: Array = []
var readiness_checks := 0
var output := ""
var loop_checks := 0
var engine_periods: Dictionary = {}
var turret_active_frames := 0
var muted_loop_frames := 0
var loop_frames: Dictionary = {}

func _initialize() -> void: start.call_deferred()

func start() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	output = args[args.find("--output")+1] if "--output" in args else directory.path_join("artifacts/pc-audio-native")
	DirAccess.make_dir_recursive_absolute(output)
	audio = PcAudio.new()
	root.add_child(audio)
	for name in ["engine","turret"]:
		loop_frames[name] = audio[name].stream.loop_end
		if int(loop_frames[name]) != 96000: errors.append("Compressed WAV loop has wrong sample-frame endpoint")
	var steps := [[30,[]],[3,["f4"]],[30,[]],[60,["kp8"]],[60,[]],[3,["kp5"]],[240,[]],
		[3,["f1"]],[60,[]],[3,["c"]],[30,[]],[60,["kp6"]],[30,[]],[3,["kp5"]],[90,[]],
		[3,["space"]],[300,[]],
		[3,["m"]],[30,[]],[3,["s"]],[30,[]],
		[3,["f5"]],[30,[]],[3,["space"]],[300,[]],
		[3,["f5"]],[30,[]],[3,["escape"]],[30,[]],[3,["space"]],[30,[]],
		[3,["space"]],[200,[]]]
	for step in steps:
		for _i in int(step[0]): commands.append(step[1])
	var python := Bridge.default_python()
	bridge.start(python,directory.path_join("artifacts/pc-source-boot-01/mission-entry/reference.state"),
		output.path_join("saves"),output.path_join("host.log"),"trace")
	started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if not audio: return false
	for message in bridge.poll():
		var packet: Dictionary = message.get("audio",{})
		events.append_array(packet.get("events",[]))
		for event in packet.get("events",[]):
			if event.kind == "readiness_visible":
				readiness_events.append(event)
				var runs: Array = message.get("presentation",{}).get("text_runs",[])
				var match_found := false
				for run in runs:
					if run.kind == "weapon_status" and run.text == "READY " and int(run.draw_sequence) == int(event.text_draw_sequence) and run.pixel_sha256 == event.text_pixel_sha256:
						match_found = true
				if not match_found: errors.append("Loader bark has no paired visible READY evidence")
				if int(event.frame)-int(event.completion_frame) < 1: errors.append("Loader bark did not wait for later visible frame")
				readiness_checks += 1
		var last := int(audio.last_event_id)
		if not audio.apply_audio(packet): errors.append(audio.failure)
		for name in ["engine","turret"]:
			var source: Dictionary = packet.get("loops",{}).get(name,{})
			var player: AudioStreamPlayer = audio.engine if name == "engine" else audio.turret
			var expected: bool = bool(packet.get("active",false)) and bool(packet.get("enabled",false)) and bool(source.get("active",false))
			if player.playing != expected: errors.append("Original channel/playback mismatch: " + name)
			loop_checks += 1
			if expected:
				if not is_equal_approx(player.pitch_scale,clampf(float(source.idle_period)/float(source.period),0.25,4.0)):
					errors.append("Original tone period/playback pitch mismatch: " + name)
				if name == "engine": engine_periods[int(source.period)] = true
				else: turret_active_frames += 1
			elif bool(source.get("active",false)): muted_loop_frames += 1
		for receipt in audio.receipts:
			if int(receipt.id) > last and receipt.reason.is_empty():
				heard.append(receipt.duplicate())
				if receipt.sample != null:
					var player: AudioStreamPlayer = audio.effects[(audio.cursor-1) % audio.effects.size()]
					if not player.playing or player.stream == null: errors.append("Mapped event did not start sample")
				if receipt.voice != null and (not audio.voice.playing or audio.last_voice != receipt.voice):
					errors.append("Mapped event did not start its generated voice")
	if not bridge.failure.is_empty() and bridge.failure not in errors: errors.append(bridge.failure)
	if Time.get_ticks_msec()-started > 240000 and not stopping: errors.append("native audio bridge deadline")
	if stopping:
		if finished: pass
		elif drained and bridge.has_exited(): finish()
		elif Time.get_ticks_msec()-stop_started > 15000:
			# A wedged host never reads quit; bound shutdown and leave no orphan child.
			bridge.kill()
			errors.append("PC child did not exit after quit; terminated")
			finish()
	elif not errors.is_empty(): stop.call_deferred()
	elif not bridge.pending:
		if index < commands.size():
			bridge.step(1,commands[index])
			index += 1
		else: stop.call_deferred()
	return false

func stop() -> void:
	if stopping: return
	stopping = true
	stop_started = Time.get_ticks_msec()
	bridge.close()
	drained = await audio.drain_for_shutdown()
	if not drained:
		errors.append("native playback did not drain")
		drained = true

func finish() -> void:
	finished = true
	var counts := {}
	var speech_counts := {}
	for event in heard:
		if event.sample != null: counts[event.sample] = int(counts.get(event.sample,0)) + 1
		if event.voice != null: speech_counts[event.voice] = int(speech_counts.get(event.voice,0)) + 1
	if int(speech_counts.get("loaded",0)) != 2: errors.append("Expected two audible visible-readiness barks")
	if readiness_events.size() != 3: errors.append("Expected three visible readiness receipts including muted load")
	if int(counts.get("cannon",0)) != 2: errors.append("Expected two audible original cannon requests")
	if int(counts.get("machinegun",0)) != 1: errors.append("Expected one original machine-gun request")
	if int(counts.get("smoke",0)) != 1: errors.append("Expected one original smoke request")
	var muted_shots := events.filter(func(e): return e.kind == "sound" and e.get("sample") == "cannon" and not e.enabled)
	if muted_shots.size() != 1: errors.append("Expected one silent original cannon request")
	var gates := events.filter(func(e): return e.kind == "gate")
	if gates.size() != 4: errors.append("Expected F5 off/on and pause/resume gates")
	if engine_periods.size() < 2: errors.append("Original engine tone never changed")
	if turret_active_frames == 0: errors.append("Original turret loop never sounded")
	if muted_loop_frames == 0: errors.append("Muted original loops were not exercised")
	var engine_stops: Array = audio.loop_transitions.filter(func(e): return e.name == "engine" and not e.active)
	if engine_stops.size() != 2: errors.append("F5 and pause missing from loop-transition evidence")
	if bridge.exit_code() != 0: errors.append("PC child did not exit cleanly")
	var report := {"frames":index,"events":events,"heard":heard,"sample_counts":counts,
		"readiness_events":readiness_events,"speech_counts":speech_counts,"readiness_checks":readiness_checks,
		"loop_checks":loop_checks,"loop_frames":loop_frames,"engine_periods":engine_periods.keys(),"turret_active_frames":turret_active_frames,
		"muted_loop_frames":muted_loop_frames,"loop_transitions":audio.loop_transitions,
		"muted_shots":muted_shots.size(),"gates":gates.size(),"child_exit":bridge.exit_code(),"errors":errors,
		"scope":"actual original PC host and native Godot playback, no mixed audio recording"}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_AUDIO_NATIVE: " + JSON.stringify({"frames":index,"counts":counts,"speech_counts":speech_counts,"readiness_checks":readiness_checks,"events":events.size(),"loop_checks":loop_checks,"turret_frames":turret_active_frames,"errors":errors}))
	quit(0 if errors.is_empty() else 1)
