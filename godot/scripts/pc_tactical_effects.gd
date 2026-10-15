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
var _frame: Dictionary
var _clip: Rect2

func _init() -> void:
	material=ShaderMaterial.new()
	material.shader=ShaderSource
	material.render_priority=2
	node=MeshInstance3D.new()
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	clear()

func clear() -> void:
	node.mesh=null
	puffs.clear()
	counts={"smoke":0,"missile":0,"exhaust":0,"dust":0,"effect":0}
	visible=false

static func world_position_ok(value) -> bool:
	# World positions include streamed cell offsets, exceeding the local mesh
	# coordinate bound. Keep the finite original world envelope separate.
	if not value is Array or value.size()!=3:return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component))>1048576.0:return false
	return true

static func actor_for(object: Dictionary, data: Dictionary) -> Dictionary:
	if not object.get("dynamic_instance",false): return {}
	var matched: Dictionary={}
	for actor: Dictionary in data.get("world",{}).get("dynamic",[]):
		if int(actor.get("pointer",-2))!=int(object.get("pointer",-1)) or int(actor.get("shape_index",-2))!=int(object.get("shape_index",-1)): continue
		if not matched.is_empty(): return {} # ambiguous/reused identity
		matched=actor
	if not world_position_ok(matched.get("world_position_raw",[])): return {}
	return matched

# Retain only inputs consumed by this presentation, excluding off-screen pools.
static func inputs(data: Dictionary) -> Array:
	var rows: Array=[data.get("world",{}).get("presentation_effects",{})]
	for object: Dictionary in data.get("objects",[]):
		var actor:=actor_for(object,data)
		rows.append([actor.get("world_position_raw"),actor.get("orientation_u8"),actor.get("speed_raw"),actor.get("shape_header_word")])
	return rows

static func tail_direction(orientation: Array, speed: float) -> Vector3:
	# 0b4d:159c/15e2: local movement is -sin(yaw), cos(yaw),
	# sin(pitch), with horizontal cos(pitch). World south reverses local Y.
	var yaw:=float(orientation[2])*TAU/256.0
	var pitch:=float(orientation[0])*TAU/256.0
	return Vector3(sin(yaw)*cos(pitch),cos(yaw)*cos(pitch),-sin(pitch))*signf(speed)

func _puff(raw: Vector3, radius: float, alpha: float, kind: float, seed: float, owner: int, root: Vector2, restrict: Rect2=Rect2()) -> void:
	if puffs.size()>=MAX_PUFFS or raw.y<=float(_frame.near_raw)+2.0 or radius<=0.0: return
	var at:=Geometry.project([raw.x,raw.y,raw.z],_frame)
	var screen_radius:=radius*float(_frame.focal_pixels)/raw.y
	if screen_radius<0.35 or not _clip.intersects(Rect2(at-Vector2.ONE*screen_radius,Vector2.ONE*screen_radius*2.0)): return
	# Optical LOD affects opacity, never original geometry or source visibility.
	alpha*=smoothstep(0.35,1.8,screen_radius)
	puffs.append([raw.y,at,screen_radius,alpha,kind,seed,owner,(root-_clip.position)/_clip.size,restrict])

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
			var ground:=point
			for source_face: Dictionary in model.faces.values():
				for vertex: Array in source_face.source: ground.z=minf(ground.z,float(vertex[2]))
			ground.z+=6.0
			return {"engine":Modern.transform_point(point,fit),"contact":Modern.transform_point(ground,fit)}
	return {}

