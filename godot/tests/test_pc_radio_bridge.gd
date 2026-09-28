extends "res://scripts/pc_bridge_viewer.gd"
## Actual production viewer, one original frame per request, no guest mutation.
var fixture: Dictionary
var events_by_frame := {}
var errors: Array[String] = []
var checks := 0
var radios: Array = []
var radio_receipts: Array = []
var alert_receipts: Array = []
var photographing := false
var muted_radio_seen := false
var fresh_radio_seen := false
var restored_silent_frames := 0
var portrait_frames: Array[Dictionary] = []

class RadioBridge extends "res://scripts/pc_bridge.gd":
	var radio_state: String
	func start(python, _state, saves, log_path, backend="reference", _audit=false) -> bool:
		return super.start(python,radio_state,saves,log_path,backend,true)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not ["--fixture","--output","--capture","--trace","--play","--frame-audit"].all(func(flag):return flag in args) or "--no-audio" in args:
		printerr("Radio bridge needs --fixture REPORT --output NEW --capture --trace --play --frame-audit")
		quit(2)
		return
	var path := args[args.find("--fixture")+1]
	var target := args[args.find("--output")+1]
	fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	var comparison: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join("comparison.json")))
	if DirAccess.dir_exists_absolute(target) or fixture.get("profile")!="radio-retrieval" or fixture.frames.size()!=3716 or not comparison.get("passed",false) or FileAccess.get_sha256(path)!=comparison.get("trace_sha256"):
		printerr("Radio bridge needs a fresh output and the passing 3716-frame parity fixture")
		quit(2)
		return
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if FileAccess.get_sha256(directory.path_join("artifacts/pc-radio-scout-01/entry/reference.state"))!=fixture.state_sha256:
		printerr("Radio bridge starting source state differs")
		quit(2)
		return
	for event: Dictionary in fixture.audio_events:
		var frame := int(event.frame_index)
		if not events_by_frame.has(frame): events_by_frame[frame]=[]
		var expected := event.duplicate(true)
		expected.erase("frame_index")
		events_by_frame[frame].append(expected)
	bridge=RadioBridge.new()
	bridge.radio_state=directory.path_join("artifacts/pc-radio-scout-01/entry/reference.state")
	super._initialize()
	auto_steps=[]
	# Host's ready packet already executes fixture frame zero (neutral keys).
	for record: Dictionary in fixture.frames.slice(1):auto_steps.append([1,record.keys])
	check(fixture.frames[0].keys.is_empty(),"ready input is neutral")

func _capture_deadline_msec() -> int: return 600000

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok and errors.size()<20:errors.append(label)

func _process(delta: float) -> bool:
	if photographing:return false
	return super._process(delta)

