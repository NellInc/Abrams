extends RefCounted
## Local outline reconstructions of the original faces, with fixed source cells.
const MANIFEST_SHA := "a9d68ef60adbca97c3f3917817c272dacf6f81f5e92171a8cb8cab837fe1b099"
var fonts: Dictionary = {}
var names: Dictionary = {}
var catalog: Dictionary = {}

func load_sources(root_path: String) -> bool:
	fonts.clear();names.clear();catalog.clear()
	var directory:=root_path.path_join("local-art/pc-outline-fonts-v3")
	var path:=directory.path_join("manifest.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=MANIFEST_SHA: return false
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var loaded: Dictionary={}
	for face in data.faces:
		path=root_path.path_join("GAME/"+face.source)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=face.source_sha256: return false
		path=directory.path_join(face.file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=face.sha256: return false
		var font:=FontFile.new()
		font.data=FileAccess.get_file_as_bytes(path)
		font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
		font.hinting=TextServer.HINTING_NONE
		font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
		loaded[face.source_sha256]=font
	fonts=loaded;catalog=data
	for face in data.faces: names[face.source]=fonts[face.source_sha256]
	return true

static func draw_text(target: CanvasItem, font: Font, words: String, box: Rect2, cell: Vector2, colour: Color) -> void:
	if words.is_empty() or box.size.x<=0 or box.size.y<=0: return
	var pixels:=maxi(1,ceili(box.size.y))
	var advance:=words.length()*cell.x/cell.y*float(pixels)
	target.draw_set_transform(box.position,0,Vector2(box.size.x/advance,box.size.y/float(pixels)))
	font.draw_string(target.get_canvas_item(),Vector2(0,pixels),words,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,colour)
	target.draw_set_transform(Vector2.ZERO)
