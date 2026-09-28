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
	func apply_pass(_drawing: Dictionary) -> void: events.append("draw")

class TestFrame extends TextureRect:
	var events: Array
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
	closing=false
	bridge.failure="synthetic failed transport"
	check(not _advance_live_frame(),"no request after transport failure")
	bridge.failure=""

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
	set_keys([])
	capture=false
	status.hide()
	bridge.failure="synthetic occupied save directory"
	super._process(period)
	check(status.visible and status.text.contains(bridge.failure),"interactive launch errors remain visible")
	check(bridge.stopped and not closing,"error gracefully closes only the child, leaving explanation visible")
	for error in errors: printerr("FAIL: "+error)
	print("PC_LIVE_SCHEDULING: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
