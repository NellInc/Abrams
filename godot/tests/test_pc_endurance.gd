extends "res://tests/test_pc_conveniences.gd"
## Finite repeated production transport and paced playback acceptance.
var pacing := false
var pacing_target := 0
var pacing_count := 0
var pacing_last_usec := 0
var pacing_intervals: Array[float] = []
var endurance_segments: Array[Dictionary] = []
var audio_max_lag := 0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if not ["--boot","--play","--capture","--frame-audit","--output"].all(func(flag):return flag in args) or "--no-audio" in args:
		printerr("Endurance requires --boot --play --capture --frame-audit --output NEW and audio")
		quit(2)
		return
	var index:=args.find("--output")+1
	if index>=args.size() or DirAccess.dir_exists_absolute(args[index]) or "--saves" in args:
		printerr("Endurance requires a fresh output and its isolated default saves")
		quit(2)
		return
	super._initialize()

func _process(delta: float) -> bool:
	if not pacing:return super._process(delta)
	elapsed+=delta
	for message in bridge.poll():
		if message.type=="state_result":_state_result(message)
		else:_apply_sample(message)
	if pacing_count<pacing_target and bridge.failure.is_empty():_advance_live_frame()
	return false

func _apply_sample(message: Dictionary) -> void:
	# Production _apply_sample can prefetch a frame. Freeze at the target before
	# invoking it, keeping the segment's endpoint exact without dropping replies.
	if pacing and pacing_count+1>=pacing_target:capture=true
	super._apply_sample(message)
	if not pacing:return
	pacing_count+=1
	var now:=Time.get_ticks_usec()
	if pacing_last_usec>0:pacing_intervals.append((now-pacing_last_usec)/1000.0)
	pacing_last_usec=now
	check(pc_audio.failure.is_empty() and bridge.failure.is_empty(),"paced presentation/audio healthy")
	var envelope:Dictionary=message.get("audio",{})
	if not envelope.is_empty():
		var lag:=int(envelope.frame)-int(pc_audio.last_frame)
		audio_max_lag=maxi(audio_max_lag,lag)
		check(lag==0,"audio consumer reaches current original frame")
	check(message.get("frame_audit",{}).get("ram_bytes")==655360,"paced full original RAM audit")

func paced_segment(index: int) -> void:
	pacing_count=0
	pacing_target=1200
	pacing_last_usec=0
	pacing_intervals.clear()
	audio_max_lag=0
	audio_menu.speed_popup.id_pressed.emit(1)
	var initial_sequence:=int(last_packet.sequence)
	var begin:=Time.get_ticks_usec()
	var deadline:=Time.get_ticks_msec()+120000
	pacing=true
	capture=false
	elapsed=0
	while pacing_count<pacing_target and bridge.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	capture=true
	pacing=false
	await wait_reply()
	var duration:float=(Time.get_ticks_usec()-begin)/1000000.0
	check(pacing_count==pacing_target,"paced segment completes finite original-frame count")
	check(int(last_packet.sequence)-initial_sequence==pacing_target,"normal transport never skips/batches original frames")
	pacing_intervals.sort()
	endurance_segments.append({"segment":index,"frames":pacing_count,"wall_seconds":duration,"fps":pacing_count/duration,"advertised_fps":fps,"p50_ms":pacing_intervals[pacing_intervals.size()/2] if not pacing_intervals.is_empty() else 0,"p95_ms":pacing_intervals[int(pacing_intervals.size()*0.95)] if not pacing_intervals.is_empty() else 0,"max_ms":pacing_intervals[-1] if not pacing_intervals.is_empty() else 0,"audio_max_consumer_lag_frames":audio_max_lag,"static_memory_bytes":OS.get_static_memory_usage(),"final_audit":last_packet.get("frame_audit",{})})

func _capture() -> void:
	exercising=true
	check(play_mode and pc_audio!=null,"native Play with production audio required")
	check(previous_program.get("name")=="SIM","cold boot reaches original SIM")
	for cycle in 3:
		await state_action("save_state",1)
		for i in 15:await advance(1)
		var expected:Dictionary=last_packet.get("frame_audit",{}).duplicate(true)
		await state_action("load_state",1)
		for multiplier in [1,2,4,8]:await advance(multiplier)
		check(last_packet.get("frame_audit",{})==expected,"repeated normal/accelerated RAM-video equality")
		await state_action("load_state",1)
		await paced_segment(cycle)
		if not errors.is_empty():break
	check(pc_audio.failure.is_empty(),"audio remains healthy through repeated timeline resets")
	var image:=await rendered_frame()
	check(image.save_png(output.path_join("endurance-final.png"))==OK,"final native screenshot")
	FileAccess.open(output.path_join("endurance-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"segments":endurance_segments,"scope":"Three checkpoint/1x-vs-fast-forward cycles and 3600 paced original frames in production Play. Audio drift is observer-to-player frame consumption, not acoustic latency. Rates/memory are measured diagnostics, never speculative gameplay-divergence thresholds. No mission victory attempt."},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_ENDURANCE_NATIVE: %d checks, %d errors, %d segments"%[checks,errors.size(),endurance_segments.size()])
	if not errors.is_empty():bridge.failure=errors[0]
	exercising=false
	_close()
