extends Node3D
## Snapshot-derived presentation, never a particle simulation or gameplay cue.
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const Modern = preload("res://scripts/pc_modern_assets.gd")
const ShaderSource = preload("res://scripts/pc_tactical_effects.gdshader")
const MAX_PUFFS := 512
var node: MeshInstance3D
var material: ShaderMaterial
var puffs: Array = []
var counts: Dictionary = {}
var _impact_births: Dictionary = {}
var _dynamics_clock := 0.0
var _plume_phase := 0.0
var _plumes_live := false
var _frame: Dictionary
var _clip: Rect2
# Persistent GPU resources: one mesh and one fixed-width root table are
# rewritten in place; the owner whitelist is replaced only when it changes.
var _mesh := ArrayMesh.new()
var _roots := Image.create(MAX_PUFFS*2,1,false,Image.FORMAT_RGBAF)
var _roots_texture: ImageTexture
var _allowed_bytes := PackedByteArray()
var _allowed_texture: ImageTexture

func _init() -> void:
	material=ShaderMaterial.new()
	material.shader=ShaderSource
	material.render_priority=2
	_roots_texture=ImageTexture.create_from_image(_roots)
	material.set_shader_parameter("roots",_roots_texture)
	material.set_shader_parameter("root_width",float(_roots.get_width()))
	node=MeshInstance3D.new()
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	clear()

func clear() -> void:
	node.mesh=null
	puffs.clear()
	_plumes_live=false
	counts={"smoke":0,"missile":0,"exhaust":0,"effect":0}
	visible=false

func reset_dynamics() -> void:
	_impact_births={}
	_dynamics_clock=0.0
	_plume_phase=0.0
	material.set_shader_parameter("dynamics_time",-1.0)
	material.set_shader_parameter("plume_phase",0.0)

func advance_dynamics(delta: float) -> bool:
	if not visible or not is_finite(delta) or delta<=0.0:return false
	var live:=false
	for birth in _impact_births.values():
		if _dynamics_clock-float(birth)<0.55:live=true;break
	var elapsed:=minf(delta,0.05)
	if live:
		_dynamics_clock+=elapsed
		material.set_shader_parameter("dynamics_time",_dynamics_clock)
	if _plumes_live:
		# A separate periodic colour clock cannot wrap or prolong impact ages.
		# The viewer alone advances it, under its pause/focus/menu/motion gates.
		_plume_phase=fposmod(_plume_phase+elapsed*0.8,TAU)
		material.set_shader_parameter("plume_phase",_plume_phase)
	return live or _plumes_live

static func world_position_ok(value) -> bool:
	# World positions include streamed cell offsets, exceeding the local mesh
	# coordinate bound. Keep the finite original world envelope separate.
	if not value is Array or value.size()!=3:return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component))>1048576.0:return false
	return true

# Pass a Modern.dynamic_index(data) built once per pass to avoid rescanning
# every dynamic actor for each object; both paths reject reused identities.
static func actor_for(object: Dictionary, data: Dictionary, actors = null) -> Dictionary:
	if not object.get("dynamic_instance",false): return {}
	var matched: Dictionary={}
	if actors is Dictionary:
		var entry = actors.get([int(object.get("pointer",-1)),int(object.get("shape_index",-1))])
		if entry==null or int(entry[1])!=1: return {} # absent or ambiguous/reused identity
		matched=entry[0]
	else:
		for actor: Dictionary in data.get("world",{}).get("dynamic",[]):
			if int(actor.get("pointer",-2))!=int(object.get("pointer",-1)) or int(actor.get("shape_index",-2))!=int(object.get("shape_index",-1)): continue
			if not matched.is_empty(): return {} # ambiguous/reused identity
			matched=actor
	if not world_position_ok(matched.get("world_position_raw",[])): return {}
	return matched

# Retain only inputs consumed by this presentation, excluding off-screen pools.
# Actor speed, heading and position never shape a puff: the original frame
# shows none of them beyond the drawn model, so they cannot dirty the batch.
static func inputs(data: Dictionary) -> Array:
	var rows: Array=[data.get("world",{}).get("presentation_effects",{})]
	var actors:=Modern.dynamic_index(data)
	for object: Dictionary in data.get("objects",[]):
		var actor:=actor_for(object,data,actors)
		rows.append([not actor.is_empty(),actor.get("shape_header_word")])
	return rows

# A stable per-actor noise phase. Pointer identity carries no world position,
# so a plume's texture cannot shimmer only while its actor travels.
static func identity_seed(object: Dictionary) -> float:
	return fposmod(float(int(object.get("pointer",0))&0xffff)*0.618034,1.0)

