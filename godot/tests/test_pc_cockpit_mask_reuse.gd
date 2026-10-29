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


# Frozen per-pixel silhouette scan that column_extents replaced.
static func extents_before(bits:PackedByteArray,roof:PackedByteArray,station:int,rail:bool,end_y:int) -> Array:
	var lower:=PackedFloat32Array();lower.resize(320);lower.fill(end_y)
	var upper:=PackedFloat32Array();upper.resize(320)
	for x in 320:
		for y in end_y:
			var at:=y*320+x
			var claimed:bool=int(bits[at])==station
			if station==4 and not roof.is_empty():claimed=claimed or roof[at*3+2]==255
			if station==3 and rail and y>=111 and y<117 and x>=159 and x<[183,206,230,242,264,286][y-111]:claimed=true
			if not claimed:continue
			if station==4 and y<77:upper[x]=y+1
			elif y<lower[x]:lower[x]=y
	return [upper,lower]

# Frozen per-pixel driver assembly validation that _driver_mask_claims replaced.
static func driver_claims_before(values:PackedByteArray,ui_bits:PackedByteArray) -> int:
	var any:=0
	for at in 64000:
		var i:=at*3
		if values[i+2] not in [0,255] or values[i+1]>127: return -1
		if values[i+2]==0:
			if values[i]!=0 or values[i+1]!=0: return -1
		elif ui_bits[at]!=255: return -1
		else: any=1
	return any

static func median_usec(work:Callable,runs:int) -> float:
	var samples:=PackedFloat64Array()
	for run in runs:
		var start:=Time.get_ticks_usec()
		work.call(run)
		samples.append(Time.get_ticks_usec()-start)
	samples.sort()
	return samples[runs/2]

func driver_claims() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=4181
	var invalid:=0
	for trial in 70:
		var mask:=Image.create_empty(320,200,false,Image.FORMAT_RGB8)
		var ui:=Image.create_empty(320,200,false,Image.FORMAT_L8);ui.fill(Color.WHITE)
		if trial%3: ui.fill_rect(Rect2i(rng.randi_range(0,300),rng.randi_range(0,190),rng.randi_range(1,60),rng.randi_range(1,30)),Color.BLACK)
		if trial%5: mask.fill_rect(Rect2i(rng.randi_range(0,200),rng.randi_range(0,100),rng.randi_range(1,100),rng.randi_range(1,60)),Color8(rng.randi_range(0,255),rng.randi_range(0,127),255))
		var at:=Vector2i(rng.randi_range(0,319),rng.randi_range(0,199))
		match trial%7:
			1:mask.set_pixelv(at,Color8(rng.randi_range(1,255),0,0))
			2:mask.set_pixelv(at,Color8(0,rng.randi_range(1,255),0))
			3:mask.set_pixelv(at,Color8(0,rng.randi_range(128,255),255))
			4:mask.set_pixelv(at,Color8(0,0,rng.randi_range(1,254)))
			5:mask.set_pixelv(at,Color8(5,127,255))
		var expected:=driver_claims_before(mask.get_data(),ui.get_data())
		if expected<0: invalid+=1
		check(Frame._driver_mask_claims(mask.get_data(),ui.get_data())==expected,"native driver validation differs from per-pixel scan "+str(trial))
	check(invalid>10 and invalid<60,"driver validation corpus mixes valid and invalid masks")

# Frame-time regressions measured against the frozen implementations, same run.
func edge_timing() -> void:
	const Edges=preload("res://scripts/pc_cockpit_edges.gd")
	var edges=Edges.new();root.add_child(edges)
	var ui:=Image.create_empty(320,200,false,Image.FORMAT_L8);ui.fill(Color.WHITE)
	var tags:=Image.create_empty(320,200,false,Image.FORMAT_L8);tags.fill(Color8(4,4,4));tags.fill_rect(Rect2i(0,0,320,100),Color.BLACK)
	var donor:=ImageTexture.create_from_image(Image.create_empty(640,400,false,Image.FORMAT_RGB8))
	var roofs:Array[Image]=[]
	for shift in 2:
		var roof:=Image.create_empty(320,200,false,Image.FORMAT_RGB8);roof.fill_rect(Rect2i(40+shift,0,200,60),Color8(10,20,255))
		roofs.append(roof)
	var camera:=Rect2i(0,0,320,136)
	edges.set_frame(ui,tags,camera,donor,roofs[0],4,false,false,donor)
	var stable:=median_usec(func(_run): edges.set_frame(ui,tags,camera,donor,roofs[0],4,false,false,donor),15)
	var builds:int=edges.build_count
	var traverse:=median_usec(func(run): edges.set_frame(ui,tags,camera,donor,roofs[(run+1)%2],4,false,false,donor),9)
	check(edges.active and edges.build_count==builds+9,"traverse timing did not exercise the miss path")
	var bits:=tags.get_data();var roof_bytes:=roofs[0].get_data()
	var scan:=median_usec(func(_run): extents_before(bits,roof_bytes,4,false,136),5)
	var claims:=median_usec(func(_run): Frame._driver_mask_claims(roof_bytes,ui.get_data()),9)
	var validation:=median_usec(func(_run): driver_claims_before(roof_bytes,ui.get_data()),5)
	print("PC_COCKPIT_EDGE_TIMING: stable %.0f us, traverse miss %.0f us, frozen scan %.0f us, driver validation %.0f us, frozen validation %.0f us"%[stable,traverse,scan,claims,validation])
	check(stable<1000.0,"stable driver outline exceeded 1 ms")
	check(traverse<scan*0.5,"traverse miss not measurably below the frozen per-pixel scan")
	check(claims<validation*0.5,"driver validation not measurably below the frozen per-pixel scan")
	edges.queue_free()

