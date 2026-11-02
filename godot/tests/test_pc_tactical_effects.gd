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
	# Use the captured PC descriptors, including the final entry's trailing word.
	# Synthetic flags=8 fixtures used to hide the observed phase-63 rejection.
	var pc_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-effects-v1/effects.json")))
	for phase: int in range(54,64):
		var source_sprite: Dictionary=pc_data.images[phase].duplicate(true)
		source_sprite.origin=[128,50];source_sprite.clip=frame.clip.duplicate()
		var observed: Dictionary={"kind":"sprite","sprite_status":"observed","bitmap_index":phase,"shape_index":Art.SHAPES[phase],"root":Art.ROOTS[phase],"sprite":source_sprite}
		var registered: Dictionary=art.mapping(observed,frame,Art.PC_PALETTE)
		check(not registered.is_empty(),"observed PC guided phase %d maps to authored art"%phase)
		if registered.is_empty(): continue
		check(registered.donor==(18 if phase%2==0 else 19),"guided phase %d preserves its authored donor"%phase)
		check(registered.target==Rect2(Vector2(128,50)+art.bounds[phase].position,art.bounds[phase].size),"guided phase %d preserves native footprint"%phase)
		var changed: Dictionary=observed.duplicate(true)
		changed.sprite.flags=8 if phase==63 else 16
		check(art.mapping(changed,frame,Art.PC_PALETTE).is_empty(),"guided phase %d rejects another descriptor's trailing word"%phase)
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
	check(effects.material.get_shader_parameter("plume_world_up")==Vector3(0,0,1),"identity source camera retains world-up")
	check(effects.material.get_shader_parameter("plume_projection")==Vector4(256,97,-127,48)/128.0,"root projection retains inclusive source clip, centre and focal length")
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
	var luminous: bool=effects._plumes_live
	var motor_puffs: int=0
	var plume_puffs: int=0
	var generic_puffs: int=0
	for n in effects.puffs.size():
		var puff: Array=effects.puffs[n]
		if puff[4]==2.0:
			generic_puffs+=1
			luminous=luminous and puff[10]==-1.0 and puff[9]==-1.0
			continue
		luminous=luminous and puff[10]==-2.0 and puff[9]==-1.0
		if puff[4]==3.0: motor_puffs+=1
		if puff[4]==0.0: plume_puffs+=1
		var anchor: Color=effects._roots.get_pixel(n*2+1,0)
		luminous=luminous and anchor.a==-2.0
	check(luminous and motor_puffs==2 and plume_puffs==7 and generic_puffs==5,"missile RGB tag keeps puff kinds, inactive impact ages and live plume clock")
	var rect: Rect2=art.mapping(object,frame,Art.PC_PALETTE).rect
	var confined:=true
	for puff: Array in effects.puffs: confined=confined and puff[8]==rect
	check(confined and not effects.puffs.is_empty(),"every flare puff is confined to the original sprite rectangle")
	for heading in [[0,0,192],[64,0,0],[0,0,0]]:
		var turned:=missile.duplicate(true);turned.world.dynamic[0].orientation_u8=heading
		check(queued(effects,turned,mapping,ownership,assets,art)==flight,"missile heading %s leaves the glow unchanged"%str(heading))
	var alternate: Dictionary=missile.duplicate(true)
	alternate.objects[0].sprite=pc_data.images[63].duplicate(true)
	alternate.objects[0].sprite.origin=[152,60];alternate.objects[0].sprite.clip=frame.clip.duplicate()
	alternate.objects[0].bitmap_index=63;alternate.objects[0].shape_index=Art.SHAPES[63];alternate.objects[0].root=Art.ROOTS[63]
	alternate.world.dynamic[0].shape_index=187
	queued(effects,alternate,mapping,ownership,assets,art)
	check(effects.counts.missile==9,"observed phase 63 retains its authored motor glow")
	var alternate_mapping: Dictionary=art.mapping(alternate.objects[0],frame,Art.PC_PALETTE)
	if not alternate_mapping.is_empty():
		var alternate_confined: bool=not effects.puffs.is_empty()
		for puff: Array in effects.puffs: alternate_confined=alternate_confined and puff[8]==alternate_mapping.rect
		check(alternate_confined,"phase 63 motor puffs remain inside the exact source rectangle")
	var impact:=missile.duplicate(true);impact.world.dynamic[0].shape_header_word=2
	queued(effects,impact,mapping,ownership,assets,art)
	check(effects.counts.missile==0,"impact starburst cannot become a missile")
	effects.prepare(sample([]),mapping,ownership,assets,art)
	check(effects.puffs.is_empty() and not effects.visible,"empty frame clears all particles")
	check(not effects._plumes_live and not effects.advance_dynamics(0.05),"empty source frame stops continuous plume redraws")
	kill_debris(effects,directory,mapping,ownership,assets,art)
	effects.free()
	finish()

func debris_rows(effects: Node3D) -> Array:
	var rows: Array=[]
	for n in effects.puffs.size():
		if effects.puffs[n][4]==4.0: rows.append([n,effects.puffs[n]])
	return rows

