extends Node3D
## Persistent source-group meshes with face fallback, fitted to this paired pass.
const Modern=preload("res://scripts/pc_modern_assets.gd")
const VehicleShader=preload("res://scripts/pc_tactical_vehicles.gdshader")
const Commands=preload("res://scripts/pc_modern_source_commands.gd")
var instances:Array[MeshInstance3D]=[]
var active_count:=0
var covered:Dictionary={}
var group_count:=0
var head_count:=0
var _flat_shader:Shader
var flat_admitted:Dictionary={}
var pose_admitted:Dictionary={}

func clear() -> void:
	for instance in instances:instance.visible=false
	active_count=0
	group_count=0
	head_count=0
	covered.clear()
	flat_admitted.clear()
	pose_admitted.clear()

static func rigid_group_fit(model:Dictionary,group:Dictionary,object:Dictionary,frame:Dictionary) -> Dictionary:
	var observed:Dictionary={}
	for polygon:Dictionary in object.get("polygons",[]):
		var primitive:=int(polygon.get("primitive",-1))
		if primitive in group.primitives and int(polygon.get("fill_mode",0))==1 and polygon.get("camera_vertices",[]).size()>=3:observed[primitive]=polygon
	# Source-area order is fixed, independent of camera angle or queue ordering.
	for candidate:Dictionary in group.candidates:
		if candidate.primitive not in observed:continue
		var face:Dictionary=model.faces[candidate.primitive]
		var fit:Dictionary=Modern.anchor_frame(face.source,observed[candidate.primitive].camera_vertices,frame)
		if fit.is_empty() or fit.get("piecewise",false):continue
		var transform:=Basis(fit.cu,fit.cv,fit.cn)*Basis(fit.u,fit.v,fit.n).inverse()
		var lengths:=Vector3(transform.x.length(),transform.y.length(),transform.z.length())
		# Three points alone admit shear. A group requires a near-rigid uniform
		# scale as well as agreement with every observed source vertex.
		if not lengths.is_finite() or lengths[lengths.min_axis_index()]<.00001:continue
		if lengths[lengths.max_axis_index()]/lengths[lengths.min_axis_index()]>1.02:continue
		if absf(transform.x.dot(transform.y))/(lengths.x*lengths.y)>.02 or absf(transform.x.dot(transform.z))/(lengths.x*lengths.z)>.02 or absf(transform.y.dot(transform.z))/(lengths.y*lengths.z)>.02:continue
		var valid:=true;var error:=0.0
		for primitive in observed:
			var source:Array=model.faces[primitive].source;var camera:Array=observed[primitive].camera_vertices
			if source.size()!=camera.size():valid=false;break
			for i in source.size():
				if not Modern.vector_ok(camera[i]):valid=false;break
				var actual:=Modern.vec(camera[i]);var predicted:=Modern.transform_point(Modern.vec(source[i]),fit)
				var raw_error:=actual.distance_to(predicted)
				var pixel_error:=raw_error*float(frame.focal_pixels)/float(frame.near_raw)
				if actual.y>=float(frame.near_raw) and predicted.y>=float(frame.near_raw):pixel_error=Modern.Geometry.project(camera[i],frame).distance_to(Modern.Geometry.project([predicted.x,predicted.y,predicted.z],frame))
				error=maxf(error,pixel_error)
				if raw_error>2.0001 or pixel_error>Modern.ANCHOR_TOLERANCE:valid=false;break
			if not valid:break
		if valid:
			return {"basis":transform,"origin":fit.camera-transform*fit.origin,"error":error,"primitive":candidate.primitive}
	return {}