func prepare(data: Dictionary, mapping: Dictionary, ownership: Texture2D, assets: RefCounted, art: RefCounted) -> void:
	clear()
	if mapping.is_empty() or ownership==null or not assets.supported_palette(data.get("palette_rgb",[])): return
	_frame=data.camera
	_clip=Rect2(Vector2(_frame.clip[0],_frame.clip[1]),Vector2(_frame.clip[2]-_frame.clip[0]+1,_frame.clip[3]-_frame.clip[1]+1))
	var origin: Vector3=mapping.origin
	var to_view: Basis=mapping.inverse.inverse()
	var allowed:=Image.create(data.objects.size()+1,1,false,Image.FORMAT_RGBA8)
	allowed.fill(Color.BLACK)
	allowed.set_pixel(0,0,Color.WHITE)
	for i in data.objects.size():
		# Original terrain may receive a translucent plume; actors, trees and
		# fallback commands always stay in front. No hidden actor can emit.
		if assets.is_terrain(data.objects[i]): allowed.set_pixel(i+1,0,Color.WHITE)
	var effects: Dictionary=data.get("world",{}).get("presentation_effects",{})
	var smoke: Dictionary=effects.get("smoke",{})
	if effects.get("schema",0)==1 and smoke.get("active",false) and world_position_ok(smoke.get("world_position_raw",[])):
		var remaining:=float(smoke.get("remaining_raw",0))
		if remaining>0.0 and remaining<=30.0:
			var age:=clampf((30.0-remaining)/30.0,0.0,1.0)
			var position:=Modern.vec(smoke.world_position_raw)
			var background: Dictionary=data.get("background",{})
			var colours: Array=background.get("colors",[])
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
	for i in data.objects.size():
		var object: Dictionary=data.objects[i]
		var owner: int=i+1
		var actor:=actor_for(object,data)
		var phase:=Modern.running_gear_anchor(object,data)
		var seed:=fposmod(phase/97.0,1.0) if is_finite(phase) else 0.0
		var effect: Dictionary=art.mapping(object,_frame,data.palette_rgb) if art else {}
		if not effect.is_empty():
			# The original bitmap phase supplies the animation. Decorative ash
			# cannot escape its registered footprint or opaque ownership.
			var target: Rect2=effect.target
			var root: Vector2=target.get_center()
			for n in 5:
				var at:=target.position+target.size*Vector2(0.23+float(n)*0.13,0.35+sin(float(n)*2.1+float(effect.index))*0.22)
				var raw:=Modern.vec(Geometry.unproject(at,1024.0,_frame))
				_puff(raw,target.size.x*1024.0/float(_frame.focal_pixels)*0.14,0.17,2.0 if int(effect.donor)!=2 else 0.0,float(n)+float(effect.index)*0.29,owner,root,effect.rect)
			counts.effect+=5
		if actor.is_empty() or not (actor.get("speed_raw") is int or actor.get("speed_raw") is float) or absf(float(actor.speed_raw))<1.0: continue
		var direction: Array=actor.get("orientation_u8",[])
		if direction.size()!=3: continue
		var orientation_ok:=true
		for value in direction:
			orientation_ok=orientation_ok and (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0.0 and float(value)<=255.0
		if not orientation_ok:continue
		var tail:=tail_direction(direction,float(actor.speed_raw))
		var position:=Modern.vec(actor.world_position_raw)
		# AX 0000:2f04 and the enemy guided-launch path 0000:02c6
		# allocate base+47h, header 100, speed 250 through 0b4d:0214.
		# Original flight code alternates base+47h/48h flare shapes.
		var missile: bool=effects.get("schema",0)==1 and int(object.get("shape_index",-1))-int(effects.get("shape_base",-100)) in [71,72] and int(actor.get("shape_header_word",-1))==100 and not effect.is_empty()
		if missile:
			var root: Vector2=effect.target.get_center()
			for n in 9:
				var point:=position+tail*(float(n)*15.0)+Vector3(0,0,float(n)*2.0)
				var raw: Vector3=to_view*Vector3(point.x-origin.x,origin.y-point.y,point.z-origin.z)
				_puff(raw,7.0+float(n)*2.8,0.42*(1.0-float(n)/10.0),3.0 if n<2 else 0.0,seed+float(n)*0.41,owner,root)
			counts.missile+=9
			continue
		var anchored:=engine_anchor(object,assets,_frame)
		if anchored.is_empty(): continue
		var anchor: Vector3=anchored.engine
		var root:=Geometry.project([anchor.x,anchor.y,anchor.z],_frame)
		var drift: Vector3=to_view*Vector3(tail.x,-tail.y,0)
		for n in 7:
			var raw:=anchor+drift*(float(n)*8.0)+to_view*Vector3(0,0,8.0+float(n)*4.0)
			_puff(raw,6.0+float(n)*2.2,0.15*(1.0-float(n)/8.0),1.0,seed+float(n)*0.37,owner,root)
		counts.exhaust+=7
		# Low dust uses the same observed engine face as visibility anchor. It
		# never guesses a hidden axle, adds collision, or rises across the optic.
		if int(object.shape_index) in [163,164]: continue
		for n in 4:
			var raw: Vector3=anchored.contact+drift*(18.0+float(n)*10.0)
			_puff(raw,9.0+float(n)*3.0,0.11,4.0,seed+float(n)*0.7,owner,root)
		counts.dust+=4
	if puffs.is_empty(): return
	puffs.sort_custom(func(a,b):return a[0]>b[0])
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var uv2:=PackedVector2Array()
	# Each source root gets two texels: packed owner, normalized root/opacity.
	var roots:=Image.create(puffs.size()*2,1,false,Image.FORMAT_RGBAF)
	for i in puffs.size():
		var p: Array=puffs[i]
		roots.set_pixel(i*2,0,Color(float(p[6]),float(p[4]),float(p[5]),0))
		roots.set_pixel(i*2+1,0,Color(p[7].x,p[7].y,float(p[3]),0))
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
			var at: Vector2=p[1]+corner*float(p[2])
			if p[8].has_area(): at=at.clamp(p[8].position,p[8].end)
			var raw: Array=Geometry.unproject(at,float(p[0]),_frame)
			vertices.append(Vector3(raw[0],raw[2],-raw[1])/64.0)
			uv.append((at-Vector2(p[1]))/float(p[2]));uv2.append(Vector2(float(i),1.0 if p[8].has_area() else 0.0))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=uv2
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh
	material.set_shader_parameter("source_ownership",ownership)
	material.set_shader_parameter("allowed_terrain",ImageTexture.create_from_image(allowed))
	material.set_shader_parameter("owner_count",float(allowed.get_width()))
	material.set_shader_parameter("roots",ImageTexture.create_from_image(roots))
	material.set_shader_parameter("root_width",float(roots.get_width()))
	visible=true
