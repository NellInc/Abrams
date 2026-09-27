extends RefCounted
## Authored terrain detail on observed PC surfaces. Never adds geometry.
const PC_PALETTE = preload("res://scripts/pc_tandem_frame.gd").ART_PALETTE
const ASSETS = {
	"field": "36eb892810f7f233b6ca4bff909ce1990ff727e6307350445398e6ef6bd6109c",
	"road": "737334a62f68cde25b62a61356c468888a12071fa1352bace2c32594af8be480"}
const LEVELS = 33
const NEUTRAL = 16
var textures: Dictionary = {}

func load_assets(directory: String) -> bool:
	textures.clear()
	var loaded := {}
	for name in ASSETS:
		var path := directory.path_join(name+".png")
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != ASSETS[name]: return false
		var image := Image.load_from_file(path)
		if image == null or image.is_empty(): return false
		image.generate_mipmaps()
		loaded[name] = ImageTexture.create_from_image(image)
	textures = loaded
	return true

func mapping(frame: Dictionary, palette: Array) -> Dictionary:
	if textures.size() != 2 or palette.size() != 16: return {}
	for i in 16:
		if not palette[i] is Array or palette[i].size() != 3: return {}
		for c in 3:
			if palette[i][c] != PC_PALETTE[i][c]: return {}
	var matrix = frame.get("matrix_q14_columns")
	var position = frame.get("world_position_raw")
	if not matrix is Array or matrix.size() != 9 or not position is Array or position.size() != 3: return {}
	for value in matrix+position:
		if not (value is int or value is float) or not is_finite(float(value)): return {}
	var basis := Basis(Vector3(matrix[0],matrix[1],matrix[2])/16384.0,
		Vector3(matrix[3],matrix[4],matrix[5])/16384.0,Vector3(matrix[6],matrix[7],matrix[8])/16384.0)
	if absf(basis.determinant()) < 0.5 or absf(basis.determinant()) > 1.5: return {}
	return {"inverse":basis.inverse(), "origin":Vector3(position[0],position[1],position[2])}

static func surface_kind(object: Dictionary, polygon: Dictionary) -> int:
	# Explicit source identities, rather than matching colours on arbitrary actors.
	if object.get("dynamic_instance",true) or not object.get("static_path",false): return 0
	if int(polygon.get("fill_mode",0)) == 0 or polygon.get("camera_vertices",[]).size() < 3: return 0
	var shape := int(object.get("shape_index",-1))
	var primitive := int(polygon.get("primitive",-1))
	var colors = polygon.get("colors",[])
	if colors.size() != 2: return 0
	if shape == 48 and primitive == 5123 and colors[0] == 8 and colors[1] == 8: return 1
	if shape >= 49 and shape <= 54 and primitive == 5199+(shape-49)*76 and colors[0] == 3 and colors[1] == 3: return 2
	return 0

static func detail_rgb(rgb: Array, level: int) -> Array:
	var factor := 0.75+float(clampi(level,0,LEVELS-1))/64.0
	return [clampi(roundi(rgb[0]*factor),0,255),clampi(roundi(rgb[1]*factor),0,255),clampi(roundi(rgb[2]*factor),0,255)]

static func world_xy(camera_point: Vector3, inverse: Basis, origin: Vector3) -> Vector2:
	var local := inverse*camera_point
	return Vector2(origin.x+local.x,origin.y-local.y)
