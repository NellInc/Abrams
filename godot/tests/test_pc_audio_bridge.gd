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
var drained := false
var errors: Array[String] = []
var events: Array = []
var heard: Array = []
var output := ""

func _initialize() -> void: start.call_deferred()

func start() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	output = args[args.find("--output")+1] if "--output" in args else directory.path_join("artifacts/pc-audio-native")
	DirAccess.make_dir_recursive_absolute(output)
	audio = PcAudio.new()
	root.add_child(audio)
	var steps := [[30,[]],[3,["c"]],[30,[]],[3,["space"]],[300,[]],
		[3,["m"]],[30,[]],[3,["s"]],[30,[]],
		[3,["f5"]],[30,[]],[3,["space"]],[300,[]],
		[3,["f5"]],[30,[]],[3,["escape"]],[30,[]],[3,["space"]],[30,[]],
		[3,["space"]],[180,[]]]
	for step in steps:
		for _i in int(step[0]): commands.append(step[1])
	var python := OS.get_environment("ABRAMS_PYTHON")
	if python.is_empty(): python = "/opt/homebrew/bin/python3"
	bridge.start(python,directory.path_join("artifacts/pc-source-boot-01/mission-entry/reference.state"),
		output.path_join("saves"),output.path_join("host.log"),"trace")
	started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if not audio: return false
	for message in bridge.poll():
		var packet: Dictionary = message.get("audio",{})
		events.append_array(packet.get("events",[]))
		var last := int(audio.last_event_id)
		if not audio.apply_audio(packet): errors.append(audio.failure)
		for receipt in audio.receipts:
			if int(receipt.id) > last and receipt.reason.is_empty():
				heard.append(receipt.duplicate())
				var player: AudioStreamPlayer = audio.effects[(audio.cursor-1) % audio.effects.size()]
				if not player.playing or player.stream == null: errors.append("Mapped event did not start sample")
	if not bridge.failure.is_empty() and bridge.failure not in errors: errors.append(bridge.failure)
	if Time.get_ticks_msec()-started > 180000 and not stopping: errors.append("native audio bridge deadline")
	if stopping:
		if drained and bridge.has_exited(): finish()
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
	bridge.close()
	drained = await audio.drain_for_shutdown()
	if not drained:
		errors.append("native playback did not drain")
		drained = true

func finish() -> void:
	var counts := {}
	for event in heard: counts[event.sample] = int(counts.get(event.sample,0)) + 1
	if int(counts.get("cannon",0)) != 2: errors.append("Expected two audible original cannon requests")
	if int(counts.get("machinegun",0)) != 1: errors.append("Expected one original machine-gun request")
	if int(counts.get("smoke",0)) != 1: errors.append("Expected one original smoke request")
	var muted_shots := events.filter(func(e): return e.kind == "sound" and e.get("sample") == "cannon" and not e.enabled)
	if muted_shots.size() != 1: errors.append("Expected one silent original cannon request")
	var gates := events.filter(func(e): return e.kind == "gate")
	if gates.size() != 4: errors.append("Expected F5 off/on and pause/resume gates")
	if bridge.exit_code() != 0: errors.append("PC child did not exit cleanly")
	var report := {"frames":index,"events":events,"heard":heard,"sample_counts":counts,
		"muted_shots":muted_shots.size(),"gates":gates.size(),"child_exit":bridge.exit_code(),"errors":errors,
		"scope":"actual original PC host and native Godot playback, no mixed audio recording"}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_AUDIO_NATIVE: " + JSON.stringify({"frames":index,"counts":counts,"events":events.size(),"errors":errors}))
	quit(0 if errors.is_empty() else 1)
