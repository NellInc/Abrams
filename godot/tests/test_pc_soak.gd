extends "res://scripts/pc_bridge_viewer.gd"
## Wall-clock production-loop soak. Never accelerates the normal-time requirement.
var seconds := 1800.0
var active := false
var checks := 0
var errors: Array[String] = []
var metrics := {}
var measured_normal := 0.0
var measured_fast := 0.0
var begun := 0
var latest_reply := 0
var last_interval := 0
var result_count := 0
var result_ok := false
var reset_count := 0
var station_counts := {}
var fingerprints := {}
var max_memory := 0
var minimum_free := 0
var next_progress := 0
var current_bucket := ""
var closing_since := 0
const STATIONS := ["gunner","commander","cupola","driver"]
var segment_sim_seconds := 0.0
var memory_baseline := 0
var memory_timeline: Array[Dictionary] = []
var next_memory := 0
var sim_replies := 0
var unexpected_program := ""
var input_observations: Array[Dictionary] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--output")+1
	if not ["--boot","--play","--capture","--frame-audit","--output"].all(func(flag):return flag in args) or "--no-audio" in args or "--saves" in args or index==0 or index>=args.size() or DirAccess.dir_exists_absolute(args[index]):
		printerr("Soak requires --boot --play --capture --frame-audit --output FRESH and isolated saves/audio")
		quit(2)
		return
	if "--seconds" in args:
		var i := args.find("--seconds")+1
		if i>=args.size() or not args[i].is_valid_float():
			quit(2)
			return
		seconds=float(args[i])
	if seconds<6 or seconds>1800:
		quit(2)
		return
	for path in ["res://tests/test_pc_soak.gd","res://scripts/pc_bridge_viewer.gd","res://scripts/pc_audio.gd","res://scripts/pc_play_menu.gd"]:
		fingerprints[path]=FileAccess.get_sha256(path)
	fingerprints["executed_test_script"]=FileAccess.get_sha256(get_script().resource_path)
	var repository := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	for path in ["GAME/SIM.EXE","tools/pc_bridge_host.py","tools/pc_state_host.py"]:
		fingerprints[path]=FileAccess.get_sha256(repository.path_join(path))
	super._initialize()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok and errors.size()<30:errors.append(label)

func _capture_deadline_msec() -> int:return 180000

func _process(delta: float) -> bool:
	if closing:
		if closing_since==0:closing_since=Time.get_ticks_msec()
		if Time.get_ticks_msec()-closing_since>30000:
			printerr("SOAK shutdown exceeded 30 seconds; child cleanup unverified")
			quit(1)
			return false
		return super._process(delta)
	if not active:return super._process(delta)
	if capture:
		for message in bridge.poll():
			if message.type=="state_result":_state_result(message)
			else:_apply_sample(message)
	else:
		super._process(delta)
	return false

func _state_result(message: Dictionary) -> void:
	result_count+=1
	result_ok=bool(message.get("success",false))
	super._state_result(message)

func _apply_sample(message: Dictionary) -> void:
	super._apply_sample(message)
	if not active:return
	var now := Time.get_ticks_usec()
	latest_reply=now
	var program: String=str(message.get("program",{}).get("name","unknown"))
	if program!="SIM":
		unexpected_program=program
		check(false,"unexpected program transition from SIM to "+program+"; no idle/menu time credited")
		last_interval=0
		return
	sim_replies+=1
	check(pc_audio.failure.is_empty() and bridge.failure.is_empty(),"production audio/transport healthy")
	var envelope: Dictionary=message.get("audio",{})
	if not envelope.is_empty():check(int(envelope.frame)==int(pc_audio.last_frame),"audio consumer at current original frame")
	check(message.get("frame_audit",{}).get("ram_bytes")==655360,"complete original RAM audit present")
	var station := str(previous.get("station","unknown"))
	check(station in STATIONS,"known original station")
	if station in STATIONS:station_counts[station]=int(station_counts.get(station,0))+1
	if current_bucket.is_empty():return
	var row: Dictionary=metrics[current_bucket]
	row.replies+=1
	if last_interval>0:
		var ms := (now-last_interval)/1000.0
		segment_sim_seconds+=ms/1000.0
		if current_bucket.ends_with("/normal"):measured_normal+=ms/1000.0
		else:measured_fast+=ms/1000.0
		row.interval_count+=1
		row.interval_sum_ms+=ms
		row.interval_max_ms=maxf(row.interval_max_ms,ms)
		if ms>100:row.over_100ms+=1
	last_interval=now
	max_memory=maxi(max_memory,OS.get_static_memory_usage())
	row.memory_max_bytes=maxi(row.memory_max_bytes,OS.get_static_memory_usage())

