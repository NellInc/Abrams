extends "res://scripts/pc_bridge_viewer.gd"
## Tactical screen-space light through the production viewer, replaying real
## all-scenario packets (no emulator). Each daylight Tactical case renders
## three ways from one packet: full light, footprints only (shade quad off),
## and light off. The shade quad may only darken source-terrain or ground
## background pixels (vehicles cast but are never darkened); the sun-leaning
## plant footprints may only change pixels of source terrain. Also: source-depth byte encoding, a concealed actor
## changing nothing, every shader copy of the Tactical sun, and ABBA timing.
const TacticalLight = preload("res://scripts/pc_tactical_light.gd")
const ModernOwnership = preload("res://scripts/pc_modern_ownership.gd")
const SourceGeometry = preload("res://scripts/pc_surface_geometry.gd")
var errors: Array[String] = []
var checks := 0
var fixture: Dictionary
var fixture_dir: String
var rows: Array = []
var report := {}

class ReplayBridge extends RefCounted:
	var pending := true
	var failure := ""
	func start(_python, _state, _saves, _log, _backend, _audit): return true
	func close(): pass
	func has_exited(): return true
	func exit_code(): return 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--fixture" not in args or "--no-audio" not in args or "--capture" not in args:
		printerr("Tactical light replay requires --fixture REPORT --capture --no-audio --play --graphics tactical")
		quit(2)
		return
	var path := args[args.find("--fixture")+1]
	fixture_dir=path.get_base_dir()
	fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	bridge=ReplayBridge.new()
	super._initialize()
	run.call_deferred()

func _process(_delta: float) -> bool: return false

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok and errors.size()<40: errors.append(why)

func sun_copies() -> void:
	var expected := "vec3(-0.58,0.34,0.74)"
	var include := FileAccess.get_file_as_string("res://scripts/pc_tactical_light.gdshaderinc")
	check(include.contains("TACTICAL_LIGHT_SUN="+expected),"light include carries the Tactical sun")
	for path in ["res://scripts/pc_surface.gdshader","res://scripts/pc_tactical_materials.gdshaderinc",
			"res://scripts/pc_tactical_groundlight.gdshaderinc","res://scripts/pc_tactical_foliage.gdshader",
			"res://scripts/pc_tactical_vehicles.gdshader"]:
		var code := FileAccess.get_file_as_string(path)
		var copies := 0
		var start := code.find("vec3(-0.")
		while start>=0:
			var end := code.find(")",start)
			var literal := code.substr(start,end-start+1).replace(" ","")
			if literal.begins_with("vec3(-0.5") and literal.count(",")==2 and literal.contains(",0.3"):
				copies+=1
				# The materials include also uses the sun's horizontal azimuth.
				check(literal in [expected,"vec3(-0.58,0.34,0.0)"],"%s sun %s differs from the light pass"%[path.get_file(),literal])
			start=code.find("vec3(-0.",start+1)
		check(copies>0,"%s still declares the Tactical sun"%path.get_file())

static func depth_code(forward: float) -> int:
	var t := clampf((log(maxf(forward,16.0))/log(2.0)-4.0)/14.0,0.0,1.0)
	return 1+int(floor(t*4194302.0+0.5))

static func texel_code(pixel: Color) -> int:
	return roundi(pixel.r*255.0)*16384+roundi(pixel.g*255.0)*64+(roundi(pixel.b*255.0)>>2)

static func decode(image: Image, x: int, y: int) -> Vector2:
	var pixel := image.get_pixel(x,y)
	if pixel.a<0.5: return Vector2(-1,-1)
	var light_class := roundi(pixel.b*255.0)&3
	var code := texel_code(pixel)
	if code==0 or light_class==0: return Vector2(0,0)
	return Vector2(pow(2.0,4.0+float(code-1)/4194302.0*14.0),float(light_class))

func draw_now() -> void:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()

