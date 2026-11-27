extends Control
## Genesis faces inside fully matched original PC portrait pixels.
## SIM draws the face at (37,59) before drawing its caption. Match the current
## portrait itself so a later text observation cannot delay the replacement.
## Every opaque source pixel and UI bit must still independently match.
const SOURCE_AT = Vector2i(37,59) # SIM.EXE:3ee1..3f03, gunner-view crew popup.
const CATALOG_SHA = "ed932398c3897f2727159457290e76e70c28d424ecb58f57998982b2dd626e5b"
const SOURCE_SHA = "e769b71bee8a40023e6ffdb3ac0fd5db0a7485148c1d2eb3fd4fe3b1da6ffa42"
const PortraitArtShader = preload("res://scripts/pc_portrait_art.gdshader")
const ART = [
	["commander","commander-v1.png","5f16b256d211dbdbf4dd6a49bf81e8dedd9000444901e691c7081baa77efbbd6"],
	["gunner","gunner-v2.png","60428eddc7c59fbdde2bc0f13693f1c2e2c7e8f3fc0dc6f70774b4c3d8be8e96"],
	["driver","driver-v2.png","fff88ec76c9455500b6564b1c78be5495b3009e4cee728d582b3fd557db548d1"],
	["loader","loader-v1.png","a392fe5714d04c05098eddb17d468f0c41bbdb4d851d67d2ad61742a8819e919"],
]
var templates: Array[Dictionary] = []
var active: Dictionary = {}
const PORTRAIT_BOX := Rect2i(37,59,49,48)
var _last_box_rgb := PackedByteArray()
var _last_box_ui := PackedByteArray()
var _last_template_textures: Array = []
var _last_active: Dictionary = {}
var _last_mask: Texture2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The 1254px faces fill a 49x48 source cell, several times minified at
	# usual window sizes; mipmaps give a filtered downscale instead of aliasing.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader_material := ShaderMaterial.new()
	shader_material.shader = PortraitArtShader
	material = shader_material

func clear() -> void:
	active.clear()
	queue_redraw()

func load_sources(root_path: String) -> bool:
	clear()
	templates.clear()
	_last_box_rgb.clear();_last_box_ui.clear();_last_template_textures.clear();_last_active.clear();_last_mask=null
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
		art.generate_mipmaps()
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
	var l8_ui := ui.get_format() == Image.FORMAT_L8 and ui.get_size() == Vector2i(320,200)
	var ui_bytes := ui.get_data() if l8_ui else PackedByteArray()
	for point in item.points:
		var p: Vector2i = at+point.at
		if (ui_bytes[p.y*320+p.x] != 255 if l8_ui else ui.get_pixelv(p).r!=1.0) or source.get_pixelv(p).to_rgba32()!=point.rgb: return false
	return true

func set_frame(source: Image, ui: Image, _presentation: Dictionary) -> void:
	clear()
	if templates.size()!=4 or source==null or ui==null: return
	if source.get_size()!=Vector2i(320,200) or ui.get_size()!=Vector2i(320,200) or ui.get_format()!=Image.FORMAT_L8: return
	var ui_crop := ui.get_region(PORTRAIT_BOX).get_data()
	# Fast path: when no UI pixels exist in the portrait slot at all, no portrait can match.
	if ui_crop.count(255)==0:
		_last_box_ui = ui_crop
		_last_box_rgb.clear()
		_last_active.clear()
		_last_mask = null
		return
	var template_textures := [templates[0].get("texture"),templates[1].get("texture"),templates[2].get("texture"),templates[3].get("texture")]
	var rgb_crop := source.get_region(PORTRAIT_BOX).get_data() if source.get_format()==Image.FORMAT_RGB8 else PackedByteArray()
	if not rgb_crop.is_empty() and rgb_crop==_last_box_rgb and ui_crop==_last_box_ui and template_textures==_last_template_textures:
		if not _last_active.is_empty():
			active = _last_active.duplicate()
			material.set_shader_parameter("original_coverage",_last_mask)
			queue_redraw()
		return
	var found_mask: Texture2D = null
	for item in templates:
		# All four identities are tested at the sole source-defined anchor. No
		# queued speaker, text hint, previous frame or timeout can grant visibility.
		if not matches(source,ui,item,SOURCE_AT): continue
		if not active.is_empty():
			_last_box_rgb.clear();_last_active.clear();_last_mask=null
			clear() # Ambiguous source identities retain original art.
			return
		active = {"id":item.id,"name":item.name,"at":SOURCE_AT,"size":item.size,
			"opaque_pixels":item.points.size(),"texture":item.texture}
		found_mask = item.mask
		material.set_shader_parameter("original_coverage",item.mask)
	if not rgb_crop.is_empty():
		_last_box_rgb = rgb_crop
		_last_box_ui = ui_crop
		_last_template_textures = template_textures
		_last_active = active.duplicate()
		_last_mask = found_mask
	queue_redraw()

func _draw() -> void:
	if active.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	draw_texture_rect(active.texture,Rect2(Vector2(active.at),Vector2(active.size)),false)
