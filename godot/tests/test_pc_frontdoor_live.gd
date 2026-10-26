extends "res://scripts/pc_bridge_viewer.gd"
## Actual native Play, isolated output/saves; only ordinary original keys.
var checks:=0
var errors:Array[String]=[]
var test_started:=false
var test_done:=false
var reports_done:=false
var deadline:=Time.get_ticks_msec()+240000
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label);printerr("FAIL: "+label)
func wait_until(predicate:Callable,label:String)->bool:
	var end:=Time.get_ticks_msec()+120000
	while not predicate.call() and bridge.failure.is_empty() and Time.get_ticks_msec()<end:
		await process_frame
	var ok:bool=predicate.call()
	check(ok,label)
	return ok
func settle(n:=6)->void:
	for i in n:
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
func shot(name:String)->void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func key(code:int,pressed:bool)->void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func click(button:Button)->void:
	var at:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
	await settle(2)
func pulse(code:int)->void:
	audio_menu.window_focused=true
	audio_menu.focus_release_keys=false
	audio_menu.release_keys=false
	key(code,true)
	var before:=samples
	await wait_until(func():return samples>=before+10,"original key press processed")
	key(code,false)
	before=samples
	await wait_until(func():return samples>=before+30 or _frontdoor_blocked(),"original key released")
func source_has(text:String)->bool:
	return _decoded_image!=null and text in frontdoor_route.proof.verified_text(_decoded_image,previous_presentation)
func check_fit()->void:
	for entry in frontdoor.main.ui.buttons:
		var b:Button=entry.node
		var width:float=b.get_theme_font("font").get_string_size(b.text,HORIZONTAL_ALIGNMENT_LEFT,-1,b.get_theme_font_size("font_size")).x
		check(width+b.get_theme_stylebox("normal").get_minimum_size().x<=b.size.x,"label fits: "+b.text)
