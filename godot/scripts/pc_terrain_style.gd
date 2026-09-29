extends RefCounted
## Authored terrain detail on observed PC surfaces. Never adds geometry.
const PC_PALETTE = preload("res://scripts/pc_tandem_frame.gd").ART_PALETTE
const ASSETS = {
	"field": "36eb892810f7f233b6ca4bff909ce1990ff727e6307350445398e6ef6bd6109c",
	"road": "737334a62f68cde25b62a61356c468888a12071fa1352bace2c32594af8be480"}
const LEVELS = 33
const NEUTRAL = 16
const HILL_HASH := "116177af6cbf7bed7ed484a9cc44267e239e6dfcba90d99ec41cf8895260d123"
const HILL_MEAN := 118.11901436932915/255.0
# Exact roots and filled primitive/material identities in pinned PC SHAPE.TBL.
const HILLS := {
	2: [828, {846:19,854:28,861:28}], 3: [946, {964:19,972:28,979:28}],
	4: [1064, {1082:17,1090:26,1098:26}], 5: [1196, {1214:17,1222:26,1230:26}],
	6: [1328, {1342:19}], 7: [1397, {1411:19}], 8: [1466, {1480:28}], 9: [1535, {1549:28}],
	10: [1604, {1618:19}], 11: [1673, {1687:19}], 12: [1742, {1756:19}], 13: [1811, {1825:19}],
	14: [1880, {1894:28}], 15: [1956, {1970:28}], 16: [2032, {2046:28}], 17: [2108, {2122:28}],
	18: [2184, {2198:28}], 19: [2260, {2274:19}], 20: [2336, {2350:19}], 21: [2412, {2426:19}],
	22: [2488, {2502:19}], 23: [2564, {2584:28,2592:19,2600:19,2608:19}],
	24: [2712, {2734:28,2742:19,2750:19,2758:19,2766:19}],
	25: [2876, {2892:28,2899:19}], 26: [2966, {2982:28,2989:19}],
	27: [3056, {3070:17}], 28: [3132, {3146:26}], 29: [3208, {3222:17}],
	30: [3284, {3298:26}], 31: [3360, {3374:17}], 32: [3429, {3443:26}], 33: [3498, {3512:26}],
	# Raised plateaus and adjoining slopes, including the Escort bridge approach.
	55: [5641, {5655: 19}],
	56: [5717, {5733: 19, 5741: 28}],
	57: [5821, {5839: 19, 5847: 28, 5855: 28}],
	58: [5947, {5963: 19, 5971: 28}],
	59: [6051, {6069: 19, 6077: 28, 6085: 28}],
	60: [6177, {6195: 19, 6203: 28, 6211: 28}],
	61: [6303, {6321: 19, 6329: 28, 6337: 28}],
	62: [6429, {6447: 19, 6455: 28, 6463: 28}],
	63: [6555, {6571: 17, 6579: 26}],
	64: [6659, {6673: 28}],
	65: [6728, {6742: 28}],
	66: [6804, {6818: 28}],
	67: [6873, {6887: 28}],
	68: [6949, {6967: 28, 6975: 19, 6983: 19}],
	69: [7081, {7095: 28}],
	70: [7150, {7164: 28}],
	71: [7219, {7233: 28}]}
# Vertical source faces need height in their UVs. The axis is source-fixed,
# never chosen from a moving camera or a noisy interpolated normal.
const HILL_VERTICAL := {
	854:9,861:9,972:9,979:9,1090:9,1098:9,1222:9,1230:9,
	2592:9,2600:9,2608:8,2742:8,2750:9,2758:9,2766:8,2899:8,2989:8,
	5741:9,5847:8,5855:9,5971:8,6077:9,6085:8,6203:9,6211:8,6329:9,6337:8,6455:9,6463:8,6579:9,6975:9,6983:9}
var textures: Dictionary = {}
var hill_texture: Texture2D

func load_hills(root: String) -> bool:
	hill_texture = null
	if FileAccess.get_sha256(root.path_join("GAME/SHAPE.TBL")) != "81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193": return false
	var path := root.path_join("local-art/genesis/remastered/terrain-v1/hill.png")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=HILL_HASH: return false
	var image := Image.load_from_file(path)
	if image==null or image.is_empty(): return false
	image.generate_mipmaps()
	hill_texture = ImageTexture.create_from_image(image)
	return true

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
	var frontend: bool = preload("res://scripts/pc_colour.gd").is_frontend_palette(palette)
	for i in 16:
		if not palette[i] is Array or palette[i].size() != 3: return {}
		for c in 3:
			if palette[i][c] != PC_PALETTE[i][c] and not frontend: return {}
	var matrix = frame.get("matrix_q14_columns")
	var position = frame.get("world_position_raw")
	if not matrix is Array or matrix.size() != 9 or not position is Array or position.size() != 3: return {}
	for value in matrix+position:
		if not (value is int or value is float) or not is_finite(float(value)): return {}
	var basis := Basis(Vector3(matrix[0],matrix[1],matrix[2])/16384.0,
		Vector3(matrix[3],matrix[4],matrix[5])/16384.0,Vector3(matrix[6],matrix[7],matrix[8])/16384.0)
	if absf(basis.determinant()) < 0.5 or absf(basis.determinant()) > 1.5: return {}
	return {"inverse":basis.inverse(), "origin":Vector3(position[0],position[1],position[2])}

static func surface_kind(object: Dictionary, polygon: Dictionary, hills := false) -> int:
	# Explicit source identities, rather than matching colours on arbitrary actors.
	if object.get("dynamic_instance",true) or not object.get("static_path",false): return 0
	if int(polygon.get("fill_mode",0)) == 0 or polygon.get("camera_vertices",[]).size() < 3: return 0
	var shape := int(object.get("shape_index",-1))
	var primitive := int(polygon.get("primitive",-1))
	var colors = polygon.get("colors",[])
	if colors.size() != 2: return 0
	if shape == 48 and primitive == 5123 and colors[0] == 8 and colors[1] == 8: return 1
	if shape >= 49 and shape <= 54 and primitive == 5199+(shape-49)*76 and colors[0] == 3 and colors[1] == 3: return 2
	if hills and shape in HILLS and int(object.get("root",-1))==HILLS[shape][0]:
		var expected: int = HILLS[shape][1].get(primitive,-1)
		if expected>=0 and colors[0]==expected and colors[1]==expected: return HILL_VERTICAL.get(primitive,7)
	return 0

static func material_mean(palette: Array, words: Array) -> Array:
	var total := [0.0,0.0,0.0]
	for y in 2:
		for x in 2:
			var word: int = int(words[y])
			var index: int = int(words[0])&15 if words[0]==words[1] else (word>>(8 if x==0 else 0))&15
			for c in 3: total[c] += float(palette[index][c])/4.0
	return total

static func detail_rgb(rgb: Array, level: int) -> Array:
	var factor := 0.75+float(clampi(level,0,LEVELS-1))/64.0
	return [clampi(roundi(rgb[0]*factor),0,255),clampi(roundi(rgb[1]*factor),0,255),clampi(roundi(rgb[2]*factor),0,255)]

static func world_xy(camera_point: Vector3, inverse: Basis, origin: Vector3) -> Vector2:
	var local := inverse*camera_point
	return Vector2(origin.x+local.x,origin.y-local.y)
