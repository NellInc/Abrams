extends RefCounted
## Immutable, preloaded presentation geometry. No actor or timeline state.
const Colour = preload("res://scripts/pc_colour.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const PC_PALETTE = preload("res://scripts/pc_tandem_frame.gd").ART_PALETTE
const SHAPE_HASH := "81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193"
const DAY_PALETTE = [[0,0,0],[236,236,220],[155,163,152],[68,76,66],[97,126,158],[158,180,190],
	[146,50,34],[114,102,70],[107,124,72],[151,164,100],[208,199,143],[0,0,0],[205,111,70],[65,86,118],[158,180,190],[236,236,220]]
const SOURCE_HASHES = {"SHAPE.TBL":SHAPE_HASH,
	"SHAPE.GI":"107fc411632ad9754ccc6d82678d7f9de501dad397c3e47a16cdece3dae73faf",
	"SIM.EXE":"9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"}
const TREE_HASH := "4570dea75ccd1f72c7675fc94773aed0495056d2798753dfdbaa4d9f3d131ed7"
# Between the crew painter-depth tag and running gear. Paint only, no new mesh.
const HIND_PAINT := 20.09375
const ARMOUR_PAINT := 20.5
const TWO_TONE_SHAPES := [129,131,133,135,137,139,141,143,159]
const BRIDGE_SHAPES := [0,1,45,46,108,114]
# Pinned original river polygons. Buildings/vehicles sharing blue materials
# cannot inherit water detail merely because their colour happens to match.
const WATER = {
	34: [3567, [3581]],
	35: [3643, [3657]],
	36: [3719, [3733]],
	37: [3795, [3809]],
	38: [3871, [3885]],
	39: [3947, [3961]],
	40: [4023, [4037]],
	41: [4099, [4113]],
	42: [4168, [4182]],
	43: [4237, [4251]],
	44: [4306, [4320]],
	113: [12367, [12411, 12419, 12427, 12435, 12443, 12451, 12459, 12467, 12475, 12483, 12491, 12499, 12507, 12515, 12523, 12531]]}
const ANCHOR_TOLERANCE := 0.25
var revision := 0
var models: Dictionary = {}
var terrain_shapes: Dictionary = {}
var tree_texture: Texture2D
var colour_texture: Texture2D
var colour_indices: Dictionary = {}
var tree_metadata: Dictionary = {}
var status := "Modern assets unavailable"
var ready := false
var disk_io_count := 0
var max_anchor_error := 0.0
var last_reason := ""
var position_cache_hits := 0
var position_cache_misses := 0

func load_assets(root: String) -> bool:
	revision += 1
	models.clear()
	colour_texture=null
	colour_indices.clear()
	terrain_shapes.clear()
	tree_texture = null
	tree_metadata.clear()
	ready = false
	max_anchor_error = 0.0
	status = "Modern assets unavailable"
	if RenderingServer.get_current_rendering_method()!="gl_compatibility":
		status="Modern requires the verified Compatibility renderer"
		return false
	var path := root.path_join("local-art/pc-modern/catalog.json")
	if not _file_exists(path): return false
	disk_io_count += 1
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()>32*1024*1024: return false
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.get("sources") is Dictionary: return false
	if data.sources.get("SHAPE.TBL","") != SHAPE_HASH: return false
	for name in ["SIM.EXE","SHAPE.GI","SHAPE.TBL"]:
		if data.sources.get(name,"")!=SOURCE_HASHES[name]: return false
		var source := root.path_join("GAME/"+str(name))
		if not _file_exists(source) or _sha256(source)!=str(data.sources[name]): return false
	if not configure(data): return false
	load_tree(root)
	if tree_texture==null:
		models.clear()
		ready=false
		status="Modern illustrated tree unavailable or invalid"
		return false
	return true

static func vector_ok(value) -> bool:
	if not value is Array or value.size()!=3: return false
	for v in value:
		if not (v is int or v is float) or not is_finite(float(v)) or absf(float(v))>65536: return false
	return true

static func vec(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

# Also used by synthetic tests. Production entrypoint verifies source files first.
func configure(data: Dictionary) -> bool:
	revision += 1
	position_cache_hits = 0
	position_cache_misses = 0
	models.clear()
	colour_texture=null
	colour_indices.clear()
	terrain_shapes.clear()
	tree_texture = null
	tree_metadata.clear()
	ready = false
	status = "Malformed Modern catalogue"
	if int(data.get("schema",-1))!=1 or not data.get("models") is Array: return false
	var accepted: Dictionary = {}
	for model in data.models:
		if not model is Dictionary or not model.get("triangles") is Array: return false
		var classification := str(model.get("status","authored_mesh"))
		if classification=="source_surface": terrain_shapes[int(model.get("shape_index",-1))]=true
		if classification in ["source_surface","source_command","unresolved_placeholder","source_line","tree_sprite_template"]: continue
		if model.triangles.is_empty(): continue # Explicit unresolved source family.
		var shape := int(model.get("shape_index",-1))
		if shape<0 or shape>255 or shape in accepted or model.triangles.size()>8192: return false
		var original = model.get("source_primitives",{})
		if original is Array:
			var indexed: Dictionary = {}
			for primitive in original:
				if not primitive is Dictionary or not primitive.has("id"): return false
				indexed[str(int(primitive.id))] = primitive.get("vertices",[])
			original = indexed
		if not original is Dictionary or original.is_empty(): return false
		if not model.get("roots") is Array or not model.get("groups") is Array: return false
		var roots: Dictionary = {}
		var groups: Dictionary = {}
		for group in model.groups:
			if not group is Dictionary or not group.get("primitive_pointers") is Array: return false
			groups[int(group.get("offset",-1))] = group.primitive_pointers
		for source_root in model.roots:
			if not source_root is Dictionary or not source_root.get("group_pointers") is Array: return false
			var ids: Array = []
			for group in source_root.group_pointers:
				if int(group) not in groups: return false
				for id in groups[int(group)]: ids.append(int(id))
			roots[int(source_root.get("offset",-1))] = ids
		var faces: Dictionary = {}
		for key in original:
			var raw = original[key]
			if raw is Dictionary: raw = raw.get("vertices",[])
			if not raw is Array or raw.size()>16: return false
			for point in raw:
				if not vector_ok(point): return false
			faces[int(key)] = {"source":raw,"triangles":[]}
		# Source lines remain the original lines. Only verified bridge records
		# may supply a colour; their endpoints, widths and painter path stay put.
		if shape in BRIDGE_SHAPES:
			for line in model.get("source_lines",[]):
				if not line is Dictionary or not line.has("color"):continue
				var pid:=int(line.get("source_primitive",-1))
				if pid not in faces or faces[pid].source.size()!=2 or line.get("vertices",[])!=faces[pid].source:return false
				if not vector_ok(line.color) or not line.get("prefix_bytes") is Array or line.prefix_bytes.size()!=3:return false
				for value in line.prefix_bytes:
					if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(float(value)) or value<0 or value>255:return false
				for channel in line.color:
					if float(channel)<0 or float(channel)>255:return false
				faces[pid].line_colour=line.color
				faces[pid].line_source_colours=line.prefix_bytes.slice(1,3)
		for triangle in model.triangles:
			if not triangle is Dictionary: return false
			var primitive := int(triangle.get("source_primitive",-1))
			if primitive not in faces: return false
			var vertices = triangle.get("vertices",[])
			var rgb = triangle.get("color",[])
			if not vertices is Array or vertices.size()!=3 or not vector_ok(rgb): return false
			for channel in rgb:
				if float(channel)<0 or float(channel)>255: return false
			for point in vertices:
				if not vector_ok(point): return false
			var motion: Dictionary = triangle.get("motion",{}) if triangle.get("motion",{}) is Dictionary else {}
			if motion.get("kind","")=="wheel":
				if not vector_ok(motion.get("center",[])) or not (motion.get("radius",0) is int or motion.get("radius",0) is float) or float(motion.radius)<=0: return false
			if str(triangle.get("component",""))=="track_band" and motion.is_empty(): motion={"kind":"track","period":12.0}
			var structure: bool = shape in [0,1,45,46,47,108,114,145,147,149,151,153,155,157] and triangle.get("material","") in ["plaster","stone_edge","roof","roof_clay","roof_slate","roof_ridge","timber"]
			var normal := (vec(vertices[1])-vec(vertices[0])).cross(vec(vertices[2])-vec(vertices[0]))
			var roof := absf(normal.z)>maxf(absf(normal.x),absf(normal.y))
			var pitched_roof := false
			if structure and roof and shape in [147,149,151,155,157] and model.get("bounds") is Dictionary:
				var height: float=(float(vertices[0][2])+float(vertices[1][2])+float(vertices[2][2]))/3.0
				# Classify slope from the original face. A bevel on a flat roof
				# is not a pitched roof and must not become a clay-coloured rim.
				var source_face: Array=faces[primitive].source
				var source_normal:=Vector3.ZERO
				for corner in range(1,source_face.size()-1):
					source_normal+=(vec(source_face[corner])-vec(source_face[0])).cross(vec(source_face[corner+1])-vec(source_face[0]))
				var horizontal:=maxf(absf(source_normal.x),absf(source_normal.y))
				pitched_roof=horizontal>absf(source_normal.z)*0.08 and absf(source_normal.z)>horizontal and height>lerpf(float(model.bounds.min[2]),float(model.bounds.max[2]),0.65)
			faces[primitive].triangles.append({"vertices":vertices,"color":rgb,"motion":motion,
				"structure_kind":HIND_PAINT if shape in [163,164] and triangle.get("material","") in ["olive","olive_edge"] else ARMOUR_PAINT if shape in TWO_TONE_SHAPES and model.get("paint_style","")=="two_tone_olive" and triangle.get("material","") in ["olive","olive_edge"] else 20.03125 if shape==157 and primitive==28751 else 20.46875 if pitched_roof else 20.4375 if structure and roof else 20.375 if structure else 20.0,
				"structure_axis":0 if absf(normal.x)>absf(normal.y) else 1})
		# Catalogue-bounded, face-local positions only. Every camera fit is still
		# checked and recomputed per mapping; no actor/frame state is retained.
		for face: Dictionary in faces.values():
			var unique: Dictionary = {}
			var unique_corners: Dictionary = {}
			var corners: Array = []
			var positions := PackedVector3Array()
			for triangle: Dictionary in face.triangles:
				var indices := PackedInt32Array()
				var corner_indices := PackedInt32Array()
				for raw: Array in triangle.vertices:
					var point := vec(raw)
					if point not in unique:
						unique[point] = positions.size()
						positions.append(point)
					indices.append(unique[point])
					# Include every attribute input. Shared positions with distinct
					# paint axes or wheel/track metadata remain distinct corners.
					var key := var_to_bytes([raw,triangle.structure_kind,triangle.structure_axis,triangle.motion])
					if key not in unique_corners:
						unique_corners[key] = corners.size()
						corners.append({"raw":raw,"position":unique[point],"kind":triangle.structure_kind,
							"axis":triangle.structure_axis,"motion":triangle.motion})
					corner_indices.append(unique_corners[key])
				triangle.position_indices = indices
				triangle.corner_indices = corner_indices
			face.positions = positions
			face.corners = corners
			face.position_coefficients = compile_position_coefficients(face.source,positions)
		accepted[shape] = {"roots":roots,"faces":faces}
	if accepted.is_empty(): return false
	models = accepted
	colour_indices.clear()
	var rgbs: Array = []
	for model: Dictionary in models.values():
		for face: Dictionary in model.faces.values():
			if face.has("line_colour"):
				var key:=colour_key(face.line_colour)
				if key not in colour_indices:
					colour_indices[key]=rgbs.size();rgbs.append(face.line_colour)
			for triangle: Dictionary in face.triangles:
				var key := colour_key(triangle.color)
				if key not in colour_indices:
					colour_indices[key]=rgbs.size()
					rgbs.append(triangle.color)
	var compatible := RenderingServer.get_current_rendering_method()=="gl_compatibility"
	var image := Image.create(rgbs.size(),1,false,Image.FORMAT_RGBAF if compatible else Image.FORMAT_RGBA8)
	for i in rgbs.size(): image.set_pixel(i,0,Colour.input_color(rgbs[i],compatible))
	colour_texture = ImageTexture.create_from_image(image)
	ready = true
	status = "Modern geometry preloaded: %d source shapes" % models.size()
	return true

static func supported_palette(palette: Array) -> bool:
	if Colour.is_frontend_palette(palette): return true
	if palette.size()!=16: return false
	for i in 16:
		if not palette[i] is Array or palette[i].size()!=3: return false
		for channel in 3:
			if palette[i][channel]!=PC_PALETTE[i][channel]: return false
	return true

static func compile_position_coefficients(source: Array, positions: PackedVector3Array) -> PackedFloat64Array:
	# The source-face basis and point coordinates are catalogue invariants.
	# Preserve transform_point's expression order and double scalar precision.
	# Camera-dependent vectors and independently rounded anchors stay live.
	var output := PackedFloat64Array()
	if source.size()<3: return output
	var origin := vec(source[0])
	var best := 0.0
	var a := -1
	var b := -1
	for i in range(1,source.size()):
		for j in range(i+1,source.size()):
			var area := (vec(source[i])-origin).cross(vec(source[j])-origin).length_squared()
			if area>best: best=area; a=i; b=j
	if best<0.000001: return output
	var u := vec(source[a])-origin
	var v := vec(source[b])-origin
	var n := u.cross(v).normalized()
	var uu := u.length_squared()
	var vv := v.length_squared()
	var uv := u.dot(v)
	var determinant := u.length_squared()*v.length_squared()-pow(u.dot(v),2)
	if determinant==0.0: return output
	for point: Vector3 in positions:
		var d := point-origin
		output.append((d.dot(u)*vv-d.dot(v)*uv)/determinant)
		output.append((d.dot(v)*uu-d.dot(u)*uv)/determinant)
		output.append(d.dot(n))
	return output

# Derive a source-face-local affine frame from the paired original vertices.
# Every source anchor is checked, including vertices not used to fit the basis.
# No ordinary Euler rotation substitutes for SIM's packed/rounded arithmetic.
static func anchor_frame(source: Array, camera: Array, frame: Dictionary) -> Dictionary:
	if source.size()!=camera.size() or source.size()<3: return {}
	for p in camera:
		if not vector_ok(p): return {}
	var origin := vec(source[0])
	var ci := vec(camera[0])
	var best := 0.0
	var a := -1
	var b := -1
	for i in range(1,source.size()):
		for j in range(i+1,source.size()):
			var area := (vec(source[i])-origin).cross(vec(source[j])-origin).length_squared()
			if area>best: best=area; a=i; b=j
	if best<0.000001: return {}
	var u := vec(source[a])-origin
	var v := vec(source[b])-origin
	var cu := vec(camera[a])-ci
	var cv := vec(camera[b])-ci
	var cross := cu.cross(cv)
	if cross.length_squared()<0.000001: return {}
	var scale := sqrt(cross.length()/u.cross(v).length())
	var mapping := {"origin":origin,"camera":ci,"u":u,"v":v,"cu":cu,"cv":cv,
		"n":u.cross(v).normalized(),"cn":cross.normalized()*scale,"error":0.0}
	# Face-invariant scalars retain the original expression order. Per-vertex
	# arithmetic and the piecewise fallback remain unchanged.
	mapping.uu=u.length_squared()
	mapping.vv=v.length_squared()
	mapping.uv=u.dot(v)
	mapping.determinant=u.length_squared()*v.length_squared()-pow(u.dot(v),2)
	var raw_error := 0.0
	for i in source.size():
		var predicted := transform_point(vec(source[i]),mapping)
		var observed := vec(camera[i])
		# Behind-near anchors cannot be projected safely. Check their raw fit;
		# later near clipping always uses the actual observed source boundary.
		var error := predicted.distance_to(observed)*float(frame.focal_pixels)/float(frame.near_raw)
		if predicted.y>=float(frame.near_raw) and observed.y>=float(frame.near_raw):
			error = Geometry.project([predicted.x,predicted.y,predicted.z],frame).distance_to(Geometry.project(camera[i],frame))
		mapping.error = maxf(mapping.error,error)
		raw_error = maxf(raw_error,predicted.distance_to(observed))
	if mapping.error>ANCHOR_TOLERANCE:
		# A rigid float fit cannot reproduce every independently rounded SIM
		# anchor. Interpolate the source triangulation only for <=2 raw units
		# of rounding disagreement; larger disagreements retain source fallback.
		if raw_error>2.0001: return {}
		var plane := PackedVector2Array()
		var axis_x := u.normalized()
		var axis_y: Vector3 = mapping.n.cross(axis_x)
		for p: Array in source:
			var d := vec(p)-origin
			plane.append(Vector2(d.dot(axis_x),d.dot(axis_y)))
		var indices := Geometry2D.triangulate_polygon(plane)
		if indices.is_empty(): return {}
		mapping.merge({"piecewise":true,"plane":plane,"indices":indices,"source":source,
			"observed":camera,"axis_x":axis_x,"axis_y":axis_y})
		mapping.error=0.0
		for i in source.size():
			var predicted := transform_point(vec(source[i]),mapping)
			var observed := vec(camera[i])
			var error := predicted.distance_to(observed)*float(frame.focal_pixels)/maxf(float(frame.near_raw),observed.y)
			mapping.error=maxf(mapping.error,error)
			if error>ANCHOR_TOLERANCE: return {}
	return mapping

static func transform_point(point: Vector3, mapping: Dictionary) -> Vector3:
	var d: Vector3 = point-mapping.origin
	if mapping.get("piecewise",false):
		var p := Vector2(d.dot(mapping.axis_x),d.dot(mapping.axis_y))
		var best := -INF
		var result := Vector3.ZERO
		for i in range(0,mapping.indices.size(),3):
			var ia: int=mapping.indices[i]; var ib: int=mapping.indices[i+1]; var ic: int=mapping.indices[i+2]
			var a: Vector2=mapping.plane[ia]; var b: Vector2=mapping.plane[ib]; var c: Vector2=mapping.plane[ic]
			var denominator := (b-a).cross(c-a)
			if absf(denominator)<0.00000001: continue
			var wb := (p-a).cross(c-a)/denominator
			var wc := (b-a).cross(p-a)/denominator
			var wa := 1.0-wb-wc
			var score := minf(wa,minf(wb,wc))
			if score>best:
				best=score
				var source := vec(mapping.source[ia])*wa+vec(mapping.source[ib])*wb+vec(mapping.source[ic])*wc
				result=vec(mapping.observed[ia])*wa+vec(mapping.observed[ib])*wb+vec(mapping.observed[ic])*wc+mapping.cn*(point-source).dot(mapping.n)
				if score>=-0.000001: break
		return result
	var u: Vector3 = mapping.u
	var v: Vector3 = mapping.v
	var determinant: float = mapping.determinant
	var a: float = (d.dot(u)*mapping.vv-d.dot(v)*mapping.uv)/determinant
	var b: float = (d.dot(v)*mapping.uu-d.dot(u)*mapping.uv)/determinant
	return mapping.camera+mapping.cu*a+mapping.cv*b+mapping.cn*d.dot(mapping.n)

# Explicit coverage gate, independent of draw queue selection. Every emitted
# point lies in the intersection of the source face and the refined triangle.
# The caller inserts results immediately at that source primitive's painter slot.
static func clip_to_source(triangle: Array, source: Array, frame: Dictionary) -> Array:
	var clip := Geometry.near_clip(source,float(frame.near_raw))
	var modern := Geometry.near_clip(triangle,float(frame.near_raw))
	if clip.size()<3 or modern.size()<3: return []
	var boundary := PackedVector2Array()
	var subject := PackedVector2Array()
	for point: Array in clip: boundary.append(Geometry.project(point,frame))
	for point: Array in modern: subject.append(Geometry.project(point,frame))
	var output: Array = []
	for intersection in Geometry2D.intersect_polygons(subject,boundary):
		var indices := Geometry2D.triangulate_polygon(intersection)
		for index in indices:
			# Painter-only screen-space vertices cannot cause depth/shadow leakage.
			output.append(Geometry.unproject(intersection[index],1024.0,frame))
	return output

func mapping(object: Dictionary, polygon: Dictionary, frame: Dictionary, palette: Array, primitive_gate: bool = true, motion_anchor: float = NAN) -> Array:
	last_reason = "unsupported source face"
	if not ready or not supported_palette(palette): return []
	var shape := int(object.get("shape_index",-1))
	if shape not in models or int(polygon.get("fill_mode",0))!=1: return []
	var model: Dictionary = models[shape]
	var source_root := int(object.get("root",-1))
	var primitive := int(polygon.get("primitive",-1))
	if source_root not in model.roots or primitive not in model.roots[source_root] or primitive not in model.faces: return []
	var face: Dictionary = model.faces[primitive]
	var points = polygon.get("camera_vertices",[])
	if not points is Array: return []
	var positions := PackedVector3Array()
	# One catalogue-bounded slot per face. Exact serialized anchor/camera bytes
	# permit reuse only of immutable transformed positions, never clipping, UVs,
	# motion, palette acceptance, identity, ownership or a previous frame result.
	# Packed arrays have value/copy-on-write semantics; callers cannot poison it.
	var position_key := var_to_bytes([points,frame])
	if face.get("position_key",PackedByteArray()) == position_key:
		positions = face.cached_positions
		max_anchor_error = maxf(max_anchor_error,float(face.cached_anchor_error))
		position_cache_hits += 1
	else:
		position_cache_misses += 1
		var fit := anchor_frame(face.source,points,frame)
		if fit.is_empty(): last_reason="source anchor fit unavailable"; return []
		max_anchor_error = maxf(max_anchor_error,float(fit.error))
		positions.resize(face.positions.size())
		if not fit.get("piecewise",false) and face.position_coefficients.size()==face.positions.size()*3:
			var coefficients: PackedFloat64Array = face.position_coefficients
			var camera_origin: Vector3 = fit.camera
			var cu: Vector3 = fit.cu
			var cv: Vector3 = fit.cv
			var cn: Vector3 = fit.cn
			for i in face.positions.size():
				positions[i] = camera_origin+cu*coefficients[i*3]+cv*coefficients[i*3+1]+cn*coefficients[i*3+2]
		else:
			# Source-rounding interpolation keeps the complete original path.
			for i in face.positions.size():
				positions[i] = transform_point(face.positions[i],fit)
		face.position_key = position_key
		face.cached_positions = positions
		face.cached_anchor_error = float(fit.error)
	# Complete attributed corners are face-local too. Clipping only reads them;
	# all returned arrays are newly allocated for this mapping invocation.
	var mapped_corners: Array = []
	var projected_corners := PackedVector2Array()
	var near_y := float(frame.near_raw)
	for corner: Dictionary in face.corners:
		var raw: Array = corner.raw
		var point: Vector3 = positions[corner.position]
		var kind: float = corner.kind
		var motion: Dictionary = corner.motion
		if is_finite(motion_anchor):
			if motion.get("kind","")=="wheel": kind=20.25
			elif motion.get("kind","")=="track": kind=20.125
		var vertex: Array=[point.x,point.y,point.z]
		if kind==HIND_PAINT:
			# Original object-local longitudinal/height coordinates. Both rotor
			# states share the livery; camera movement and rebases cannot slide it.
			vertex.append_array([float(raw[1]),float(raw[2])])
		elif kind==ARMOUR_PAINT:
			# Oblique local projection joins roof and side patches without
			# screen/world-space sliding or seams between owning source faces.
			vertex.append_array([float(raw[1])+float(raw[0])*.45,float(raw[2])+float(raw[0])*.25])
		elif kind>20.3:
			vertex.append_array([float(raw[0]) if int(corner.axis)==1 else float(raw[1]),float(raw[2]) if kind<20.4 else float(raw[1])])
		elif kind>20.2:
			var center: Vector3=vec(motion.center)
			var radius: float=float(motion.radius)
			var mark:=Vector2((float(raw[1])-center.y)/radius,(float(raw[2])-center.z)/radius).rotated(-fposmod(motion_anchor/radius,TAU))
			vertex.append_array([mark.x,mark.y])
		elif kind>20.1:
			vertex.append_array([(float(raw[1])+motion_anchor)/12.0,0.0])
		mapped_corners.append(vertex)
		if not primitive_gate:
			projected_corners.append(Geometry.project(vertex,frame) if point.y>=near_y else Vector2.ZERO)
	var ordered: Array = []
	for triangle: Dictionary in face.triangles:
		var transformed: Array = []
		var depth := 0.0
		var kind: float = triangle.structure_kind
		var motion: Dictionary = triangle.motion
		if is_finite(motion_anchor):
			if motion.get("kind","")=="wheel": kind=20.25
			elif motion.get("kind","")=="track": kind=20.125
		for i in triangle.corner_indices:
			var vertex: Array = mapped_corners[i]
			transformed.append(vertex)
			depth += float(vertex[1])
		ordered.append({"points":transformed,"color":triangle.color,"depth":depth,"kind":kind,"corners":triangle.corner_indices})
	ordered.sort_custom(func(a,b): return a.depth>b.depth)
	var result: Array = []
	for triangle: Dictionary in ordered:
		var clipped: Array
		if primitive_gate:
			clipped = clip_to_source(triangle.points,points,frame)
		elif triangle.points[0][1]>=near_y and triangle.points[1][1]>=near_y and triangle.points[2][1]>=near_y:
			# Same native triangulator, including winding and tiny/degenerate
			# rejection. Only redundant near clipping and projection are skipped.
			var screen := PackedVector2Array()
			for corner_index in triangle.corners: screen.append(projected_corners[corner_index])
			clipped = []
			for index in Geometry2D.triangulate_polygon(screen): clipped.append(triangle.points[index])
		else:
			clipped = Geometry.triangle_vertices(triangle.points,frame)
		if not clipped.is_empty(): result.append({"points":clipped,"color":triangle.color,"depth":triangle.depth,"kind":triangle.kind})
	last_reason = "" if not result.is_empty() else "fully clipped source face"
	return result

static func water_surface(object: Dictionary, polygon: Dictionary) -> bool:
	var shape := int(object.get("shape_index",-1))
	if object.get("dynamic_instance",true) or not object.get("static_path",false) or shape not in WATER: return false
	return int(object.get("root",-1))==WATER[shape][0] and int(polygon.get("primitive",-1)) in WATER[shape][1] and int(polygon.get("fill_mode",0))==1 and polygon.get("colors",[]).size()==2 and polygon.colors[0]==4 and polygon.colors[1]==4

func bridge_line_colour_index(object: Dictionary, polygon: Dictionary, palette: Array) -> int:
	var shape:=int(object.get("shape_index",-1))
	if not ready or shape not in BRIDGE_SHAPES or shape not in models or not supported_palette(palette):return -1
	if not bool(object.get("static_path",false)) or bool(object.get("dynamic_instance",false)):return -1
	var model:Dictionary=models[shape]
	var root_id:=int(object.get("root",-1));var pid:=int(polygon.get("primitive",-1))
	if root_id not in model.roots or pid not in model.roots[root_id] or pid not in model.faces:return -1
	var face:Dictionary=model.faces[pid]
	if not face.has("line_colour") or polygon.get("camera_vertices",[]).size()!=2:return -1
	var colours=polygon.get("colors",[])
	if not colours is Array or colours.size()!=2:return -1
	# JSON numbers load as floats; trace adapters may supply integers. Array
	# equality is type-sensitive in Godot, while scalar numeric equality is not.
	if colours[0]!=face.line_source_colours[0] or colours[1]!=face.line_source_colours[1]:return -1
	return int(colour_indices.get(colour_key(face.line_colour),-1))

func is_terrain(object: Dictionary) -> bool:
	return not bool(object.get("dynamic_instance",false)) and int(object.get("shape_index",-1)) in terrain_shapes

func load_tree(root: String) -> void:
	revision += 1
	var path := root.path_join("local-art/pc-modern/tree.json")
	if not _file_exists(path): return
	var metadata = JSON.parse_string(_read_text(path))
	if not metadata is Dictionary: return
	if int(metadata.get("schema",-1))!=1 or int(metadata.get("shape_index",-1))!=103: return
	if metadata.get("file","")!="tree.png" or metadata.get("sha256","")!=TREE_HASH or float(metadata.get("alpha_cutoff",0))!=0.85: return
	var texture_path := root.path_join("local-art/pc-modern/tree.png")
	if not _file_exists(texture_path): return
	# This author-approved generated asset is immutable, including alpha.
	if _sha256(texture_path)!=TREE_HASH: return
	var image := _read_image(texture_path)
	if image==null or image.get_size()!=Vector2i(1024,1536): return
	image.generate_mipmaps()
	tree_texture = ImageTexture.create_from_image(image)
	tree_metadata = metadata

static func tree_colour_variant(object: Dictionary, frame: Dictionary) -> float:
	# Stable source placement, not painter-slot identity, camera angle or time.
	var delta=object.get("world_delta",[])
	var origin=frame.get("world_position_raw",[])
	if not vector_ok(delta) or not vector_ok(origin): return 0.5
	var x:=roundi(float(delta[0])+float(origin[0]))
	var y:=roundi(float(origin[1])-float(delta[1]))
	return float(posmod(x*31+y*17,257))/256.0

func tree_mapping(object: Dictionary, polygon: Dictionary, frame: Dictionary, palette: Array) -> Array:
	if tree_texture==null or not supported_palette(palette) or int(object.get("shape_index",-1))!=103 or int(object.get("root",-1))!=10523: return []
	var primitive := int(polygon.get("primitive",-1))
	var source: Array = []
	# Exact crossed source planes, no camera-facing or enlarged billboard.
	if primitive==10549: source=[[-160,0,128],[160,0,128],[0,0,480]]
	elif primitive==10564: source=[[0,160,128],[0,-160,128],[0,0,480]]
	elif primitive==10541: source=[[-32,0,0],[32,0,0],[32,0,128],[-32,0,128]]
	elif primitive==10571: source=[[0,32,128],[0,32,0],[0,-32,0],[0,-32,128]]
	else: return []
	var points: Array = polygon.get("camera_vertices",[])
	if source.size()!=points.size() or anchor_frame(source,points,frame).is_empty(): return []
	var uv: Array = []
	var crown := primitive in [10549,10564]
	for raw: Array in source:
		var horizontal: float = raw[0] if primitive in [10549,10541] else raw[1]
		var u := (horizontal/320.0)+0.5
		var v := lerpf(0.805,0.005,(float(raw[2])-128.0)/352.0) if crown else lerpf(0.995,0.805,float(raw[2])/128.0)
		uv.append(Vector2(u,v))
	return Geometry.textured_triangles(points,uv,frame)

static func colour_key(rgb: Array) -> String:
	return "%d,%d,%d"%[int(rgb[0]),int(rgb[1]),int(rgb[2])]

# Instrumented logical asset I/O operations. Frame mapping calls none of these.
func _file_exists(path: String) -> bool:
	disk_io_count += 1
	return FileAccess.file_exists(path)
func _sha256(path: String) -> String:
	disk_io_count += 1
	return FileAccess.get_sha256(path)
func _read_text(path: String) -> String:
	disk_io_count += 1
	return FileAccess.get_file_as_string(path)
func _read_image(path: String) -> Image:
	disk_io_count += 1
	return Image.load_from_file(path)

static func running_gear_anchor(object: Dictionary, pass_data: Dictionary) -> float:
	if not bool(object.get("dynamic_instance",false)): return NAN
	var world = pass_data.get("world")
	if not world is Dictionary or not world.get("dynamic") is Array: return NAN
	var pointer := int(object.get("pointer",-1))
	var shape := int(object.get("shape_index",-1))
	for actor in world.dynamic:
		if not actor is Dictionary or int(actor.get("pointer",-2))!=pointer or int(actor.get("shape_index",-2))!=shape: continue
		var position=actor.get("world_position_raw",[])
		if not position is Array or position.size()!=3: return NAN
		for value in position:
			if not (value is int or value is float) or not is_finite(float(value)): return NAN
		# A deterministic world-position marking phase, not an odometer or
		# physical tangential-travel reconstruction. No camera/yaw/time input.
		return float(position[0])+sqrt(2.0)*float(position[1])
	return NAN