# Admission precedes ownership construction, so one failure keeps the complete
# incumbent command stream and silhouette. No partial body/head substitution.
func admit_poses(assets:RefCounted,data:Dictionary) -> Dictionary:
	pose_admitted.clear()
	if not assets.ready:return pose_admitted
	for index in data.objects.size():
		var object:Dictionary=data.objects[index];var shape:=int(object.get("shape_index",-1))
		if shape not in assets.gpu_poses:continue
		var fit:=pose_fit(assets,object,data.camera)
		if fit.is_empty():continue
		var camera_triangles:Array=[]
		var positions:PackedVector3Array=assets.gpu_poses[shape].positions
		for start in range(0,positions.size(),3):
			var triangle:Array=[]
			for i in 3:
				var point:Vector3=fit.basis*positions[start+i]+fit.origin
				triangle.append([point.x,point.y,point.z])
			camera_triangles.append_array(Modern.Geometry.triangle_vertices(triangle,data.camera))
		if camera_triangles.is_empty():continue
		pose_admitted[index+1]={"basis":fit.basis,"origin":fit.origin,"camera_triangles":camera_triangles,"shape":shape}
	return pose_admitted

static func pose_fit(assets:RefCounted,object:Dictionary,frame:Dictionary) -> Dictionary:
	var shape:=int(object.get("shape_index",-1));var root:=int(object.get("root",-1))
	if object.get("shape_index")!=shape or object.get("root")!=root:return {}
	if shape not in assets.gpu_poses or shape not in assets.models or root not in assets.models[shape].roots:return {}
	if object.has("sprite") or not object.get("polygons") is Array or object.polygons.is_empty():return {}
	if not object.get("round_forms") is Array or object.round_forms.size()!=1 or not object.round_forms[0] is Dictionary:return {}
	var head:Dictionary=assets.gpu_heads[shape]
	if object.round_forms[0].get("command_offset")!=head.command_offset or object.round_forms[0].get("fill_mode")!=1:return {}
	if object.polygons.size()>assets.models[shape].roots[root].size():return {}
	if root not in head.roots or not Commands.crew_head(object,object.round_forms[0]) or Commands.round_runs(object.round_forms[0],frame).is_empty():return {}
	if not object.get("draw_order") is Array or object.draw_order.size()!=object.polygons.size()+1:return {}
	var slots:Dictionary={}
	for entry in object.draw_order:
		if not entry is Dictionary or entry.get("kind") not in ["polygon","round_form"]:return {}
		var at:Variant=entry.get("index")
		if not (at is int or at is float) or not is_finite(float(at)) or float(at)!=floorf(float(at)):return {}
		var key:=str(entry.kind)+":"+str(int(at))
		if key in slots or int(at)<0 or int(at)>=(object.polygons.size() if entry.kind=="polygon" else 1):return {}
		slots[key]=true
	var model:Dictionary=assets.models[shape];var candidates:Array=[];var primitives:Array=[]
	for polygon in object.polygons:
		if not polygon is Dictionary:return {}
		var primitive:=int(polygon.get("primitive",-1))
		if polygon.get("primitive")!=primitive or polygon.get("fill_mode")!=1:return {}
		if primitive in primitives or primitive not in model.roots[root] or primitive not in model.faces or int(polygon.get("fill_mode",0))!=1:return {}
		if not polygon.get("camera_vertices") is Array or polygon.camera_vertices.size()!=model.faces[primitive].source.size() or polygon.camera_vertices.size()<3:return {}
		for point in polygon.camera_vertices:
			if not Modern.vector_ok(point):return {}
		primitives.append(primitive)
		var source:Array=model.faces[primitive].source;var area:=0.0
		for i in range(1,source.size()-1):area=maxf(area,(Modern.vec(source[i])-Modern.vec(source[0])).cross(Modern.vec(source[i+1])-Modern.vec(source[0])).length_squared())
		candidates.append({"primitive":primitive,"area":area})
	candidates.sort_custom(func(a,b):return a.area>b.area if a.area!=b.area else a.primitive<b.primitive)
	var fit:=rigid_group_fit(model,{"primitives":primitives,"candidates":candidates},object,frame)
	return fit if not fit.is_empty() else dynamic_pose_context_fit(model,object,frame)

