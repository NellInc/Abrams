extends SceneTree
const Audio = preload("res://scripts/pc_audio.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func event(name: String, cue: Dictionary, id := 1, frame := 10, assignment := 1) -> Dictionary:
	return {"kind":"radio_visible","sample":null,"voice":name,"ip":0x3f73,
		"return_ip":0,"value":0,"backend":0,"enabled":true,"epoch":1,"id":id,"frame":frame,
		"message_id":assignment,"speaker":null,"text":cue.caption,"parts":[{
			"rect":[46,112,180,6],"source_pointer":cue.source_variants[0][0] if cue.has("source_variants") else 0xb000,
			"draw_sequence":1,"pixel_sha256":"a".repeat(64)}]}

func packet(frame: int, id: int, events: Array, enabled := true, epoch := 1) -> Dictionary:
	return {"schema":3,"frame":frame,"last_id":id,"epoch":epoch,"active":true,"enabled":enabled,"events":events}

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var cues: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_radio_voice_script.json")).cues
	check(cues.size()==7,"seven original radio performances")
	for name: String in cues:
		var cue: Dictionary=cues[name]
		for ip in cue.assignment_ips:
			var audio := Audio.new();root.add_child(audio)
			var current := event(name,cue);current.ip=ip
			check(audio.get_stream("voice_"+name)!=null,"radio asset imported")
			check(audio.apply_audio(JSON.parse_string(JSON.stringify(packet(10,1,[current])))),"radio JSON packet accepted")
			check(audio.voice.playing and audio.last_voice==name,"actual radio voice player started")
			check(audio.apply_audio(packet(10,1,[current])) and audio.delivered==1,"same packet stays once-only")
			for fault in ["speaker","ip","text","parts","hash","voice"]:
				var bad := current.duplicate(true)
				match fault:
					"speaker":bad.speaker=3
					"ip":bad.ip=0x3d6a
					"text":bad.text+=" invented"
					"parts":bad.parts=[]
					"hash":bad.parts[0].pixel_sha256="bad"
					"voice":bad.voice="pc_no_smoke_mortars"
				check(not audio._valid_radio(bad),"radio rejects wrong "+fault)
			var muted := event(name,cue,2,11,2);muted.enabled=false
			check(audio.apply_audio(packet(11,2,[muted],false)),"muted report consumed")
			check(not audio.voice.playing and audio.receipts[-1].reason=="original-sound-gate","original mute owns speech")
			check(audio.apply_audio(packet(12,2,[])) and not audio.voice.playing,"restoring sound cannot replay old radio")
			var fresh := event(name,cue,3,13,3)
			check(audio.apply_audio(packet(13,3,[fresh])) and audio.voice.playing,"new original retrieval speaks again")
			var new_epoch := event(name,cue,4,14,1);new_epoch.epoch=2
			check(audio.apply_audio(packet(14,4,[new_epoch],true,2)),"new SIM epoch owns new radio identities")
			check(await audio.drain_for_shutdown(),"radio playback drains")
			audio.queue_free();await process_frame
	var audio := Audio.new();root.add_child(audio)
	var signal_event := {"kind":"sound","sample":"radio","voice":null,"ip":0x9107,"return_ip":0x3c97,"value":11,
		"backend":0,"enabled":true,"epoch":1,"id":1,"frame":10}
	check(audio.apply_audio(packet(10,1,[signal_event])),"source radio attention signal accepted")
	check(audio.effects[0].playing and not audio.voice.playing,"attention is a sample without queued speech")
	var stale := event("pc_radio_hind",cues.pc_radio_hind,2,11)
	check(audio.apply_audio(packet(30,2,[stale])) and audio.receipts[-1].reason=="stale-diagnostic-step","old batched radio is not replayed")
	check(await audio.drain_for_shutdown(),"signal playback drains")
	audio.queue_free();await process_frame
	for failure in failures:printerr("FAIL: "+failure)
	print("PC_RADIO: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
