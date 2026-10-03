extends SceneTree
## Exact output equivalence against the pre-reuse mapping loop. No GPU needed.
const Modern = preload("res://scripts/pc_modern_assets.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
# This exhaustively executes both mapping implementations. Its wall-clock
# budget accommodates a busy development machine; it is not an FPS threshold.
const NUMERICAL_DEADLINE_MSEC := 300000
var failures: Array[String] = []
var checks := 0
var compared_facets := 0
var cases: Array = []
var replay_cases: Array = []
var diagnostic_cases: Array = []
var frame := {"clip":[0,0,319,199],"center":[160,100],"focal_pixels":192,"near_raw":16}
var started := Time.get_ticks_msec()

func _initialize() -> void: run.call_deferred()
# run() is synchronous, so --quit-after cannot stop it; every phase polls this.
func over_deadline() -> bool:
	if Time.get_ticks_msec()-started<=NUMERICAL_DEADLINE_MSEC: return false
	printerr("FAIL: numerical deadline; elapsed_msec=",Time.get_ticks_msec()-started," checks=",checks," facets=",compared_facets);quit(2)
	return true
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and failures.size()<20: failures.append(message)

func compare(art, object: Dictionary, polygon: Dictionary, camera: Dictionary, palette: Array, gate: bool, phase: float) -> void:
	var input_bytes := var_to_bytes([object,polygon,camera,palette])
	var expected := oracle_mapping(art,object,polygon,camera,palette,gate,phase)
	var reason: String = art.last_reason
	var observed: Array = art.mapping(object,polygon,camera,palette,gate,phase)
	check(var_to_bytes(expected)==var_to_bytes(observed),"mapping bytes differ: shape=%s primitive=%s gate=%s phase=%s"%[object.shape_index,polygon.primitive,gate,phase])
	check(reason==art.last_reason,"fallback reason changed")
	check(input_bytes==var_to_bytes([object,polygon,camera,palette]),"mapping mutated input packet")
	var repeated: Array = art.mapping(object,polygon,camera,palette,gate,phase)
	check(var_to_bytes(expected)==var_to_bytes(repeated),"warm transformed-position cache changed mapping bytes")
	compared_facets += expected.size()

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var art = Modern.new()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("local-art/pc-modern/catalog.json")))
	check(art.configure(catalog),"production catalogue configure")
	var source_corners := 0
	var unique_positions := 0
	for shape in art.models:
		var model: Dictionary = art.models[shape]
		for primitive in model.faces:
			var face: Dictionary = model.faces[primitive]
			if face.source.size()<3 or face.triangles.is_empty(): continue
			var root_id := -1
			for candidate in model.roots:
				if primitive in model.roots[candidate]: root_id=candidate;break
			if root_id<0: continue
			var object := {"shape_index":shape,"root":root_id}
			for triangle: Dictionary in face.triangles: source_corners+=triangle.vertices.size()
			unique_positions+=face.positions.size()
			for mode in 3:
				var points: Array = []
				for raw: Array in face.source:
					# Two nontrivial, invertible affine views plus near-plane crossings.
					points.append([raw[0]*0.8+raw[1]*0.6, (4096.0 if mode==0 else 160.0 if mode==1 else 16.0)-raw[0]*0.6+raw[1]*0.8,raw[2]])
				var polygon := {"primitive":primitive,"fill_mode":1,"camera_vertices":points}
				for gate in [false,true]:
					for phase in [NAN,0.0,37.25,-1234.5]:
						compare(art,object,polygon,frame,Modern.PC_PALETTE,gate,phase)
				if mode==0 and face.triangles.size()>50: cases.append([object,polygon,frame,NAN])
			if over_deadline(): return
	# Independently rounded original camera anchors and actual source packet palettes.
	var path := directory.path_join("artifacts/pc-sprite-controls-02/report.json")
	check(FileAccess.file_exists(path),"paired replay fixture missing")
	if FileAccess.file_exists(path):
		var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for index in range(0,replay.render_passes.size(),10):
			var packet: Dictionary = replay.render_passes[index]
			for object: Dictionary in packet.objects:
				var phase := Modern.running_gear_anchor(object,packet)
				for polygon: Dictionary in object.get("polygons",[]):
					for gate in [false,true]: compare(art,object,polygon,packet.camera,packet.palette_rgb,gate,phase)
					if not art.mapping(object,polygon,packet.camera,packet.palette_rgb,false,phase).is_empty(): replay_cases.append([object,polygon,packet.camera,phase])
			if over_deadline(): return
	var diagnostic_path := directory.path_join("artifacts/performance-60fps-20260929/optimized-canvas/diagnostic-draws.json")
	if FileAccess.file_exists(diagnostic_path):
		var diagnostic: Array = JSON.parse_string(FileAccess.get_file_as_string(diagnostic_path))
		for packet: Dictionary in diagnostic:
			for object: Dictionary in packet.objects:
				var phase := Modern.running_gear_anchor(object,packet)
				for polygon: Dictionary in object.get("polygons",[]):
					for gate in [false,true]: compare(art,object,polygon,packet.camera,packet.palette_rgb,gate,phase)
					if not art.mapping(object,polygon,packet.camera,packet.palette_rgb,false,phase).is_empty(): diagnostic_cases.append([object,polygon,packet.camera,phase])
			if over_deadline(): return
	# Explicit piecewise interpolation, >2-unit rejection and palette/identity gates.
	var synthetic := {"schema":1,"models":[{"shape_index":115,"roots":[{"offset":1,"group_pointers":[2]}],"groups":[{"offset":2,"primitive_pointers":[10]}],"source_primitives":{"10":[[-40,0,-20],[40,0,-20],[40,0,20],[-40,0,20]]},"triangles":[{"source_primitive":10,"vertices":[[-40,-4,-20],[40,-4,-20],[40,-4,20]],"color":[90,110,70]},{"source_primitive":10,"vertices":[[-40,-4,-20],[40,-4,20],[-40,-4,20]],"color":[90,110,70]}]}]}
	var probe = Modern.new()
	check(probe.configure(synthetic),"synthetic configure")
	var object := {"shape_index":115,"root":1}
	var polygon := {"primitive":10,"fill_mode":1,"camera_vertices":[[-40,160,-20],[40,160,-20],[40,160,20],[-39,160,20]]}
	var fit := Modern.anchor_frame(probe.models[115].faces[10].source,polygon.camera_vertices,frame)
	check(fit.get("piecewise",false),"piecewise fixture must actually enter fallback")
	for gate in [false,true]: compare(probe,object,polygon,frame,Modern.PC_PALETTE,gate,0.0)
	polygon.camera_vertices[3][0]=-30
	compare(probe,object,polygon,frame,Modern.PC_PALETTE,false,0.0)
	var bad_palette: Array=Modern.PC_PALETTE.duplicate(true);bad_palette[3]=[1,2,3]
	compare(probe,object,polygon,frame,bad_palette,false,0.0)
	object.root=-1;compare(probe,object,polygon,frame,Modern.PC_PALETTE,false,0.0)
	check(not probe.configure({"schema":1,"models":[]}) and probe.models.is_empty(),"failed configure must discard compiled positions")
	check(probe.configure(synthetic),"reload compiled positions")
	object.root=1;polygon.camera_vertices[3][0]=-40
	compare(probe,object,polygon,frame,Modern.PC_PALETTE,false,0.0)
	var retained: Array = probe.mapping(object,polygon,frame,Modern.PC_PALETTE,false,0.0)
	var retained_bytes := var_to_bytes(retained)
	check(probe.position_cache_hits>0,"exact anchors must reuse transformed positions")
	retained[0].points[0][0]+=17
	check(var_to_bytes(probe.mapping(object,polygon,frame,Modern.PC_PALETTE,false,0.0))==retained_bytes,"caller point mutation poisoned transformed-position cache")
	var misses: int = probe.position_cache_misses
	var changed_frame: Dictionary = frame.duplicate(true)
	changed_frame.focal_pixels+=1
	compare(probe,object,polygon,changed_frame,Modern.PC_PALETTE,false,0.0)
	check(probe.position_cache_misses>misses,"camera change reused transformed-position proof")
	misses=probe.position_cache_misses
	polygon.camera_vertices[0][0]+=0.25
	compare(probe,object,polygon,changed_frame,Modern.PC_PALETTE,false,37.25)
	check(probe.position_cache_misses>misses,"in-place source-anchor mutation reused position proof")
	for bad_points in [[],[[0,160,0],[0,160,0],[0,160,0],[0,160,0]],[[-40,160,-20],[40,160,-20],[40,160,20],[NAN,160,20]]]:
		polygon.camera_vertices=bad_points
		compare(probe,object,polygon,frame,Modern.PC_PALETTE,false,0.0)
	var timings: Array = []
	# Alternating measured order, identical corpus; warm both before measuring.
	for round_index in 7:
		var pair := {}
		for optimized in ([false,true] if round_index%2==0 else [true,false]):
			var begin := Time.get_ticks_usec()
			for sample: Array in cases:
				if optimized: art.mapping(sample[0],sample[1],sample[2],Modern.PC_PALETTE,false,sample[3])
				else: oracle_mapping(art,sample[0],sample[1],sample[2],Modern.PC_PALETTE,false,sample[3])
			pair["optimized_ms" if optimized else "before_ms"]=(Time.get_ticks_usec()-begin)/1000.0
		if round_index>0: timings.append(pair)
		if over_deadline(): return
	var replay_timings: Array = []
	for round_index in 7:
		var pair := {}
		for optimized in ([false,true] if round_index%2==0 else [true,false]):
			var begin := Time.get_ticks_usec()
			for sample: Array in replay_cases:
				if optimized: art.mapping(sample[0],sample[1],sample[2],Modern.PC_PALETTE,false,sample[3])
				else: oracle_mapping(art,sample[0],sample[1],sample[2],Modern.PC_PALETTE,false,sample[3])
			pair["optimized_ms" if optimized else "before_ms"]=(Time.get_ticks_usec()-begin)/1000.0
		if round_index>0: replay_timings.append(pair)
		if over_deadline(): return
	var diagnostic_timings: Array = []
	for round_index in 7:
		var pair := {}
		for optimized in ([false,true] if round_index%2==0 else [true,false]):
			var begin := Time.get_ticks_usec()
			for repeat_index in 20:
				for sample: Array in diagnostic_cases:
					if optimized: art.mapping(sample[0],sample[1],sample[2],Modern.PC_PALETTE,false,sample[3])
					else: oracle_mapping(art,sample[0],sample[1],sample[2],Modern.PC_PALETTE,false,sample[3])
			pair["optimized_ms" if optimized else "before_ms"]=(Time.get_ticks_usec()-begin)/20000.0
		if round_index>0: diagnostic_timings.append(pair)
		if over_deadline(): return
	var result := {"checks":checks,"failures":failures,"position_cache_hits":art.position_cache_hits,"position_cache_misses":art.position_cache_misses,"compared_facets":compared_facets,"source_corners":source_corners,"unique_positions":unique_positions,"timing_case_count":cases.size(),"timings":timings,"diagnostic_case_count":diagnostic_cases.size(),"diagnostic_timings":diagnostic_timings,"replay_case_count":replay_cases.size(),"replay_timings":replay_timings,"elapsed_ms":Time.get_ticks_msec()-started}
	# The dated 2026-09-29 snapshot is evidence; write a report only where asked (-- --output <dir>).
	var args := OS.get_cmdline_user_args()
	var at := args.find("--output")+1
	if at>0:
		var output: String = args[at] if at<args.size() else ""
		if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
		var file: FileAccess = FileAccess.open(output.path_join("equivalence.json"),FileAccess.WRITE) if not output.is_empty() else null
		check(file!=null,"cannot write equivalence report: %s"%output)
		if file: file.store_string(JSON.stringify(result,"  "))
	for failure in failures: printerr("FAIL: "+failure)
	print("PC_MODERN_MAPPING_REUSE: %s; %d checks; %d facets; %s"%["PASS" if failures.is_empty() else "FAIL",checks,compared_facets,JSON.stringify(timings)])
	quit(0 if failures.is_empty() else 1)

