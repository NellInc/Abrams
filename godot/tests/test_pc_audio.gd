extends SceneTree
const PcAudio = preload("res://scripts/pc_audio.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func sound(id: int, frame: int, sample: String = "cannon", enabled: bool = true, epoch: int = 1) -> Dictionary:
	var request: int = {"cannon":1,"smoke":3,"machinegun":2}.get(sample,1)
	var caller: int = {1:0x33c4,2:0x32fa,3:0x7c07}[request]
	return {"kind":"sound", "ip":0x9107, "return_ip":caller, "value":request, "backend":0,
		"id":id, "frame":frame, "epoch":epoch, "sample":sample,
		"voice":{"cannon":"on_the_way","smoke":"smoke"}.get(sample), "enabled":enabled}

func packet(frame: int, id: int, events: Array, enabled: bool = true, epoch: int = 1) -> Dictionary:
	return {"schema":3, "frame":frame, "epoch":epoch, "last_id":id,
		"active":true, "enabled":enabled, "events":events}

func readiness(id: int, frame: int, enabled: bool = true) -> Dictionary:
	return {"kind":"readiness_visible","ip":0x35ee,"return_ip":0,"value":0,"backend":0,
		"id":id,"frame":frame,"epoch":1,"enabled":enabled,"sample":null,"voice":"loaded",
		"completion_frame":frame-3,"text_sequence":10,"text_draw_sequence":11,
		"text_return_ip":0x55df,"text_pointer":0x0aca,"text_pixel_sha256":"a".repeat(64)}

func loops(engine_on: bool = true, turret_on: bool = false) -> Dictionary:
	return {"engine":{"active":engine_on,"channel":3,"ticks":85,"program":0xbf8,"period":0x4584,
		"amplitude":3,"idle_period":0x4584,"amplitude_reference":3},
		"turret":{"active":turret_on,"channel":2,"ticks":20,"program":0xc4c,"period":8500,
		"amplitude":3,"idle_period":8500,"amplitude_reference":3}}

func crew(id: int, frame: int, assignment: int = 1) -> Dictionary:
	return {"kind":"crew_visible","sample":null,"voice":"pc_hit_zero_four_three",
		"ip":0x3d6a,"return_ip":0,"value":0,"backend":0,"enabled":true,"epoch":1,
		"id":id,"frame":frame,"message_id":assignment,"speaker":3,
		"text":"We've been hit! Bearing 043","parts":[
			{"rect":[46,112,144,6],"draw_sequence":1,"source_pointer":0x95d,"pixel_sha256":"a".repeat(64)},
			{"rect":[190,112,18,6],"draw_sequence":2,"source_pointer":0x6472,"pixel_sha256":"b".repeat(64)}]}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var audio := PcAudio.new()
	root.add_child(audio)
	check(audio.crew_catalogue.size()==442,"24 damage, 360 bearings, eight warnings and 50 remaining source calls")
	for cue: String in audio.crew_catalogue:
		check(audio.get_stream("voice_"+cue)!=null,"generated full-sentence resource: "+cue)
	var warnings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_warning_voice_script.json"))
	for cue: String in warnings.cues:
		var spec: Dictionary=warnings.cues[cue]
		for variant: Array in spec.source_variants:
			var warning_audio := PcAudio.new()
			root.add_child(warning_audio)
			var event := crew(1,10)
			event.voice=cue;event.text=spec.caption;event.ip=spec.assignment_ip;event.speaker=spec.speaker
			event.parts=event.parts.slice(0,variant.size())
			for i in variant.size(): event.parts[i].source_pointer=variant[i]
			check(warning_audio.apply_audio(JSON.parse_string(JSON.stringify(packet(10,1,[event])))),"qualified original warning: "+cue)
			check(warning_audio.voice.playing and warning_audio.last_voice==cue,"actual warning sample player: "+cue)
			check(warning_audio.apply_audio(packet(10,1,[event])) and warning_audio.delivered==1,"warning identity consumed once")
			for fault in ["speaker","pointer","ip","parts","caption"]:
				var bad := event.duplicate(true)
				match fault:
					"speaker":bad.speaker=3
					"pointer":bad.parts[0].source_pointer+=1
					"ip":bad.ip=0x3d6a
					"parts":bad.parts=[]
					"caption":bad.text+="!"
				check(not audio._valid_crew(bad),"warning rejects wrong "+fault)
			check(await warning_audio.drain_for_shutdown(),"warning shutdown")
			warning_audio.queue_free()
			await process_frame
	var damage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_damage_voice_script.json"))
	for cue: String in damage.cues:
		var damage_audio := PcAudio.new()
		root.add_child(damage_audio)
		var event := crew(1,10)
		event.voice=cue
		event.text=damage.cues[cue].caption
		event.ip=0x3dd2
		for i in 2: event.parts[i].source_pointer=damage.cues[cue].source_pointers[i]
		check(damage_audio.apply_audio(packet(10,1,[event])),"source-qualified damage event: "+cue)
		check(damage_audio.last_voice==cue and damage_audio.voice.playing,"actual damage voice player: "+cue)
		check(damage_audio.apply_audio(packet(10,1,[event])) and damage_audio.delivered==1,"damage assignment speaks once: "+cue)
		check(await damage_audio.drain_for_shutdown(),"damage voice shutdown: "+cue)
		damage_audio.queue_free()
		await process_frame
	var fresh_bearing := crew(1,10)
	fresh_bearing.voice="pc_hit_zero_five_eight"
	fresh_bearing.text="We've been hit! Bearing 058"
	check(audio._valid_crew(fresh_bearing),"newly encountered digit-wise bearing retains original source gate")
	fresh_bearing.text="We've been hit! Bearing 059"
	check(not audio._valid_crew(fresh_bearing),"bearing cannot select another number's performance")
	for fault in ["ip","return_ip","value","sample","voice","backend"]:
		var guarded:=PcAudio.new()
		root.add_child(guarded)
		var invalid_source:=sound(1,1)
		match fault:
			"ip": invalid_source.ip=0x9108
			"return_ip": invalid_source.return_ip=0x33c5
			"value": invalid_source.value=2
			"sample": invalid_source.sample="impact"
			"voice": invalid_source.voice=null
			"backend": invalid_source.backend=2
		check(not guarded.apply_audio(packet(1,1,[invalid_source])),"forged sound "+fault+" rejected")
		check(guarded.cursor==0 and not guarded.voice.playing,"forged request fails before playback")
		check(await guarded.drain_for_shutdown(),"forged source drains")
		guarded.queue_free()
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
	var motors := PcAudio.new()
	root.add_child(motors)
	check(motors.engine.stream.loop_end == 96000,"full engine loop survives compressed WAV import")
	check(motors.turret.stream.loop_end == 96000,"full turret loop survives compressed WAV import")
	var loop_packet := packet(1,0,[])
	loop_packet.loops = loops()
	check(motors.apply_audio(loop_packet) and motors.engine.playing and not motors.turret.playing,"restored original engine channel starts")
	check(is_equal_approx(motors.engine.pitch_scale,1.0),"original idle period")
	loop_packet = packet(2,0,[])
	loop_packet.loops = loops(true,true)
	loop_packet.loops.engine.period = 0x3384
	check(motors.apply_audio(loop_packet) and motors.turret.playing,"original turret channel starts")
	check(is_equal_approx(motors.engine.pitch_scale,float(0x4584)/float(0x3384)),"original tone period controls engine pitch")
	check(motors.turret.stream is AudioStreamWAV and motors.turret.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"authored turret PCM loop")
	loop_packet = packet(3,0,[],false)
	loop_packet.loops = loops(true,true)
	check(motors.apply_audio(loop_packet) and not motors.engine.playing and not motors.turret.playing,"original gate silences active channels")
	check(motors.loop_transitions[-1].active == false and motors.loop_transitions[-2].active == false,"mute stops retained in transition evidence")
	loop_packet = packet(4,0,[])
	loop_packet.loops = loops(true,true)
	check(motors.apply_audio(loop_packet) and motors.engine.playing and motors.turret.playing,"gate resume restores original channels")
	loop_packet = packet(5,0,[])
	loop_packet.loops = loops(true,false)
	check(motors.apply_audio(loop_packet) and motors.engine.playing and not motors.turret.playing,"original turret release stops independently")
	loop_packet = packet(6,0,[])
	loop_packet.active = false
	check(motors.apply_audio(loop_packet) and not motors.engine.playing,"leaving SIM clears original engine")
	loop_packet = packet(7,0,[])
	loop_packet.loops = loops()
	loop_packet.loops.engine.period = 0
	check(not motors.apply_audio(loop_packet) and not motors.engine.playing,"invalid active tone fails closed")
	check(await motors.drain_for_shutdown(),"motor playback drains")
	motors.queue_free()
	await process_frame
	var loader := PcAudio.new()
	root.add_child(loader)
	var up := packet(10,1,[readiness(1,10)])
	check(loader.apply_audio(JSON.parse_string(JSON.stringify(up))),"visible readiness JSON envelope")
	check(loader.voice.playing and loader.last_voice == "loaded" and loader.voice.stream == loader.get_stream("voice_loaded"),"actual generative loader sample started")
	check(loader.cursor == 0 and loader.delivered == 1,"readiness is voice-only")
	check(loader.apply_audio(up) and loader.delivered == 1,"repeated READY packet never repeats bark")
	check(loader.apply_audio(packet(11,2,[readiness(2,11,false)],false)),"muted readiness consumed")
	check(not loader.voice.playing and loader.delivered == 1,"muted completion stays silent")
	check(loader.apply_audio(packet(30,3,[readiness(3,20)])),"stale readiness consumed")
	check(loader.delivered == 1 and loader.receipts[-1].reason == "stale-diagnostic-step","old batch never speaks loader backlog")
	check(await loader.drain_for_shutdown(),"loader voice playback drain")
	loader.queue_free()
	await process_frame
	for mode in ["draw_order","delay","caller","pointer","digest","effect","voice","schema"]:
		var bad := PcAudio.new()
		root.add_child(bad)
		var attempt := packet(10,1,[readiness(1,10)])
		match mode:
			"draw_order": attempt.events[0].text_draw_sequence = 10
			"delay": attempt.events[0].completion_frame = 0
			"caller": attempt.events[0].text_return_ip = 0x3f1d
			"pointer": attempt.events[0].text_pointer = 0xad8
			"digest": attempt.events[0].text_pixel_sha256 = "x".repeat(64)
			"effect": attempt.events[0].sample = "cannon"
			"voice": attempt.events[0].voice = "ready"
			"schema": attempt.schema = 1
		check(not bad.apply_audio(attempt) and bad.delivered == 0,"loader "+mode+" rejected before playback")
		check(await bad.drain_for_shutdown(),"loader "+mode+" drain")
		bad.queue_free()
		await process_frame
	var crew_audio := PcAudio.new()
	root.add_child(crew_audio)
	var hit := packet(10,1,[crew(1,10)])
	check(crew_audio.apply_audio(JSON.parse_string(JSON.stringify(hit))),"visible crew JSON envelope")
	check(crew_audio.voice.playing and crew_audio.last_voice == "pc_hit_zero_four_three","actual digit-bearing sample starts")
	check(crew_audio.cursor == 0,"crew is voice-only")
	check(crew_audio.apply_audio(hit) and crew_audio.delivered == 1,"same crew envelope never replays")
	check(crew_audio.apply_audio(packet(11,2,[crew(2,11,2)])) and crew_audio.delivered == 2,"repeated identical report has new original identity")
	check(crew_audio.apply_audio(packet(12,3,[crew(3,12,3)],false)) and not crew_audio.voice.playing,"original mute suppresses crew")
	check(crew_audio.apply_audio(packet(30,4,[crew(4,20,4)])) and crew_audio.delivered == 2,"diagnostic batch never speaks stale crew backlog")
	check(await crew_audio.drain_for_shutdown(),"crew playback drain")
	crew_audio.queue_free()
	await process_frame
	for mode in ["identity","speaker","caption","voice","ip","parts","hash","rect","fraction","effect","duplicate"]:
		var bad := PcAudio.new()
		root.add_child(bad)
		var event := crew(1,10)
		match mode:
			"identity": event.message_id = 0
			"speaker": event.speaker = 1
			"caption": event.text = "We've been hit! Bearing 040"
			"voice": event.voice = "hit"
			"ip": event.ip = 0x3d0c
			"parts": event.parts.pop_back()
			"hash": event.parts[0].pixel_sha256 = "z".repeat(64)
			"rect": event.parts[1].rect[0] = 189
			"fraction": event.parts[0].draw_sequence = 1.5
			"effect": event.sample = "impact"
			"duplicate":
				check(bad.apply_audio(packet(9,1,[crew(1,9)])),"duplicate crew setup")
				event.id = 2
		check(not bad.apply_audio(packet(10,int(event.id),[event])),"crew "+mode+" rejected")
		check(await bad.drain_for_shutdown(),"crew "+mode+" drain")
		bad.queue_free()
		await process_frame
	var pc_script: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_crew_voice_script.json"))
	var pc_receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/pc_crew_provenance.json"))
	pc_script.cues.merge(damage.cues)
	pc_script.cues.merge(warnings.cues)
	pc_receipt.voices.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/pc_damage_provenance.json")).voices)
	pc_receipt.voices.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/pc_warning_provenance.json")).voices)
	for cue in pc_script.cues:
		var stream := load("res://assets/audio/voice_%s.wav" % cue) as AudioStreamWAV
		var entry: Dictionary = pc_receipt.voices[cue]
		check(stream != null and stream.mix_rate == int(entry.sample_rate) and not stream.stereo and not stream.data.is_empty(),"crew imported format "+cue)
		check(absf(stream.get_length()-float(entry.duration_seconds)) < 0.001,"crew imported duration "+cue)
		check(entry.text == pc_script.cues[cue].caption and entry.generator == "gemini-3.8-flash-tts","crew caption/provider "+cue)
	print("PC_AUDIO: %d checks, %d failures" % [checks,failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
