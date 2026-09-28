extends Control
## Genesis faces inside fully matched original PC portrait pixels.
## SIM draws the face at (37,59) before drawing its caption. Match the current
## portrait itself so a later text observation cannot delay the replacement.
## Every opaque source pixel and UI bit must still independently match.
const SOURCE_AT = Vector2i(37,59) # SIM.EXE:3ee1..3f03, gunner-view crew popup.
const CATALOG_SHA = "ed932398c3897f2727159457290e76e70c28d424ecb58f57998982b2dd626e5b"
const SOURCE_SHA = "e769b71bee8a40023e6ffdb3ac0fd5db0a7485148c1d2eb3fd4fe3b1da6ffa42"
const ART = [
	["commander","commander-v1.png","5f16b256d211dbdbf4dd6a49bf81e8dedd9000444901e691c7081baa77efbbd6"],
	["gunner","gunner-v2.png","60428eddc7c59fbdde2bc0f13693f1c2e2c7e8f3fc0dc6f70774b4c3d8be8e96"],
	["driver","driver-v2.png","fff88ec76c9455500b6564b1c78be5495b3009e4cee728d582b3fd557db548d1"],
	["loader","loader-v1.png","a392fe5714d04c05098eddb17d468f0c41bbdb4d851d67d2ad61742a8819e919"],
]
var templates: Array[Dictionary] = []
var active: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://scripts/pc_portrait_art.gdshader")
	material = shader_material

func clear() -> void:
	active.clear()
	queue_redraw()

func load_sources(root_path: String) -> bool:
	clear()
	templates.clear()
	var source := root_path.path_join("GAME/FACES.BMP")
	var catalogue := root_path.path_join("local-art/pc-portraits-v1/faces.json")
	if not FileAccess.file_exists(source) or FileAccess.get_sha256(source)!=SOURCE_SHA: return false
	if not FileAccess.file_exists(catalogue) or FileAccess.get_sha256(catalogue)!=CATALOG_SHA: return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalogue))
	var pending: Array[Dictionary] = []
	for id in 4:
		var definition: Array = ART[id]
		var path := root_path.path_join("local-art/genesis/remastered/crew-v1/"+definition[1])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=definition[2]: return false
		var art := Image.load_from_file(path)
		if art==null or art.get_size()!=Vector2i(1254,1254): return false
		var original: Dictionary = data.images[id]
		var pixels: Array = original.pixels
		var points: Array[Dictionary] = []
		var right := 0
		for i in pixels.size():
			if int(pixels[i])==0: continue # Proven original preservation mask.
			var p := Vector2i(i%int(original.width),i/int(original.width))
			var rgb: Array = data.palette_rgb[int(pixels[i])]
			points.append({"at":p,"rgb":Color8(rgb[0],rgb[1],rgb[2]).to_rgba32()})
			right = maxi(right,p.x+1)
		var coverage := Image.create_empty(right,int(original.height),false,Image.FORMAT_L8)
		coverage.fill(Color.BLACK)
		for p in points: coverage.set_pixelv(p.at,Color.WHITE)
		pending.append({"id":id,"name":definition[0],"size":coverage.get_size(),"points":points,
			"mask":ImageTexture.create_from_image(coverage),"texture":ImageTexture.create_from_image(art)})
	templates = pending
	return true

func matches(source: Image, ui: Image, item: Dictionary, at: Vector2i) -> bool:
	var box := Rect2i(at,item.size)
	if not Rect2i(0,0,320,200).encloses(box): return false
	for point in item.points:
		var p: Vector2i = at+point.at
		if ui.get_pixelv(p).r!=1.0 or source.get_pixelv(p).to_rgba32()!=point.rgb: return false
	return true

func set_frame(source: Image, ui: Image, _presentation: Dictionary) -> void:
	clear()
	if templates.size()!=4 or source==null or ui==null: return
	if source.get_size()!=Vector2i(320,200) or ui.get_size()!=Vector2i(320,200) or ui.get_format()!=Image.FORMAT_L8: return
	for item in templates:
		# All four identities are tested at the sole source-defined anchor. No
		# queued speaker, text hint, previous frame or timeout can grant visibility.
		if not matches(source,ui,item,SOURCE_AT): continue
		if not active.is_empty():
			clear() # Ambiguous source identities retain original art.
			return
		active = {"id":item.id,"name":item.name,"at":SOURCE_AT,"size":item.size,
			"opaque_pixels":item.points.size(),"texture":item.texture}
		material.set_shader_parameter("original_coverage",item.mask)
	queue_redraw()

func _draw() -> void:
	if active.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	draw_texture_rect(active.texture,Rect2(Vector2(active.at),Vector2(active.size)),false)
