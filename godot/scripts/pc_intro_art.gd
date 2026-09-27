extends Control
## Stateless presentation: every pose and credit comes from a complete PC frame.
## There is deliberately no independent animation clock or input handling here.
const CATALOG_SHA := "1d90451bca98d7c2311ba29c2c9ca09352193c3ef72213c59a895d473bc8e99b"
const Geometry = preload("res://scripts/pc_information_art.gd")
const Typography = preload("res://scripts/pc_typography.gd")
const DEDICATION_RECT := Rect2(8,164,164,30)
const DEDICATION_LINES := [
	["Dedicated to the memory of","6X6.FNT",Vector2(12,168),Color8(170,170,170)],
	["David \"Ming\" Kenny","8X8.FNT",Vector2(18,180),Color.WHITE]
]
var catalog: Dictionary = {}
var textures: Dictionary = {}
var frames: Dictionary = {}
var overlays: Dictionary = {}
var active: Dictionary = {}
var dedication := []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	clear()

func clear() -> void:
	active.clear()
	visible = false
	queue_redraw()

func load_sources(root_path: String) -> bool:
	clear(); catalog.clear(); textures.clear(); frames.clear(); overlays.clear(); dedication.clear()
	var path := root_path.path_join("local-art/pc-intro-v1/intro.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA: return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for name in data.sources:
		path=root_path.path_join("GAME/"+name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.sources[name]: return false
	var loaded := {}
	for name in data.assets:
		var asset: Dictionary=data.assets[name]
		path=root_path.path_join("local-art/genesis/remastered/"+asset.path)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=asset.sha256: return false
		var image := Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(asset.size[0],asset.size[1]): return false
		loaded[name]=ImageTexture.create_from_image(image)
	var memorial := []
	for line in DEDICATION_LINES:
		path=root_path.path_join("GAME/"+line[1])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=Typography.FONT_SOURCES[line[1]]: return false
		var font:=FileAccess.get_file_as_bytes(path)
		var mesh:=Typography.RunLabel.make_mesh({"text":line[0],"cell_size":Vector2(font[0],font[1]),"glyphs":Typography.glyph_geometry(font)})
		memorial.append({"mesh":mesh,"position":line[2],"colour":line[3]})
	for entry in data.entries:
		frames[entry.rgb_sha256]=entry
		var items := []
		for overlay in entry.overlays:
			items.append({"mesh":Geometry.span_mesh(overlay.rects),"colour":Color8(overlay.rgb[0],overlay.rgb[1],overlay.rgb[2])})
		overlays[entry.name]=items
	catalog=data; textures=loaded; dedication=memorial
	return true

func set_frame(source: Image, program: Dictionary) -> bool:
	clear()
	if catalog.is_empty() or program.get("name")!="START": return false
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8: return false
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256);hash.update(source.get_data())
	var fingerprint := hash.finish().hex_encode()
	if not frames.has(fingerprint): return false
	active=frames[fingerprint].duplicate(true)
	active.dedication=active.name=="credit-8"
	visible=true
	queue_redraw()
	return true

static func rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func _draw() -> void:
	if active.is_empty(): return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	draw_texture_rect(textures.title,Rect2(0,0,320,200),false)
	if int(active.flash)>0:
		var flash: Dictionary=catalog.flashes[int(active.flash)-1]
		draw_texture_rect_region(textures.flash,rect(flash.rect),rect(flash.source_rect))
	for overlay in overlays[active.name]:
		draw_mesh(overlay.mesh,null,Transform2D.IDENTITY,overlay.colour)
	# Nell's dedication accompanies the final original copyright card. It never
	# replaces an original credit or delays the PC-owned transition to the menu.
	if active.dedication:
		draw_rect(DEDICATION_RECT,Color8(255,85,85))
		draw_rect(DEDICATION_RECT.grow(-1),Color.BLACK)
		for line in dedication:
			draw_mesh(line.mesh,null,Transform2D(0,line.position),line.colour)