func edge_extents() -> void:
	const Edges=preload("res://scripts/pc_cockpit_edges.gd")
	var rng:=RandomNumberGenerator.new();rng.seed=1722
	for trial in 24:
		var station:int=3 if trial%2==0 else 4
		var end_y:int=117 if station==3 else 136
		var tags:=Image.create_empty(320,200,false,Image.FORMAT_L8)
		for blob in rng.randi_range(0,12):
			tags.fill_rect(Rect2i(rng.randi_range(0,319),rng.randi_range(0,199),rng.randi_range(1,90),rng.randi_range(1,90)),Color8(station,station,station))
		for dot in 40:tags.set_pixel(rng.randi_range(0,319),rng.randi_range(0,199),Color8(station,station,station))
		var assembly:Image=null
		if station==4 and trial%4!=1:
			assembly=Image.create_empty(320,200,false,Image.FORMAT_RGB8)
			for blob in rng.randi_range(0,8):
				assembly.fill_rect(Rect2i(rng.randi_range(0,319),rng.randi_range(0,199),rng.randi_range(1,60),rng.randi_range(1,40)),Color8(rng.randi_range(0,255),rng.randi_range(0,127),255))
		var rail:=trial%3==0
		var expected:=extents_before(tags.get_data(),assembly.get_data() if assembly!=null else PackedByteArray(),station,rail,end_y)
		var actual:Array=Edges.column_extents(tags,assembly,station,rail,end_y)
		check(actual[0]==expected[0] and actual[1]==expected[1],"native column extents match per-pixel scan "+str(trial))
	# Turret traverse that only changes offset bytes reuses the outline mesh.
	var edges=Edges.new();root.add_child(edges)
	var ui:=Image.create_empty(320,200,false,Image.FORMAT_L8);ui.fill(Color.WHITE)
	var tags:=Image.create_empty(320,200,false,Image.FORMAT_L8);tags.fill_rect(Rect2i(0,150,320,50),Color8(4,4,4))
	var donor:=ImageTexture.create_from_image(Image.create_empty(640,400,false,Image.FORMAT_RGB8))
	var roof:=Image.create_empty(320,200,false,Image.FORMAT_RGB8);roof.fill_rect(Rect2i(40,0,200,30),Color8(10,20,255))
	edges.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor)
	var builds:int=edges.build_count
	check(edges.active and builds>0,"driver outline built")
	roof.fill_rect(Rect2i(40,0,200,30),Color8(99,100,255))
	edges.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor)
	check(edges.active and edges.build_count==builds,"offset-only assembly change rebuilt the outline")
	roof.fill_rect(Rect2i(40,0,201,30),Color8(99,100,255))
	edges.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor)
	check(edges.active and edges.build_count==builds+1,"moved assembly claim kept a stale outline")
	# A plate change under an unchanged assembly cannot reuse the cached plate scan.
	tags.fill_rect(Rect2i(0,120,90,30),Color8(4,4,4))
	edges.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor)
	var fresh=Edges.new();root.add_child(fresh)
	fresh.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor)
	check(edges.active and edges.build_count==builds+2 and edges.profiles==fresh.profiles,"changed plate kept a stale cached plate scan")
	var legacy_profiles: Array=edges.profiles.duplicate(true)
	edges.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor,null,null,null,true)
	var rounded_builds: int=edges.build_count
	edges.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor,null,null,null,true)
	check(edges.build_count==rounded_builds,"Tactical cap mode reuses its stable geometry")
	edges.set_frame(ui,tags,Rect2i(0,0,320,136),donor,roof,4,true,false,donor)
	check(edges.profiles==legacy_profiles,"switching out of Tactical restores exact legacy profiles")
	fresh.queue_free()
	edges.queue_free()
	# Analytic quantised caps exercise the guarded curve without storing decoded
	# original art. Native capture separately checks the actual source profiles.
	for station in [3,4]:
		var centre: float=120.0 if station==3 else 161.0
		var peak: float=84.9 if station==3 else 77.1
		var direction: float=1.0 if station==3 else -1.0
		var heights: PackedFloat32Array=PackedFloat32Array();heights.resize(320);heights.fill(100.0 if station==3 else 32.0)
		for x in range(int(centre-12.5),int(centre+12.5)+1):
			heights[x]=roundf(peak+direction*0.0465*pow(float(x)+0.5-centre,2))
		var original_bytes: PackedByteArray=heights.to_byte_array()
		var linear: PackedVector2Array=Edges.fit(heights)
		var curved: PackedVector2Array=Edges.round_barrel_cap(linear,heights,station)
		check(curved.size()>linear.size(),"supported cap gets continuous quarter-pixel curvature "+str(station))
		var bounded: bool=true
		for x in 320:bounded=bounded and absf(Edges.profile_y(curved,float(x)+0.5)-heights[x])<=Edges.ERROR+0.0001
		check(bounded and heights.to_byte_array()==original_bytes,"curved cap retains source error bound and input bytes "+str(station))
		var unknown: PackedFloat32Array=heights.duplicate();unknown[int(centre)]+=5.0
		check(Edges.round_barrel_cap(linear,unknown,station)==linear,"unrecognised cap keeps the original linear fit "+str(station))
		# A qualifying cap must also cross the real geometry-cache mode boundary.
		var cap_tags: Image=Image.create_empty(320,200,false,Image.FORMAT_L8)
		var ink: Color=Color8(station,station,station)
		for x in 320:
			var y: int=int(heights[x])
			cap_tags.fill_rect(Rect2i(x,y if station==3 else 0,1,200-y if station==3 else y),ink)
		if station==4:cap_tags.fill_rect(Rect2i(0,150,320,50),ink)
		var cap_edges: Control=Edges.new();root.add_child(cap_edges)
		var cap_camera: Rect2i=Rect2i(0,0,320,117 if station==3 else 136)
		cap_edges.set_frame(ui,cap_tags,cap_camera,donor,null,station,true,false,donor)
		var cap_legacy: Array=cap_edges.profiles.duplicate(true)
		cap_edges.set_frame(ui,cap_tags,cap_camera,donor,null,station,true,false,donor,null,null,null,true)
		var cap_tactical: Array=cap_edges.profiles.duplicate(true)
		check(cap_tactical!=cap_legacy,"qualifying cap activates only in Tactical "+str(station))
		var cap_builds: int=cap_edges.build_count
		cap_edges.set_frame(ui,cap_tags,cap_camera,donor,null,station,true,false,donor,null,null,null,true)
		check(cap_edges.build_count==cap_builds,"qualifying Tactical cap reuses its cached mesh "+str(station))
		cap_edges.set_frame(ui,cap_tags,cap_camera,donor,null,station,true,false,donor)
		check(cap_edges.profiles==cap_legacy,"qualifying cap restores exact non-Tactical geometry "+str(station))
		cap_edges.set_frame(ui,cap_tags,cap_camera,donor,null,station,true,false,donor,null,null,null,true)
		check(cap_edges.profiles==cap_tactical,"qualifying cap round trip restores exact Tactical geometry "+str(station))
		cap_edges.queue_free()

