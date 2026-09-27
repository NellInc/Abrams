extends Control
## Genesis illustrations registered into verified original-PC instrument cells.
## No values, states or visibility are inferred from the remastered artwork.
const SOURCE_HASH = "83e46895044a85a4e3abdd8daf836605a40cbb475c02fe2c8b3fe0664da9e036"
# Source rectangles are PC coordinates. Donor rectangles are measured pixels
# in the Genesis-derived 1586x992 illustration, never guessed gameplay values.
const CELLS = [
	{"name":"heat_icon","source":Rect2i(240,141,23,12),"donor":Rect2(1106,649,205,51)},
	{"name":"sabot_icon","source":Rect2i(240,154,23,11),"donor":Rect2(1106,730,205,49)},
	{"name":"ax_icon","source":Rect2i(240,167,23,11),"donor":Rect2(1106,810,205,51)},
	{"name":"coax_icon","source":Rect2i(240,180,23,11),"donor":Rect2(1106,893,205,47)},
	{"name":"smoke_icon","source":Rect2i(285,141,23,12),"donor":Rect2(1347,652,198,44)},
	{"name":"temperature_label","source":Rect2i(285,154,23,11),"donor":Rect2(1347,732,198,45)},
	{"name":"display_icon","source":Rect2i(285,167,23,11),"donor":Rect2(1347,811,198,44)},
	{"name":"target_icon","source":Rect2i(285,180,23,11),"donor":Rect2(1347,894,198,45)},
	{"name":"speed_scale","source":Rect2i(13,178,78,7),"donor":Rect2(76,868,357,29)},
]
var source_plate: Image
var donor: Texture2D
var active: Array[Dictionary] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func load_sources(root: String, art: Image) -> bool:
	clear()
	source_plate = null
	donor = null
	var path := root.path_join("local-art/pc-ui-v2/gps-bin.png")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=SOURCE_HASH: return false
	if art==null or art.get_size()!=Vector2i(1586,992): return false
	source_plate = Image.load_from_file(path)
	donor = ImageTexture.create_from_image(art)
	return true

func clear() -> void:
	active.clear()
	queue_redraw()

func set_frame(source: Image, ui: Image, tags: Image) -> void:
	clear()
	if source_plate==null or donor==null or tags==null: return
	for item in CELLS:
		var box: Rect2i = item.source
		var valid := true
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				if ui.get_pixel(x,y).r!=1.0 or roundi(tags.get_pixel(x,y).r*255)!=1 or source.get_pixel(x,y).to_rgba32()!=source_plate.get_pixel(x,y).to_rgba32():
					valid = false
					break
			if not valid: break
		if valid: active.append(item)
	queue_redraw()

func _draw() -> void:
	if donor==null: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	for item in active: draw_texture_rect_region(donor,Rect2(item.source),item.donor)