func wait_reply() -> bool:
	var deadline := Time.get_ticks_msec()+60000
	while bridge.pending and bridge.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(not bridge.pending and bridge.failure.is_empty(),"bounded bridge reply")
	return not bridge.pending and bridge.failure.is_empty()

func checkpoint(operation: String) -> void:
	if not disk_ok():return
	var before := result_count
	_request_state(operation,1)
	_send_state_command()
	await wait_reply()
	check(result_count==before+1 and result_ok,"checkpoint "+operation)
	if operation=="load_state":reset_count+=1

func disk_ok() -> bool:
	var directory := DirAccess.open(output)
	var free := directory.get_space_left() if directory else 0
	minimum_free=free if minimum_free==0 else mini(minimum_free,free)
	check(free>1024*1024*1024,"at least 1 GiB free; preserve all existing artifacts")
	return free>1024*1024*1024

func memory_sample() -> void:
	if memory_timeline.size()<128:
		memory_timeline.append({"wall_seconds":(Time.get_ticks_usec()-begun)/1000000.0,"normal_sim_seconds":measured_normal,"static_memory_bytes":OS.get_static_memory_usage(),"bucket":current_bucket,"resets":reset_count})

func report(final: bool) -> void:
	var file := FileAccess.open(output.path_join("soak-report.json" if final else "soak-progress.json"),FileAccess.WRITE)
	if file==null:
		check(false,"report writable")
		return
	file.store_string(JSON.stringify({"final":final,"passed":final and errors.is_empty(),"requested_normal_seconds":seconds,"measured_normal_seconds":measured_normal,"measured_fast_seconds":measured_fast,"wall_seconds":(Time.get_ticks_usec()-begun)/1000000.0,"checks":checks,"errors":errors,"metrics":metrics,"stations":station_counts,"resets":reset_count,"source_sha256":fingerprints,"memory_max_bytes":max_memory,"memory_baseline_bytes":memory_baseline,"memory_current_bytes":OS.get_static_memory_usage(),"memory_timeline":memory_timeline,"sim_replies":sim_replies,"unexpected_program":unexpected_program,"minimum_free_bytes":minimum_free,"audio_delivered":pc_audio.delivered,"audio_suppressed":pc_audio.suppressed,"audio_epoch":pc_audio.epoch,"scope":"Actual paced production transport; normal elapsed time excludes fast-forward, resets, and setup. Audio health measures consumer state, not acoustic latency or human listening. No mission victory claim. Native focus testing is a separate gate."},"  "))
	var input_file := FileAccess.open(output.path_join("soak-inputs.json"),FileAccess.WRITE)
	if input_file: input_file.store_string(JSON.stringify(input_observations,"  "))

