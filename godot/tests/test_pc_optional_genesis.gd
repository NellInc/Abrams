extends "res://scripts/pc_bridge_viewer.gd"
## Local files deliberately remain present: PC-only must skip their loaders.
const Menu = preload("res://scripts/pc_play_menu.gd")
var errors: Array[String] = []
var checks := 0

class MusicProbe extends Node:
	var context_queries := 0
	var applied: Array = []
	func music_context_for_frame(_source: Image, _program: Dictionary, _presentation: Dictionary) -> String:
		context_queries+=1
		return "menu"
	func apply_music_context(context: String, enabled: bool) -> void:
		applied.append([context,enabled])

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)

func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool: return false

func run() -> void:
	trace_mode=true
	play_mode=true
	_configure_art_requests([])
	check(not pc_only and pc_presentation_requested and cockpit_art_requested and gunner_art_requested and genesis_colours_requested,"default checkout retains all-art requests")
	check(graphics_launch_error(["--graphics","genesis"]).is_empty(),"default still accepts Genesis")
	check(not graphics_launch_error(["--pc-only","--graphics","genesis"]).is_empty(),"explicit PC-only Genesis rejected")
	check(not graphics_launch_error(["--graphics"]).is_empty(),"missing graphics argument rejected")
	check(not graphics_launch_error(["--graphics","unknown"]).is_empty(),"unknown graphics mode rejected")
	for mode in ["ega","upscaled","modern"]:
		check(graphics_launch_error(["--pc-only","--graphics",mode]).is_empty(),"PC-only accepts "+mode)
	_configure_art_requests(["--pc-only","--cockpit-art","--gunner-art","--genesis-colours"])
	check(pc_only and pc_presentation_requested,"PC-only retains independent PC presentation")
	check(not cockpit_art_requested and not gunner_art_requested and not genesis_colours_requested,"donor flags cannot override PC-only")
	draw_view=DrawPass.new()
	tandem_frame=TandemFrame.new()
	root.add_child(draw_view)
	root.add_child(tandem_frame)
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	_load_world_presentation(directory,["--pc-only"])
	_load_cockpit_presentation(directory)
	check(tandem_frame.modern_available and draw_view.modern_assets.ready,"Modern resources load independently of Genesis")
	check(genesis_style.palette.is_empty(),"Genesis palette never loaded")
	check(not tandem_frame.genesis_art_enabled and tandem_frame.gunner_art_texture==null and tandem_frame.cockpit_art_textures.is_empty() and tandem_frame.status_art_texture==null,"Genesis cockpits never loaded")
	check(not tandem_frame.native_graphics.loaded and tandem_frame.native_graphics.load_count==0,"native donor loader never called")
	check(tandem_frame.frontend_art.catalog.is_empty() and tandem_frame.frontend_art.portraits.is_empty(),"donor frontend never loaded")
	check(draw_view.effect_art==null,"Genesis effects never loaded")
	check(draw_view.terrain_style!=null and draw_view.terrain_style.textures.size()==2,"authored PC field and road retained")
	check(draw_view.terrain_style.hill_texture==null,"Genesis hill never loaded")
	check(tandem_frame.typography.fonts.size()==4,"PC typography remains available")
	check(not tandem_frame.set_graphics_mode("genesis"),"compositor refuses unloaded Genesis")
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color.CYAN)
	var source_bytes := source.get_data()
	var presentation := {"draw_pass":{"camera":{"clip":[32,13,287,109]}},"ui_overlay":{"width":320,"height":200}}
	var mask := Image.create_empty(320,200,false,Image.FORMAT_L8)
	mask.fill(Color.BLACK)
	presentation.ui_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
	var original_presentation := presentation.duplicate(true)
	var world := ImageTexture.create_from_image(source)
	check(tandem_frame.set_frame(source,presentation,world),"PC-only high-resolution world composition stays available")
	check(tandem_frame.set_graphics_mode("ega") and tandem_frame.texture.get_image().get_data()==source_bytes,"EGA retains exact source framebuffer")
	check(tandem_frame.set_graphics_mode("upscaled") and tandem_frame.world_enabled,"Upscaled restores PC world")
	audio_menu=Menu.new()
	audio_menu.config_path=""
	root.add_child(audio_menu)
	_choose_graphics("modern")
	check(tandem_frame.graphics_mode=="modern" and draw_view.modern_enabled,"PC-only Modern enables the refined world")
	_choose_graphics("upscaled")
	check(tandem_frame.graphics_mode=="upscaled" and not draw_view.modern_enabled,"PC-only can return to Upscaled immediately")
	audio_menu.free()
	audio_menu=null
	check(source.get_data()==source_bytes and presentation==original_presentation,"graphics choices leave source pixels and packet unchanged")
	check(bridge.process.is_empty() and bridge.next_id==0 and fps==59.9227 and fast_forward==1,"presentation setup never advances source or changes timing")
	pc_audio=MusicProbe.new()
	root.add_child(pc_audio)
	_apply_frontend_music(source,{"name":"START"},{})
	check(pc_audio.context_queries==0 and pc_audio.applied==[["",false]],"PC-only skips donor music discovery and playback")
	check(audio_requested(true,["--pc-only"]),"generated source-event audio remains enabled")
	pc_only=false
	_apply_frontend_music(source,{"name":"START"},{})
	check(pc_audio.context_queries==1 and pc_audio.applied[-1]==["menu",true],"default music behavior unchanged")
	pc_audio=null
	for available in [true,false]:
		var menu := Menu.new()
		menu.config_path=""
		menu.genesis_available=available
		root.add_child(menu)
		check(menu.graphics_popup.is_item_disabled(1)==not available,"Genesis availability visible in menu")
		check(menu.graphics_popup.is_item_disabled(3),"Modern remains disabled")
		check(menu.choose_graphics("genesis")==available,"Genesis direct selection honors availability")
		menu.choose_graphics("upscaled")
		var expected := ["ega","genesis","upscaled"] if available else ["ega","upscaled","ega"]
		for mode in expected:
			var event := InputEventKey.new()
			event.keycode=KEY_G;event.pressed=true
			event.meta_pressed=menu.shortcut_is_macos
			event.ctrl_pressed=not menu.shortcut_is_macos
			event.alt_pressed=not menu.shortcut_is_macos
			check(menu.handle_shortcut(event) and menu.graphics_mode==mode,"graphics shortcut cycles only available modes: "+mode)
		menu.free()
	# The actual first-run status must have a width before any guest frame arrives.
	_build_play_ui()
	for extent in [Vector2i(640,480),Vector2i(1280,960)]:
		root.size=extent
		await process_frame
		check(status.size.x>=float(extent.x-48),"startup text spans the available window")
		check(status.get_line_count()==1,"startup text stays on one readable line")
	for error in errors: printerr("FAIL: "+error)
	print("PC_OPTIONAL_GENESIS: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
