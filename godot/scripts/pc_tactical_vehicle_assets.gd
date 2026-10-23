extends "res://scripts/pc_modern_assets.gd"
## Optional complete roster, validated pair fallback, then incumbent rendering.
var albedo_atlas: Texture2D
var normal_atlas: Texture2D
var orm_atlas: Texture2D
var detail_status := "Tactical vehicle pair unavailable"
var gpu_faces:Dictionary={}
var gpu_groups:Dictionary={}
var gpu_heads:Dictionary={}
var gpu_poses:Dictionary={}
const CrewPose=preload("res://scripts/pc_tactical_crew_pose.gd")
var grounding_bounds:Dictionary={}
var cpu_geometry_released:=false

const ROSTER_SHAPES = [115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,159,160,163,164]
const SCENE_SHAPES = [0,1,45,46,47,108,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164]
# Bridges retain painter ordering; relief crews use opaque depth per source face.
const FLAT_SHAPES = [0,1,45,46,47,108,114]
const CREW_SHAPES = [161,162]
const PER_FACE_SHAPES = [0,1,45,46,47,108,114,161,162]
const SURFACE_PASSTHROUGH = {153:[27177],156:[28325]}
const BANK_SIZES = {"pair":Vector2i(2048,1024),"intact":Vector2i(4096,4096),"wreck":Vector2i(2048,2048),"scene":Vector2i(4096,4096),"bridge":Vector2i(2048,1024)}
const ROSTER_CATALOG_LIMIT = 96*1024*1024
var texture_banks:Dictionary={}
var shape_banks:Dictionary={}
var protected_lines:Dictionary={}
var protected_surfaces:Dictionary={}
var decoded_texture_bytes:=0

func clear_detail() -> void:
	cpu_geometry_released=false
	ready=false;models.clear();gpu_faces.clear();gpu_groups.clear();gpu_heads.clear();gpu_poses.clear();grounding_bounds.clear()
	clear_position_cache();texture_banks.clear();shape_banks.clear();protected_lines.clear();protected_surfaces.clear()
	colour_texture=null;colour_indices.clear();terrain_shapes.clear()
	albedo_atlas=null;normal_atlas=null;orm_atlas=null;decoded_texture_bytes=0

static func face_has_geometry(face:Dictionary) -> bool:
	return bool(face.has_authored_triangles) if face.has("has_authored_triangles") else not face.triangles.is_empty()

func release_cpu_geometry() -> void:
	# Explicit GPU-only lifetime boundary, after full load_detail validation.
	# Working if: Web keeps every mesh and source admission anchor, while the
	# duplicate triangle/corner dictionaries no longer occupy its 2 GiB heap.
	# Reload with load_detail before any recompilation or CPU diagnostics.
	if not ready or cpu_geometry_released:return
	for model:Dictionary in models.values():
		for face:Dictionary in model.faces.values():
			face.has_authored_triangles=not face.triangles.is_empty()
			for key:String in ["triangles","positions","corners","position_coefficients"]:face.erase(key)
	clear_position_cache()
	cpu_geometry_released=true

func mapping(object:Dictionary,polygon:Dictionary,frame:Dictionary,palette:Array,primitive_gate:bool=true,motion_anchor:float=NAN,depth_presort:bool=true) -> Array:
	if cpu_geometry_released:return []
	return super.mapping(object,polygon,frame,palette,primitive_gate,motion_anchor,depth_presort)

func load_detail(root: String) -> bool:
	clear_detail();revision+=1;last_reason=""
	detail_status="Tactical vehicles unavailable"
	var base:=load_catalogue(root)
	if base.is_empty():return false
	var roster:=root.path_join("local-art/pc-tactical-roster-v1")
	if FileAccess.file_exists(roster.path_join("manifest.json")):
		if load_candidate(roster,base,true):
			detail_status="Blender-authored full Tactical vehicle roster preloaded"
			return true
		var failure:=last_reason
		clear_detail();last_reason=failure
		# A failed candidate cannot leave mixed geometry or stale bank textures.
		# Legacy assets independently pass the same source/geometry gates.
	if load_candidate(root.path_join("local-art/pc-tactical-vehicles-v1"),base,false):
		detail_status="Validated Tactical M1A1/T-62 pair preloaded (full roster unavailable)"
		return true
	clear_detail()
	return false

