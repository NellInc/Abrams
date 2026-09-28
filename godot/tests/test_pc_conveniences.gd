extends "res://scripts/pc_bridge_viewer.gd"
## Production key events, same-frame GFX, state restore and FF parity.
var exercising := false
var errors: Array[String] = []
var checks := 0
var last_packet: Dictionary = {}
var state_results: Array[Dictionary] = []
var mode_images := {}

func rendered_frame() -> Image:
	# Bridge replies arrive during _process; let queued CanvasItem redraws finish.
	await process_frame
	# An occluded macOS window can stop emitting frame_post_draw indefinitely.
	# Flush this owned test viewport explicitly; no guest frame is advanced.
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return tandem_viewport.get_texture().get_image()

func shortcut(code: int, shift: bool=false) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code;event.pressed=pressed;event.shift_pressed=shift
		event.meta_pressed=audio_menu.shortcut_is_macos
		event.ctrl_pressed=not audio_menu.shortcut_is_macos
		event.alt_pressed=not audio_menu.shortcut_is_macos
		root.push_input(event)
		check(audio_menu.game_keys([String.chr(code).to_lower()]).is_empty(),"shortcut letter is withheld from original")
		await process_frame
	audio_menu.game_keys([])

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok and errors.size()<30:errors.append(label)

func _capture_deadline_msec() -> int:return 600000

func _process(delta: float) -> bool:
	if not exercising:return super._process(delta)
	for message in bridge.poll():
		if message.type=="state_result":_state_result(message)
		else:_apply_sample(message)
	return false

func _apply_sample(message: Dictionary) -> void:
	last_packet=message.duplicate(true)
	super._apply_sample(message)

func _state_result(message: Dictionary) -> void:
	state_results.append(message.duplicate(true))
	super._state_result(message)

func wait_reply() -> bool:
	var deadline:=Time.get_ticks_msec()+60000
	while bridge.pending and bridge.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(not bridge.pending and bridge.failure.is_empty(),"bounded production reply: "+bridge.failure)
	return not bridge.pending and bridge.failure.is_empty()

func state_action(operation: String, slot: int) -> void:
	var before:=state_results.size()
	await shortcut(KEY_S if operation=="save_state" else KEY_L,slot==0)
	check(not pending_state_command.is_empty(),"keyboard dispatches "+operation)
	_send_state_command()
	if not await wait_reply():return
	check(state_results.size()==before+1 and state_results[-1].get("success",false),"state operation succeeds: "+operation)
	check(not state_control_pending and not audio_menu.busy,"state control releases transport")
	check(pc_audio.failure.is_empty(),"audio timeline healthy after "+operation)

func advance(multiplier: int) -> void:
	audio_menu.speed_popup.id_pressed.emit(multiplier)
	capture=false
	elapsed=1.0/fps
	check(_advance_live_frame(),"production speed request dispatched: "+str(multiplier))
	capture=true # test driver prevents the next automatic request, not this one.
	await wait_reply()
	check(pc_audio.transport_muted==(multiplier>1),"accelerated original frames are muted")
	check(pc_audio.failure.is_empty(),"accelerated audio consumed without failure")

func _capture() -> void:
	exercising=true
	check(previous_program.get("name")=="SIM" and not previous.is_empty(),"ordinary cold boot reaches SIM")
	check(audio_menu.get_menu_count()==3 and tandem_frame.native_graphics.loaded,"production controls and authentic donor bank loaded")
	var source:=picture.texture.get_image().get_data()
	var state_json:=JSON.stringify(previous)
	var original_samples:=samples
	var loads:int=tandem_frame.native_graphics.load_count
	for mode in ["ega","genesis","upscaled","ega","genesis","upscaled"]:
		await shortcut(KEY_G)
		check(tandem_frame.graphics_mode==mode,"same-frame graphics mode: "+mode)
		check(source==picture.texture.get_image().get_data() and state_json==JSON.stringify(previous) and samples==original_samples,"mode switch does not execute or modify the original")
		await process_frame
		RenderingServer.force_draw(false);RenderingServer.force_sync()
		var rendered:=tandem_viewport.get_texture().get_image()
		if mode_images.has(mode):check(mode_images[mode]==rendered.get_data(),"returning to same mode is byte-identical: "+mode)
		mode_images[mode]=rendered.get_data()
		check(rendered.save_png(output.path_join("graphics-"+mode+".png"))==OK,"graphics screenshot")
	check(mode_images.ega!=mode_images.genesis and mode_images.genesis!=mode_images.upscaled,"three genuine distinct presentations")
	check(tandem_frame.native_graphics.load_count==loads,"no image loading on graphics switches")
	check(not audio_menu.choose_graphics("modern") and tandem_frame.graphics_mode=="upscaled","Modern explicitly unavailable")
	await state_action("save_state",1)
	check((await rendered_frame()).get_data()==mode_images.upscaled,"saving leaves complete rendered frame unchanged")
	var normal:Dictionary={}
	for i in 15:await advance(1)
	var normal_image:=await rendered_frame()
	normal=last_packet.get("frame_audit",{}).duplicate(true)
	var normal_state:=JSON.stringify(previous)
	check(not normal.is_empty(),"normal replay has source RAM/video audit")
	await state_action("load_state",1)
	check((await rendered_frame()).get_data()==mode_images.upscaled,"loading restores complete rendered cockpit")
	for multiplier in [1,2,4,8]:await advance(multiplier)
	check((await rendered_frame()).get_data()==normal_image.get_data(),"fast forward preserves complete rendered cockpit")
	check(last_packet.get("frame_audit",{})==normal,"1x and fast-forward execute the same fifteen original frames")
	check(JSON.stringify(previous)==normal_state,"same complete game state after accelerated replay")
	audio_menu.speed_popup.id_pressed.emit(1)
	check(not pc_audio.transport_muted,"normal-speed audio resumes without stale queued speech")
	check(audio_menu.state_slots.any(func(row):return int(row.slot)==0 and row.get("exists",false)),"pre-load recovery available")
	await state_action("load_state",0)
	check(last_packet.get("frame_audit",{})==normal,"Undo load shortcut restores pre-load original RAM/video")
	FileAccess.open(output.path_join("conveniences-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"normal_audit":normal,"accelerated_audit":last_packet.get("frame_audit",{}),"state_results":state_results.map(func(r):return {"success":r.get("success"),"message":r.get("message")}),"scope":"Production native viewer; keyboard events through the live shortcut handler; graphics switches on frozen source frame; persisted quick save/load and recovery; 1x vs 1+2+4+8 original-frame replay. No mission victory claim."},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_CONVENIENCES: %d checks, %d errors"%[checks,errors.size()])
	if not errors.is_empty():bridge.failure=errors[0]
	exercising=false
	await super._capture()
