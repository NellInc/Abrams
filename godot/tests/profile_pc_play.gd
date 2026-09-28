extends "res://scripts/pc_bridge_viewer.gd"
## Opt-in bounded profiler for the actual production viewer and original host.
## Run with --play --trace --capture --capture-station gunner --output NEW_DIR.
var profile_rows: Array = []
var profile_begin := 0
var profile_previous := 0
var warmup_sequence := 0
var last_profile_message: Dictionary = {}
var interactive_clock := false
var profile_frames := 120
var transport_probe := false
var late_dispatch := false
var applying_sample := false
var replay_keys: Array = []
var replay_held: Array = []
var sample_hashes: Array = []

class ProbeBridge extends "res://scripts/pc_bridge.gd":
	var rows: Array = []
	var enabled := false
	var sent_us := 0
	var last_poll_us := 0
	var polls := 0
	var requests: Array = []
	func step(frames: int, keys: Array) -> bool:
		var now := Time.get_ticks_usec()
		var accepted := super.step(frames,keys)
		if accepted:
			sent_us=now
			polls=0
			if enabled: requests.append({"id":waiting_id,"frames":frames,"keys":keys.duplicate()})
		return accepted
	func poll() -> Array[Dictionary]:
		var now := Time.get_ticks_usec()
		var was_pending := pending
		var before := buffered.length()
		var messages := super.poll()
		polls+=1
		if enabled:
			rows.append({"request_id":waiting_id,"polls":polls,"pending_before":was_pending,
				"prefix_before":before,"prefix_after":buffered.length(),"messages":messages.size(),
				"request_age_ms":(now-sent_us)/1000.0,"poll_gap_ms":(now-last_poll_us)/1000.0,
				"poll_ms":(Time.get_ticks_usec()-now)/1000.0})
		last_poll_us=now
		return messages

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	transport_probe="--transport-probe" in args or "--replay-controls" in args
	late_dispatch="--late-dispatch" in args
	if transport_probe: bridge=ProbeBridge.new()
	super._initialize()
	if not capture or not trace_mode:
		bridge.failure="Live profiler requires --trace --capture"
		return
	for step in auto_steps: warmup_sequence+=int(step[0])
	if "--profile-frames" in args:
		var index := args.find("--profile-frames")+1
		if index>=args.size() or not args[index].is_valid_int() or int(args[index])<1 or int(args[index])>1800:
			bridge.failure="profile frames must be 1..1800"
			return
		profile_frames=int(args[index])
	interactive_clock="--interactive-clock" in args
	if "--replay-controls" in args:
		if not interactive_clock:
			bridge.failure="Control replay requires --interactive-clock"
			return
		var steps: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_play_control_steps.json"))
		for step in steps:
			for i in int(step[0]): replay_keys.append(step[1])
		profile_frames=replay_keys.size()
	if not interactive_clock:
		for i in profile_frames: auto_steps.append([1,[]])

func _capture_deadline_msec() -> int: return 90000

func _advance_live_frame() -> bool:
	# A/B diagnostic reproduces the previous post-presentation dispatch policy.
	if late_dispatch and applying_sample: return false
	return super._advance_live_frame()

func replay_input(keys: Array) -> void:
	for code in replay_held:
		var event := InputEventKey.new()
		event.keycode=code
		event.pressed=false
		Input.parse_input_event(event)
	replay_held.clear()
	for key in keys:
		var code: int={"f1":KEY_F1,"f2":KEY_F2,"f3":KEY_F3,"f4":KEY_F4,
			"kp5":KEY_KP_5,"kp6":KEY_KP_6,"kp8":KEY_KP_8,"c":KEY_C,"s":KEY_S,"space":KEY_SPACE}[key]
		var event := InputEventKey.new()
		event.keycode=code
		event.pressed=true
		Input.parse_input_event(event)
		replay_held.append(code)
	Input.flush_buffered_events()