func load_candidate(directory:String,base:Dictionary,roster:bool) -> bool:
	var raw:=_read_bounded(directory.path_join("manifest.json"))
	var manifest:Variant=JSON.parse_string(raw.get_string_from_utf8()) if not raw.is_empty() else null
	if not manifest is Dictionary or not manifest.get("files") is Dictionary:return reject_detail("manifest schema")
	var version:Variant=manifest.get("schema")
	if not (version is int or version is float) or ((version!=2 and version!=3) if roster else version!=1):return reject_detail("manifest schema")
	var scene:bool=roster and manifest.schema==3
	var expected:Array=(SCENE_SHAPES if scene else ROSTER_SHAPES) if roster else [115,125]
	var required_banks:Array=["pair","intact","wreck","scene","bridge"] if scene else ["pair","intact","wreck"]
	var bank_specs:Dictionary={}
	var filenames:Array=["catalog.json"]
	if roster:
		if not integer_list_matches(manifest.get("shapes"),expected) or not manifest.get("banks") is Dictionary or manifest.banks.size()!=required_banks.size():return reject_detail("exact roster and bank set")
		for bank:String in required_banks:
			var spec:Variant=manifest.banks.get(bank)
			if not spec is Dictionary or not integer_list_matches(spec.get("size"),[BANK_SIZES[bank].x,BANK_SIZES[bank].y]) or not spec.get("maps") is Dictionary or spec.maps.size()!=3:return reject_detail("bank dimensions and maps")
			for kind:String in ["albedo","normal","orm"]:
				var name:=bank+"-"+kind+".png"
				if spec.maps.get(kind)!=name:return reject_detail("bank map filename")
				filenames.append(name)
			bank_specs[bank]=spec.maps
	else:
		bank_specs["pair"]={"albedo":"albedo.png","normal":"normal.png","orm":"orm.png"}
		filenames.append_array(["albedo.png","normal.png","orm.png"])
	if manifest.files.size()!=filenames.size():return reject_detail("manifest file set")
	for name:String in filenames:
		if not manifest.files.get(name) is String or _sha256(directory.path_join(name))!=manifest.files[name]:return reject_detail("file hash")
	if roster:
		# Only the expanded authored catalogue gets this bounded allowance.
		# Original registry and all other reads keep their existing 32 MiB cap.
		var file:=FileAccess.open(directory.path_join("catalog.json"),FileAccess.READ)
		if file==null or file.get_length()>ROSTER_CATALOG_LIMIT:return reject_detail("catalogue size")
		disk_io_count+=1;raw=file.get_buffer(file.get_length())
	else:raw=_read_bounded(directory.path_join("catalog.json"))
	var data:Variant=JSON.parse_string(raw.get_string_from_utf8()) if not raw.is_empty() else null
	# Parsing owns its values; do not retain the96MiB input through texture/GPU compilation.
	raw=PackedByteArray()
	if not data is Dictionary or data.get("schema")!=1 or data.get("sources")!=base.sources or data.get("source_registry")!=base.source_registry:return reject_detail("catalogue source pins")
	if not data.get("models") is Array or data.models.size()!=expected.size():return reject_detail("model count")
	var accepted:Dictionary={};var selected_banks:Dictionary={};var heads:Dictionary={}
	for model in data.models:
		if not model is Dictionary or not model.get("triangles") is Array:return reject_detail("model triangles")
		if model.triangles.is_empty() or model.triangles.size()>8192 or model.get("status") not in ["authored_mesh","partial_opaque"]:return reject_detail("authored triangle budget")
		var id:Variant=model.get("shape_index")
		if not (id is int or id is float) or float(id)!=floor(float(id)):return reject_detail("integer shape id")
		var shape:=int(id)
		if shape not in expected or shape in accepted:return reject_detail("unique approved shape")
		var bank:Variant=model.get("texture_bank","pair" if not roster else "")
		if not bank is String or bank not in bank_specs:return reject_detail("model texture bank")
		selected_banks[shape]=bank
		var source:Dictionary=base.models[shape]
		if model.has("command_head"):
			if not validate_command_head(model.command_head,source,model.triangles.size()):return reject_detail("command head schema")
			heads[shape]={"data":model.command_head,"roots":source.roots.filter(func(r):return r.command_pointers.any(func(v):return float(v)==float(model.command_head.command_offset))).map(func(r):return int(r.offset))}
		if model.has("presentation_pose") and not CrewPose.validate(model.presentation_pose,source,model.get("command_head")):return reject_detail("presentation pose schema and bounds")
		var expected_status:String="partial_opaque" if source.get("status")=="partial_opaque" else "authored_mesh"
		if model.get("status")!=expected_status:return reject_detail("partial source status")
		if not integer_list_matches(model.get("source_passthrough",[]),SURFACE_PASSTHROUGH.get(shape,[]) if scene else []):return reject_detail("source passthrough")
		if scene and shape in SURFACE_PASSTHROUGH:
			var primitives:Dictionary={}
			for primitive in source.source_primitives:primitives[int(primitive.id)]=true
			for primitive in SURFACE_PASSTHROUGH[shape]:
				if primitive not in primitives:return reject_detail("pinned passthrough primitive")
		if source.shape_index!=shape or model.get("source_bounds")!=source.source_bounds:return reject_detail("original source bounds")
		for field in REGISTRY_FIELDS:
			if model.has(field):return reject_detail("embedded registry decode")
			model[field]=source[field]
		# Published bridge colour annotations omit their decoded endpoints and
		# prefix. Rejoin only the pinned incumbent records, as Modern does.
		if shape in BRIDGE_SHAPES:model.source_lines=source.source_lines.duplicate(true)
		for triangle in model.triangles:
			if not triangle is Dictionary or not triangle.get("uvs") is Array:return reject_detail("triangle UVs")
			for point in triangle.get("vertices",[]):
				if not vector_ok(point):return reject_detail("finite vertex")
				for axis in 3:
					if point[axis]<source.source_bounds.min[axis]-0.00001 or point[axis]>source.source_bounds.max[axis]+0.00001:return reject_detail("source bounded vertex")
		# These exact two flag primitives always use incumbent authored facets.
		# Their subpixel/collinear stars have no useful texture UV area. Exclude
		# them before UV compilation, retaining the ordinary body UV gate intact.
		if scene and shape in SURFACE_PASSTHROUGH:
			model.triangles=model.triangles.filter(func(t):return int(t.get("source_primitive",-1)) not in SURFACE_PASSTHROUGH[shape])
		accepted[shape]=true
	var loaded_banks:Dictionary={};var bytes:=0
	for bank:String in bank_specs:
		var textures:Array[Texture2D]=[]
		for kind:String in ["albedo","normal","orm"]:
			var pixels:=Image.load_from_file(directory.path_join(bank_specs[bank][kind]));disk_io_count+=1
			if pixels==null or pixels.is_empty() or pixels.get_size()!=BANK_SIZES[bank]:return reject_detail("decoded map dimensions")
			pixels.generate_mipmaps();bytes+=pixels.get_data_size()
			textures.append(ImageTexture.create_from_image(pixels))
		loaded_banks[bank]=textures
	if not configure(data):return reject_detail("geometry and UV schema")
	if models.size()!=expected.size():return reject_detail("configured model count")
	for shape in accepted:
		if scene and shape in SURFACE_PASSTHROUGH:
			protected_surfaces[shape]={}
			for primitive in SURFACE_PASSTHROUGH[shape]:protected_surfaces[shape][primitive]=true
	# Exclude exact passthrough flags: their tall poles are not building footings.
	for shape in models:
		var low:=INF;var high:=-INF
		for face:Dictionary in models[shape].faces.values():
			for triangle:Dictionary in face.triangles:
				for point:Array in triangle.vertices:low=minf(low,point[2]);high=maxf(high,point[2])
		grounding_bounds[shape]=Vector2(low,high) if is_finite(low) and is_finite(high) else Vector2.ZERO
	compile_gpu_faces();compile_gpu_groups(data)
	for shape in heads:
		var head:Dictionary=heads[shape].data
		var positions:=PackedVector3Array();var uvs:=PackedVector2Array()
		for triangle:Dictionary in head.triangles:
			for i in 3:positions.append(vec(triangle.vertices[i]));uvs.append(Vector2(triangle.uvs[i][0],triangle.uvs[i][1]))
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_TEX_UV]=uvs
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		gpu_heads[shape]={"mesh":mesh,"triangles":head.triangles.size(),"command_offset":head.command_offset,"roots":heads[shape].roots}
	compile_gpu_poses(data)
	for shape in models:
		for primitive in models[shape].faces:
			if primitive not in protected_surfaces.get(shape,{}) and not models[shape].faces[primitive].triangles.is_empty() and primitive not in gpu_faces[shape]:return reject_detail("compiled GPU face")
	for shape in models:
		var lines:Dictionary={}
		for primitive in models[shape].faces:
			if models[shape].faces[primitive].source.size()==2:lines[primitive]=true
		if not lines.is_empty():protected_lines[shape]=lines
	texture_banks=loaded_banks;shape_banks=selected_banks;decoded_texture_bytes=bytes
	albedo_atlas=texture_banks.pair[0];normal_atlas=texture_banks.pair[1];orm_atlas=texture_banks.pair[2]
	return true

