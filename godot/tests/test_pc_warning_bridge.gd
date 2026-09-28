extends "res://scripts/pc_bridge_viewer.gd"
## Actual production viewer, one original frame per request, no guest mutation.
var fixture: Dictionary
var events_by_frame := {}
var errors: Array[String] = []
var checks := 0
var warnings: Array = []
var warning_receipts: Array = []
var photographing := false
var muted_warning_seen := false
var fresh_warning_seen := false
var restored_silent_frames := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not ["--fixture","--output","--capture","--trace","--play","--frame-audit"].all(func(flag):return flag in args) or "--no-audio" in args:
		printerr("Warning bridge needs --fixture REPORT --output NEW --capture --trace --play --frame-audit")
		quit(2)
		return
	var path := args[args.find("--fixture")+1]
	var target := args[args.find("--output")+1]
	fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	var comparison: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join("comparison.json")))
	if DirAccess.dir_exists_absolute(target) or fixture.get("profile")!="smoke-warnings" or fixture.frames.size()!=1060 or not comparison.get("passed",false) or FileAccess.get_sha256(path)!=comparison.get("trace_sha256"):
		printerr("Warning bridge needs a fresh output and the passing 1060-frame parity fixture")
		quit(2)
		return
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if FileAccess.get_sha256(directory.path_join("artifacts/pc-source-boot-01/mission-entry/reference.state"))!=fixture.state_sha256:
		printerr("Warning bridge starting source state differs")
		quit(2)
		return
	for event: Dictionary in fixture.audio_events:
		var frame := int(event.frame_index)
		if not events_by_frame.has(frame): events_by_frame[frame]=[]
		var expected := event.duplicate(true)
		expected.erase("frame_index")
		events_by_frame[frame].append(expected)
	super._initialize()
	auto_steps=[]
	# Host's ready packet already executes fixture frame zero (neutral keys).
	for record: Dictionary in fixture.frames.slice(1):auto_steps.append([1,record.keys])
	check(fixture.frames[0].keys.is_empty(),"ready input is neutral")

func _capture_deadline_msec() -> int: return 180000

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok and errors.size()<20:errors.append(label)

func _process(delta: float) -> bool:
	if photographing:return false
	return super._process(delta)

func photograph(identity: int) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	check(root.get_texture().get_image().save_png(output.path_join("warning-%d.png"%identity))==OK,"native warning photograph")
	photographing=false
	if not errors.is_empty():bridge.failure=errors[0]

func _apply_sample(message: Dictionary) -> void:
	var last := int(pc_audio.last_event_id)
	super._apply_sample(message)
	var index := int(message.sequence)
	check(index>=0 and index<fixture.frames.size(),"known original frame")
	if index<0 or index>=fixture.frames.size():bridge.failure="unknown warning route frame";return
	var source: Dictionary=fixture.frames[index]
	var audit: Dictionary=message.get("frame_audit",{})
	check(audit.get("ram_sha256")==source.ram_sha256 and audit.get("ram_bytes")==655360,"paired original RAM: %d"%index)
	check(audit.get("video_sha256")==source.video_sha256 and audit.get("video_bytes")==256000,"paired original video: %d"%index)
	check(message.get("program")==source.program,"original program: %d"%index)
	check(bridge.failure.is_empty() and pc_audio.failure.is_empty(),"production presentation/audio accepted")
	check(draw_view.vehicle_art==null and draw_view.vehicle_polygon_count==0,"rejected vehicle textures absent")
	var packet: Dictionary=message.audio
	check(packet.events==events_by_frame.get(index,[]),"every audio request equals the parity-tested trace: %d"%index)
	for event: Dictionary in packet.events:
		if event.kind!="crew_visible":continue
		warnings.append(event.duplicate(true))
		check(event.voice=="pc_no_smoke_mortars","original empty-mortar call")
		check(tandem_frame.genesis_art_enabled and tandem_frame.gunner_art_enabled and 1 in tandem_frame.cockpit_art_ids,"Genesis cockpit active on the original warning frame")
		check(not tandem_frame.portrait_art.active.is_empty(),"remastered portrait active on original warning frame")
		check(message.presentation.messages.any(func(m):return m.id==event.message_id and m.text==event.text and m.parts==event.parts),"complete current original message")
		var image := picture.texture.get_image().duplicate() as Image
		image.convert(Image.FORMAT_RGB8)
		for part: Dictionary in event.parts:
			var rect: Array=part.rect
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(image.get_region(Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3]))).get_data())
			check(digest.finish().hex_encode()==part.pixel_sha256,"current source pixels of every warning part")
		check(tandem_frame.typography.runs.any(func(r):return str(r.text).strip_edges()==event.text),"original warning also renders through high-resolution typeface")
		if not event.enabled:muted_warning_seen=true
		elif muted_warning_seen:fresh_warning_seen=true
		photographing=true
		self.photograph.call_deferred(int(event.message_id))
	for receipt: Dictionary in pc_audio.receipts:
		if int(receipt.id)<=last or receipt.kind!="crew_visible":continue
		warning_receipts.append(receipt.duplicate(true))
		if packet.enabled:
			check(receipt.reason.is_empty() and pc_audio.voice.playing and pc_audio.last_voice==receipt.voice and pc_audio.voice.stream==pc_audio.get_stream("voice_"+receipt.voice),"fresh warning starts its generated sample")
		else:
			check(receipt.reason=="original-sound-gate" and not pc_audio.voice.playing,"muted warning consumed silently")
	if muted_warning_seen and not fresh_warning_seen and packet.enabled:
		restored_silent_frames+=1
		check(not pc_audio.voice.playing,"F5 restore does not replay the muted warning")
	if not errors.is_empty():bridge.failure=errors[0]

func _capture() -> void:
	while photographing:await process_frame
	check(samples==1060,"all source frames delivered once")
	check(previous==fixture.final_state and previous_program==fixture.final_program,"exact final original state and program")
	check(warnings.size()==3 and warning_receipts.size()==3,"three unique warning assignments consumed")
	check(warnings.map(func(e):return int(e.message_id))==[1,2,3],"monotone once-only warning identities")
	check(warning_receipts.map(func(r):return r.reason)==["","original-sound-gate",""],"two audible warnings and one muted warning")
	check(restored_silent_frames>0,"F5 restore observed before fresh warning")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"errors":errors,"frames":samples,"warnings":warnings,"receipts":warning_receipts,
		"restored_silent_frames":restored_silent_frames,
		"scope":"Production native viewer and real source host. All 1060 paired original RAM/video records and audio events equal the parity-tested trace. Three current warning pixel hashes, two sample starts, one muted consumption, no F5 replay. No physical-device/listening approval or other warning live-occurrence claim."},"  "))
	print("PC_WARNING_NATIVE: %d checks, %d frames, %d errors"%[checks,samples,errors.size()])
	if not errors.is_empty():bridge.failure=errors[0]
	await super._capture()