func _puff(raw: Vector3, radius: float, alpha: float, kind: float, seed: float, owner: int, root: Vector2, restrict: Rect2=Rect2(), impact_birth: float=-1.0, impact_phase: float=-1.0) -> void:
	if puffs.size()>=MAX_PUFFS or raw.y<=float(_frame.near_raw)+2.0 or radius<=0.0: return
	var at:=Geometry.project([raw.x,raw.y,raw.z],_frame)
	var screen_radius:=radius*float(_frame.focal_pixels)/raw.y
	if screen_radius<0.35 or not _clip.intersects(Rect2(at-Vector2.ONE*screen_radius,Vector2.ONE*screen_radius*2.0)): return
	# Optical LOD affects opacity, never original geometry or source visibility.
	alpha*=smoothstep(0.35,1.8,screen_radius)
	puffs.append([raw.y,at,screen_radius,alpha,kind,seed,owner,(root-_clip.position)/_clip.size,restrict,impact_birth,impact_phase])
	if kind<1.5:_plumes_live=true

# The screen rectangle the original drew this object into, near-clipped. Fumes
# are confined to it and, in the shader, to that object's own painted pixels,
# so a plume never extends a hull-down or tree-masked silhouette.
static func drawn_rect(object: Dictionary, frame: Dictionary) -> Rect2:
	var bounds:=Rect2()
	var first:=true
	for polygon: Dictionary in object.get("polygons",[]):
		for point: Array in Geometry.near_clip(polygon.get("camera_vertices",[]),float(frame.near_raw)):
			var at:=Geometry.project(point,frame)
			if not at.is_finite(): continue
			if first: bounds=Rect2(at,Vector2.ZERO);first=false
			else: bounds=bounds.expand(at)
	var clip:=Rect2(Vector2(frame.clip[0],frame.clip[1]),Vector2(frame.clip[2]-frame.clip[0]+1,frame.clip[3]-frame.clip[1]+1))
	return Rect2() if first else bounds.intersection(clip)

static func engine_anchor(object: Dictionary, assets: RefCounted, frame: Dictionary) -> Dictionary:
	var shape:=int(object.get("shape_index",-1))
	if shape not in Modern.EQUIPMENT_SHAPES or shape not in assets.models: return {}
	var model: Dictionary=assets.models[shape]
	var root:=int(object.get("root",-1))
	if root not in model.roots: return {}
	for polygon: Dictionary in object.get("polygons",[]):
		var pid:=int(polygon.get("primitive",-1))
		if pid not in model.roots[root] or pid not in model.faces or int(polygon.get("fill_mode",0))!=1: continue
		var face: Dictionary=model.faces[pid]
		var fit:=Modern.anchor_frame(face.source,polygon.get("camera_vertices",[]),frame)
		if fit.is_empty(): continue
		for triangle: Dictionary in face.triangles:
			if float(triangle.structure_kind)!=Modern.EQUIPMENT_VENT: continue
			var point:=Vector3.ZERO
			for raw: Array in triangle.vertices: point+=Modern.vec(raw)/3.0
			return {"engine":Modern.transform_point(point,fit)}
	return {}

