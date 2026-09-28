extends "res://scripts/pc_bridge_viewer.gd"
## Actual-window acceptance using the production host/viewer, without guest
## requests while changing display size or entering/leaving native fullscreen.
var resize_errors: Array[String] = []
var resize_samples: Array = []

func _settled() -> void:
	var prior := root.size
	var stable := 0
	var deadline := Time.get_ticks_msec()+6000
	while Time.get_ticks_msec()<deadline and stable<20:
		await process_frame
		if root.size==prior: stable+=1
		else: stable=0;prior=root.size
	if stable<20: resize_errors.append("window never settled")

func _capture() -> void:
	if not play_mode:
		bridge.failure="Resize acceptance requires --play"
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
			await _settled()
		if not fullscreen: root.size=Vector2i(item[0],item[1])
		await _settled()
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
		resize_samples.append({"requested":item,"mode":root.mode,"passed":valid,"letterbox_clean":letterbox_clean,"display":play_display.description()})
	var file := FileAccess.open(output.path_join("resize-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":resize_samples,"errors":resize_errors,"guest_samples":count,"unchanged_guest_state":previous==state,"scope":"six live window/display transitions at one frozen original frame; no guest step requests"},"  "))
	if not resize_errors.is_empty(): bridge.failure="; ".join(resize_errors)
	print("PC_PLAY_RESIZE: %d samples, %d errors"%[resize_samples.size(),resize_errors.size()])
	await super._capture()
