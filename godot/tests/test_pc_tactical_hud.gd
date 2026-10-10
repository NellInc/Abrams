extends SceneTree
const Display=preload("res://scripts/pc_play_display.gd")
const Menu=preload("res://scripts/pc_play_menu.gd")
var errors: Array[String]=[]
var checks:=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var display:=Display.new()
	root.add_child(display)
	display.size=Vector2i(640,480)
	var menu:=Menu.new()
	menu.config_path=""
	menu.quality_config_path=""
	root.add_child(menu)
	check(menu.hud_style=="restored" and display.hud_style=="restored","Restored defaults")
	check(not menu.choose_hud_style("unknown") and menu.hud_style=="restored","unknown HUD style rejected")
	check(menu.choose_hud_style("tactical") and menu.hud_style=="tactical","Tactical control accepted")
	var settings:=OS.get_temp_dir().path_join("abrams-tactical-hud-%d.cfg"%OS.get_process_id())
	DirAccess.remove_absolute(settings)
	menu.quality_config_path=settings
	check(menu.choose_hud_style("tactical") and FileAccess.file_exists(settings),"HUD preference saved")
	var loaded:=Menu.new()
	loaded.quality_config_path=settings
	check(loaded.load_quality_settings() and loaded.hud_style=="tactical","HUD preference restored")
	DirAccess.remove_absolute(settings)
	loaded.free()
	check(display.set_hud_style("tactical"),"Tactical renderer accepted")
	check(not display.set_hud_style("unknown") and display.hud_style=="tactical","renderer keeps state on unknown style")
	var mask:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	mask.fill(Color.WHITE)
	var packet: Dictionary={"ui_overlay":{"width":320,"height":200,
		"mask_png":Marshalls.raw_to_base64(mask.save_png_to_buffer())},
		"draw_pass":{"camera":{"clip":[32,13,287,109]}}}
	display.set_hud_frame(packet,{"name":"SIM"})
	check(display.display.material==display.tactical_material,"paired SIM mask enables Tactical")
	check(display.tactical_material.get_shader_parameter("camera_verified"),"camera aperture proven")
	check(not display.tactical_material.get_shader_parameter("panels_verified"),"unverified panel absent")
	display.set_hud_frame(packet,{"name":"START"})
	check(display.display.material==null,"non-SIM screen restores source")
	display.set_hud_frame(packet,{"name":"SIM"})
	check(display.display.material==display.tactical_material,"Tactical resumes on paired SIM frame")
	var wrong_size:=Image.create_empty(1,1,false,Image.FORMAT_L8)
	packet.ui_overlay.mask_png=Marshalls.raw_to_base64(wrong_size.save_png_to_buffer())
	display.set_hud_frame(packet,{"name":"SIM"})
	check(display.display.material==null,"malformed mask restores source immediately")
	packet.ui_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
	var plate:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	plate.fill(Color8(1,1,1))
	var plate_packet:=packet.duplicate(true)
	plate_packet.plate_overlay={"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(plate.save_png_to_buffer()),
		"plates":{"1":{"source":"GPS.BIN","source_sha256":preload("res://scripts/pc_tandem_frame.gd").GUNNER_SOURCE_SHA256}}}
	display.set_hud_frame(plate_packet,{"name":"SIM"})
	check(display.description().display_aspect=="16:9" and display._wide_gunner,"PC-only Gunner expands only with source-proven plate")
	check(display.tandem_viewport.size.x*3==display.tandem_viewport.size.y*4,"wide display keeps 4:3 source composition")
	plate.set_pixel(312,199,Color.BLACK)
	plate_packet.plate_overlay.mask_png=Marshalls.raw_to_base64(plate.save_png_to_buffer())
	display.set_hud_frame(plate_packet,{"name":"SIM"})
	check(display._wide_gunner,"live source border remains visible in the reflow")
	plate.set_pixel(0,0,Color.BLACK)
	plate_packet.plate_overlay.mask_png=Marshalls.raw_to_base64(plate.save_png_to_buffer())
	display.set_hud_frame(plate_packet,{"name":"SIM"})
	check(display.description().display_aspect=="4:3" and not display._wide_gunner,"unmapped live UI restores full layout")
	display.set_hud_frame(plate_packet,{"name":"START"})
	check(not display._wide_gunner,"program transition clears wide layout")
	check(display.set_hud_style("restored") and display.display.material==null,"Restored removes shader")
	menu.free()
	display.free()
	print("PC_TACTICAL_HUD: %d checks, %d errors"%[checks,errors.size()])
	for error in errors: printerr(error)
	quit(0 if errors.is_empty() else 1)
