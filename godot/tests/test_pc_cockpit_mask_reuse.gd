extends SceneTree
## Frozen pre-optimization predicates versus exact row-local reuse.
const Frame = preload("res://scripts/pc_tandem_frame.gd")
class Before extends "res://scripts/pc_tandem_frame.gd":
	func _set_art(presentation: Dictionary, ui: Image) -> void:
		_disable_art("material pilot disabled")
		if gunner_art_texture == null and cockpit_art_textures.is_empty() and status_art_texture==null: return
		gunner_art_reason = "no supported plate provenance"
		if not _art_palette_matches(presentation.get("palette_rgb")):
			gunner_art_reason = "palette differs from material study"
			return
		var overlay = presentation.get("plate_overlay")
		if not overlay is Dictionary or overlay.get("width") != 320 or overlay.get("height") != 200: return
		var plates = overlay.get("plates")
		if not plates is Dictionary: return
		var encoded = overlay.get("mask_png")
		if not encoded is String: return
		var mask := Image.new()
		if mask.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or mask.get_size() != Vector2i(320,200): return
		if mask.get_format() != Image.FORMAT_L8: return
		var tags := mask.get_data()
		var ui_bits := ui.get_data()
		var present: Dictionary
		if tags==_plate_tags and ui_bits==_plate_ui:
			present=_plate_ids
		else:
			present={}
			for at in tags.size():
				if tags[at]>8 or (tags[at]!=0 and ui_bits[at]!=255): return
				if tags[at]!=0: present[int(tags[at])]=true
			_plate_tags=tags
			_plate_ui=ui_bits
			_plate_ids=present
		var available := cockpit_art_textures.duplicate()
		if gunner_art_texture != null: available[1] = gunner_art_texture
		if status_art_texture != null: available[5] = status_art_texture
		for id in available:
			if not present.has(id): continue
			var source = plates.get(str(id))
			if not source is Dictionary or source.get("source") != COCKPIT_SOURCES[id][0] or source.get("source_sha256") != COCKPIT_SOURCES[id][1]:
				_disable_art("unsupported cockpit source fingerprint")
				return
			cockpit_art_ids.append(id)
		if cockpit_art_ids.is_empty():
			gunner_art_reason = "no surviving supported cockpit plate pixels"
			return
		for id in [2,3,4]:
			var donor = commander_status_atlas if id==2 and genesis_art_enabled else available.get(id)
			material.set_shader_parameter(["commander_art","cupola_art","driver_art"][id-2], donor)
		material.set_shader_parameter("station_art_enabled", Vector3(1 if 2 in cockpit_art_ids else 0, 1 if 3 in cockpit_art_ids else 0, 1 if 4 in cockpit_art_ids else 0))
		material.set_shader_parameter("gunner_art", gunner_art_texture)
		material.set_shader_parameter("plate_mask", ImageTexture.create_from_image(mask))
		_current_plate_mask = mask
		gunner_art_enabled = 1 in cockpit_art_ids
		material.set_shader_parameter("gunner_art_enabled", gunner_art_enabled)
		material.set_shader_parameter("status_art_enabled",5 in cockpit_art_ids)
		if 5 in cockpit_art_ids:
			status_diagram_verified = true
			for y in range(37,100):
				for x in range(123,305):
					if tags[y*320+x]!=5:
						status_diagram_verified = false
						break
				if not status_diagram_verified: break
		material.set_shader_parameter("status_diagram_verified",status_diagram_verified)
		gunner_art_reason = "" if gunner_art_enabled else "no surviving gunner plate pixels"

	func _set_driver_assembly(presentation: Dictionary, ui: Image) -> void:
		if not cockpit_art_textures.has(4) or not _art_palette_matches(presentation.get("palette_rgb")): return
		var overlay = presentation.get("driver_overlay")
		if not overlay is Dictionary or overlay.get("width") != 320 or overlay.get("height") != 200: return
		if overlay.get("source") != "SIM.EXE:5ba1..5da3" or overlay.get("source_sha256") != "9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099": return
		if not overlay.get("mask_png") is String: return
		var mask := Image.new()
		if mask.load_png_from_buffer(Marshalls.base64_to_raw(overlay.mask_png)) != OK or mask.get_size() != Vector2i(320,200) or mask.get_format() != Image.FORMAT_RGB8: return
		var values := mask.get_data()
		var ui_bits := ui.get_data()
		var any := _driver_nonempty
		if values!=_driver_bits or ui_bits!=_driver_ui:
			any=false
			for at in 64000:
				var i := at*3
				if values[i+2] not in [0,255] or values[i+1] > 127: return
				if values[i+2] == 0:
					if values[i] != 0 or values[i+1] != 0: return
				elif ui_bits[at] != 255: return
				else: any = true
			_driver_bits=values
			_driver_ui=ui_bits
			_driver_nonempty=any
		if not any: return
		material.set_shader_parameter("driver_art", cockpit_art_textures[4])
		material.set_shader_parameter("driver_assembly_mask", ImageTexture.create_from_image(mask))
		material.set_shader_parameter("driver_assembly_enabled", true)
		_current_driver_mask=mask
		driver_assembly_enabled = true