func photograph(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native photograph: "+label)
	photographing=false
	if not errors.is_empty():bridge.failure=errors[0]

func _apply_sample(message: Dictionary) -> void:
	var last := int(pc_audio.last_event_id)
	super._apply_sample(message)
	var index := int(message.sequence)
	check(index>=0 and index<fixture.frames.size(),"known original frame")
	if index<0 or index>=fixture.frames.size():bridge.failure="unknown radio route frame";return
	var source: Dictionary=fixture.frames[index]
	var audit: Dictionary=message.get("frame_audit",{})
	check(audit.get("ram_sha256")==source.ram_sha256 and audit.get("ram_bytes")==655360,"paired original RAM: %d"%index)
	check(audit.get("video_sha256")==source.video_sha256 and audit.get("video_bytes")==256000,"paired original video: %d"%index)
	check(message.get("program")==source.program,"original program: %d"%index)
	check(bridge.failure.is_empty() and pc_audio.failure.is_empty(),"production presentation/audio accepted")
	check(draw_view.vehicle_art==null and draw_view.vehicle_polygon_count==0,"rejected vehicle textures absent")
	var packet: Dictionary=message.audio
	check(packet.events==events_by_frame.get(index,[]),"every audio request equals the parity-tested trace: %d"%index)
	# Consecutive original scanouts independently establish a complete driver
	# portrait at 3583, its caption at 3601, and original erasure at 3690.
	if index>=3570 and index<=3715:
		var expected := 2 if index>=3583 and index<3690 else -1
		var actual := int(tandem_frame.portrait_art.active.get("id",-1))
		check(actual==expected,"same-frame driver portrait lifecycle: %d"%index)
		var captions: Array=message.presentation.text_runs.filter(func(r):return r.kind=="crew_primary")
		check(captions.size()==(1 if index>=3601 and index<3690 else 0),"source caption timing remains separate: %d"%index)
		portrait_frames.append({"frame":index,"portrait":actual,"caption_visible":not captions.is_empty()})
		if index in [3582,3583,3601,3689,3690]:
			photographing=true
			self.photograph.call_deferred("portrait-%d"%index)
	for event: Dictionary in packet.events:
		if event.kind!="radio_visible":continue
		radios.append(event.duplicate(true))
		check(event.voice=="pc_radio_airborne","original airborne radio report")
		check(tandem_frame.genesis_art_enabled and tandem_frame.gunner_art_enabled and 1 in tandem_frame.cockpit_art_ids,"Genesis cockpit active on the original radio frame")
		check(message.presentation.messages.any(func(m):return m.id==event.message_id and m.text==event.text and m.parts==event.parts),"complete current original message")
		var image := picture.texture.get_image().duplicate() as Image
		image.convert(Image.FORMAT_RGB8)
		for part: Dictionary in event.parts:
			var rect: Array=part.rect
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(image.get_region(Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3]))).get_data())
			check(digest.finish().hex_encode()==part.pixel_sha256,"current source pixels of every radio part")
		check(tandem_frame.typography.runs.any(func(r):return str(r.text).strip_edges()==event.text),"original radio also renders through high-resolution typeface")
		if not event.enabled:muted_radio_seen=true
		elif muted_radio_seen:fresh_radio_seen=true
		photographing=true
		self.photograph.call_deferred("radio-%d"%int(event.message_id))
	for receipt: Dictionary in pc_audio.receipts:
		if int(receipt.id)>last and receipt.sample=="radio":
			alert_receipts.append(receipt.duplicate(true))
			check(index==2614 and receipt.reason.is_empty() and receipt.voice==null,"source queue plays only the attention signal")
			check(pc_audio.effects.any(func(player):return player.playing and player.stream==pc_audio.get_stream("radio")),"actual attention sample started")
			check(radios.is_empty(),"queued radio has not spoken")
		if int(receipt.id)<=last or receipt.kind!="radio_visible":continue
		radio_receipts.append(receipt.duplicate(true))
		if packet.enabled:
			check(receipt.reason.is_empty() and pc_audio.voice.playing and pc_audio.last_voice==receipt.voice and pc_audio.voice.stream==pc_audio.get_stream("voice_"+receipt.voice),"fresh radio starts its generated sample")
		else:
			check(receipt.reason=="original-sound-gate" and not pc_audio.voice.playing,"muted radio consumed silently")
	if muted_radio_seen and not fresh_radio_seen and packet.enabled:
		restored_silent_frames+=1
		check(not pc_audio.voice.playing,"F5 restore does not replay the muted radio")
	if not errors.is_empty():bridge.failure=errors[0]

func _capture() -> void:
	while photographing:await process_frame
	check(samples==3716,"all source frames delivered once")
	check(previous==fixture.final_state and previous_program==fixture.final_program,"exact final original state and program")
	check(radios.size()==3 and radio_receipts.size()==3,"three unique radio assignments consumed")
	check(radios.map(func(e):return int(e.message_id))==[4,5,6],"monotone once-only radio identities")
	check(radio_receipts.map(func(r):return r.reason)==["","original-sound-gate",""],"two audible radios and one muted radio")
	check(alert_receipts.size()==1,"one original radio notification")
	check(restored_silent_frames>0,"F5 restore observed before fresh radio")
	check(portrait_frames.size()==146,"every driver onset/display/erasure scanout checked")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"errors":errors,"frames":samples,"radios":radios,"receipts":radio_receipts,
		"restored_silent_frames":restored_silent_frames,"alerts":alert_receipts,
		"portrait_frames":portrait_frames,
		"scope":"Production native viewer and real source host. All 3716 paired original RAM/video records and audio events equal the parity-tested trace. One notification sample, three current radio pixel hashes, two generated voice starts, one muted consumption, no F5 replay. Driver portrait appears on its first complete source frame, 18 frames before its caption, and clears on source erasure; all 146 transition frames checked. No physical-device/listening approval or other radio live-occurrence claim."},"  "))
	print("PC_RADIO_NATIVE: %d checks, %d frames, %d errors"%[checks,samples,errors.size()])
	if not errors.is_empty():bridge.failure=errors[0]
	await super._capture()