func kill_debris(effects: Node3D, directory: String, mapping: Dictionary, ownership: Texture2D, assets: RefCounted, art: RefCounted) -> void:
	# The class table must be the catalogue's own intact/replacement pairing.
	var catalog: Dictionary=ModernAssets.new().load_catalogue(directory)
	var models: Array=catalog.models.values() if catalog.models is Dictionary else catalog.models
	var intact: Dictionary={}
	var wrecks: Dictionary={}
	for model: Dictionary in models:
		for role: Dictionary in model.get("class_roles",[]):
			var group: Dictionary=intact if role.variant=="primary" else wrecks if role.variant=="replacement" else {}
			group[int(role.class_index)]=int(model.shape_index)
	var pairs: Dictionary={}
	for index: int in intact:
		var shape: int=intact[index]
		if index in wrecks and (shape in range(115,145) or shape==159):pairs[shape]=wrecks[index]
	check(pairs==Effects.KILL_WRECKS,"kill table matches every catalogued vehicle class's replacement")
	var alive:=vehicle(directory)
	var dead:=alive.duplicate(true);dead.objects[0].shape_index=130;dead.world.dynamic[0].shape_index=130
	effects.reset_dynamics()
	effects.prepare(dead,mapping,ownership,assets,art)
	check(effects.counts.debris==0,"a wreck first seen already destroyed throws nothing")
	effects.prepare(alive,mapping,ownership,assets,art)
	check(effects.counts.debris==0,"an intact vehicle throws nothing")
	effects.prepare(dead,mapping,ownership,assets,art)
	var rows:=debris_rows(effects)
	check(effects.counts.debris==1 and rows.size()==1,"observed intact-to-wreck swap queues one debris quad")
	if rows.size()==1:
		var puff: Array=rows[0][1]
		check(int(puff[6])==1 and float(puff[9])==effects._dynamics_clock and float(puff[10])==-4.0 and not Rect2(puff[8]).has_area(),"debris belongs to the wreck, starts now and may cross open ground")
		var emitter: Color=effects._roots.get_pixel(int(rows[0][0])*2,0)
		check(emitter.r==1.0 and emitter.g==4.0 and is_equal_approx(emitter.a,float(puff[9])+1.0),"root table carries owner, debris kind and birth")
		var hull: Rect2=Effects.drawn_rect(dead.objects[0],frame)
		check(Vector2(puff[1]).is_equal_approx(hull.get_center()) and is_equal_approx(float(puff[2]),maxf(hull.size.x,hull.size.y)*1.4),"debris quad is centred on the drawn wreck and spans its flight")
		var ground:=hull.size.y*0.5/(maxf(hull.size.x,hull.size.y)*1.4)
		var flags:PackedVector2Array=effects.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		var carried:=puff.size()==12 and is_equal_approx(float(puff[11]),ground)
		for n in 6: carried=carried and is_equal_approx(flags[int(rows[0][0])*6+n].y,2.0+ground)
		check(carried,"fragments land on the wreck's drawn base, carried to every debris vertex")
	var birth: float=effects._dynamics_clock
	check(effects.advance_dynamics(0.05) and effects._dynamics_clock>birth,"live debris advances the explicit clock")
	effects.prepare(dead,mapping,ownership,assets,art)
	rows=debris_rows(effects)
	check(rows.size()==1 and float(rows[0][1][9])==birth,"a later pass keeps the original birth, never restarts the burst")
	check(not effects.advance_dynamics(NAN) and not effects.advance_dynamics(-1.0),"invalid deltas cannot age debris")
	for n in 30: effects.advance_dynamics(0.05)
	check(not effects.advance_dynamics(0.05),"spent debris stops redraws")
	effects.prepare(dead,mapping,ownership,assets,art)
	check(effects.counts.debris==0,"spent debris leaves the queue")
	# Refusals: each runs alive -> (gap) -> dead from a clean observation.
	var reused:=alive.duplicate(true);reused.objects[0].shape_index=133;reused.world.dynamic[0].shape_index=133
	var doubled:=alive.duplicate(true);doubled.objects.append(doubled.objects[0].duplicate(true))
	var doubled_dead:=dead.duplicate(true);doubled_dead.objects.append(doubled_dead.objects[0].duplicate(true))
	var unseen:=dead.duplicate(true);unseen.objects=[]
	var thermal:=alive.duplicate(true);thermal.palette_rgb=thermal.palette_rgb.duplicate(true);thermal.palette_rgb[6]=[1,2,3]
	var fixed:=alive.duplicate(true);fixed.objects[0].dynamic_instance=false
	var fixed_dead:=dead.duplicate(true);fixed_dead.objects[0].dynamic_instance=false
	var at:=func(data: Dictionary, sequence: int) -> Dictionary:
		var copy:=data.duplicate(true);copy.sequence=sequence;return copy
	var window: int=Effects.KILL_WINDOW_PASSES
	for case: Array in [["reused slot of another class",[reused,dead]],["ambiguous pointer",[doubled,doubled_dead]],
			["unsupported palette between",[alive,thermal,dead]],
			["static object",[fixed,fixed_dead]],["timeline reset between",[alive,null,dead]],
			["kill long out of view",[at.call(alive,100),at.call(unseen,104),at.call(dead,101+window)]],
			["rewound timeline",[at.call(alive,100),at.call(dead,90)]]]:
		effects.reset_dynamics()
		for pass_data in case[1]:
			if pass_data==null: effects.reset_dynamics()
			else: effects.prepare(pass_data,mapping,ownership,assets,art)
		check(effects.counts.debris==0 and effects._kill_births.is_empty(),"%s throws nothing"%case[0])
	# A burst survives a pass with its wreck undrawn, keeping its birth, and the
	# wreck's return never starts a second one.
	effects.reset_dynamics()
	effects.prepare(alive,mapping,ownership,assets,art);effects.prepare(dead,mapping,ownership,assets,art)
	var first: Array=effects._kill_births.get(99,[])
	effects.advance_dynamics(0.05)
	effects.prepare(unseen,mapping,ownership,assets,art)
	check(effects.counts.debris==0 and effects._kill_births.get(99,[])==first,"an undrawn wreck hides its burst without dropping it")
	effects.prepare(dead,mapping,ownership,assets,art)
	check(effects.counts.debris==1 and effects._kill_births.get(99,[])==first and not first.is_empty(),"the returning wreck resumes the same burst")
	for n in 30: effects.advance_dynamics(0.05)
	effects.prepare(unseen,mapping,ownership,assets,art)
	check(effects._kill_births.is_empty(),"a spent burst is dropped while undrawn")
	# The original may leave a dying vehicle undrawn for a pass or two around
	# the swap; a gap inside the window still counts as one observed kill.
	for gap in [1,window]:
		effects.reset_dynamics()
		effects.prepare(at.call(alive,200),mapping,ownership,assets,art)
		effects.prepare(at.call(unseen,200+gap-1 if gap>1 else 200),mapping,ownership,assets,art)
		effects.prepare(at.call(dead,200+gap),mapping,ownership,assets,art)
		check(effects.counts.debris==1,"kill after a %d-pass undrawn gap throws debris"%gap)
	# A distant kill keeps its debris on the wreck and impact sprites only.
	var far:=alive.duplicate(true)
	for polygon: Dictionary in far.objects[0].polygons:
		for point: Array in polygon.camera_vertices: point[1]=float(point[1])*16.0
	var far_dead:=far.duplicate(true);far_dead.objects[0].shape_index=130
	effects.reset_dynamics()
	effects.prepare(far,mapping,ownership,assets,art);effects.prepare(far_dead,mapping,ownership,assets,art)
	rows=debris_rows(effects)
	var far_size:=Effects.drawn_rect(far_dead.objects[0],frame).size
	check(maxf(far_size.x,far_size.y)<Effects.DEBRIS_OPEN_PIXELS and rows.size()==1 and float(rows[0][1][10])==-3.0,"a small distant kill stays confined")
	effects.reset_dynamics()
	check(effects._kill_births.is_empty() and effects.material.get_shader_parameter("dynamics_time")==-1.0,"timeline reset drops debris and hides the clock")
	# Fast forward / motion off: a burst is spent, never frozen at age zero.
	var fresh:=Effects.new();root.add_child(fresh)
	check(not fresh.rest_dynamics(),"resting a never-run clock changes nothing")
	fresh.prepare(alive,mapping,ownership,assets,art);fresh.advance_dynamics(0.05)
	fresh.prepare(dead,mapping,ownership,assets,art)
	check(fresh.counts.debris==1 and fresh.rest_dynamics(),"rest spends a live kill burst")
	check(fresh._kill_births.is_empty() and fresh.material.get_shader_parameter("dynamics_time")==-1.0 and not fresh.rest_dynamics(),"rest hides the clock once and is then idle")
	fresh.prepare(dead,mapping,ownership,assets,art)
	check(fresh.counts.debris==0 and not fresh.advance_dynamics(0.05),"a rested wreck cannot re-trigger or restart")
	fresh.free()
	# Whitelist: background is open ground (red), impact sprites green, flares not.
	var marked:=alive.duplicate(true)
	marked.objects.append({"kind":"sprite","shape_index":183,"polygons":[]})
	marked.objects.append({"kind":"sprite","shape_index":186,"polygons":[]})
	effects.prepare(marked,mapping,ownership,assets,art)
	var whitelist: Image=effects.material.get_shader_parameter("allowed_terrain").get_image()
	check(whitelist.get_pixel(0,0)==Color(1,0,0) and whitelist.get_pixel(1,0)==Color(0,0,0) and whitelist.get_pixel(2,0)==Color(0,1,0) and whitelist.get_pixel(3,0)==Color(0,0,0),"whitelist marks open background and impact sprites only")

func finish() -> void:
	print("PC_TACTICAL_EFFECTS: %d checks, %d errors"%[checks,errors.size()])
	for error in errors: printerr("FAIL: "+error)
	quit(0 if errors.is_empty() else 1)
