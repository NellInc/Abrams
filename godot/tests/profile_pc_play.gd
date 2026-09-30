extends "res://scripts/pc_bridge_viewer.gd"
## Opt-in bounded profiler for the actual production viewer and original host.
## Run with --play --trace --capture --capture-station gunner --output NEW_DIR.
var profile_rows: Array = []
var diagnostic_draws: Array = []
var process_begin_usec := 0
var crossed_dispatch_deadlines := 0
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
var profile_deadline_ms := 90000
var replay_cycles := 1
var display_intervals: Array[float] = []
var display_previous := 0
var distinct_draw_passes := {}
var profile_memory_begin := 0
var route_stations := {}
var route_origins := {}
var focused_samples := 0
var mesh_build_begin := 0
var mesh_reuse_begin := 0
var awaiting_profile_focus := false
var profile_focus_since := 0
var minimal_profile := false

func _displayed() -> void:
	if profile_begin==0 or capture_done:return
	var now := Time.get_ticks_usec()
	if display_previous>0:display_intervals.append((now-display_previous)/1000.0)
	display_previous=now

func distribution(values: Array) -> Dictionary:
	if values.is_empty():return {"count":0}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered:total+=float(value)
	return {"count":ordered.size(),"mean_ms":total/ordered.size(),"p95_ms":ordered[mini(ordered.size()-1,ceili(ordered.size()*0.95)-1)],"p99_ms":ordered[mini(ordered.size()-1,ceili(ordered.size()*0.99)-1)],"max_ms":ordered[-1]}

class ProbeBridge extends "res://scripts/pc_bridge.gd":
	var rows: Array = []
	var enabled := false
	var sent_us := 0
	var last_poll_us := 0
	var polls := 0
	var requests: Array = []
	var record_poll_rows := true
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
		if enabled and record_poll_rows:
			rows.append({"request_id":waiting_id,"polls":polls,"pending_before":was_pending,
				"prefix_before":before,"prefix_after":buffered.length(),"messages":messages.size(),
				"request_age_ms":(now-sent_us)/1000.0,"poll_gap_ms":(now-last_poll_us)/1000.0,
				"poll_ms":(Time.get_ticks_usec()-now)/1000.0})
		last_poll_us=now
		return messages

func _initialize() -> void:
	RenderingServer.frame_post_draw.connect(_displayed)
	var args := OS.get_cmdline_user_args()
	minimal_profile="--minimal-profile" in args
	transport_probe="--transport-probe" in args or "--replay-controls" in args
	late_dispatch="--late-dispatch" in args
	if transport_probe: bridge=ProbeBridge.new()
	if transport_probe: bridge.record_poll_rows=not minimal_profile
	presentation_cache_enabled="--no-presentation-cache" not in args
	super._initialize()
	draw_view.profile_builds="--build-timings" in args
	if not capture or not trace_mode:
		bridge.failure="Live profiler requires --trace --capture"
		return
	for step in auto_steps: warmup_sequence+=int(step[0])
	if "--profile-frames" in args:
		var index := args.find("--profile-frames")+1
		if index>=args.size() or not args[index].is_valid_int() or int(args[index])<1 or int(args[index])>20400:
			bridge.failure="profile frames must be 1..20400"
			return
		profile_frames=int(args[index])
	if "--replay-cycles" in args:
		var index := args.find("--replay-cycles")+1
		if "--replay-controls" not in args or index>=args.size() or not args[index].is_valid_int() or int(args[index])<1 or int(args[index])>20:
			bridge.failure="replay cycles require --replay-controls and 1..20 cycles"
			return
		replay_cycles=int(args[index])
	interactive_clock="--interactive-clock" in args
	if "--replay-controls" in args:
		if not interactive_clock:
			bridge.failure="Control replay requires --interactive-clock"
			return
		var steps: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_play_control_steps.json"))
		for cycle in replay_cycles:
			for step in steps:
				for i in int(step[0]): replay_keys.append(step[1])
		profile_frames=replay_keys.size()
	# Diagnostics keep one original frame per request, with a bounded allowance
	# for sustained routes on a loaded host and final capture.
	profile_deadline_ms=maxi(90000,30000+profile_frames*100)
	if not interactive_clock:
		for i in profile_frames: auto_steps.append([1,[]])