static func validate_command_head(value:Variant,source:Dictionary,body_count:int) -> bool:
	if int(source.shape_index) not in CREW_SHAPES or not value is Dictionary or value.get("schema")!=1:return false
	var command:Dictionary={}
	for observed:Dictionary in source.get("visual_commands",[]):
		if observed.command_offset==value.get("command_offset") and integer_list_matches(value.get("command"),observed.command_bytes):command=observed;break
	if command.is_empty() or not integer_list_matches(command.command_bytes,[170,15,2,171]) or not vector_ok(command.center_raw) or vec(command.center_raw)!=Vector3.ZERO:return false
	if not source.roots.any(func(r):return r.command_pointers.any(func(v):return float(v)==float(command.command_offset))):return false
	var triangles:Variant=value.get("triangles")
	if not triangles is Array or triangles.size()<100 or triangles.size()>4096 or triangles.size()+body_count>8192:return false
	for triangle in triangles:
		if not triangle is Dictionary or triangle.get("source_primitive")!=command.command_offset:return false
		var vertices:Variant=triangle.get("vertices");var uv:Variant=triangle.get("uvs")
		if not vertices is Array or vertices.size()!=3 or not uv is Array or uv.size()!=3:return false
		for point in vertices:
			if not vector_ok(point) or absf(point[1])>1.0 or point[0]*point[0]+point[2]*point[2]>1.000001:return false
		if (vec(vertices[1])-vec(vertices[0])).cross(vec(vertices[2])-vec(vertices[0])).length_squared()<1e-18:return false
		for point in uv:
			if not point is Array or point.size()!=2:return false
			for number in point:
				if not (number is int or number is float) or not is_finite(float(number)) or number<0 or number>1:return false
		if absf((Vector2(uv[1][0],uv[1][1])-Vector2(uv[0][0],uv[0][1])).cross(Vector2(uv[2][0],uv[2][1])-Vector2(uv[0][0],uv[0][1])))<1e-12:return false
	return true