var errors: Array[String] = []
var checks := 0
var before = Before.new()
var after = Frame.new()
func _initialize() -> void: run.call_deferred()
## Rows for the per-row sweeps: both ends, the rows either side of every 13th
## row and of the commander status band (37..99), and a fixed-seed sample. The
## complete 200-row sweep runs with -- --exhaustive (VALIDATE_EXHAUSTIVE=1).
func sweep_rows() -> Array:
	if "--exhaustive" in OS.get_cmdline_user_args(): return range(200)
	var rows := {}
	for y in [0,1,2,36,37,38,98,99,100,101,197,198,199]: rows[y]=true
	for y in range(0,200,13):
		for near in [y-1,y,y+1]:
			if near>=0 and near<200: rows[near]=true
	var rng := RandomNumberGenerator.new();rng.seed=20261015
	for i in 16: rows[rng.randi_range(0,199)]=true
	var sorted := rows.keys();sorted.sort()
	return sorted
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
	var rows := sweep_rows()
	for y in rows:
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
	for y in rows:
		for corruption in ["valid","mixed","unowned","valid"]:
			var current_tags := tags.duplicate()
			var current_ui := ui.duplicate()
			if corruption=="mixed":current_tags.set_pixel(100,y,Color(3.0/255.0,0,0))
			if corruption=="unowned":current_ui.set_pixel(100,y,Color.BLACK)
			for trim in trims:trim.set_frame(source,current_ui,current_tags,trim.CAMERA,world)
			check(trims[0].active==trims[1].active,"commander row proof "+str(y)+corruption)
	edge_extents()
	driver_claims()
	edge_timing()
	for error in errors:printerr("FAIL: "+error)
	print("PC_COCKPIT_MASK_REUSE: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