func segment(mode: String, multiplier: int, duration: float, station_index: int) -> void:
	var old_samples := samples
	var old_state := JSON.stringify(previous)
	audio_menu.choose_graphics(mode)
	check(tandem_frame.graphics_mode==mode and samples==old_samples and JSON.stringify(previous)==old_state,"immediate same-frame graphics switch "+mode)
	audio_menu.speed_popup.id_pressed.emit(multiplier)
	current_bucket=mode+("/normal" if multiplier==1 else "/fast")
	if not metrics.has(current_bucket):metrics[current_bucket]={"replies":0,"interval_count":0,"interval_sum_ms":0.0,"interval_max_ms":0.0,"over_100ms":0,"memory_max_bytes":0,"wall_seconds":0.0}
	last_interval=0
	segment_sim_seconds=0.0
	var begin := Time.get_ticks_usec()
	latest_reply=begin
	var key: int = [KEY_F1,KEY_F2,KEY_F3,KEY_F4][station_index%4]
	var event := InputEventKey.new()
	event.keycode=key;event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	input_observations.append({"bucket":current_bucket,"station_index":station_index%4,"focused":root.has_focus(),"menu_focused":audio_menu.window_focused,"release_keys":audio_menu.release_keys,"held":Keyboard.held()})
	capture=false
	elapsed=0
	var released := false
	while segment_sim_seconds<duration and errors.is_empty() and bridge.failure.is_empty():
		await process_frame
		if not released and Time.get_ticks_usec()-begin>250000:
			event=InputEventKey.new();event.keycode=key;event.pressed=false
			Input.parse_input_event(event);released=true
		if Time.get_ticks_usec()-latest_reply>10000000:check(false,"no production frame for ten seconds")
		if Time.get_ticks_usec()-begin>int((duration+60)*1000000):check(false,"bounded segment wall deadline")
		if Time.get_ticks_usec()>next_memory:
			memory_sample();next_memory=Time.get_ticks_usec()+30000000
		if Time.get_ticks_usec()>next_progress:
			disk_ok();report(false);next_progress=Time.get_ticks_usec()+30000000
	capture=true
	event=InputEventKey.new();event.keycode=key;event.pressed=false
	Input.parse_input_event(event)
	await wait_reply()
	var duration_actual := (Time.get_ticks_usec()-begin)/1000000.0
	metrics[current_bucket].wall_seconds+=duration_actual
	current_bucket=""

func _capture() -> void:
	active=true
	# Capture cold boot can finish while another app is foreground. Require an
	# actual OS focus event before injecting test keys, never fake focus flags.
	var focus_deadline := Time.get_ticks_msec()+60000
	while not root.has_focus() and Time.get_ticks_msec()<focus_deadline: await process_frame
	check(root.has_focus(),"real native focus acquired before measured input route")
	begun=Time.get_ticks_usec()
	memory_baseline=OS.get_static_memory_usage()
	memory_sample()
	check(play_mode and pc_audio!=null and previous_program.get("name")=="SIM","production SIM and audio active")
	await checkpoint("save_state")
	# Eighteen restores maximum, 36 paced segments. Full run: 1800 normal seconds
	# plus 36 real fast-forward seconds; short smoke follows the same code path.
	for cycle in 6:
		for mode_index in 3:
			if not errors.is_empty() or not bridge.failure.is_empty():break
			var mode: String=["ega","genesis","upscaled"][mode_index]
			await segment(mode,1,maxf(2.0,seconds/18.0),cycle*3+mode_index)
			if errors.is_empty():await segment(mode,2,2.0,cycle*3+mode_index)
			if not errors.is_empty() or not bridge.failure.is_empty():break
			await checkpoint("load_state")
	check(measured_normal>=seconds,"requested real normal-speed duration completed")
	check(STATIONS.all(func(station):return station_counts.get(station,0)>0),"gunner, commander, cupola and driver each observed")
	check(bridge.failure.is_empty() and pc_audio.failure.is_empty(),"final transport/audio healthy")
	memory_sample()
	report(true)
	for error in errors:printerr("FAIL: "+error)
	print("PC_SOAK: %d checks, %d errors, %.3f normal seconds"%[checks,errors.size(),measured_normal])
	if not errors.is_empty():bridge.failure=errors[0]
	active=false
	_close()