static func dynamic_pose_context_fit(model:Dictionary,object:Dictionary,frame:Dictionary) -> Dictionary:
	# Small independently rounded source faces can distort a face-seeded fit.
	# The witnessed dynamic Q14 context supplies a candidate only; every source
	# anchor must still pass the same raw/pixel limits before it gains standing.
	var static_value:Variant=object.get("static_path")
	if static_value is bool:
		if static_value:return {}
	elif static_value is int or static_value is float:
		if not is_finite(float(static_value)) or float(static_value)!=0.0:return {}
	else:return {}
	if not object.get("dynamic_instance") is bool or not object.dynamic_instance:return {}
	for field in ["matrix_mode","packed_shift"]:
		var value:Variant=object.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(float(value)):return {}
	if int(object.matrix_mode)<0 or int(object.matrix_mode)>3 or int(object.packed_shift)<0 or int(object.packed_shift)>15:return {}
	var values:Variant=object.get("matrix");var origin_value:Variant=object.get("view_origin")
	if not values is Array or values.size()!=9 or not Modern.vector_ok(origin_value):return {}
	for value in values+origin_value:
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(float(value)) or value<-32768 or value>32767:return {}
	var transform:=Basis(Vector3(values[0],values[1],values[2])/16384.0,Vector3(values[3],values[4],values[5])/16384.0,Vector3(values[6],values[7],values[8])/16384.0)
	var lengths:=Vector3(transform.x.length(),transform.y.length(),transform.z.length())
	# Q14 composition introduces small coefficient truncation, not authored
	# scale or shear. Do not orthonormalize an arbitrary affine context.
	if not lengths.is_finite() or absf(lengths.x-1.0)>.002 or absf(lengths.y-1.0)>.002 or absf(lengths.z-1.0)>.002 or transform.determinant()<=0:return {}
	if absf(transform.x.dot(transform.y))/(lengths.x*lengths.y)>.002 or absf(transform.x.dot(transform.z))/(lengths.x*lengths.z)>.002 or absf(transform.y.dot(transform.z))/(lengths.y*lengths.z)>.002:return {}
	transform=transform.orthonormalized()
	var origin:=Modern.vec(origin_value);var error:=0.0
	for polygon:Dictionary in object.polygons:
		var source:Array=model.faces[int(polygon.primitive)].source
		for i in source.size():
			var actual:=Modern.vec(polygon.camera_vertices[i]);var predicted:=transform*Modern.vec(source[i])+origin
			var raw_error:=actual.distance_to(predicted)
			var pixel_error:=raw_error*float(frame.focal_pixels)/float(frame.near_raw)
			if actual.y>=float(frame.near_raw) and predicted.y>=float(frame.near_raw):pixel_error=Modern.Geometry.project(polygon.camera_vertices[i],frame).distance_to(Modern.Geometry.project([predicted.x,predicted.y,predicted.z],frame))
			if raw_error>2.0001 or pixel_error>Modern.ANCHOR_TOLERANCE:return {}
			error=maxf(error,pixel_error)
	return {"basis":transform,"origin":origin,"error":error,"primitive":-1,"context_fit":true}

func submit_pose(assets:RefCounted,owner:int,ownership:Texture2D,basis:Dictionary) -> int:
	if owner not in pose_admitted:return 0
	var pose:Dictionary=pose_admitted[owner];var instance:=acquire()
	instance.mesh=assets.gpu_poses[pose.shape].mesh
	var material:ShaderMaterial=instance.material_override
	bind_material(material,assets,pose.shape,owner,ownership,basis)
	material.set_shader_parameter("source_group",true)
	material.set_shader_parameter("source_group_basis",pose.basis);material.set_shader_parameter("source_group_origin",pose.origin)
	material.set_shader_parameter("strict_source_coverage",true)
	head_count+=1;group_count+=1
	return int(assets.gpu_poses[pose.shape].triangles)