func _apply_sample(message: Dictionary) -> void:
	last_profile_message=message
	if not replay_keys.is_empty() and int(message.sequence)>=warmup_sequence:
		var index := int(message.sequence)-warmup_sequence
		replay_input(replay_keys[index] if index<replay_keys.size() else [])
		if profile_begin!=0:
			sample_hashes.append({"sequence":int(message.sequence),"sha256":JSON.stringify(message).sha256_text(),
				"frame_audit":message.get("frame_audit",{})})
	# Stop before production's early one-frame dispatch at the final boundary.
	if interactive_clock and profile_begin!=0 and profile_rows.size()+1==profile_frames:
		capture=true
		capture_done=true
	var start := Time.get_ticks_usec()
	applying_sample=true
	super._apply_sample(message)
	applying_sample=false
	var end := Time.get_ticks_usec()
	if int(message.sequence)<warmup_sequence: return
	if profile_begin==0:
		profile_begin=end
		profile_previous=end
		if transport_probe: bridge.enabled=true
		if interactive_clock: capture=false
		return
	profile_rows.append({"sequence":int(message.sequence),"arrival_gap_ms":(start-profile_previous)/1000.0,
		"apply_ms":(end-start)/1000.0,"interval_ms":(end-profile_previous)/1000.0})
	profile_previous=end
	if interactive_clock and profile_rows.size()==profile_frames:
		capture=true
		capture_done=true
		_capture.call_deferred()

func _process(delta: float) -> bool:
	var start := Time.get_ticks_usec()
	if not closing and Time.get_ticks_msec()-started>90000: bridge.failure="live profiler deadline"
	var count := profile_rows.size()
	var result := super._process(delta)
	if profile_rows.size()>count: profile_rows[-1].process_ms=(Time.get_ticks_usec()-start)/1000.0
	return result

func measure(callback: Callable) -> float:
	var start := Time.get_ticks_usec()
	for i in 30: callback.call()
	return (Time.get_ticks_usec()-start)/30000.0

func components() -> Dictionary:
	var source := picture.texture.get_image()
	var ui := Image.new()
	ui.load_png_from_buffer(Marshalls.base64_to_raw(previous_presentation.ui_overlay.mask_png))
	var tags := Image.new()
	tags.load_png_from_buffer(Marshalls.base64_to_raw(previous_presentation.plate_overlay.mask_png))
	var clip: Array=previous_presentation.draw_pass.camera.clip
	var box := Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)
	var drawing: Dictionary=previous_presentation.draw_pass.duplicate(false)
	drawing.palette_rgb=previous_presentation.palette_rgb
	var data := {
		"world":measure(func():draw_view.apply_pass(drawing)),
		"whole_frame":measure(func():tandem_frame.set_frame(source,previous_presentation,world_viewport.get_texture())),
		"plate_art":measure(func():tandem_frame._set_art(previous_presentation,ui)),
		"driver_assembly":measure(func():tandem_frame._set_driver_assembly(previous_presentation,ui)),
		"instruments":measure(func():tandem_frame.instrument_art.set_frame(source,ui,tags,previous_presentation.get("orientation",{}))),
		"typography":measure(func():tandem_frame.typography.set_frame(source,ui,previous_presentation,null,box)),
		"reticle":measure(func():tandem_frame.reticle_art.set_frame(source,ui,previous_presentation)),
		"portrait":measure(func():tandem_frame.portrait_art.set_frame(source,ui,previous_presentation)),
		"frontend":measure(func():tandem_frame.frontend_art.set_frame(source,previous_program,previous_presentation))}
	super._apply_sample(last_profile_message)
	return data

func _capture() -> void:
	var elapsed_ms := (profile_previous-profile_begin)/1000.0
	var summary := {"samples":profile_rows.size(),"elapsed_ms":elapsed_ms,
		"effective_fps":profile_rows.size()*1000.0/elapsed_ms,"advertised_fps":fps,"interactive_clock":interactive_clock,
		"rows":profile_rows,"display":play_display.description() if play_mode else {"mode":"comparison"},
		"scope":"Bounded sequential single-frame requests (capture-neutral or the actual interactive keyboard path) in the real capture pipeline, including native rendering; no claim of historical CPU speed calibration"}
	if "--components" in OS.get_cmdline_user_args(): summary.component_mean_ms=components()
	if transport_probe:
		summary.transport_polls=bridge.rows
		summary.requests=bridge.requests
	summary.late_dispatch=late_dispatch
	if not replay_keys.is_empty(): summary.sample_hashes=sample_hashes
	var file := FileAccess.open(output.path_join("pacing.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"  "))
	print("PC_PLAY_PROFILE: %d samples, %.3f effective fps"%[profile_rows.size(),summary.effective_fps])
	await super._capture()
