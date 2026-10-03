extends SceneTree
## One-frame original-PC transport, all observed crew barks, native playback.
const Bridge = preload("res://scripts/pc_bridge.gd")
const PcAudio = preload("res://scripts/pc_audio.gd")
var bridge = Bridge.new()
var audio: Node
var output := ""
var index := 0
var started := 0
var stopping := false
var stop_started := 0
var finished := false
var drained := false
var errors: Array[String] = []
var heard: Array = []
var barks: Array = []
var expected: Array = []
var final_program := ""
var received_frames := 0
var approach := false
var approach_keys: Array = []

func _initialize() -> void: start.call_deferred()

func start() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	approach = "--approach" in args
	var at := args.find("--output")+1
	var reference_at := args.find("--reference")+1
	var valid := func(i: int) -> bool: return i > 0 and i < args.size() and not args[i].begins_with("--")
	if not valid.call(at) or (not approach and not valid.call(reference_at)):
		printerr("usage: test_pc_crew_bridge.gd -- (--approach | --reference <report.json>) --output <fresh dir>")
		quit(2)
		return
	output = args[at]
	if DirAccess.dir_exists_absolute(output):
		printerr("Fresh native crew output required")
		quit(1)
		return
	if approach:
		var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_vehicle_approach_steps.json"))
		for step: Array in steps:
			for i in int(step[0]): approach_keys.append(step[1])
	else:
		var report = JSON.parse_string(FileAccess.get_file_as_string(args[reference_at]))
		if not report is Dictionary or not report.get("audio_events") is Array:
			printerr("Crew reference report unreadable: " + args[reference_at])
			quit(2)
			return
		expected = report.audio_events.filter(func(e): return e.kind == "crew_visible")
	DirAccess.make_dir_recursive_absolute(output)
	audio = PcAudio.new()
	root.add_child(audio)
	var python := Bridge.default_python()
	bridge.start(python,directory.path_join("artifacts/pc-source-boot-01/mission-entry/reference.state"),
		output.path_join("saves"),output.path_join("host.log"),"trace")
	started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if not audio: return false
	for message in bridge.poll():
		received_frames += 1
		var packet: Dictionary = message.get("audio",{})
		var visible: Array = message.get("presentation",{}).get("messages",[])
		for event in packet.get("events",[]):
			if event.kind != "crew_visible": continue
			barks.append(event.duplicate())
			var matches: Array = visible.filter(func(m): return int(m.id) == int(event.message_id) and m.text == event.text and m.parts == event.parts)
			if matches.size() != 1: errors.append("Bark lacks its complete presented original message")
			var references: Array = expected.filter(func(e): return int(e.message_id) == int(event.message_id))
			if approach: pass # Current presented pixels above own the native-event proof.
			elif references.size() != 1:
				errors.append("Unexpected original message identity")
			elif int(references[0].frame_index) != index or references[0].voice != event.voice or references[0].parts != event.parts:
				errors.append("Live crew event differs from parity-tested trace")
		var last := int(audio.last_event_id)
		if not audio.apply_audio(packet): errors.append(audio.failure)
		for receipt in audio.receipts:
			if int(receipt.id) <= last or receipt.kind != "crew_visible": continue
			heard.append(receipt.duplicate())
			if not receipt.reason.is_empty(): errors.append("Unexpectedly suppressed original visible crew")
			if not audio.voice.playing or audio.last_voice != receipt.voice or audio.voice.stream != audio.get_stream("voice_"+receipt.voice):
				errors.append("Original crew event did not start its generated stream")
		final_program = str(message.program.name) if message.get("program") != null else ""
	if not bridge.failure.is_empty() and bridge.failure not in errors: errors.append(bridge.failure)
	if Time.get_ticks_msec()-started > 600000 and not stopping: errors.append("native crew bridge deadline")
	if stopping:
		if finished: pass
		elif drained and bridge.has_exited(): finish()
		elif Time.get_ticks_msec()-stop_started > 15000:
			# A wedged host never reads quit; bound shutdown and leave no orphan child.
			bridge.kill()
			errors.append("PC core host did not exit after quit; terminated")
			finish()
	elif not errors.is_empty(): stop.call_deferred()
	elif not bridge.pending:
		if approach:
			if index>=approach_keys.size(): stop.call_deferred()
			else:
				bridge.step(1,approach_keys[index])
				index+=1
		elif final_program != "SIM": stop.call_deferred()
		else:
			index += 1
			if index >= 12000:
				errors.append("Original SIM did not exit within fixture")
				stop.call_deferred()
			else:
				bridge.step(1,["r"] if index >= 600 and (index-600)%1200 < 3 else [])
	return false

func stop() -> void:
	if stopping: return
	stopping = true
	stop_started = Time.get_ticks_msec()
	bridge.close()
	drained = await audio.drain_for_shutdown()
	if not drained:
		errors.append("Native crew playback did not drain")
		drained = true

func finish() -> void:
	finished = true
	if approach:
		if received_frames != approach_keys.size()+1: errors.append("Approach route frame count differs")
		if final_program != "SIM": errors.append("Approach unexpectedly left original mission")
		if not heard.any(func(r):return r.voice=="pc_hit_zero_five_eight"): errors.append("New original bearing 058 never spoke")
	else:
		if received_frames != 8576: errors.append("Expected 8576 original fixture frames")
		if final_program != "END": errors.append("Expected original END transition")
		if barks.size() != 16 or heard.size() != 16: errors.append("Expected 16 once-only original visible crew performances")
	var ids := {}
	var cues := {}
	for event in barks:
		ids[int(event.message_id)] = true
		cues[event.voice] = true
	if approach:
		if ids.size()!=barks.size() or heard.size()!=barks.size(): errors.append("Approach repeated or omitted an original crew assignment")
	elif ids.size() != 16 or ids.has(15) or cues.size() != 14: errors.append("Duplicate, hidden or missing crew messages")
	if bridge.exit_code() != 0: errors.append("Original PC child exit failure")
	var report := {"frames":received_frames,"final_program":final_program,"barks":barks,"heard":heard,
		"voices":cues.keys(),"child_exit":bridge.exit_code(),"errors":errors,
		"scope":"Actual native AudioStreamPlayer starts paired with complete original visible messages; approach mode checks current frames, original mode also checks parity-trace receipts; no mixed recording or physical-device latency measurement"}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_CREW_NATIVE: " + JSON.stringify({"frames":received_frames,"barks":barks.size(),"voices":cues.size(),"child_exit":bridge.exit_code(),"errors":errors}))
	quit(0 if errors.is_empty() else 1)