func prepare_object(assets:RefCounted,object:Dictionary,frame:Dictionary,owner:int,ownership:Texture2D,basis:Dictionary) -> int:
	var shape:=int(object.get("shape_index",-1));var source_root:=int(object.get("root",-1));var count:=0
	if shape in assets.gpu_poses:return 0
	if shape not in assets.gpu_groups or source_root not in assets.models[shape].roots:return 0
	var model:Dictionary=assets.models[shape]
	if shape in assets.PER_FACE_SHAPES:
		# Keep unsupported commands in the complete common fallback. Bridges
		# retain painter order; crew parts use depth inside original coverage.
		var commands:Array=Commands.ordered(object)
		if shape in assets.FLAT_SHAPES and commands.size()>127:return 0
		for item:Dictionary in commands:
			if item.kind!="polygon":continue
			var polygon:Dictionary=item.data
			if int(polygon.get("fill_mode",0))==0 or polygon.get("camera_vertices",[]).size()<3:continue
			var primitive:=int(polygon.get("primitive",-1))
			if int(polygon.get("fill_mode",0))!=1 or primitive not in model.faces or primitive not in model.roots[source_root]:return 0
			var face:Dictionary=model.faces[primitive]
			if Modern.anchor_frame(face.source,polygon.camera_vertices,frame).is_empty():return 0
			if not face.triangles.is_empty() and primitive not in assets.gpu_faces[shape]:return 0
		flat_admitted[owner]=true
		return 0
	for group:Dictionary in assets.gpu_groups[shape].values():
		var allowed:=true
		for primitive in group.primitives:
			if int(primitive) not in model.roots[source_root]:allowed=false;break
		if not allowed:continue
		var fit:=rigid_group_fit(model,group,object,frame)
		if fit.is_empty():continue
		var instance:=acquire()
		if instance.mesh!=group.mesh:instance.mesh=group.mesh
		var material:ShaderMaterial=instance.material_override
		material.set_shader_parameter("source_group",true)
		material.set_shader_parameter("source_group_basis",fit.basis);material.set_shader_parameter("source_group_origin",fit.origin)
		bind_material(material,assets,shape,owner,ownership,basis)
		for primitive in group.primitives:covered[Vector2i(owner,int(primitive))]=true
		assets.max_anchor_error=maxf(assets.max_anchor_error,float(fit.error))
		group_count+=1;count+=int(group.triangles)
	return count

func covers(owner:int,primitive:int) -> bool:
	return Vector2i(owner,primitive) in covered

func submit_head(assets:RefCounted,object:Dictionary,form:Dictionary,frame:Dictionary,owner:int,ownership:Texture2D,basis:Dictionary) -> int:
	var shape:=int(object.get("shape_index",-1))
	if shape in assets.gpu_poses:return 0
	if not assets.ready or shape not in assets.gpu_heads or owner not in flat_admitted or ownership==null:return 0
	var head:Dictionary=assets.gpu_heads[shape]
	if int(object.get("root",-1)) not in head.roots or not Commands.crew_head(object,form):return 0
	# Owner+round coverage cannot disambiguate overlapping round writes from
	# the same object. Keep complete incumbent rendering for such packets.
	if not object.get("round_forms") is Array or object.round_forms.size()!=1 or object.round_forms[0]!=form:return 0
	if Commands.round_runs(form,frame).is_empty() or float(frame.focal_pixels)<=0 or float(frame.near_raw)>=512:return 0
	if 1024.0*(1.0-float(form.radius)/float(frame.focal_pixels))<=float(frame.near_raw):return 0
	var instance:=acquire();instance.mesh=head.mesh
	var material:ShaderMaterial=instance.material_override
	bind_material(material,assets,shape,owner,ownership,basis)
	material.set_shader_parameter("source_round",true)
	material.set_shader_parameter("source_round_center",Vector2(form.center[0],form.center[1]))
	material.set_shader_parameter("source_round_radii",Vector2(form.horizontal_radius,form.radius))
	material.set_shader_parameter("source_projection",Vector3(frame.focal_pixels,frame.center[0],frame.center[1]))
	head_count+=1
	return int(head.triangles)