# effect_mappings, when supplied, holds art.mapping(object,camera,palette) for
# every pass object in order (the draw pass already computed them this frame).
func prepare(data: Dictionary, mapping: Dictionary, ownership: Texture2D, assets: RefCounted, art: RefCounted, effect_mappings: Array = []) -> void:
	# Mesh clears happen on every moving-camera pass. Only the next original
	# observation prunes lifetimes; visibility still disappears immediately.
	var previous_births:=_impact_births
	clear()
	_impact_births={}
	if mapping.is_empty() or ownership==null or not assets.supported_palette(data.get("palette_rgb",[])): return
	_frame=data.camera
	_clip=Rect2(Vector2(_frame.clip[0],_frame.clip[1]),Vector2(_frame.clip[2]-_frame.clip[0]+1,_frame.clip[3]-_frame.clip[1]+1))
	var origin: Vector3=mapping.origin
	var to_view: Basis=mapping.inverse.inverse()
	# The source-local basis reverses world Y. In screen-facing coordinates,
	# +X is right, +Y down and +Z toward the optic, matching the puff dome.
	var sun:Vector3=(to_view*Vector3(-0.58,-0.34,0.74)).normalized()
	material.set_shader_parameter("plume_sun",Vector3(sun.x,-sun.z,-sun.y))
	material.set_shader_parameter("plume_world_up",(to_view*Vector3(0,0,1)).normalized())
	material.set_shader_parameter("plume_projection",Vector4(_clip.size.x,_clip.size.y,_clip.position.x-float(_frame.center[0]),float(_frame.center[1])-_clip.position.y)/float(_frame.focal_pixels))
	var allowed:=Image.create(data.objects.size()+1,1,false,Image.FORMAT_RGBA8)
	allowed.fill(Color.BLACK)
	allowed.set_pixel(0,0,Color.WHITE)
	for i in data.objects.size():
		# Original terrain may receive a translucent smoke deployment; actors,
		# trees and fallback commands always stay in front. Vehicle fumes and
		# source effects are confined to their own painted pixels instead.
		if assets.is_terrain(data.objects[i]): allowed.set_pixel(i+1,0,Color.WHITE)
	var effects: Dictionary=data.get("world",{}).get("presentation_effects",{})
	var smoke: Dictionary=effects.get("smoke",{})
	if effects.get("schema",0)==1 and smoke.get("active",false) and world_position_ok(smoke.get("world_position_raw",[])):
		var remaining:=float(smoke.get("remaining_raw",0))
		if remaining>0.0 and remaining<=30.0:
			var age:=clampf((30.0-remaining)/30.0,0.0,1.0)
			var position:=Modern.vec(smoke.world_position_raw)
			var background: Dictionary=data.background if data.get("background") is Dictionary else {}
			var colours: Array=background.colors if background.get("colors") is Array else []
			# Original smoke spawns at the player's position. When the source
			# paints its smoke background and the optic is inside that volume,
			# show immersed billows rather than projecting every root above it.
			var immersed: bool=origin.distance_to(position)<110.0+age*240.0 and background.get("kind","")=="horizon" and colours.size()==2 and int(colours[0])==2 and int(colours[1])==2
			if immersed:
				for i in 15:
					var at:=_clip.position+_clip.size*Vector2((float(i%5)+0.5)/5.0+sin(float(i)*2.3+age*2.0)*0.025,(float(i/5)+0.5)/3.0+cos(float(i)*1.7+age)*0.025)
					var raw:=Modern.vec(Geometry.unproject(at,256.0,_frame))
					_puff(raw,_clip.size.x*256.0/float(_frame.focal_pixels)*0.21,0.23*(1.0-smoothstep(0.85,1.0,age)),0.0,float(i)*0.37+age*0.9,0,at)
			for i in 24 if not immersed else 0:
				var angle:=float(i)*2.399963
				var ring:=sqrt(float(i+1)/24.0)*(110.0+age*240.0)
				var point:=position+Vector3(cos(angle)*ring,sin(angle)*ring,38.0+float(i%5)*23.0+age*110.0)
				var raw: Vector3=to_view*Vector3(point.x-origin.x,origin.y-point.y,point.z-origin.z)
				_puff(raw,85.0+float(i%4)*13.0+age*65.0,0.30*(1.0-smoothstep(0.85,1.0,age)),0.0,float(i)*0.37,0,Geometry.project([raw.x,raw.y,raw.z],_frame))
			counts.smoke=puffs.size()
	var actors:=Modern.dynamic_index(data)
	for i in data.objects.size():
		var object: Dictionary=data.objects[i]
		var owner: int=i+1
		var actor:=actor_for(object,data,actors)
		var seed:=identity_seed(object)
		var effect: Dictionary=effect_mappings[i] if i<effect_mappings.size() else (art.mapping(object,_frame,data.palette_rgb) if art else {})
		if not effect.is_empty():
			# The original bitmap phase supplies the animation. Decorative ash
			# cannot escape its registered footprint or opaque ownership.
			var target: Rect2=effect.target
			var root: Vector2=target.get_center()
			var birth:=-1.0
			if int(effect.donor) in [0,1]:
				# Only the two registered impact donors, never every hot/motor puff.
				# Both impact phases of one source actor share a short burst. A
				# camera/mask rebuild cannot restart it. Unknown identities stay local.
				var pointer:=int(object.get("pointer",-1))
				var key:Array=[pointer] if pointer>=0 else [owner,effect.index,target]
				birth=float(previous_births.get(key,_dynamics_clock))
				_impact_births[key]=birth
			for n in 5:
				var at:=target.position+target.size*Vector2(0.23+float(n)*0.13,0.35+sin(float(n)*2.1+float(effect.index))*0.22)
				var raw:=Modern.vec(Geometry.unproject(at,1024.0,_frame))
				_puff(raw,target.size.x*1024.0/float(_frame.focal_pixels)*0.14,0.17,2.0 if int(effect.donor)!=2 else 0.0,float(n)+float(effect.index)*0.29,owner,root,effect.rect,birth,float(effect.donor) if int(effect.donor) in [0,1] else -1.0)
			counts.effect+=5
		if actor.is_empty(): continue
		# AX 0000:2f04 and the enemy guided-launch path 0000:02c6
		# allocate base+47h, header 100, speed 250 through 0b4d:0214.
		# Original flight code alternates base+47h/48h flare shapes.
		var missile: bool=effects.get("schema",0)==1 and int(object.get("shape_index",-1))-int(effects.get("shape_base",-100)) in [71,72] and int(actor.get("shape_header_word",-1))==100 and not effect.is_empty()
		if missile:
			# The motor glow stays inside the drawn flare's registered footprint.
			# No wake is laid along the RAM travel axis toward its launcher.
			var target: Rect2=effect.target
			var root: Vector2=target.get_center()
			for n in 9:
				var at:=target.position+target.size*Vector2(0.5+cos(float(n)*2.4)*0.07*float(n%3),0.5+sin(float(n)*2.4)*0.07*float(n%3))
				var raw:=Modern.vec(Geometry.unproject(at,1024.0,_frame))
				# Negative phase -2 marks missile RGB only. Puff type, alpha,
				# geometry and existing plume clock retain their original values.
				_puff(raw,target.size.x*1024.0/float(_frame.focal_pixels)*(0.10+float(n%3)*0.035),0.42*(1.0-float(n)/10.0),3.0 if n<2 else 0.0,seed+float(n)*0.41,owner,root,effect.rect,-1.0,-2.0)
			counts.missile+=9
			continue
		var anchored:=engine_anchor(object,assets,_frame)
		if anchored.is_empty(): continue
		# Idle engine fumes rise from the observed vent face of every admitted,
		# visible vehicle alike. RAM speed and heading select nothing, so moving,
		# reversing and stationary vehicles look identical, as in the original.
		# Like the flare glow, they shade only pixels the original painted as
		# this vehicle: no sky halo, and no plume above a crest or tree line.
		var anchor: Vector3=anchored.engine
		var root:=Geometry.project([anchor.x,anchor.y,anchor.z],_frame)
		var hull:=drawn_rect(object,_frame)
		if not hull.has_area() or not hull.has_point(root): continue
		for n in 7:
			var raw:=anchor+to_view*Vector3(0,0,8.0+float(n)*4.0)
			_puff(raw,6.0+float(n)*2.2,0.15*(1.0-float(n)/8.0),1.0,seed+float(n)*0.37,owner,root,hull)
		counts.exhaust+=7
	if puffs.is_empty(): return
	puffs.sort_custom(func(a,b):return a[0]>b[0])
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var uv2:=PackedVector2Array()
	# Each source root gets two texels: packed owner, normalized root/opacity.
	# Texels past the current puff count are never addressed by a vertex.
	for i in puffs.size():
		var p: Array=puffs[i]
		_roots.set_pixel(i*2,0,Color(float(p[6]),float(p[4]),float(p[5]),float(p[9])+1.0 if float(p[9])>=0.0 else 0.0))
		_roots.set_pixel(i*2+1,0,Color(p[7].x,p[7].y,float(p[3]),float(p[10])))
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
			var at: Vector2=p[1]+corner*float(p[2])
			if p[8].has_area(): at=at.clamp(p[8].position,p[8].end)
			var raw: Array=Geometry.unproject(at,float(p[0]),_frame)
			vertices.append(Vector3(raw[0],raw[2],-raw[1])/64.0)
			uv.append((at-Vector2(p[1]))/float(p[2]));uv2.append(Vector2(float(i),1.0 if p[8].has_area() else 0.0))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=uv2
	_mesh.clear_surfaces();_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=_mesh
	_roots_texture.update(_roots)
	material.set_shader_parameter("source_ownership",ownership)
	# The whitelist only changes with the object list; identical bytes keep the
	# uploaded texture, and a changed list gets a fresh exact one.
	if _allowed_texture==null or allowed.get_data()!=_allowed_bytes:
		_allowed_bytes=allowed.get_data()
		_allowed_texture=ImageTexture.create_from_image(allowed)
		material.set_shader_parameter("allowed_terrain",_allowed_texture)
	material.set_shader_parameter("owner_count",float(allowed.get_width()))
	visible=true