# Frozen pre-optimization traversal, copied from the before snapshot. Deliberately
# retains repeated vec/transform_point calls, original sort and UV expressions.
func oracle_mapping(art, object: Dictionary, polygon: Dictionary, frame: Dictionary, palette: Array, primitive_gate: bool = true, motion_anchor: float = NAN) -> Array:
	art.last_reason = "unsupported source face"
	if not art.ready or not Modern.supported_palette(palette): return []
	var shape := int(object.get("shape_index",-1))
	if shape not in art.models or int(polygon.get("fill_mode",0))!=1: return []
	var model: Dictionary = art.models[shape]
	var source_root := int(object.get("root",-1))
	var primitive := int(polygon.get("primitive",-1))
	if source_root not in model.roots or primitive not in model.roots[source_root] or primitive not in model.faces: return []
	var face: Dictionary = model.faces[primitive]
	var points = polygon.get("camera_vertices",[])
	if not points is Array: return []
	var fit := Modern.anchor_frame(face.source,points,frame)
	if fit.is_empty(): art.last_reason="source anchor fit unavailable"; return []
	art.max_anchor_error = maxf(art.max_anchor_error,float(fit.error))
	var ordered: Array = []
	for triangle: Dictionary in face.triangles:
		var transformed: Array = []
		var depth := 0.0
		var kind: float=float(triangle.get("structure_kind",20.0))
		var motion: Dictionary=triangle.get("motion",{})
		if is_finite(motion_anchor):
			if motion.get("kind","")=="wheel": kind=20.25
			elif motion.get("kind","")=="track": kind=20.125
		for raw: Array in triangle.vertices:
			var point := Modern.transform_point(Modern.vec(raw),fit)
			var vertex: Array=[point.x,point.y,point.z]
			if kind==Modern.HIND_PAINT:
				# Original object-local longitudinal/height coordinates. Both rotor
				# states share the livery; camera movement and rebases cannot slide it.
				vertex.append_array([float(raw[1]),float(raw[2])])
			elif kind==Modern.ARMOUR_PAINT:
				# Oblique local projection joins roof and side patches without
				# screen/world-space sliding or seams between owning source faces.
				vertex.append_array([float(raw[1])+float(raw[0])*.45,float(raw[2])+float(raw[0])*.25])
			elif kind>20.3:
				# Mirrors the F064 roof-grain fix in pc_modern_assets.gd: roofs (>=20.4) use both horizontal axes.
				vertex.append_array([float(raw[0]) if int(triangle.structure_axis)==1 or kind>=20.4 else float(raw[1]),float(raw[2]) if kind<20.4 else float(raw[1])])
			elif kind>20.2:
				var center: Vector3=Modern.vec(motion.center)
				var radius: float=float(motion.radius)
				var mark:=Vector2((float(raw[1])-center.y)/radius,(float(raw[2])-center.z)/radius).rotated(-fposmod(motion_anchor/radius,TAU))
				vertex.append_array([mark.x,mark.y])
			elif kind>20.1:
				vertex.append_array([(float(raw[1])+motion_anchor)/12.0,0.0])
			transformed.append(vertex)
			depth += point.y
		ordered.append({"points":transformed,"color":triangle.color,"depth":depth,"kind":kind})
	ordered.sort_custom(func(a,b): return a.depth>b.depth)
	var result: Array = []
	for triangle: Dictionary in ordered:
		var clipped := Modern.clip_to_source(triangle.points,points,frame) if primitive_gate else Geometry.triangle_vertices(triangle.points,frame)
		if not clipped.is_empty(): result.append({"points":clipped,"color":triangle.color,"depth":triangle.depth,"kind":triangle.kind})
	art.last_reason = "" if not result.is_empty() else "fully clipped source face"
	return result