func submit(assets:RefCounted,object:Dictionary,polygon:Dictionary,frame:Dictionary,owner:int,ownership:Texture2D,basis:Dictionary,source_layer:int=0) -> int:
	if int(polygon.get("fill_mode",0))!=1:return 0
	var shape:=int(object.get("shape_index",-1));var primitive:=int(polygon.get("primitive",-1));var source_root:=int(object.get("root",-1))
	if shape in assets.gpu_poses:return 0
	if shape in assets.PER_FACE_SHAPES and owner not in flat_admitted:return 0
	if shape not in assets.models or primitive not in assets.models[shape].faces or primitive in assets.protected_surfaces.get(shape,{}):return 0
	var model:Dictionary=assets.models[shape]
	if source_root not in model.roots or primitive not in model.roots[source_root]:return 0
	var face:Dictionary=model.faces[primitive]
	var fit:Dictionary=Modern.anchor_frame(face.source,polygon.camera_vertices,frame)
	if fit.is_empty():return 0
	assets.max_anchor_error=maxf(assets.max_anchor_error,float(fit.error))
	# An authored empty face is an intentional void, not permission to restore
	# the old outer plane over an inset hull or roof fitting.
	if face.triangles.is_empty():return -1
	var instance:=acquire()
	var meshes:Dictionary=assets.gpu_faces[shape][primitive]
	var piecewise:bool=fit.get("piecewise",false)
	var selected:ArrayMesh=meshes.piecewise if piecewise else meshes.affine
	if instance.mesh!=selected:instance.mesh=selected
	var material:ShaderMaterial=instance.material_override
	material.set_shader_parameter("source_group",false)
	material.set_shader_parameter("source_piecewise",piecewise)
	material.set_shader_parameter("source_camera",fit.camera)
	material.set_shader_parameter("source_cu",fit.cu);material.set_shader_parameter("source_cv",fit.cv);material.set_shader_parameter("source_cn",fit.cn)
	if piecewise:
		var anchors:=PackedVector3Array();anchors.resize(16)
		for i in polygon.camera_vertices.size():anchors[i]=Modern.vec(polygon.camera_vertices[i])
		material.set_shader_parameter("source_anchors",anchors)
	bind_material(material,assets,shape,owner,ownership,basis)
	material.render_priority=clampi(source_layer,-128,127) if shape in assets.FLAT_SHAPES else 0
	return int(meshes.triangles)

func acquire() -> MeshInstance3D:
	if active_count==instances.size():
		var instance:=MeshInstance3D.new()
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader replaces coefficient-space positions by original camera
		# coordinates. CPU coefficient bounds cannot be used for frustum culling.
		instance.custom_aabb=AABB(Vector3(-100000,-100000,-100000),Vector3(200000,200000,200000))
		var material:=ShaderMaterial.new();material.shader=VehicleShader;instance.material_override=material
		add_child(instance);instances.append(instance)
	var instance:MeshInstance3D=instances[active_count];active_count+=1
	instance.visible=true
	var material:ShaderMaterial=instance.material_override
	for flag in ["source_round","source_group","source_piecewise"]:material.set_shader_parameter(flag,false)
	return instance

func bind_material(material:ShaderMaterial,assets:RefCounted,shape:int,owner:int,ownership:Texture2D,basis:Dictionary) -> void:
	if shape in assets.FLAT_SHAPES and _flat_shader==null:
		_flat_shader=Shader.new()
		_flat_shader.code=VehicleShader.code.replace("depth_draw_opaque","depth_test_disabled,depth_draw_never").replace("void fragment() {","void fragment() {\n    ALPHA=1.0;")
	material.shader=_flat_shader if shape in assets.FLAT_SHAPES else VehicleShader
	material.render_priority=0
	material.set_shader_parameter("source_round",false)
	material.set_shader_parameter("strict_source_coverage",shape not in assets.ROSTER_SHAPES)
	material.set_shader_parameter("instance_owner",float(owner))
	material.set_shader_parameter("source_ownership",ownership)
	var bank:Array=assets.bank_for_shape(shape)
	material.set_shader_parameter("tactical_vehicle_albedo",bank[0])
	material.set_shader_parameter("tactical_vehicle_normal",bank[1])
	material.set_shader_parameter("tactical_vehicle_orm",bank[2])
	material.set_shader_parameter("camera_basis_ready",not basis.is_empty())
	if not basis.is_empty():
		material.set_shader_parameter("camera_to_local",basis.inverse);material.set_shader_parameter("world_origin",basis.origin)
