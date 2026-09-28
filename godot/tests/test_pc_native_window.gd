extends "res://scripts/pc_bridge_viewer.gd"
## Observer only: real native focus/menu/window changes must come from the user/CUA.
var observing := false
var finishing := false
var finished := false
var begin_msec := 0
var next_tick := 0
var shutdown_msec := 0
var telemetry: FileAccess
var event_count := 0
var last_status := ""
var transitions := {"focus_entered":0,"focus_exited":0,"window_mode":0,"menus":0,"graphics":0}
var last_values := {}
var observer_errors: Array[String] = []
var last_dispatch := {}
var dispatch_counts := {"all":0,"unfocused":0,"menu_open":0,"nonneutral_blocked":0}
var menu_events := {"opened":0,"closed":0}

class ObservedBridge extends "res://scripts/pc_bridge.gd":
	var observer
	func step(frames: int, keys: Array) -> bool:
		var sent := super.step(frames,keys)
		if sent and observer.observing:observer.observe_dispatch(frames,keys)
		return sent

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--output")+1
	if not ["--boot","--play","--capture","--output"].all(func(flag):return flag in args) or "--saves" in args or "--no-audio" in args or i==0 or i>=args.size() or DirAccess.dir_exists_absolute(args[i]):
		printerr("Native window observer requires boot/play/capture/audio and fresh isolated output")
		quit(2)
		return
	var observed := ObservedBridge.new()
	observed.observer=self
	bridge=observed
	super._initialize()
	telemetry=FileAccess.open(output.path_join("native-window-events.jsonl"),FileAccess.WRITE)
	root.focus_entered.connect(func():focus_event("focus_entered"))
	root.focus_exited.connect(func():focus_event("focus_exited"))
	# Native AppKit menus can suspend _process while tracking. Record their real
	# callbacks directly so an open/close pair between ticks is not lost.
	for menu in audio_menu.find_children("*","PopupMenu",true,false):
		menu.about_to_popup.connect(func():menu_event("opened",menu))
		menu.popup_hide.connect(func():menu_event("closed",menu))

func menu_event(kind: String, menu: PopupMenu) -> void:
	menu_events[kind]+=1
	emit_record("menu_"+kind,{"name":menu.name,"held":Keyboard.held(),"release_keys":audio_menu.release_keys,"dispatch_counts":dispatch_counts.duplicate()})

func emit_record(kind: String, values: Dictionary) -> void:
	if telemetry and event_count<4096:
		telemetry.store_line(JSON.stringify({"event":kind,"elapsed_ms":Time.get_ticks_msec()-begin_msec,"values":values}))
		telemetry.flush()
		event_count+=1

func focus_event(kind: String) -> void:
	transitions[kind]+=1
	emit_record(kind,{"root_has_focus":root.has_focus()})

func observe_dispatch(frames: int, keys: Array) -> void:
	var focused := root.has_focus()
	var menus: bool=not audio_menu.open_menus.is_empty()
	dispatch_counts.all+=1
	if not focused:dispatch_counts.unfocused+=1
	if menus:dispatch_counts.menu_open+=1
	if (not focused or menus) and not keys.is_empty():
		dispatch_counts.nonneutral_blocked+=1
		if observer_errors.size()<20:observer_errors.append("Nonneutral guest dispatch during actual unfocused/menu state")
	last_dispatch={"frames":frames,"keys":keys.duplicate(),"focused":focused,"menu_open":menus}

func snapshot() -> Dictionary:
	return {"focused":root.has_focus(),"window_mode":root.mode,"menus":audio_menu.open_menus.keys().map(func(menu):return str(menu.name)),"graphics":tandem_frame.graphics_mode,"samples":samples,"program":previous_program.get("name","unknown"),"station":previous.get("station","unknown"),"held":Keyboard.held(),"last_dispatch":last_dispatch,"dispatch_counts":dispatch_counts.duplicate(),"audio_failure":pc_audio.failure,"bridge_failure":bridge.failure,"audio_epoch":pc_audio.epoch,"audio_last_frame":pc_audio.last_frame}

func _capture() -> void:
	begin_msec=Time.get_ticks_msec()
	observing=true
	capture=false
	elapsed=0
	emit_record("live_started",snapshot())

func _process(delta: float) -> bool:
	if closing:
		if shutdown_msec==0:shutdown_msec=Time.get_ticks_msec()
		if Time.get_ticks_msec()-shutdown_msec>30000:
			printerr("Native observer shutdown timeout; child cleanup unverified")
			quit(1)
			return false
	if finishing and not finished:
		for message in bridge.poll():
			if message.type=="state_result":_state_result(message)
			else:_apply_sample(message)
		return false
	var result := super._process(delta)
	if not observing or finishing:return result
	var now := Time.get_ticks_msec()
	if now>=next_tick:
		var state := snapshot()
		for key in ["window_mode","menus","graphics"]:
			if last_values.has(key) and last_values[key]!=state[key]:
				transitions[key]+=1
				emit_record("transition_"+key,{"before":last_values[key],"after":state[key]})
			last_values[key]=state[key].duplicate() if state[key] is Array else state[key]
		emit_record("telemetry",state)
		next_tick=now+250
	if now-begin_msec>=240000 or FileAccess.file_exists(output.path_join("finish.json")) or not bridge.failure.is_empty() or not pc_audio.failure.is_empty():
		finish.call_deferred()
	return result

func _close() -> void:
	if finished:super._close()
	elif not finishing:finish.call_deferred()

func finish() -> void:
	if finishing:return
	finishing=true
	capture=true
	var deadline := Time.get_ticks_msec()+30000
	while bridge.pending and bridge.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if bridge.pending:observer_errors.append("Pending bridge reply at bounded finish")
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var screenshot_error := tandem_viewport.get_texture().get_image().save_png(output.path_join("native-window-final.png"))
	if screenshot_error!=OK:observer_errors.append("Final screenshot failed")
	var final := snapshot()
	final["transitions"]=transitions
	final["menu_events"]=menu_events
	final["errors"]=observer_errors
	final["elapsed_seconds"]=(Time.get_ticks_msec()-begin_msec)/1000.0
	final["scope"]="Observed real native window/focus/menu transitions and exact production step keys. No synthetic focus/fullscreen/menu events; no claim about physically held hardware keys. Missing transitions require human/CUA action and are not inferred."
	var report := FileAccess.open(output.path_join("native-window-report.json"),FileAccess.WRITE)
	if report:report.store_string(JSON.stringify(final,"  "))
	else:observer_errors.append("Final report write failed")
	emit_record("finished",final)
	if not observer_errors.is_empty() and bridge.failure.is_empty():bridge.failure=observer_errors[0]
	finished=true
	observing=false
	super._close()
