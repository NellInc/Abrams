extends Control
## Exact visible PC pixels select the newspaper. No score or campaign inference.
const CATALOG_SHA := "9513a1c78ae1e150e95ff0e948378344409e6aae4f79f267a502cf8e73013875"
var entries: Array = []
var images: Dictionary = {}
var active: Dictionary = {}
var high_resolution := true

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	visible=false
	resized.connect(queue_redraw)

func clear() -> void:
	active.clear();visible=false;queue_redraw()

func load_sources(root_path: String) -> bool:
	clear();entries.clear();images.clear()
	var path:=root_path.path_join("local-art/pc-newspapers-v1/newspapers.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA:return false
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for source in data.sources:
		path=root_path.path_join("GAME/"+source)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.sources[source]:return false
	var loaded:Dictionary={}
	for item in data.entries:
		loaded[item.name]={}
		for kind in ["native","art"]:
			var donor:Dictionary=item[kind];path=root_path.path_join(donor.path)
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=donor.sha256:return false
			var im:=Image.load_from_file(path)
			if im==null or im.get_size()!=Vector2i(donor.size[0],donor.size[1]):return false
			loaded[item.name][kind]=ImageTexture.create_from_image(im)
	entries=data.entries;images=loaded
	return true

static func digest(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	return hash.finish().hex_encode()

func set_frame(source: Image, program: Dictionary) -> bool:
	clear()
	if entries.is_empty() or program.get("name")!="END":return false
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8:return false
	var bytes:=source.get_data()
	var header:=digest(bytes.slice(0,320*72*3))
	for item in entries:
		if item.header_sha256!=header:continue
		var height:=200 if digest(bytes)==item.rgb_sha256 else 72
		active={"name":item.name,"height":height,"source":item.source,"whole_plate":height==200}
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if high_resolution else CanvasItem.TEXTURE_FILTER_NEAREST
		visible=true;queue_redraw();return true
	return false

func _draw() -> void:
	if active.is_empty():return
	var donor:Texture2D=images[active.name]["art" if high_resolution else "native"]
	var height:=float(active.height)/200.0
	draw_texture_rect_region(donor,Rect2(Vector2.ZERO,Vector2(size.x,size.y*height)),Rect2(Vector2.ZERO,Vector2(donor.get_width(),donor.get_height()*height)))
