extends "res://scripts/pc_bridge_viewer.gd"
## Exercise the production loop with a deterministic transport and input events.
var errors: Array[String] = []
var checks := 0
var events: Array = []
var held_codes: Array = []
var valid_sample: Dictionary

class TestBridge extends RefCounted:
	var pending := true
	var failure := ""
	var incoming: Array[Dictionary] = []
	var requests: Array = []
	var events: Array
	var stopped := false
	func poll() -> Array[Dictionary]:
		events.append("poll")
		var result := incoming.duplicate()
		incoming.clear()
		if not result.is_empty(): pending=false
		return result
	func step(frames: int, keys: Array) -> bool:
		if pending or stopped or not failure.is_empty(): return false
		events.append("step")
		requests.append({"frames":frames,"keys":keys.duplicate()})
		pending=true
		return true
	func close() -> void: stopped=true
	func has_exited() -> bool: return false

class TestDraw extends Node3D:
	var events: Array
	var extents: Array = []
	var dynamic_polygon_count := 0
	var sprite_count := 0
	var render_warnings: Array = []
	var presentation_palette: Array = []
	func apply_pass(_drawing: Dictionary) -> void:
		events.append("draw")
		# What DrawPass hands Modern ownership.prepare as its extent.
		extents.append(Vector2i(get_viewport().get_visible_rect().size))

class TestFrame extends TextureRect:
	var events: Array
	var world_enabled := true
	func set_frame(_source: Image, _presentation: Dictionary, _world: Texture2D, _program: Dictionary={}) -> bool:
		events.append("frame")
		return false

class TestAudio extends Node:
	var failure := "synthetic invalid audio packet"
	func apply_audio(_packet: Dictionary) -> bool: return false

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: errors.append(why)

func _initialize() -> void:
	# Do not launch a real child or load artwork in this scheduler-only fixture.
	bridge=TestBridge.new()
	bridge.events=events
	draw_view=TestDraw.new()
	draw_view.events=events
	tandem_frame=TestFrame.new()
	tandem_frame.events=events
	picture=TextureRect.new()
	status=Label.new()
	caption=Label.new()
	for node in [draw_view,tandem_frame,picture,status,caption]: root.add_child(node)
	trace_mode=true
	# This fixture deliberately bypasses _complete_startup, which opens the gate.
	startup_ready=true
	started=Time.get_ticks_msec()
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color.BLACK)
	valid_sample={"type":"sample","sequence":1,"state":null,"fps":59.9227256774902,
		"png":Marshalls.raw_to_base64(source.save_png_to_buffer()),"program":{"name":"START"},"presentation":{}}
	run.call_deferred()

func _process(_delta: float) -> bool: return false

func set_keys(codes: Array) -> void:
	for code in held_codes:
		var release := InputEventKey.new()
		release.keycode=code
		release.pressed=false
		Input.parse_input_event(release)
	held_codes=codes.duplicate()
	for code in codes:
		var press := InputEventKey.new()
		press.keycode=code
		press.pressed=true
		Input.parse_input_event(press)
	Input.flush_buffered_events()

func reply() -> void:
	bridge.incoming.append(valid_sample.duplicate(true))
	events.clear()

