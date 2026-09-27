extends SceneTree
const PcAudio = preload("res://scripts/pc_audio.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func sound(id: int, frame: int, sample: String = "cannon", enabled: bool = true, epoch: int = 1) -> Dictionary:
	return {"kind":"sound", "ip":0x9107, "return_ip":0x33c4, "value":1, "backend":0,
		"id":id, "frame":frame, "epoch":epoch, "sample":sample,
		"voice":"on_the_way" if sample == "cannon" else null, "enabled":enabled}

func packet(frame: int, id: int, events: Array, enabled: bool = true, epoch: int = 1) -> Dictionary:
	return {"schema":1, "frame":frame, "epoch":epoch, "last_id":id,
		"active":true, "enabled":enabled, "events":events}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var audio := PcAudio.new()
	root.add_child(audio)
	var first := packet(10,1,[sound(1,10)])
	# The real pipe uses JSON floats, not hand-authored integer dictionaries.
	check(audio.apply_audio(JSON.parse_string(JSON.stringify(first))),"JSON first event")
	check(audio.delivered == 1 and audio.effects[0].playing,"actual sample player started")
	check(audio.last_voice == "on_the_way" and audio.voice.playing,"actual generated voice started")
	check(audio.apply_audio(first) and audio.delivered == 1,"replayed packet never repeats audio")
	var off := packet(11,2,[{"kind":"gate","ip":0x8da3,"return_ip":0x4080,"value":0,"backend":0,
		"id":2,"frame":11,"epoch":1,"enabled":false}],false)
	check(audio.apply_audio(off),"original pause gate")
	check(not audio.voice.playing and not audio.effects[0].playing,"pause stops voices and effects")
	check(audio.apply_audio(packet(12,3,[sound(3,12,"cannon",false)],false)),"muted original shot")
	check(audio.delivered == 1,"muted shot stays silent")
	check(audio.apply_audio(packet(30,4,[sound(4,15)])),"batched old event consumed")
	check(audio.delivered == 1 and audio.receipts[-1].reason == "stale-diagnostic-step","no stale burst")
	check(audio.apply_audio(packet(31,6,[sound(5,30,"smoke",true,1),sound(6,31,"machinegun",true,2)],true,2)),"epoch transition")
	check(audio.delivered == 2 and audio.receipts[-2].reason == "previous-program","old mission sound discarded")
	check(not audio.engine.playing,"no invented engine loop")
	check(audio.apply_audio(off) and not audio.muted,"old envelope cannot mute new epoch")
	var invalid := packet(32,8,[sound(7,32),sound(8,32,"../bad")],true,2)
	check(not audio.apply_audio(invalid) and audio.delivered == 2,"atomic fail closed before any partial playback")
	check(audio.muted and not audio.voice.playing,"invalid event clears live audio")
	check(await audio.drain_for_shutdown(),"real playback drain")
	audio.queue_free()
	await process_frame
	for mode in ["gap","missing","future","fraction","voice","backwards","overflow"]:
		var bad := PcAudio.new()
		root.add_child(bad)
		check(bad.apply_audio(packet(1,1,[sound(1,1)])),mode+" initial")
		var attempt := packet(2,2,[sound(2,2)])
		match mode:
			"gap": attempt = packet(2,3,[sound(3,2)])
			"missing": attempt.events = []
			"future": attempt.events[0].frame = 3
			"fraction": attempt.events[0].id = 2.5
			"voice": attempt.events[0].voice = "hit"
			"backwards": attempt.epoch = 0
			"overflow": attempt.events.resize(4097)
		check(not bad.apply_audio(attempt) and bad.delivered == 1,mode+" rejected")
		check(await bad.drain_for_shutdown(),mode+" drain")
		bad.queue_free()
		await process_frame
	print("PC_AUDIO: %d checks, %d failures" % [checks,failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
