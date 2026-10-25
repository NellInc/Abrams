extends SceneTree
## Headless Tactical particle queue checks. The confinement and pixel studies
## that need a GPU stay in test_pc_effect_art.gd --tactical-particles.
const Art = preload("res://scripts/pc_effect_art.gd")
const Effects = preload("res://scripts/pc_tactical_effects.gd")
const Foliage = preload("res://scripts/pc_tactical_foliage.gd")
const ModernAssets = preload("res://scripts/pc_modern_assets.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
var errors: Array[String] = []
var checks := 0
var frame := {"clip":[32,13,287,109],"center":[159,61],"near_raw":16,"focal_pixels":128,
	"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)

func _initialize() -> void: run.call_deferred()

func sample(objects: Array) -> Dictionary:
	return {"camera":frame,"palette_rgb":Art.PC_PALETTE,"background":{"kind":"solid","color":8},"objects":objects}

func vehicle(directory: String) -> Dictionary:
	# Real catalogued M113 source faces, as in the GPU particle study.
	# Source structure lives in the pinned registry; load it merged and verified.
	var catalog: Dictionary=ModernAssets.new().load_catalogue(directory)
	var model: Dictionary=catalog.models[129]
	var object: Dictionary={"shape_index":129,"root":int(model.roots[0].offset),"dynamic_instance":true,"static_path":false,"pointer":99,"polygons":[]}
	var rotation:=Basis(Vector3.RIGHT,0.65)*Basis(Vector3(0,0,1),0.4)
	var selected: Dictionary={}
	for group: Dictionary in model.groups:
		if group.offset in model.roots[0].group_pointers:
			for pid in group.primitive_pointers:selected[int(pid)]=true
	for primitive: Dictionary in model.source_primitives:
		if primitive.vertices.size()<3 or int(primitive.id) not in selected:continue
		var points: Array=[]
		for raw: Array in primitive.vertices:
			var point: Vector3=rotation*Vector3(raw[0],raw[1],raw[2]);points.append([point.x,point.y+300,point.z])
		object.polygons.append({"primitive":int(primitive.id),"fill_mode":1,"colors":[int(primitive.prefix_bytes[1]),int(primitive.prefix_bytes[2])],"camera_vertices":points})
	var data:=sample([object])
	data.world={"dynamic":[{"pointer":99,"shape_index":129,"world_position_raw":[0,-300,0],"orientation_u8":[0,0,0],"speed_raw":30,"shape_header_word":100}],"presentation_effects":{"schema":1,"shape_base":115}}
	return data

func queued(effects: Node3D, data: Dictionary, mapping: Dictionary, ownership: Texture2D, assets: RefCounted, art: RefCounted) -> String:
	effects.prepare(data,mapping,ownership,assets,art)
	return var_to_str([effects.counts,effects.puffs])

func run() -> void:
	var directory:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var assets:=ModernAssets.new()
	check(assets.load_assets(directory),"Tactical effects Modern catalogue available")
	var art:=Art.new()
	check(art.load_assets(directory),"Tactical effects source art available")
	if not assets.ready or not art.loaded: finish(); return
	var effects:=Effects.new()
	root.add_child(effects)
	var mapping:={"origin":Vector3.ZERO,"inverse":Basis.IDENTITY}
	var ownership:=ImageTexture.create_from_image(Image.create(256,97,false,Image.FORMAT_RGBA8))

	# RAM speed, heading and travel never select or shape a puff. A vehicle the
	# original draws identically while moving, reversing or parked looks the same.
	var data:=vehicle(directory)
	var moving:=queued(effects,data,mapping,ownership,assets,art)
	check(effects.counts.exhaust==7 and not effects.counts.has("dust"),"visible engine face queues idle fumes and no motion dust")
	var original_puffs:=var_to_str(effects.puffs)
	var original_roots:PackedByteArray=effects.material.get_shader_parameter("roots").get_image().get_data()
	check(effects.advance_dynamics(0.05) and effects._plume_phase>0.0 and effects._dynamics_clock==0.0,"idle exhaust advances only the bounded plume clock")
	check(var_to_str(effects.puffs)==original_puffs and effects.material.get_shader_parameter("roots").get_image().get_data()==original_roots,"plume animation cannot change geometry, alpha, roots or source phase")
	var held_phase:float=effects._plume_phase
	check(not effects.advance_dynamics(NAN) and not effects.advance_dynamics(INF) and not effects.advance_dynamics(-1.0) and effects._plume_phase==held_phase,"invalid plume deltas cannot advance")
	effects.reset_dynamics()
	check(effects._plume_phase==0.0 and effects.material.get_shader_parameter("plume_phase")==0.0,"timeline reset clears plume phase")
	var expected_sun:=Vector3(-0.58,-0.74,0.34).normalized()
	check(effects.material.get_shader_parameter("plume_sun").is_equal_approx(expected_sun),"world sun maps to the source camera's screen-facing frame")
	# Fumes stay inside the rectangle the original drew this vehicle into; the
	# shader then admits only its own painted pixels, never sky or a crest.
	var clip:=Rect2(Vector2(frame.clip[0],frame.clip[1]),Vector2(frame.clip[2]-frame.clip[0]+1,frame.clip[3]-frame.clip[1]+1))
	var hull: Rect2=Effects.drawn_rect(data.objects[0],frame)
	var hull_ok:=hull.has_area() and not effects.puffs.is_empty()
	for puff: Array in effects.puffs: hull_ok=hull_ok and puff[8]==hull and int(puff[6])==1 and hull.has_point(clip.position+Vector2(puff[7])*clip.size)
	check(hull_ok,"every exhaust puff is confined to the vehicle's drawn rectangle around its vent")
	var vertices: PackedVector3Array=effects.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var inside:=vertices.size()==effects.puffs.size()*6
	for vertex: Vector3 in vertices:
		inside=inside and hull.grow(0.01).has_point(Geometry.project([vertex.x*64.0,-vertex.z*64.0,vertex.y*64.0],frame))
	check(inside,"exhaust quads are clipped to the drawn rectangle")
	check(not Effects.drawn_rect({"polygons":[{"camera_vertices":[[0,4,0],[5,6,0],[0,8,5]]}]},frame).has_area(),"geometry behind the near plane draws no rectangle")
	# A vent outside the source clip has no visible root, however much hull shows.
	var root_at: Vector2=clip.position+Vector2(effects.puffs[0][7])*clip.size
	var shifted:=data.duplicate(true)
	for polygon: Dictionary in shifted.objects[0].polygons:
		for point: Array in polygon.camera_vertices: point[0]=float(point[0])+(clip.end.x+3.0-root_at.x)*float(point[1])/float(frame.focal_pixels)
	var shifted_hull: Rect2=Effects.drawn_rect(shifted.objects[0],frame)
	effects.prepare(shifted,mapping,ownership,assets,art)
	check(shifted_hull.has_area() and effects.counts.exhaust==0 and not effects.visible,"a vent outside the drawn on-screen hull emits nothing")
	check(queued(effects,data,mapping,ownership,assets,art)==moving,"restored vehicle queues the same fumes")
	var mesh: Mesh=effects.node.mesh
	var allowed: Texture2D=effects.material.get_shader_parameter("allowed_terrain")
	var roots: Texture2D=effects.material.get_shader_parameter("roots")
	for change in [["speed_raw",0],["speed_raw",-30],["orientation_u8",[0,0,128]],["orientation_u8",[32,0,77]],["world_position_raw",[512,-900,40]]]:
		var variant:=data.duplicate(true)
		variant.world.dynamic[0][change[0]]=change[1]
		check(queued(effects,variant,mapping,ownership,assets,art)==moving,"RAM %s cannot change Tactical fumes"%change[0])
		check(Effects.inputs(variant)==Effects.inputs(data),"RAM %s cannot dirty the particle batch"%change[0])
	check(effects.node.mesh==mesh and effects.material.get_shader_parameter("allowed_terrain")==allowed and effects.material.get_shader_parameter("roots")==roots,"rebuilds reuse one mesh, whitelist and root table")
	var unmatched:=data.duplicate(true);unmatched.world.dynamic[0].pointer=100
	queued(effects,unmatched,mapping,ownership,assets,art)
	check(effects.counts.exhaust==0 and not effects.visible,"unmatched actor identity emits nothing")
	var reused:=data.duplicate(true);reused.world.dynamic.append(reused.world.dynamic[0].duplicate(true))
	queued(effects,reused,mapping,ownership,assets,art)
	check(effects.counts.exhaust==0 and not effects.visible,"reused actor identity emits nothing")
	var index:=ModernAssets.dynamic_index(data)
	var index_agrees:=true
	for variant: Dictionary in [data,unmatched,reused]:
		index_agrees=index_agrees and Effects.actor_for(variant.objects[0],variant,ModernAssets.dynamic_index(variant))==Effects.actor_for(variant.objects[0],variant)
	check(index_agrees and not Effects.actor_for(data.objects[0],data,index).is_empty(),"per-pass actor index matches the scan, including reused identities")
	# A pass may carry a null background (or colours); smoke and foliage must
	# treat it as no backdrop rather than abort on a typed assignment.
	var bare:=data.duplicate(true);bare.background=null
	bare.world.presentation_effects.smoke={"active":true,"world_position_raw":[0,0,0],"remaining_raw":15}
	queued(effects,bare,mapping,ownership,assets,art)
	check(effects.counts.get("smoke",0)>0 and effects.counts.exhaust==7,"null background keeps smoke and fumes")
	var uncoloured:=bare.duplicate(true);uncoloured.background={"kind":"horizon","colors":null}
	queued(effects,uncoloured,mapping,ownership,assets,art)
	check(effects.counts.get("smoke",0)>0 and effects.counts.exhaust==7,"null background colours keep smoke and fumes")
	var plants:=Foliage.new()
	for variant: Dictionary in [bare,uncoloured]:
		plants.prepare(variant,mapping,ownership)
		check(plants.instance_count==0,"foliage treats a null backdrop as unplantable")
	plants.free()
	var extra:=data.duplicate(true);extra.objects.append({"shape_index":1,"polygons":[]})
	queued(effects,extra,mapping,ownership,assets,art)
	var widened: Texture2D=effects.material.get_shader_parameter("allowed_terrain")
	check(widened!=allowed and widened.get_width()==3 and effects.material.get_shader_parameter("owner_count")==3.0,"changed object list replaces the exact whitelist")

	# The motor glow stays inside the drawn flare's own registered footprint and
	# never points along the RAM travel axis toward its launcher.
	var flare: Dictionary=art.sources[62].duplicate(true)
	flare.flags=8;flare.origin=[152,60];flare.clip=frame.clip.duplicate()
	var object:={"kind":"sprite","sprite_status":"observed","bitmap_index":62,"root":Art.ROOTS[62],"shape_index":Art.SHAPES[62],"dynamic_instance":true,"sprite":flare,"polygons":[],"pointer":99}
	var missile:=sample([object])
	var box: Rect2=art.mapping(object,frame,Art.PC_PALETTE).target
	var raw: Array=Geometry.unproject(box.get_center(),600.0,frame)
	missile.world={"dynamic":[{"pointer":99,"shape_index":186,"shape_header_word":100,"world_position_raw":[raw[0],-raw[1],raw[2]],"orientation_u8":[0,0,64],"speed_raw":250}],"presentation_effects":{"schema":1,"shape_base":115}}
	var flight:=queued(effects,missile,mapping,ownership,assets,art)
	check(effects.counts.missile==9,"observed guided flare keeps its motor glow")
	var rect: Rect2=art.mapping(object,frame,Art.PC_PALETTE).rect
	var confined:=true
	for puff: Array in effects.puffs: confined=confined and puff[8]==rect
	check(confined and not effects.puffs.is_empty(),"every flare puff is confined to the original sprite rectangle")
	for heading in [[0,0,192],[64,0,0],[0,0,0]]:
		var turned:=missile.duplicate(true);turned.world.dynamic[0].orientation_u8=heading
		check(queued(effects,turned,mapping,ownership,assets,art)==flight,"missile heading %s leaves the glow unchanged"%str(heading))
	var impact:=missile.duplicate(true);impact.world.dynamic[0].shape_header_word=2
	queued(effects,impact,mapping,ownership,assets,art)
	check(effects.counts.missile==0,"impact starburst cannot become a missile")
	effects.prepare(sample([]),mapping,ownership,assets,art)
	check(effects.puffs.is_empty() and not effects.visible,"empty frame clears all particles")
	check(not effects._plumes_live and not effects.advance_dynamics(0.05),"empty source frame stops continuous plume redraws")
	effects.free()
	finish()

func finish() -> void:
	print("PC_TACTICAL_EFFECTS: %d checks, %d errors"%[checks,errors.size()])
	for error in errors: printerr("FAIL: "+error)
	quit(0 if errors.is_empty() else 1)
