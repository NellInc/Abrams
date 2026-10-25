extends "res://scripts/pc_bridge_viewer.gd"
## Actual-window acceptance using the production host/viewer, without guest
## requests while changing display size or entering/leaving native fullscreen.
var resize_errors: Array[String] = []
var resize_samples: Array = []

func _settled(mode: int, expected_size: Vector2i=Vector2i.ZERO) -> void:
	# macOS mode transitions are asynchronous. Twenty unthrottled frames can
	# elapse before the native animation even starts; require elapsed stability.
	var prior := root.size
	var stable_since := Time.get_ticks_msec()
	var deadline := stable_since+10000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		var ready := root.mode==mode and root.size.x>0 and root.size.y>0
		ready=ready and (expected_size==Vector2i.ZERO or root.size==expected_size)
		if not ready or root.size!=prior:
			stable_since=Time.get_ticks_msec()
			prior=root.size
		elif Time.get_ticks_msec()-stable_since>=750:
			return
	resize_errors.append("window mode/size never stable for 750 ms: mode=%d expected=%s actual=%s"%[mode,expected_size,root.size])

func _capture() -> void:
	if not play_mode:
		bridge.failure="Resize acceptance requires --play"
		_close()
		return
	# This gate checks the un-reflowed 4:3 compositor byte-for-byte. Tactical
	# HUD intentionally reflows to 16:9 with a separate shader/chrome layer.
	_choose_hud_style("restored")
	if play_display.hud_style!="restored":
		bridge.failure="Resize acceptance could not select the restored HUD"
		_close()
		return
	var original := picture.texture.get_image().get_data()
	var state: Dictionary=previous.duplicate(true)
	var presentation: Dictionary=previous_presentation.duplicate(true)
	var count := samples
	for item in [[1440,900],[1280,960],[900,1200],[1920,1080],[-1,-1],[1440,900]]:
		var fullscreen: bool=item[0]==-1
		var target_mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if root.mode!=target_mode:
			root.mode=target_mode
			await _settled(target_mode)
		if not fullscreen: root.size=Vector2i(item[0],item[1])
		await _settled(target_mode,Vector2i.ZERO if fullscreen else Vector2i(item[0],item[1]))
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		var image := root.get_texture().get_image()
		var frame := tandem_viewport.get_texture().get_image()
		var rect: Rect2i=PlayDisplay.fitted_rect(root.size)
		var valid := image.get_size()==root.size and frame.get_size()==rect.size and play_display.size==Vector2(root.size)
		valid=valid and image.get_region(rect).get_data()==frame.get_data()
		valid=valid and previous==state and previous_presentation==presentation and samples==count
		valid=valid and picture.texture.get_image().get_data()==original
		valid=valid and root.mode==target_mode
		if not fullscreen: valid=valid and root.size==Vector2i(item[0],item[1])
		var letterbox_clean := true
		for y in image.get_height():
			for x in image.get_width():
				if not rect.has_point(Vector2i(x,y)) and image.get_pixel(x,y).to_rgba32()!=Color.BLACK.to_rgba32(): letterbox_clean=false
		valid=valid and letterbox_clean
		if not valid: resize_errors.append("resize/fullscreen mismatch "+str(item))
		var name := "fullscreen" if fullscreen else "%dx%d-%d"%[item[0],item[1],resize_samples.size()]
		image.save_png(output.path_join("window-"+name+".png"))
		var restored_display:Dictionary=play_display.description()
		# Reuse this native size to exercise the source-proven Tactical reflow.
		# Its shader/chrome output is intentionally different from raw tandem.
		_choose_hud_style("tactical")
		await process_frame
		RenderingServer.force_draw(false);RenderingServer.force_sync()
		var wide:Rect2i=PlayDisplay.wide_fitted_rect(root.size)
		var tactical_checks:Dictionary={
			"proven_station":play_display._wide_station==1,
			"display_geometry":Rect2i(Vector2i(play_display.display.position),Vector2i(play_display.display.size))==wide,
			"chrome_geometry":play_display.tactical_chrome.position==Vector2(wide.position) and play_display.tactical_chrome.size==Vector2(wide.size) and play_display.tactical_chrome.frame_rect==Rect2i(Vector2i.ZERO,wide.size),
			"source_extent":tandem_viewport.size==Vector2i(wide.size.x,wide.size.x*3/4),
			"original_unchanged":previous==state and previous_presentation==presentation and samples==count and picture.texture.get_image().get_data()==original,
			"window_unchanged":root.mode==target_mode and (fullscreen or root.size==Vector2i(item[0],item[1]))}
		var tactical_valid:bool=tactical_checks.values().all(func(value):return value==true)
		if not tactical_valid:resize_errors.append("Tactical resize/fullscreen mismatch "+str(item)+": "+JSON.stringify(tactical_checks))
		root.get_texture().get_image().save_png(output.path_join("tactical-"+name+".png"))
		resize_samples.append({"requested":item,"mode":root.mode,"passed":valid and tactical_valid,"restored_passed":valid,"letterbox_clean":letterbox_clean,"restored_display":restored_display,"tactical_checks":tactical_checks,"display":play_display.description()})
		_choose_hud_style("restored")
	var file := FileAccess.open(output.path_join("resize-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":resize_samples,"errors":resize_errors,"guest_samples":count,"unchanged_guest_state":previous==state,"scope":"Six actual-window transitions: exact Restored4:3compositor pixels and source-proven Tactical16:9geometry at every size. Tactical final shader pixels are not compared against the unprocessed tandem texture. No guest step requests."},"  "))
	if not resize_errors.is_empty(): bridge.failure="; ".join(resize_errors)
	print("PC_PLAY_RESIZE: %d samples, %d errors"%[resize_samples.size(),resize_errors.size()])
	await super._capture()