func run() -> void:
	check(audio_requested(true,[]),"original-event audio enabled by default")
	check(audio_requested(true,["--audio"]),"legacy explicit audio remains supported")
	check(not audio_requested(true,["--no-audio"]),"explicit diagnostic audio disable")
	check(not audio_requested(false,[]),"reference-only protocol cannot enable trace audio")
	var chunked := capture_chunks([[413,["up"]],[3,["kp5"]],[120,[]]])
	var expanded: Array = []
	for step: Array in chunked:
		check(int(step[0])>0 and int(step[0])<=60,"bounded diagnostic requests")
		for i in int(step[0]): expanded.append(step[1])
	check(expanded.size()==536,"capture chunking retains total frames")
	check(expanded.slice(0,413).all(func(keys):return keys==["up"]),"drive hold has no added key releases")
	check(expanded.slice(413,416).all(func(keys):return keys==["kp5"]),"stop command retains original duration")
	check(expanded.slice(416).all(func(keys):return keys==[]),"neutral tail retains original duration")
	check(_capture_deadline_msec()==60000,"ordinary snapshot capture deadline unchanged")
	boot_mode=true
	check(_capture_deadline_msec()==180000,"ordinary cold-boot capture deadline unchanged")
	boot_mode=false
	var period := 1.0/fps
	for codes in [[],[KEY_SPACE,KEY_KP_6],[KEY_5,KEY_KP_5],[KEY_F2],
		[KEY_UP,KEY_KP_8],[KEY_ENTER,KEY_KP_ENTER],[KEY_Q],[KEY_SHIFT,KEY_3],[]]:
		set_keys(codes)
		var wanted := Keyboard.encode(codes)
		wanted.sort()
		var before: int=bridge.requests.size()
		reply()
		super._process(period)
		if events.is_empty() or bridge.requests.is_empty():
			check(false,"super._process polled and dispatched (startup gate open)")
			finish()
			return
		check(bridge.requests.size()==before+1,"one request per validated available boundary")
		check(events==["poll","step","draw","frame"],"original frame starts before presentation construction")
		var actual: Array=bridge.requests[-1].keys.duplicate()
		actual.sort()
		check(actual==wanted and bridge.requests[-1].frames==1,"current original held keys and single-frame request")
		var previous: Dictionary=bridge.requests[-1].duplicate(true)
		set_keys([KEY_F4])
		super._process(period*4.25)
		check(bridge.requests.size()==before+1,"no second request while first is outstanding")
		check(bridge.requests[-1]==previous,"later input cannot alter an outstanding request")
	check(elapsed>=period,"busy time retained until next available request")
	set_keys([])
	reply()
	super._process(0)
	check(elapsed>=0 and elapsed<period,"busy intervals discarded without a catch-up burst")
	audio_menu=preload("res://scripts/pc_audio_menu.gd").new()
	audio_menu.config_path=""
	root.add_child(audio_menu)
	audio_menu.popup.about_to_popup.emit()
	set_keys([KEY_UP,KEY_SPACE])
	reply()
	super._process(period)
	check(bridge.requests[-1].frames==1 and bridge.requests[-1].keys.is_empty(),"audio menu continues source clock with neutral input")
	audio_menu.popup.popup_hide.emit()
	set_keys([KEY_ENTER])
	reply()
	super._process(period)
	check(bridge.requests[-1].keys.is_empty(),"audio menu closing Enter cannot select original menu")
	set_keys([])
	reply()
	super._process(period)
	set_keys([KEY_F2])
	reply()
	super._process(period)
	check(bridge.requests[-1].keys==["f2"],"fresh original command after audio-menu release")
	audio_menu.queue_free()
	audio_menu=null
	set_keys([])
	# Explicit fast-forward is the only live path allowed to batch originals.
	# One request remains outstanding, and source CPU/fps settings stay intact.
	var source_fps := fps
	for multiplier in [2,4,8]:
		_choose_speed(multiplier)
		reply()
		super._process(period)
		check(bridge.requests[-1].frames==multiplier and bridge.requests[-1].keys.is_empty(),"explicit fast-forward original-frame count")
		check(fps==source_fps and inflight_fast,"fast-forward retains source clock and marks pending audio")
	_choose_speed(1)
	check(inflight_fast,"normal-speed selection cannot unmark an in-flight fast batch")
	reply()
	super._process(period)
	check(bridge.requests[-1].frames==1 and not inflight_fast,"normal speed resumes without a catch-up batch")
	pending_state_command={"op":"save_state","slot":1}
	bridge.pending=false
	elapsed=period
	check(not _advance_live_frame(),"queued state operation blocks early frame prefetch")
	pending_state_command.clear()
	state_control_pending=true
	check(not _advance_live_frame(),"running state operation blocks original stepping")
	state_control_pending=false

	# Save/load control replies never resample a historical key set. Releases
	# received while the worker restarts take effect at the next source frame.
	audio_menu=preload("res://scripts/pc_play_menu.gd").new()
	audio_menu.config_path=""
	root.add_child(audio_menu)
	for operation in ["save_state","load_state","undo_load","failed_load"]:
		for held_after in [[],[KEY_UP,KEY_SPACE],[KEY_KP_4]]:
			set_keys([KEY_UP,KEY_SPACE])
			bridge.pending=false
			elapsed=period
			check(_advance_live_frame(),"held controls dispatch before "+operation)
			var before: int=bridge.requests.size()
			state_control_pending=true
			set_keys(held_after)
			bridge.pending=false
			_state_result({"type":"state_result","success":operation!="failed_load",
				"restored":valid_sample.duplicate(true),"slots":[],"message":operation})
			check(bridge.requests.size()==before,"state result renders saved boundary without advancing "+operation)
			check(not state_control_pending and not audio_menu.busy,"control reply unlocks host "+operation)
			elapsed=period
			check(_advance_live_frame(),"current controls resume after "+operation)
			var wanted:=Keyboard.encode(held_after);wanted.sort()
			var actual: Array=bridge.requests[-1].keys.duplicate();actual.sort()
			check(actual==wanted,"release or changed controls during state operation are current "+operation)
	# Losing focus while a batch is outstanding cannot mutate that batch, and
	# neutralizes the very next frame even when host polling still says held.
	set_keys([KEY_SPACE,KEY_UP])
	_choose_speed(8)
	bridge.pending=false;elapsed=period
	check(_advance_live_frame(),"held fast-forward batch sent")
	var sent_before_focus: Dictionary=bridge.requests[-1].duplicate(true)
	root.focus_exited.emit()
	check(bridge.requests[-1]==sent_before_focus,"focus event cannot change already executing original batch")
	reply();super._process(period)
	check(bridge.requests[-1].frames==8 and bridge.requests[-1].keys.is_empty(),"next fast-forward batch neutral after focus loss")
	root.focus_entered.emit()
	reply();super._process(period)
	check(bridge.requests[-1].keys.is_empty(),"focus regain quarantines stale held keys")
	set_keys([]);reply();super._process(period)
	set_keys([KEY_SPACE]);reply();super._process(period)
	check(bridge.requests[-1].keys==["space"],"new trigger press survives focus recovery")
	audio_menu.queue_free();audio_menu=null
	_choose_speed(1);set_keys([])

	# Capture routes retain explicit batches and dispatch only after presentation.
	capture=true
	auto_steps=[[3,["f4"]],[20,[]]]
	auto_index=0
	for step in auto_steps:
		var before: int=bridge.requests.size()
		reply()
		super._process(period)
		check(events==["poll","draw","frame","step"],"capture never uses early live dispatch")
		check(bridge.requests.size()==before+1 and bridge.requests[-1].frames==step[0] and bridge.requests[-1].keys==step[1],"exact capture batch preserved")
	capture_done=true
	var stopped_count: int=bridge.requests.size()
	reply()
	super._process(period)
	check(bridge.requests.size()==stopped_count and events==["poll","draw","frame"],"final capture boundary cannot prefetch an extra frame")
	capture=false
	bridge.pending=false
	elapsed=period*0.5
	check(not _advance_live_frame(),"no original frame before its clock interval")
	elapsed=period*2
	closing=true
	check(not _advance_live_frame(),"no request while closing")
	var closing_samples := samples
	for late in [valid_sample.duplicate(true),{"type":"state_result","restored":valid_sample.duplicate(true),"slots":[],"message":"late restore"}]:
		bridge.incoming.append(late)
		events.clear()
		super._process(period)
		check(events==["poll"] and samples==closing_samples,"closing drains transport without replaying late presentation or audio")
	closing=false
	bridge.failure="synthetic failed transport"
	check(not _advance_live_frame(),"no request after transport failure")
	bridge.failure=""

	# Exact compressed-byte reuse may bypass decoding, never delivery or state.
	capture=true
	capture_done=true
	bridge.failure=""
	_apply_sample(valid_sample)
	var retained_texture := picture.texture
	var delivered_before := samples
	_apply_sample(valid_sample.duplicate(true))
	check(picture.texture==retained_texture and samples==delivered_before+1,"identical PNG retains texture and still consumes reply")
	var changed_sample := valid_sample.duplicate(true)
	var changed_image := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	changed_image.fill(Color.MAGENTA)
	changed_sample.png=Marshalls.raw_to_base64(changed_image.save_png_to_buffer())
	_apply_sample(changed_sample)
	check(picture.texture!=retained_texture and picture.texture.get_image().get_data()==changed_image.get_data(),"changed PNG replaces source pixels")
	_apply_sample(valid_sample)
	check(picture.texture.get_image().get_data()==_decoded_image.get_data() and _decoded_png==valid_sample.png,"previous source restored after different frame")
	capture=false
	events.clear()

	# Failures known before rendering must not advance the original.
	trace_mode=false
	events.clear()
	_apply_sample(valid_sample)
	check(bridge.requests.size()==stopped_count and events.is_empty() and not bridge.failure.is_empty(),"invalid required SIM state cannot dispatch")
	trace_mode=true
	bridge.failure=""
	pc_audio=TestAudio.new()
	root.add_child(pc_audio)
	_apply_sample(valid_sample)
	check(bridge.requests.size()==stopped_count and events.is_empty() and bridge.failure==pc_audio.failure,"invalid audio cannot dispatch")
	pc_audio.queue_free()
	pc_audio=null
	bridge.failure=""
	if "--invalid-png" in OS.get_cmdline_user_args():
		# This opt-in case deliberately emits libpng's diagnostic on stderr.
		var bad := valid_sample.duplicate(true)
		bad.png=Marshalls.raw_to_base64("not a PNG".to_utf8_buffer())
		_apply_sample(bad)
		check(bridge.requests.size()==stopped_count and events.is_empty() and bridge.failure=="invalid original framebuffer","invalid original image cannot dispatch")
	# A station switch changes the clip: the SIM pass must be built at the new
	# world extent, as on the menu, or Modern ownership registers at the old aspect.
	bridge.failure="hold transport"
	camera=Camera3D.new()
	world_viewport=SubViewport.new()
	world_viewport.size=Vector2i(1024,388)
	root.add_child(world_viewport)
	world_viewport.add_child(camera)
	draw_view.reparent(camera)
	for clip in [[32,13,287,109],[0,10,319,52],[32,13,287,109]]:
		var sim := valid_sample.duplicate(true)
		sim.program={"name":"SIM"}
		sim.state={"station":"gunner","heading_degrees":0,"bearing_degrees":0,"speed_display":0,"fuel_display":0,
			"ammunition":{"HEAT":0,"SABOT":0,"AX":0,"COAX":0},"world_position_raw":[0,0,0],"camera":{},
			"world":{"window_origin":[0,0],"static":[]}}
		sim.presentation={"draw_pass":{"sequence":1,"objects":[],"unsupported":[],"camera":{"clip":clip,"center":[159,61],
			"near_raw":16,"focal_pixels":128,"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}}}
		draw_view.extents.clear()
		_apply_sample(sim)
		var wanted := Vector2i(clip[2]-clip[0]+1,clip[3]-clip[1]+1)*4
		check(draw_view.extents==[wanted] and world_viewport.size==wanted,"SIM pass built at the current clip's world extent %s: %s"%[wanted,draw_view.extents])
	draw_view.reparent(root)
	world_viewport.queue_free()
	world_viewport=null
	camera=null
	bridge.failure=""
	set_keys([])
	capture=false
	status.hide()
	bridge.failure="synthetic occupied save directory"
	super._process(period)
	check(status.visible and status.text.contains(bridge.failure),"interactive launch errors remain visible")
	check(bridge.stopped and not closing,"error gracefully closes only the child, leaving explanation visible")
	check(anchor_path("/repo","artifacts/x")=="/repo/artifacts/x" and anchor_path("/repo","/abs/x")=="/abs/x","relative --output/--saves resolve against the repo root")
	check(anchor_path("/repo","user://x")==ProjectSettings.globalize_path("user://x"),"Godot virtual paths keep their meaning")
	# The host's own error line outlives its prompt exit; a silent exit stays generic.
	for script in ["printf '{\"type\":\"error\",\"message\":\"Rebuild the local trace core for X\"}\\n'","exit 1"]:
		var real := Bridge.new()
		real.process=OS.execute_with_pipe("/bin/sh",["-c",script],false)
		var deadline := Time.get_ticks_msec()+5000
		while OS.is_process_running(int(real.process.pid)) and Time.get_ticks_msec()<deadline: OS.delay_msec(10)
		real.poll()
		check(real.failure==("PC core host exited; see the local host log." if script=="exit 1" else "Rebuild the local trace core for X"),"host failure text survives its exit: "+real.failure)
	# Harness-only kill ends a wedged child (one that never reads quit) and is a no-op without one.
	var wedged := Bridge.new()
	wedged.kill()
	wedged.process=OS.execute_with_pipe("/bin/sh",["-c","sleep 30"],false)
	wedged.close()
	check(not wedged.has_exited(),"wedged child outlives its quit request")
	var wedged_pid := int(wedged.process.pid)
	wedged.kill()
	# Independent of Godot's process table: the pid itself is gone.
	check(wedged.has_exited() and wedged.exit_code()==-1 and OS.execute("/bin/kill",["-0",str(wedged_pid)])!=0,"Bridge.kill ends a wedged child")
	var saved_python := OS.get_environment("ABRAMS_PYTHON")
	OS.unset_environment("ABRAMS_PYTHON")
	check(Bridge.default_python()=="python3","viewer falls back to python3 on PATH, like PC Bridge.command")
	OS.set_environment("ABRAMS_PYTHON","/opt/test/python3")
	check(Bridge.default_python()=="/opt/test/python3","ABRAMS_PYTHON selects the interpreter")
	if saved_python.is_empty(): OS.unset_environment("ABRAMS_PYTHON")
	else: OS.set_environment("ABRAMS_PYTHON",saved_python)
	play_mode=true
	_choose_speed(8)
	var fast_title := root.title
	_choose_speed(1)
	play_mode=false
	var app_name := str(ProjectSettings.get_setting("application/config/name"))
	check(fast_title==app_name+" (8x fast forward)" and root.title==app_name,"fast forward keeps the project window title")
	# A host that never exits after Close (has_exited stays false) cannot hold the window forever.
	_close()
	check(closing and close_deadline>Time.get_ticks_msec() and close_deadline<=Time.get_ticks_msec()+5000,"failed host gets a short close grace")
	check(not _close_expired(),"Close waits for the host during its grace")
	close_deadline=Time.get_ticks_msec()-1
	check(_close_expired(),"hung host Close is bounded")
	finish()

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_LIVE_SCHEDULING: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