static func integer_list_matches(value:Variant,expected:Array) -> bool:
	if not value is Array or value.size()!=expected.size():return false
	for i in expected.size():
		if not (value[i] is int or value[i] is float) or float(value[i])!=float(expected[i]):return false
	return true

func reject_detail(reason:String) -> bool:
	last_reason=reason
	return false

func bank_for_shape(shape:int) -> Array:
	return texture_banks.get(shape_banks.get(shape,""),[])

func grounding_height(shape:int,point:Vector3) -> float:
	# Independently observed scene pieces and aircraft keep neutral grounding.
	if shape in PER_FACE_SHAPES or shape in [163,164]:return 1.0
	var extent:Vector2=grounding_bounds.get(shape,Vector2.ZERO)
	return clampf((point.z-extent.x)/(extent.y-extent.x),0.0,1.0) if extent.y-extent.x>0.00001 else 1.0

func compile_gpu_groups(data:Dictionary) -> void:
	# Rigid group meshes contain authored positions, independent of a particular
	# source face. Runtime admission validates every observed group anchor.
	for model:Dictionary in data.models:
		var shape:=int(model.shape_index)
		gpu_groups[shape]={}
		for group:Dictionary in model.groups:
			if shape in PER_FACE_SHAPES:continue
			var positions:=PackedVector3Array();var uv:=PackedVector2Array();var heights:=PackedVector2Array();var candidates:Array=[]
			var primitives:Array[int]=[]
			for primitive in group.primitive_pointers:
				if int(primitive) in protected_surfaces.get(shape,{}):continue
				primitives.append(int(primitive))
				var face:Dictionary=models[shape].faces[int(primitive)]
				if face.source.size()<3:continue
				var area:=0.0
				for i in range(1,face.source.size()):
					for j in range(i+1,face.source.size()):area=maxf(area,(vec(face.source[i])-vec(face.source[0])).cross(vec(face.source[j])-vec(face.source[0])).length_squared())
				candidates.append({"primitive":int(primitive),"area":area})
				for triangle:Dictionary in face.triangles:
					for i in 3:
						positions.append(vec(triangle.vertices[i]));uv.append(Vector2(triangle.uvs[i][0],triangle.uvs[i][1]));heights.append(Vector2(0,grounding_height(shape,vec(triangle.vertices[i]))))
			if positions.is_empty():continue
			candidates.sort_custom(func(a,b):return a.area>b.area if a.area!=b.area else a.primitive<b.primitive)
			var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=heights
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			gpu_groups[shape][int(group.offset)]={"mesh":mesh,"candidates":candidates,"primitives":primitives,"triangles":positions.size()/3}