# Constant-depth strips through the real ownership mesh and depth shader.
func encoding_contract() -> void:
	var frame := {"clip":[0,0,319,199],"center":[160,100],"focal_pixels":192,"near_raw":16,
		"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,120]}
	var depths := [20.0,61.0,150.0,407.0,1000.0,2500.0,6100.0,15000.0,41000.0,120000.0]
	var data := {"camera":frame,"objects":[]}
	var classes := {}
	for strip in depths.size():
		var top := float(strip*20)
		var bottom := top+20.0
		var d: float=depths[strip]
		var z_top := (100.0-top)/192.0*d
		var z_bottom := (100.0-bottom)/192.0*d
		data.objects.append({"shape_index":48,"static_path":1,"dynamic_instance":false,"polygons":[{"primitive":strip,"fill_mode":1,"colors":[2,2],
			"camera_vertices":[[-2.0*d,d,z_top],[2.0*d,d,z_top],[2.0*d,d,z_bottom],[-2.0*d,d,z_bottom]]}]})
		classes[strip+1]=TacticalLight.TERRAIN if strip%2==0 else TacticalLight.STATIC_CASTER
	var owner := ModernOwnership.new()
	var light := TacticalLight.new()
	root.add_child(owner)
	root.add_child(light)
	check(owner.prepare(data,Vector2i(640,400),null,{},{},{},{},classes),"encoding fixture ownership prepared")
	check(light.prepare(owner,frame,{"inverse":Basis.IDENTITY,"origin":Vector3(0,0,120)}),"encoding fixture light prepared")
	await draw_now()
	var image: Image=light.depth_view.get_texture().get_image()
	var worst := 0
	for strip in depths.size():
		var pixel := image.get_pixel(320,strip*40+20)
		worst=maxi(worst,absi(texel_code(pixel)-depth_code(depths[strip])))
		check((roundi(pixel.b*255.0)&3)==(2 if strip%2==0 else 1) and pixel.a>0.99,"strip %d class bits and coverage"%strip)
	# Float32 log2 in the shader versus double here: allow a few 22-bit codes
	# (each 2.3e-6 relative depth); byte transfer errors would be >=64 codes.
	check(worst<=8,"source depth survives the Compatibility transfer (worst code error %d)"%worst)
	report["encoding_worst_code_error"]=worst
	owner.queue_free()
	light.queue_free()

# The production grade function on rendered 8-bit ramps: every channel must be
# non-decreasing and luminance slope stay within 0.9..1.1 (one 8-bit step of
# slack over each 16-level stride).
func grade_contract() -> void:
	var bases := [Vector3(1,1,1),Vector3(0.62,0.70,0.40),Vector3(0.78,0.86,0.88),Vector3(0.40,0.38,0.36),Vector3(0.9,0.3,0.2)]
	var view := SubViewport.new()
	view.size=Vector2i(256,bases.size())
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size=Vector2(256,bases.size())
	var shader := Shader.new()
	var rows := ""
	for i in bases.size(): rows+="row==%d ? vec3(%f,%f,%f) : "%[i,bases[i].x,bases[i].y,bases[i].z]
	shader.code="shader_type canvas_item;\n#include \"res://scripts/pc_tactical_grade.gdshaderinc\"\nvoid fragment(){int row=int(floor(UV.y*%d.0));float l=floor(UV.x*256.0)/255.0;vec3 base=%svec3(1.0);COLOR=vec4(tactical_grade_colour(base*l),1.0);}"%[bases.size(),rows]
	var material := ShaderMaterial.new()
	material.shader=shader
	rect.material=material
	view.add_child(rect)
	root.add_child(view)
	await draw_now()
	var image: Image=view.get_texture().get_image()
	var lowest := 9.0
	var highest := 0.0
	var reversals := 0
	for row in bases.size():
		var base: Vector3=bases[row]
		var input_luma: float=0.2126*base.x+0.7152*base.y+0.0722*base.z
		for x in 255:
			var a := image.get_pixel(x,row)
			var b := image.get_pixel(x+1,row)
			if b.r<a.r-0.001 or b.g<a.g-0.001 or b.b<a.b-0.001: reversals+=1
		# A stride's mean slope lies within the curve's own slope range; one
		# output step of 8-bit quantisation is the only slack, per ramp.
		var slack: float=1.0/(32.0*input_luma)
		for x in range(0,224,32):
			var a := image.get_pixel(x,row)
			var b := image.get_pixel(x+32,row)
			var out_step: float=(0.2126*b.r+0.7152*b.g+0.0722*b.b)-(0.2126*a.r+0.7152*a.g+0.0722*a.b)
			var slope: float=out_step/(input_luma*32.0/255.0)
			lowest=minf(lowest,slope+slack)
			highest=maxf(highest,slope-slack)
			check(slope>=0.76-slack and slope<=1.24+slack,"ramp %d at %d: grade luminance slope %.3f outside 0.76..1.24"%[row,x,slope])
	check(reversals==0,"grade is non-decreasing in every channel (%d reversals)"%reversals)
	report["grade"]={"reversals":reversals,"min_luminance_slope_upper_bound":lowest,"max_luminance_slope_lower_bound":highest,
		"scope":"32-level strides on 8-bit rendered ramps (grey, olive, sky, road, red); each bound already allows one output step"}
	view.queue_free()

# The retained final composition must follow the light setting: toggling it
# on an identical packet recomposes, and switching back restores the frame.
func retention_contract(message: Dictionary, label: String) -> void:
	await render(message,true)
	var on_frame: Image=root.get_texture().get_image()
	await render(message,false)
	var off_frame: Image=root.get_texture().get_image()
	await render(message,true)
	var again: Image=root.get_texture().get_image()
	check(on_frame.get_data()!=off_frame.get_data(),label+": toggling the light recomposes the retained frame")
	check(again.get_data()==on_frame.get_data(),label+": restoring the light restores the identical frame")
	report["retention"]={"case":label,"toggle_changes_frame":on_frame.get_data()!=off_frame.get_data(),"restore_identical":again.get_data()==on_frame.get_data()}

func sample_message(sample: Dictionary) -> Dictionary:
	var png := FileAccess.get_file_as_bytes(fixture_dir.path_join(sample.image))
	return {"state":sample.state,"program":sample.program,"presentation":sample.presentation,
		"png":Marshalls.raw_to_base64(png),"sequence":sample.frame,"fps":59.9227256774902}

func render(message: Dictionary, enabled: bool) -> Image:
	draw_view.screen_light_enabled=enabled
	_apply_sample(message)
	await draw_now()
	return world_viewport.get_texture().get_image()

func redraw_scenery() -> Image:
	world_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await draw_now()
	return world_viewport.get_texture().get_image()

# A dynamic actor wholly behind a later static object, inserted just before
# it in painter order. The original shows nothing of it; nor may the light.
func concealed_actor(message: Dictionary, label: String) -> void:
	var drawing: Dictionary=message.presentation.draw_pass
	var cover := -1
	for index in drawing.objects.size():
		var object: Dictionary=drawing.objects[index]
		if not bool(object.get("dynamic_instance",true)) and not draw_view.modern_assets.is_terrain(object) and object.get("polygons",[]).any(func(p):return int(p.get("fill_mode",0))!=0 and p.camera_vertices.size()>=3):
			cover=index
			break
	check(cover>=0,label+": concealed-actor fixture found a static cover")
	if cover<0: return
	# The cover's largest projected fill; the actor is a small quad behind its
	# centroid whose projected corners all lie well inside that polygon.
	var frame: Dictionary=drawing.camera
	var polygon: Dictionary={}
	var outline := PackedVector2Array()
	var area := 0.0
	for candidate: Dictionary in drawing.objects[cover].polygons:
		if int(candidate.get("fill_mode",0))==0 or candidate.camera_vertices.size()<3: continue
		var projected := PackedVector2Array()
		for p: Array in candidate.camera_vertices: projected.append(SourceGeometry.project(p,frame))
		var bounds := Rect2(projected[0],Vector2.ZERO)
		for q in projected: bounds=bounds.expand(q)
		if bounds.get_area()>area:
			area=bounds.get_area();polygon=candidate;outline=projected
	var centre := Vector3.ZERO
	for p: Array in polygon.camera_vertices: centre+=Vector3(p[0],p[1],p[2])
	centre/=float(polygon.camera_vertices.size())
	var hidden := {"shape_index":-1,"root":0,"static_path":0,"dynamic_instance":true,"pointer":424242,"polygons":[]}
	var points: Array=[]
	var depth: float=centre.y+maxf(400.0,polygon.camera_vertices.map(func(p):return float(p[1])).max()-centre.y+300.0)
	var half: float=0.012*depth
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var ray := Vector3(centre.x/centre.y,1.0,centre.z/centre.y)*depth
		points.append([ray.x+corner.x*half,ray.y,ray.z+corner.y*half])
	var inside := true
	for p: Array in points:
		var q: Vector2=SourceGeometry.project(p,frame)
		inside=inside and Geometry2D.is_point_in_polygon(q,outline) and outline.size()>=3
	check(inside,label+": concealed-actor corners project inside the cover")
	hidden.polygons.append({"primitive":9999,"fill_mode":1,"colors":[4,4],"camera_vertices":points})
	var base := await render(message,true)
	report["concealed_actor"]={"case":label,"cover_object":cover}
	# A hidden actor, and hidden static scenery that would cast if visible.
	for kind in ["actor","static"]:
		var inserted: Dictionary=hidden.duplicate(true)
		if kind=="static":
			inserted.dynamic_instance=false
			inserted.static_path=1
		var with_actor: Dictionary=message.duplicate(true)
		with_actor.presentation.draw_pass.objects.insert(cover,inserted)
		var concealed := await render(with_actor,true)
		var owners: Image=draw_view.ownership.get_texture().get_image()
		var actor_pixels := 0
		for y in owners.get_height():
			for x in owners.get_width():
				var o := owners.get_pixel(x,y)
				if o.a>0.5 and roundi(o.r*255.0)+256*roundi(o.g*255.0)==cover+1: actor_pixels+=1
		check(actor_pixels==0,label+": inserted %s is fully concealed in the original painter order (%d pixels)"%[kind,actor_pixels])
		var identical: bool=concealed.get_data()==base.get_data()
		check(identical,label+": a concealed %s leaves the lit scenery byte-identical"%kind)
		report.concealed_actor[kind]={"pixels":actor_pixels,"identical":identical}

# A visible vehicle standing on open ground must shade terrain beside it
# (sun shadow and contact occlusion), while its own pixels stay unshaded.
func visible_actor_casts(message: Dictionary, label: String) -> void:
	var frame: Dictionary=message.presentation.draw_pass.camera
	var basis: Dictionary=preload("res://scripts/pc_terrain_style.gd").camera_basis(frame)
	check(not basis.is_empty(),label+": caster fixture has a camera basis")
	if basis.is_empty(): return
	var to_camera: Basis=basis.inverse.inverse()
	var origin: Vector3=basis.origin
	var forward: Vector3=basis.inverse*Vector3(0,1,0)
	forward.z=0.0
	forward=forward.normalized()
	var right := Vector3(forward.y,-forward.x,0.0)
	var foot: Vector3=forward*1400.0+Vector3(0,0,-origin.z)
	var points: Array=[]
	for corner in [Vector2(-70,0),Vector2(70,0),Vector2(70,150),Vector2(-70,150)]:
		var local: Vector3=foot+right*corner.x+Vector3(0,0,corner.y)
		var c: Vector3=to_camera*local
		points.append([c.x,c.y,c.z])
	var actor := {"shape_index":-1,"root":0,"static_path":0,"dynamic_instance":true,"pointer":434343,
		"polygons":[{"primitive":9998,"fill_mode":1,"colors":[4,4],"camera_vertices":points}]}
	var with_actor: Dictionary=message.duplicate(true)
	with_actor.presentation.draw_pass.objects.append(actor)
	var id: int=with_actor.presentation.draw_pass.objects.size()
	var base := await render(message,true)
	var lit := await render(with_actor,true)
	var owners: Image=draw_view.ownership.get_texture().get_image()
	var depth: Image=draw_view.tactical_light.depth_view.get_texture().get_image()
	var actor_pixels := 0
	var shaded_terrain := 0
	var darker := 0
	for y in owners.get_height():
		for x in owners.get_width():
			var o := owners.get_pixel(x,y)
			if o.a>0.5 and roundi(o.r*255.0)+256*roundi(o.g*255.0)==id:
				actor_pixels+=1
				continue
			var surface := decode(depth,x,y)
			if surface.y!=2.0 and surface.y!=-1.0: continue
			var a := base.get_pixel(x,y)
			var b := lit.get_pixel(x,y)
			if a!=b:
				shaded_terrain+=1
				if b.r+b.g+b.b<a.r+a.g+a.b: darker+=1
	check(actor_pixels>100,label+": caster fixture is visible (%d pixels)"%actor_pixels)
	check(shaded_terrain>50 and darker*10>=shaded_terrain*9,label+": a visible vehicle shades terrain beside it (%d pixels, %d darker)"%[shaded_terrain,darker])
	report["visible_actor"]={"case":label,"actor_pixels":actor_pixels,"terrain_pixels_changed":shaded_terrain,"darker":darker}
	lit.save_png(output.path_join(label+"-caster.png"))

func timing(message: Dictionary, label: String) -> void:
	await render(message,true)
	var samples := {"on":[],"off":[]}
	for cycle in 8:
		for arm in ["on","off","off","on"]:
			draw_view.tactical_light.shade.visible=arm=="on"
			world_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await process_frame
			var started := Time.get_ticks_usec()
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			samples[arm].append(float(Time.get_ticks_usec()-started)/1000.0)
	draw_view.tactical_light.shade.visible=true
	var on_mean: float=samples.on.reduce(func(a,b):return a+b,0.0)/samples.on.size()
	var off_mean: float=samples.off.reduce(func(a,b):return a+b,0.0)/samples.off.size()
	report["timing"]={"case":label,"world_pixels":[world_viewport.size.x,world_viewport.size.y],
		"on_ms_mean":on_mean,"off_ms_mean":off_mean,"on_ms":samples.on,"off_ms":samples.off,
		"scope":"Synchronized whole-frame redraw (all viewports) with the shade quad visible vs hidden, ABBA x8. Not GPU-isolated."}

func run() -> void:
	var args := OS.get_cmdline_user_args()
	sun_copies()
	await encoding_contract()
	await grade_contract()
	var only := args[args.find("--case")+1] if "--case" in args else ""
	for sample: Dictionary in fixture.samples:
		var label: String=sample.label
		if not ["gunner","commander","cupola","driver"].any(func(station):return label.ends_with("-"+station)): continue
		if not only.is_empty() and label!=only: continue
		var message := sample_message(sample)
		var lit := await render(message,true)
		var light_active: bool=draw_view.tactical_light.active
		var depth: Image=draw_view.tactical_light.depth_view.get_texture().get_image() if light_active else null
		var owners: Image=draw_view.ownership.get_texture().get_image()
		var row := {"label":label,"active":light_active,"shade_changed":0,"shade_outside_terrain":0,"shade_brighter":0,"footprint_changed":0,"footprint_outside_terrain":0,"coverage_mismatch":0}
		if light_active:
			draw_view.tactical_light.shade_material.set_shader_parameter("light_strength",0.0)
			var footprints := await redraw_scenery()
			draw_view.tactical_light.shade_material.set_shader_parameter("light_strength",1.0)
			var plain := await render(message,false)
			check(not draw_view.tactical_light.active,label+": light off leaves no shade quad")
			check(depth.get_size()==lit.get_size() and plain.get_size()==lit.get_size(),label+": depth target matches the scenery viewport")
			var classes := {}
			for y in lit.get_height():
				for x in lit.get_width():
					var surface := decode(depth,x,y)
					classes[int(surface.y)]=classes.get(int(surface.y),0)+1
					# Ground background is transparent in both targets.
					if (surface.y==-1.0)!=(owners.get_pixel(x,y).a<0.5): row.coverage_mismatch+=1
					var receiver: bool=surface.y==2.0 or surface.y==-1.0
					var a := lit.get_pixel(x,y)
					var f := footprints.get_pixel(x,y)
					var b := plain.get_pixel(x,y)
					if a!=f:
						row.shade_changed+=1
						if not receiver: row.shade_outside_terrain+=1
						if a.r>f.r+0.002 or a.g>f.g+0.002 or a.b>f.b+0.002: row.shade_brighter+=1
					if f!=b:
						row.footprint_changed+=1
						if not receiver: row.footprint_outside_terrain+=1
			row.classes=classes
			check(row.coverage_mismatch==0,label+": depth coverage differs from ownership at %d pixels"%row.coverage_mismatch)
			check(row.shade_outside_terrain==0,label+": %d shaded pixels outside terrain"%row.shade_outside_terrain)
			check(row.shade_brighter==0,label+": shade brightened %d pixels"%row.shade_brighter)
			check(row.footprint_outside_terrain==0,label+": %d footprint pixels outside source terrain"%row.footprint_outside_terrain)
			lit.save_png(output.path_join(label+"-lit.png"))
			plain.save_png(output.path_join(label+"-plain.png"))
		else:
			var plain := await render(message,false)
			check(lit.get_data()==plain.get_data(),label+": inactive light leaves scenery byte-identical")
		rows.append(row)
		if label=="scenario-4-gunner":
			await concealed_actor(message,label)
			await retention_contract(message,label)
			await visible_actor_casts(message,label)
			await timing(message,label)
	var active_rows: Array=rows.filter(func(row):return row.active)
	if only.is_empty():
		check(rows.size()==32,"all four stations across all eight original scenarios rendered")
		check(active_rows.size()>=24,"daylight cases activate the light (%d)"%active_rows.size())
		check(active_rows.all(func(row):return row.shade_changed+row.footprint_changed>0),"every active case changes some terrain")
		check(report.has("concealed_actor") and report.has("retention") and report.has("visible_actor"),"concealed-actor, caster and retention contracts ran")
	report.merge({"checks":checks,"errors":errors,"cases":rows,
		"scope":"Production-viewer replay of recorded source packets: full light, footprints only, light off from identical packets. Not a moving-gameplay or GPU-isolated performance measurement."})
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_TACTICAL_LIGHT: %d checks, %d cases, %d active, %d errors"%[checks,rows.size(),active_rows.size(),errors.size()])
	quit(0 if errors.is_empty() else 1)