class CommanderBefore extends "res://scripts/pc_commander_trim.gd":
	func set_frame(source: Image, ui: Image, tags: Image, camera: Rect2i, world: Texture2D = null) -> void:
		clear()
		if camera!=CAMERA or world==null: return
		for im in [source,ui,tags]:
			if im==null or im.get_size()!=Vector2i(320,200): return
		if ui.get_format()!=Image.FORMAT_L8 or tags.get_format()!=Image.FORMAT_L8: return
		var bits := tags.get_data()
		var owners := ui.get_data()
		if bits!=_verified_tags or owners!=_verified_ui:
			# A mixed station transition cannot inherit an earlier settled housing.
			for i in bits.size():
				if bits[i]!=0 and (bits[i]!=2 or owners[i]!=255): return
			# Demand the complete outer housing anchors, not an isolated plate pixel.
			for p in [Vector2i(187,63),Vector2i(307,63),Vector2i(187,192),Vector2i(307,192)]:
				if bits[p.y*320+p.x]!=2: return
			_verified_tags = bits
			_verified_ui = owners
		material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(ui))
		material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(tags))
		active = true
		_layout()
		show()


var errors: Array[String] = []
var checks := 0
var before = Before.new()
var after = Frame.new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(message)
func state(frame) -> Array:
	return [frame.cockpit_art_ids,frame.gunner_art_enabled,frame.gunner_art_reason,frame.driver_assembly_enabled,frame.status_diagram_verified]
func compare(p: Dictionary, ui: Image, label: String) -> void:
	var original := var_to_bytes(p)
	for frame in [before,after]:
		frame._set_art(p,ui)
		frame._set_driver_assembly(p,ui)
	check(state(before)==state(after),label+": identical ownership decisions")
	check(var_to_bytes(p)==original,label+": immutable packet")
func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var path := directory.path_join("artifacts/pc-live-type-cockpit-02/report.json")
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var donor := Image.create_empty(640,400,false,Image.FORMAT_RGB8)
	for frame in [before,after]:
		root.add_child(frame)
		frame.set_gunner_art(donor)
		for id in [2,3,4]:frame.set_cockpit_art(id,donor)
		frame.status_art_texture=ImageTexture.create_from_image(donor)
	for e in report.ui_presentations:
		var p: Dictionary=report.presentations[int(e.frame_index)].duplicate(true)
		var ui := Image.load_from_file(path.get_base_dir().path_join(e.mask))
		var tags := Image.load_from_file(path.get_base_dir().path_join(e.plate_mask))
		p.plate_overlay.mask_png=Marshalls.raw_to_base64(tags.save_png_to_buffer())
		compare(p,ui,str(e.stage))
		compare(p,ui,str(e.stage)+" repeat")
		for y in range(0,200,13):
			var changed := tags.duplicate()
			changed.set_pixel(0,y,Color(9.0/255.0,0,0))
			var bad := p.duplicate(true)
			bad.plate_overlay.mask_png=Marshalls.raw_to_base64(changed.save_png_to_buffer())
			compare(bad,ui,"bad plate row "+str(y))
			compare(p,ui,"plate recovery")
		var unowned := Image.create_empty(320,200,false,Image.FORMAT_L8)
		compare(p,unowned,"lost all UI ownership")
		compare(p,ui,"UI ownership restored")
	var p := {"palette_rgb":Frame.ART_PALETTE,"driver_overlay":{"width":320,"height":200,"source":"SIM.EXE:5ba1..5da3","source_sha256":"9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"}}
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8);ui.fill(Color.WHITE)
	for y in 200:
		var mask := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
		for color in [Color(1,127.0/255.0,1),Color(1,128.0/255.0,1),Color(0,0,0.5),Color(1,0,0),Color(0,1.0/255.0,0),Color.BLACK]:
			mask.set_pixel(y%320,y,color)
			p.driver_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
			compare(p,ui,"driver row component "+str(y))
		mask.set_pixel(y%320,y,Color(1,0,1))
		p.driver_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
		var missing := ui.duplicate();missing.set_pixel(y%320,y,Color.BLACK)
		compare(p,missing,"driver claim missing")
		compare(p,ui,"driver claim restored")
	var trims := [CommanderBefore.new(),preload("res://scripts/pc_commander_trim.gd").new()]
	for trim in trims:root.add_child(trim)
	var tags := Image.create_empty(320,200,false,Image.FORMAT_L8);tags.fill(Color(2.0/255.0,0,0))
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	var world := ImageTexture.create_from_image(source)
	for y in 200:
		for corruption in ["valid","mixed","unowned","valid"]:
			var current_tags := tags.duplicate()
			var current_ui := ui.duplicate()
			if corruption=="mixed":current_tags.set_pixel(100,y,Color(3.0/255.0,0,0))
			if corruption=="unowned":current_ui.set_pixel(100,y,Color.BLACK)
			for trim in trims:trim.set_frame(source,current_ui,current_tags,trim.CAMERA,world)
			check(trims[0].active==trims[1].active,"commander row proof "+str(y)+corruption)
	for error in errors:printerr("FAIL: "+error)
	print("PC_COCKPIT_MASK_REUSE: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