func _capture_deadline_msec() -> int: return profile_deadline_ms

func _advance_live_frame() -> bool:
	if profile_begin!=0 and process_begin_usec>0 and not capture and not closing and not state_control_pending and pending_state_command.is_empty() and not bridge.pending and bridge.failure.is_empty():
		if elapsed<1.0/fps and elapsed+(Time.get_ticks_usec()-process_begin_usec)/1000000.0>=1.0/fps:
			crossed_dispatch_deadlines+=1
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
	if profile_begin!=0 and not replay_keys.is_empty() and int(message.sequence)>=warmup_sequence:
		var index := int(message.sequence)-warmup_sequence
		replay_input(replay_keys[index] if index<replay_keys.size() else [])
		if profile_begin!=0 and not minimal_profile:
			sample_hashes.append({"sequence":int(message.sequence),"sha256":JSON.stringify(message).sha256_text(),
				"frame_audit":message.get("frame_audit",{})})
	# Stop before production's early one-frame dispatch at the final boundary.
	if interactive_clock and profile_begin!=0 and profile_rows.size()+1==profile_frames:
		capture=true
		capture_done=true
	var builds_before: int=draw_view.mesh_build_count
	var start := Time.get_ticks_usec()
	applying_sample=true
	super._apply_sample(message)
	applying_sample=false
	var end := Time.get_ticks_usec()
	if int(message.sequence)<warmup_sequence: return
	if profile_begin==0:
		if interactive_clock:
			# Finish setup first, then require actual native focus. Holding the
			# original frame here is outside the measured production loop.
			awaiting_profile_focus=true
			capture=true
			capture_done=true
		else:_begin_profile(end)
		return
	if root.has_focus():focused_samples+=1
	var draw_sequence: int=int(previous_presentation.get("draw_pass",{}).get("sequence",-1))
	if draw_sequence>=0:distinct_draw_passes[draw_sequence]=true
	if diagnostic_draws.size()<2 and (diagnostic_draws.is_empty() or diagnostic_draws[-1].sequence!=draw_sequence):
		diagnostic_draws.append(previous_presentation.get("draw_pass",{}).duplicate(true))
	route_stations[str(previous.get("station","unknown"))]=true
	route_origins[JSON.stringify(previous.get("world",{}).get("window_origin",[]))]=true
	profile_rows.append({"sequence":int(message.sequence),"draw_sequence":draw_sequence,"arrival_gap_ms":(start-profile_previous)/1000.0,
		"build_timings_usec":draw_view.last_apply_timings_usec.duplicate() if draw_view.profile_builds else {},"mesh_rebuilt":draw_view.mesh_build_count>builds_before,"focused":root.has_focus(),"apply_ms":(end-start)/1000.0,"interval_ms":(end-profile_previous)/1000.0,
		"world_position_raw":previous.get("world_position_raw",[]),"station":previous.get("station","unknown"),
		"program":previous_program.get("name",""),"audio_failure":pc_audio.failure if pc_audio else ""})
	profile_previous=end
	if interactive_clock and profile_rows.size()==profile_frames:
		capture=true
		capture_done=true
		_capture.call_deferred()

func _begin_profile(now: int) -> void:
	profile_begin=now
	profile_previous=now
	profile_memory_begin=OS.get_static_memory_usage()
	mesh_build_begin=draw_view.mesh_build_count
	mesh_reuse_begin=draw_view.mesh_reuse_count
	if transport_probe:bridge.enabled=true
	if interactive_clock:
		capture=false
		capture_done=false
		elapsed=0.0
		if not replay_keys.is_empty():
			# Inject the first command only after real focus is acquired. A key
			# held across the focus boundary is correctly quarantined by Play.
			replay_input([])
			if audio_menu: audio_menu.game_keys([])
			replay_input(replay_keys[0])
	awaiting_profile_focus=false