func run_test()->void:
	audio_menu.config_path=output.path_join("audio.cfg")
	audio_menu.quality_config_path=output.path_join("graphics.cfg")
	check(_frontdoor_blocked() and frontdoor.visible,"ordinary Play lands on cover")
	check(frontdoor.main.embedded and not auto_accept_quit,"embedded scene cannot own quit")
	check(frontdoor.main.ui.buttons.map(func(entry):return entry.node.text)==["SCENARIO","CAMPAIGN","SETTINGS","EXTRAS","QUIT"],"five main actions")
	var id:int=bridge.next_id
	await shot("01-main-1280")
	root.size=Vector2i(1152,648);await shot("02-main-wide");check_fit()
	root.size=Vector2i(640,480);await shot("03-main-compact");check_fit()
	check(bridge.next_id==id,"idle cover freezes original guest")
	await click(frontdoor.main.ui.buttons[2].node)
	check(is_instance_valid(frontdoor.settings_page),"pointer reaches embedded Settings button")
	await shot("04-settings-compact")
	check(frontdoor.settings_columns.columns==1,"compact settings scroll in one column")
	var sliders=frontdoor.settings_page.find_children("*","HSlider",true,false)
	check(sliders.size()==17,"all group, individual and private world mix channels accessible")
	sliders[0].value=31
	check(audio_menu.settings.master==31 and is_equal_approx(frontdoor.main.sound.volume,0.65*0.31),"settings and practice share master volume")
	for channel in ["cannon","engine","turret","radio","switch"]:
		var percent := 0 if channel=="engine" else 40
		sliders[audio_menu.DEFAULTS.keys().find(channel)].value=percent
		check(audio_menu.settings[channel]==percent and is_equal_approx(frontdoor.main.sound.cue_gain(channel),float(percent)/100.0),"settings and practice share individual gain: "+channel)
	for channel in ["river","hind","field","cow"]:
		sliders[audio_menu.DEFAULTS.keys().find(channel)].value=0 if channel=="hind" else 37
		check(audio_menu.settings[channel]==(0 if channel=="hind" else 37) and (pc_audio==null or pc_audio.mix[channel]==audio_menu.settings[channel]),"Settings updates private world gain: "+channel)
	var options=frontdoor.settings_page.find_children("*","OptionButton",true,false)
	var old_mode:String=audio_menu.graphics_mode
	options[0].item_selected.emit(0)
	check(audio_menu.graphics_mode=="ega" and tandem_frame.graphics_mode=="ega","Settings applies actual graphics controller")
	audio_menu.choose_graphics(old_mode)
	var old_msaa:int=audio_menu.quality.msaa
	options[2].item_selected.emit(1)
	check(audio_menu.quality.msaa==2 and frontdoor.stage.msaa_3d==Viewport.MSAA_2X,"cover and practice share graphics quality settings")
	audio_menu.choose_quality("msaa",old_msaa)
	root.size=Vector2i(1152,648);await shot("05-settings-wide")
	check(frontdoor.settings_columns.columns==2,"wide settings uses two columns")
	if "--settings-only" in OS.get_cmdline_user_args():
		var scroll: ScrollContainer=frontdoor.settings_columns.get_parent()
		scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
		await shot("06-settings-individual")
		check(bridge.next_id==id,"individual settings never advance original guest")
		test_done=true
		frontdoor.main.request_quit()
		return
	frontdoor.close_settings()
	await click(frontdoor.main.ui.buttons[3].node)
	check(frontdoor.main.screen=="extras","pointer reaches embedded Extras button")
	await shot("06-extras")
	frontdoor.main.ui.buttons[0].node.pressed.emit()
	var ticks:int=frontdoor.main.sim.elapsed_ticks
	await settle(20)
	check(frontdoor.main.sim.elapsed_ticks>ticks and bridge.next_id==id,"practice runs while original guest remains frozen")
	frontdoor.main.paused=true;frontdoor.main.ui.rebuild_buttons()
	frontdoor.main.ui.buttons[-1].node.pressed.emit()
	frontdoor.main.ui.buttons[1].node.pressed.emit()
	await shot("07-artwork")
	check(frontdoor.artwork.embedded and not auto_accept_quit,"artwork retains viewer shutdown authority")
	frontdoor.artwork._back();await settle()
	check(frontdoor.main.screen=="extras","artwork returns to Extras")
	check(not audio_menu.request_state("save_state",1) and pending_state_command.is_empty(),"Extras cannot save the hidden guest")
	check(bridge.next_id==id,"settings and artwork also freeze guest")
	frontdoor.main.set_screen("menu")
	await settle()
	key(KEY_ENTER,true);await process_frame;key(KEY_ENTER,false)
	await settle(2)
	check(frontdoor.busy,"keyboard activates focused Scenario button on release")
	if not frontdoor.busy:_close();return
	key(KEY_ENTER,true)
	if not await wait_until(func():return not _frontdoor_blocked(),"Scenario route completes"):_close();return
	var held_samples:=samples
	await wait_until(func():return samples>=held_samples+60,"held activation key quarantined after handoff")
	check(source_has("MISSION:") and source_has("SKILL:"),"Scenario opens original setup without Begin")
	key(KEY_ENTER,false)
	await shot("08-scenario")
	await pulse(KEY_ESCAPE)
	if not await wait_until(func():return _frontdoor_blocked(),"original scenario cancel returns to cover"):_close();return
	frontdoor.main.ui.buttons[1].node.pressed.emit()
	if not await wait_until(func():return not _frontdoor_blocked(),"Campaign route completes"):_close();return
	check(source_has("BEGIN") and not source_has("NAME:"),"Campaign stops before original name/save choice")
	await shot("09-campaign")
	await pulse(KEY_ENTER)
	check(source_has("NAME:") and not _frontdoor_blocked(),"campaign name entry stays in original game")
	await pulse(KEY_N)
	await pulse(KEY_ESCAPE)
	check(not _frontdoor_blocked(),"name cancellation retains campaign dropdown")
	await pulse(KEY_ESCAPE)
	if not await wait_until(func():return _frontdoor_blocked(),"campaign cancellation returns to cover"):_close();return
	frontdoor.main.set_screen("extras");frontdoor.main.start_range()
	test_done=true
	frontdoor.main.request_quit()
func _process(delta:float)->bool:
	if frontdoor_shown and not test_started and bridge.failure.is_empty():
		test_started=true;run_test.call_deferred()
	if Time.get_ticks_msec()>deadline and not closing:
		check(false,"live test deadline");_close()
	var parent_result: bool = super._process(delta)
	if closing and bridge.has_exited() and audio_drained and not reports_done:
		reports_done=true
		check(test_done,"all frontend routes completed")
		check(bridge.failure.is_empty() and bridge.exit_code()==0,"embedded Quit drains audio and closes original host")
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"samples":samples,"bridge_failure":bridge.failure},"  "))
		print("PC_FRONTDOOR_LIVE: %d checks, %d errors"%[checks,errors.size()])
		if not errors.is_empty():quit(1);return false
	return parent_result