func compile_gpu_faces() -> void:
	# Fit-independent vertex coefficients are uploaded once. Each observed face
	# updates only its original anchors; no CPU triangle traversal while playing.
	for shape in models:
		gpu_faces[shape]={}
		for primitive in models[shape].faces:
			if primitive in protected_surfaces.get(shape,{}):continue
			var face:Dictionary=models[shape].faces[primitive]
			if face.triangles.is_empty():continue
			var fit:=anchor_frame(face.source,face.source,{"focal_pixels":192.0,"near_raw":16.0,"center":[160,100]})
			if fit.is_empty():continue
			var axis_x:Vector3=fit.u.normalized()
			var axis_y:Vector3=fit.n.cross(axis_x)
			var plane:=PackedVector2Array()
			for raw:Array in face.source:
				var delta:Vector3=vec(raw)-fit.origin
				plane.append(Vector2(delta.dot(axis_x),delta.dot(axis_y)))
			var source_triangles:=Geometry2D.triangulate_polygon(plane)
			if source_triangles.is_empty():continue
			var affine:=PackedVector3Array();var piecewise:=PackedVector3Array()
			var uv:=PackedVector2Array();var ids:=PackedVector2Array();var indices:=PackedInt32Array()
			for corner:Dictionary in face.corners:
				var offset:int=corner.position*3
				affine.append(Vector3(face.position_coefficients[offset],face.position_coefficients[offset+1],face.position_coefficients[offset+2]))
				uv.append(Vector2(corner.extras[0],corner.extras[1]))
				var point:=vec(corner.raw)
				var delta:Vector3=point-fit.origin
				var projected:=Vector2(delta.dot(axis_x),delta.dot(axis_y))
				var best:float=-INF
				var weights:=Vector3.ZERO;var packed:=0
				for i in range(0,source_triangles.size(),3):
					var ia:int=source_triangles[i];var ib:int=source_triangles[i+1];var ic:int=source_triangles[i+2]
					var a:=plane[ia];var b:=plane[ib];var c:=plane[ic]
					var denominator:float=(b-a).cross(c-a)
					if absf(denominator)<0.00000001:continue
					var wb:float=(projected-a).cross(c-a)/denominator
					var wc:float=(b-a).cross(projected-a)/denominator
					var wa:float=1.0-wb-wc
					var score:float=minf(wa,minf(wb,wc))
					if score>best:
						best=score
						var source:Vector3=vec(face.source[ia])*wa+vec(face.source[ib])*wb+vec(face.source[ic])*wc
						weights=Vector3(wa,wb,(point-source).dot(fit.n));packed=ia+ib*16+ic*256
						if score>=-0.000001:break
				piecewise.append(weights);ids.append(Vector2(packed,grounding_height(shape,point)))
			for triangle:Dictionary in face.triangles:indices.append_array(triangle.corner_indices)
			var meshes:Array[ArrayMesh]=[]
			for positions in [affine,piecewise]:
				var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=ids;arrays[Mesh.ARRAY_INDEX]=indices
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes.append(mesh)
			gpu_faces[shape][primitive]={"affine":meshes[0],"piecewise":meshes[1],"triangles":face.triangles.size()}

func compile_gpu_poses(data:Dictionary) -> void:
	for model:Dictionary in data.models:
		if not model.has("presentation_pose"):continue
		var positions:=PackedVector3Array();var uvs:=PackedVector2Array();var heights:=PackedVector2Array()
		for triangle:Dictionary in model.triangles:
			for i in 3:
				positions.append(vec(triangle.vertices[i]));uvs.append(Vector2(triangle.uvs[i][0],triangle.uvs[i][1]));heights.append(Vector2(0,1))
		for triangle:Dictionary in model.command_head.triangles:
			for i in 3:
				positions.append(CrewPose.head_point(model.presentation_pose,triangle.vertices[i]));uvs.append(Vector2(triangle.uvs[i][0],triangle.uvs[i][1]));heights.append(Vector2(0,1))
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TEX_UV2]=heights
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		gpu_poses[int(model.shape_index)]={"mesh":mesh,"positions":positions,"triangles":positions.size()/3}