func _process(delta: float) -> bool:
	var start := Time.get_ticks_usec()
	process_begin_usec=start
	if not closing and Time.get_ticks_msec()-started>profile_deadline_ms: bridge.failure="live profiler deadline"
	var count := profile_rows.size()
	var result := super._process(delta)
	if awaiting_profile_focus:
		if not root.has_focus():profile_focus_since=0
		elif profile_focus_since==0:profile_focus_since=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-profile_focus_since>=250:_begin_profile(Time.get_ticks_usec())
	if profile_rows.size()>count: profile_rows[-1].process_ms=(Time.get_ticks_usec()-start)/1000.0
	process_begin_usec=0
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
		"minimal_profile":minimal_profile,"packet_hashes_enabled":not minimal_profile,
		"replay_cycles":replay_cycles,"deadline_ms":profile_deadline_ms,
		"effective_fps":profile_rows.size()*1000.0/elapsed_ms,"advertised_fps":fps,"interactive_clock":interactive_clock,
		"presentation_builds":presentation_builds,"presentation_reuses":presentation_reuses,"presentation_cache_enabled":presentation_cache_enabled,
		"focused_samples":focused_samples,"mesh_builds":draw_view.mesh_build_count-mesh_build_begin,"mesh_reuses":draw_view.mesh_reuse_count-mesh_reuse_begin,
		"graphics_mode":tandem_frame.graphics_mode,"distinct_draw_passes":distinct_draw_passes.size(),"distinct_draw_fps":distinct_draw_passes.size()*1000.0/elapsed_ms,
		"display_frame_intervals":distribution(display_intervals),"source_reply_intervals":distribution(profile_rows.map(func(row):return row.interval_ms)),
		"memory_begin_bytes":profile_memory_begin,"memory_end_bytes":OS.get_static_memory_usage(),
		"route_stations":route_stations.keys(),"window_origins":route_origins.keys(),
		"rows":profile_rows,"display":play_display.description() if play_mode else {"mode":"comparison"},
		"scope":"Bounded sequential single-frame requests (capture-neutral or the actual interactive keyboard path) in the real capture pipeline, including native rendering; no claim of historical CPU speed calibration"}
	if "--components" in OS.get_cmdline_user_args(): summary.component_mean_ms=components()
	if transport_probe:
		summary.transport_polls=bridge.rows
		summary.requests=bridge.requests
	summary.late_dispatch=late_dispatch
	summary.crossed_dispatch_deadlines=crossed_dispatch_deadlines
	summary.fully_focused=focused_samples==profile_rows.size()
	if not replay_keys.is_empty():
		# Native input can arrive alongside injected keys. Reject that route as
		# an A/B benchmark instead of silently comparing different battlefields.
		var mismatches: Array = []
		for i in mini(bridge.requests.size(),replay_keys.size()):
			var actual: Array=bridge.requests[i].keys.duplicate()
			var expected: Array=replay_keys[i].duplicate()
			actual.sort();expected.sort()
			if actual!=expected or int(bridge.requests[i].frames)!=1:
				mismatches.append(i)
		summary.input_mismatch_indices=mismatches
		summary.control_route_exact=mismatches.is_empty() and bridge.requests.size()==replay_keys.size()
		summary.control_route_complete=summary.fully_focused and summary.control_route_exact and ["gunner","driver","commander","cupola"].all(func(station):return station in route_stations)
	if not replay_keys.is_empty(): summary.sample_hashes=sample_hashes
	FileAccess.open(output.path_join("diagnostic-draws.json"),FileAccess.WRITE).store_string(JSON.stringify(diagnostic_draws))
	var file := FileAccess.open(output.path_join("pacing.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"  "))
	print("PC_PLAY_PROFILE: %d samples, %.3f effective fps"%[profile_rows.size(),summary.effective_fps])
	await super._capture()
