extends "res://scripts/pc_bridge_viewer.gd"
## Bounded real-menu acceptance. Select Effects 40% and Crew voices 70% in UI.
## The original is frozen only at this diagnostic capture boundary.
func _capture_deadline_msec() -> int: return 300000

func _capture() -> void:
	var start_samples := samples
	var source := picture.texture.get_image().get_data()
	var state := previous.duplicate(true)
	var presentation := previous_presentation.duplicate(true)
	audio_menu.config_path=output.path_join("audio-preferences.cfg")
	audio_menu.refresh()
	var wanted := {"master":100,"effects":40,"voice":70,"motors":100,"music":70}
	print("PC_AUDIO_MENU_READY: select Sound effects 40% and Crew voices 70%")
	var deadline := Time.get_ticks_msec()+240000
	while Time.get_ticks_msec()<deadline and (audio_menu.settings!=wanted or not audio_menu.open_menus.is_empty()):
		await process_frame
	var restored=preload("res://scripts/pc_audio_menu.gd").new()
	restored.config_path=audio_menu.config_path
	var loaded: bool=restored.load_settings()
	var checks := {"native_menu":audio_menu.is_native_menu(),"UI_choices_received":audio_menu.settings==wanted,
		"players_updated":pc_audio.mix==wanted,"persisted":loaded and restored.settings==wanted,
		"menu_closed":audio_menu.open_menus.is_empty(),"no_original_requests":samples==start_samples,
		"original_frame_unchanged":source==picture.texture.get_image().get_data(),
		"state_unchanged":previous==state,"presentation_unchanged":previous_presentation==presentation,
		"native_menu_uses_no_game_pixels":play_display.offset_top==0 and play_display.size==Vector2(root.size),
		"no_save_error":audio_menu.save_error.is_empty(),"audio_healthy":pc_audio.failure.is_empty()}
	restored.free()
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	root.get_texture().get_image().save_png(output.path_join("native-menu-closed.png"))
	# Also render the non-native fallback on this actual backend. This establishes
	# its layout, not Windows/Linux platform acceptance.
	# Construct a local menu in its startup mode rather than switching an
	# existing native menu (whose cached native minimum size can remain zero).
	var settings: Dictionary=audio_menu.settings.duplicate()
	root.remove_child(audio_menu)
	audio_menu.free()
	audio_menu=preload("res://scripts/pc_audio_menu.gd").new()
	audio_menu.prefer_global_menu=false
	audio_menu.settings=settings
	audio_menu.audio=pc_audio
	audio_menu.config_path=""
	root.add_child(audio_menu)
	audio_menu.resized.connect(_layout_audio_menu)
	await process_frame
	_layout_audio_menu()
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	root.get_texture().get_image().save_png(output.path_join("local-menu-fallback.png"))
	checks.fallback_outside_HUD=play_display.offset_top>=audio_menu.get_combined_minimum_size().y and play_display.offset_top>0
	checks.fallback_4_by_3=tandem_viewport.size.x*3==tandem_viewport.size.y*4
	checks.fallback_no_original_requests=samples==start_samples and picture.texture.get_image().get_data()==source
	FileAccess.open(output.path_join("menu-report.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"settings":audio_menu.settings,"scope":"Real UI interaction with native macOS menus; fallback rendered on macOS; original frame frozen at diagnostic boundary."},"  "))
	print("PC_AUDIO_MENU: "+JSON.stringify(checks))
	if not checks.values().all(func(value):return value==true): bridge.failure="native Audio menu acceptance failed"
	await super._capture()
