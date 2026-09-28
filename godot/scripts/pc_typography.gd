extends Control
## Original letterforms as scalable geometry, after source-glyph/UI-box checks.
const FONT_SOURCES = {
	"6X6.FNT":"a1ab3119ad84f1debb4fda3a57271e08ed9f0bdf1e535a5885a92758e07d5840",
	"8X6.FNT":"aa295b11f913a8829baf0590fc9405a602deae2a50a00ee592ffaac2f1099567",
	"8X8.FNT":"857af65a215ccfcf92508ad43848c63e08bcef7ed2da2f3bcd75b670cd515812",
	"STENCIL.FNT":"3f92e8c7488278d86aeaa978d87d980d6a688fc9c8dbf87befaf4e6bbc9f4181"}
var fonts: Dictionary = {}
var font_geometry: Dictionary = {}
var runs: Array[Dictionary] = []
var labels: Array[Control] = []
var world_ink: Array[Vector2i] = []
var fixed_labels_enabled := false
var status_numbers_enabled := false
var dialogue_glyphs: Dictionary = {}
var outline_fonts = preload("res://scripts/pc_outline_fonts.gd").new()
# Bounded expected glyph bytes only. Never cache source/UI validity, pixel
# hashes, event identities or caller-visible run dictionaries. Colours are part
# of the expected-byte key, never inherited from an earlier source packet.
var _expected_text: Dictionary = {}
const EXPECTED_TEXT_LIMIT := 64
# These words are confirmed in the source screens. Each candidate still has to
# match every original font bit and every UI pixel before it may be redrawn.
const FIXED_LABELS = [
	["HDG",66,191],["SPD",114,191],["FUEL",156,191],["TMP",210,191],
	["ID:",16,143],["RANGE",16,154],["HEADING",128,188],
	["HEADING",216,134],["E",104,179],["F",154,179],
	["GPS",35,110],["Smoke Dischargers",35,123],["COAX machine gun",35,136],
	["Main Gun",35,149],["Ballistic Computer",35,162],["Thermal Equipment",35,175],
	["Radio Equipment",166,110],["Halon",166,123],["Turret Motors",166,136],
	["Left Tread",166,149],["Right Tread",166,162],["Engine",166,175]]

class RunLabel extends Control:
	var run: Dictionary
	var mesh: ArrayMesh
	var mesh_key := ""
	func _draw() -> void:
		if run.is_empty(): return
		if not run.get("transparent_world",false): draw_rect(Rect2(Vector2.ZERO,size),run.background)
		if run.get("outline_font") is Font:
			preload("res://scripts/pc_outline_fonts.gd").draw_text(self,run.outline_font,run.text,Rect2(Vector2.ZERO,size),run.cell_size,run.foreground)
			return
		# Cache only this label's current text. No unbounded cache of live values.
		var key: String = run.font_sha256+run.text
		if key!=mesh_key:
			mesh = make_mesh(run)
			mesh_key = key
		if mesh==null: return
		draw_set_transform(Vector2.ZERO,0,size/run.rect.size)
		draw_mesh(mesh,null,Transform2D.IDENTITY,run.foreground)
		draw_set_transform(Vector2.ZERO)

	static func make_mesh(value: Dictionary) -> ArrayMesh:
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		for i in value.text.length():
			var offset := Vector2(i*value.cell_size.x,0)
			for rect: Rect2 in value.glyphs[value.text.unicode_at(i)]:
				var a := rect.position+offset
				var b := rect.end+offset
				var start := vertices.size()
				vertices.append_array(PackedVector3Array([Vector3(a.x,a.y,0),
					Vector3(b.x,a.y,0),Vector3(b.x,b.y,0),Vector3(a.x,b.y,0)]))
				indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
		if vertices.is_empty(): return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

static func glyph_geometry(bytes: PackedByteArray) -> Dictionary:
	# One rectangle per contiguous ink span, with the original side bearings,
	# baseline, counters and stencil cuts. No autotracing, smoothing or lookalike.
	var result := {}
	var width := int(bytes[0])
	var height := int(bytes[1])
	var stride := (width+7)/8
	for code in range(32,127):
		var spans: Array[Rect2] = []
		for y in height:
			var start := -1
			for x in range(width+1):
				var ink := false
				if x<width:
					var at := 4+((code-int(bytes[2]))*height+y)*stride+x/8
					ink = (int(bytes[at]) & (128>>(x%8)))!=0
				if ink and start<0: start=x
				if not ink and start>=0:
					spans.append(Rect2(start,y,x-start,1))
					start=-1
		result[code] = spans
	return result

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(_layout)

func load_sources(directory: String) -> bool:
	fonts.clear()
	_expected_text.clear()
	font_geometry.clear()
	dialogue_glyphs.clear()
	clear_runs()
	var found := {}
	for name in FONT_SOURCES:
		var path := directory.path_join(name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=FONT_SOURCES[name]: return false
		found[FONT_SOURCES[name]] = FileAccess.get_file_as_bytes(path)
	fonts = found
	outline_fonts.load_sources(directory.get_base_dir())
	for sha in fonts: font_geometry[sha] = glyph_geometry(fonts[sha])
	var dialogue: PackedByteArray = fonts[FONT_SOURCES["8X8.FNT"]]
	for code in range(32,127):
		var at := 4+(code-int(dialogue[2]))*8
		var key := dialogue.slice(at,at+8).hex_encode()
		# Ambiguous source glyphs can never be silently assigned a character.
		dialogue_glyphs[key] = "" if dialogue_glyphs.has(key) else String.chr(code)
	return true

func clear_runs() -> void:
	runs.clear()
	world_ink.clear()
	for label in labels: label.hide()

func _fixed_candidate(words: String, at: Vector2i, source: Image, font_name: String="6X6.FNT") -> Dictionary:
	var font: PackedByteArray = fonts[FONT_SOURCES[font_name]]
	var cell := Vector2i(font[0],font[1])
	var box := Rect2i(at,Vector2i(words.length()*cell.x,cell.y))
	var crop := source.get_region(box)
	crop.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	return {"text":words,"rect":[box.position.x,box.position.y,box.size.x,box.size.y],
		"font_sha256":FONT_SOURCES[font_name],"cell_size":[cell.x,cell.y],"foreground":1,
		"uniform_background_rgb":[0,0,0],"pixel_sha256":hash.finish().hex_encode(),"kind":"verified_fixed_cell"}

func set_office_dialogue(source: Image, border_y: int) -> void:
	clear_runs()
	if dialogue_glyphs.is_empty() or source==null or source.get_size()!=Vector2i(320,200): return
	if border_y not in [137,147,157,167,177,187,200]: return
	var candidates: Array = []
	for y in range(border_y+2,192,10):
		var words := ""
		var valid := true
		for column in 38:
			var bits := PackedByteArray()
			for dy in 8:
				var row := 0
				for dx in 8:
					var rgb := source.get_pixel(8+column*8+dx,y+dy).to_rgba32()
					if rgb==0xffffffff: row|=128>>dx
					elif rgb!=0x5555ffff: valid=false
				bits.append(row)
			var character: String = dialogue_glyphs.get(bits.hex_encode(),"")
			if character.is_empty(): valid=false
			words+=character
		if not valid or words.strip_edges().is_empty(): continue
		var candidate := _fixed_candidate(words,Vector2i(8,y),source,"8X8.FNT")
		candidate.uniform_background_rgb=[85,85,255]
		candidate.kind="verified_office_dialogue"
		candidates.append(candidate)
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE) # Caller already proved the original office/dialogue layout.
	# Only foreground entry 1 is used. Background comes from its exact RGB cell.
	var palette: Array = []
	for i in 16: palette.append([255,255,255] if i==1 else [0,0,0])
	set_frame(source,ui,{"text_runs":candidates,"palette_rgb":palette})

func set_information_page(source: Image, fields: Array) -> void:
	# Caller proves the complete original page. Each text cell is checked again
	# against the original font before applying its existing presentation colours.
	clear_runs()
	if fonts.is_empty(): return
	var candidates: Array=[]
	var palette: Array=[]
	for field in fields:
		if not palette.has(field.source_foreground): palette.append(field.source_foreground)
		var candidate:=_fixed_candidate(field.text,Vector2i(field.rect[0],field.rect[1]),source,field.font)
		candidate.foreground=palette.find(field.source_foreground)
		candidate.uniform_background_rgb=field.source_background
		candidate.kind="verified_information_text"
		candidates.append(candidate)
	while palette.size()<16: palette.append([0,0,0])
	var ui:=Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	set_frame(source,ui,{"text_runs":candidates,"palette_rgb":palette})
	for run in runs:
		for field in fields:
			if run.text!=field.text or run.rect.position!=Vector2(field.rect[0],field.rect[1]): continue
			run.foreground=Color8(field.foreground[0],field.foreground[1],field.foreground[2])
			run.background=Color8(field.background[0],field.background[1],field.background[2])
			break
	_layout()

func _status_number(source: Image, y: int) -> Dictionary:
	# Three original right-aligned digit cells. Exact glyph lookup, not OCR or
	# a value from current simulation RAM; only the already visible digits count.
	if not fonts.has(FONT_SOURCES["6X6.FNT"]): return {}
	var bytes: PackedByteArray = fonts[FONT_SOURCES["6X6.FNT"]]
	var words := ""
	for cell in 3:
		var matches := ""
		for character in " 0123456789":
			var code := character.unicode_at(0)
			var same := true
			for dy in 6:
				for dx in 6:
					var ink := (int(bytes[4+(code-32)*6+dy])&(128>>dx))!=0
					if source.get_pixel(83+cell*6+dx,y+dy).to_rgba32()!=(Color.WHITE if ink else Color.BLACK).to_rgba32(): same=false; break
				if not same: break
			if same: matches+=character
		if matches.length()!=1: return {}
		words+=matches
	if words.strip_edges().is_empty(): return {}
	return _fixed_candidate(words,Vector2i(83,y),source)

func set_motor_pool_menu(source: Image, ui: Image, tags: Image) -> void:
	clear_runs()
	if not fonts.has(FONT_SOURCES["6X6.FNT"]): return
	var bytes: PackedByteArray=fonts[FONT_SOURCES["6X6.FNT"]]
	var fields: Array=[[257,113,"SELECT",Color.WHITE],[245,123,"ARMING MIX",Color.WHITE],
		[245,170,"GOVERNOROFF",Color.WHITE],[245,170,"GOVERNOR ON",Color.WHITE],
		[259,183,"BEGIN",Color(170.0/255,0,0)]]
	# Original digit cells have an unambiguous numeric alphabet. The font's
	# O/0 and I/1 glyphs overlap, so unrestricted character OCR is forbidden.
	for field in [[137,"HEAT"],[147,"SABOT"],[157,"AX"]]:
		var digits := ""
		for column in 2:
			var matches := ""
			for character in " 0123456789":
				var same := true
				for y in 6:
					for x in 6:
						var ink := (int(bytes[4+(character.unicode_at(0)-32)*6+y])&(128>>x))!=0
						var actual := source.get_pixel(299+column*6+x,field[0]+y)
						if ink and not actual.is_equal_approx(Color.BLACK): same=false
						if not ink and not actual.is_equal_approx(Color.WHITE) and not actual.is_equal_approx(Color(170.0/255,0,0)): same=false
				if same: matches+=character
			if matches.length()!=1: digits=""; break
			digits+=matches
		if digits.length()==2 and not digits.strip_edges().is_empty():
			fields.append([245,field[0],field[1]+" ".repeat(9-field[1].length())+digits,Color.WHITE])
	var candidates: Array=[]
	for field in fields:
		var eligible := true
		for y in 6:
			for x in field[2].length()*6:
				if tags.get_pixel(field[0]+x,field[1]+y).r!=0: eligible=false
		if not eligible: continue
		for background in [Color.WHITE,Color(170.0/255,0,0)]:
			var candidate := _fixed_candidate(field[2],Vector2i(field[0],field[1]),source)
			candidate.foreground=0
			candidate.uniform_background_rgb=[roundi(background.r*255),roundi(background.g*255),roundi(background.b*255)]
			candidate.kind="verified_motor_pool_menu"
			candidates.append(candidate)
	var palette: Array=[]
	for i in 16: palette.append([0,0,0])
	# Every full string still has to match the original font and UI ownership,
	# including spaces, highlighting and all unchanged functional labels.
	set_frame(source,ui,{"text_runs":candidates,"palette_rgb":palette})

func use_genesis_menu_style() -> void:
	# Only called after the complete clipboard and all seven source runs pass.
	# Source glyph/state evidence is unchanged; these are presentation colours.
	for run in runs:
		var focused: bool=run.background.is_equal_approx(Color(170.0/255,0,0))
		var heading: bool=run.text in ["SELECT","ARMING MIX"]
		run.background=Color(238.0/255,238.0/255,238.0/255) if focused else Color(98.0/255,101.0/255,98.0/255) if heading else Color.BLACK
		run.foreground=Color.BLACK if focused else Color(238.0/255,238.0/255,238.0/255)
	for label in labels: label.queue_redraw()

static func integers(value: Variant, count: int, low: int, high: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for n in value:
		if not (n is int or n is float) or not is_finite(float(n)) or n!=floorf(n) or n<low or n>high: return false
	return true

func _expected_pixels(words: String, bytes: PackedByteArray, foreground: Color, background: Color, font_id: String) -> Dictionary:
	var key := "%s/%08x/%08x/"%[font_id,foreground.to_rgba32(),background.to_rgba32()]+words
	var cached: Dictionary = _expected_text.get(key,{})
	if not cached.is_empty() and cached.font==bytes: return cached
	var cell := Vector2i(bytes[0],bytes[1])
	var stride := (cell.x+7)/8
	var expected := Image.create_empty(words.length()*cell.x,cell.y,false,Image.FORMAT_RGBA8)
	expected.fill(background)
	var visible_ink := false
	for i in words.length():
		var code := words.unicode_at(i)
		if code<32 or code>126 or code<int(bytes[2]) or code>=int(bytes[2])+int(bytes[3]): return {}
		for y in cell.y:
			for x in cell.x:
				var at := 4+((code-int(bytes[2]))*cell.y+y)*stride+x/8
				if (int(bytes[at])&(128>>(x%8)))!=0:
					expected.set_pixel(i*cell.x+x,y,foreground)
					visible_ink=true
	if _expected_text.size()>=EXPECTED_TEXT_LIMIT and not _expected_text.has(key):
		_expected_text.erase(_expected_text.keys()[0])
	cached={"font":bytes.duplicate(),"pixels":expected.get_data(),"visible_ink":visible_ink}
	_expected_text[key]=cached
	return cached

func verified_run(item: Variant, source: Image, ui: Image, palette: Array, cursor_mask: Image=null) -> Dictionary:
	if not item is Dictionary or not item.get("text") is String: return {}
	var words: String = item.text
	if words.is_empty() or words.length()>53 or not fonts.has(item.get("font_sha256")): return {}
	if not integers(item.get("rect"),4,0,320) or not integers(item.get("cell_size"),2,1,32): return {}
	if not integers(item.get("uniform_background_rgb"),3,0,255): return {}
	if not integers([item.get("foreground")],1,0,15): return {}
	var bytes: PackedByteArray = fonts[item.font_sha256]
	var cell := Vector2i(bytes[0],bytes[1])
	var box := Rect2i(item.rect[0],item.rect[1],item.rect[2],item.rect[3])
	if box.size!=Vector2i(words.length()*cell.x,cell.y) or item.cell_size[0]!=cell.x or item.cell_size[1]!=cell.y: return {}
	if box.end.x>320 or box.end.y>200 or box.size.x<=0 or box.size.y<=0: return {}
	if palette.size()!=16 or not integers(palette[int(item.foreground)],3,0,255): return {}
	var foreground := Color8(palette[int(item.foreground)][0],palette[int(item.foreground)][1],palette[int(item.foreground)][2])
	var background := Color8(item.uniform_background_rgb[0],item.uniform_background_rgb[1],item.uniform_background_rgb[2])
	if foreground==background: return {}
	var stride := (cell.x+7)/8
	var visible_ink := false
	if cursor_mask==null and ui.get_format()==Image.FORMAT_L8 and source.get_format() in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8]:
		if ui.get_region(box).get_data().count(255)!=box.size.x*box.size.y: return {}
		var expected := _expected_pixels(words,bytes,foreground,background,item.font_sha256)
		if expected.is_empty() or not expected.visible_ink: return {}
		var actual := source.get_region(box)
		actual.convert(Image.FORMAT_RGBA8)
		if actual.get_data()!=expected.pixels: return {}
		visible_ink=true
	else:
		# Cursor exclusions and other pixel formats retain the original predicate.
		for i in words.length():
			var code := words.unicode_at(i)
			if code<32 or code>126 or code<int(bytes[2]) or code>=int(bytes[2])+int(bytes[3]): return {}
			for y in cell.y:
				for x in cell.x:
					var at := 4+((code-int(bytes[2]))*cell.y+y)*stride+x/8
					var ink := (int(bytes[at]) & (128>>(x%8)))!=0
					var px := box.position.x+i*cell.x+x
					var py := box.position.y+y
					if ui.get_pixel(px,py).r!=1.0: return {}
					if cursor_mask!=null and cursor_mask.get_pixel(px,py).r==1.0: continue
					visible_ink = visible_ink or ink
					if source.get_pixel(px,py).to_rgba32()!=(foreground if ink else background).to_rgba32(): return {}
	if not visible_ink: return {}
	var crop := source.get_region(box)
	crop.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	if hash.finish().hex_encode()!=item.get("pixel_sha256"): return {}
	return {"text":words,"rect":Rect2(box),"foreground":foreground,"background":background,
		"font_sha256":item.font_sha256,"cell_size":cell,"glyphs":font_geometry[item.font_sha256],
		"outline_font":outline_fonts.fonts.get(item.font_sha256),
		"kind":item.get("kind",""),"draw_sequence":item.get("draw_sequence",0)}

func verified_world_bearing(item: Variant, source: Image, ui: Image, presentation: Dictionary, camera: Rect2i) -> Dictionary:
	# Only original 5728 bearing calls. Each glyph bit must be UI-owned and
	# every non-ink bit world-owned, with the entire RGB crop matched to scanout.
	if camera.size==Vector2i.ZERO or not item is Dictionary: return {}
	if item.get("transparent")!=true or item.get("font_sha256")!=FONT_SOURCES["6X6.FNT"]: return {}
	if item.get("page_offset")!=presentation.get("page_offset") or not integers([item.get("page_offset")],1,0,8192): return {}
	if item.page_offset!=0 and item.page_offset!=8192: return {}
	if not item.get("text") is String or not integers([item.get("return_ip")],1,0,65535): return {}
	var words: String = item.text
	var caller := int(item.return_ip)
	if caller==0x5764:
		if words!="BEARING": return {}
	elif caller==0x57a2:
		if words.length()!=3 or not words.is_valid_int() or int(words)<0 or int(words)>359: return {}
		for c in words:
			if c<"0" or c>"9": return {}
	else: return {}
	if not integers(item.get("rect"),4,0,320) or not integers(item.get("cell_size"),2,6,6): return {}
	var box := Rect2i(item.rect[0],item.rect[1],item.rect[2],item.rect[3])
	if box.position.x!=(128 if caller==0x5764 else 173) or box.position.y not in [12,17]: return {}
	if box.size!=Vector2i(words.length()*6,6) or not camera.encloses(box): return {}
	if item.get("foreground")!=0 and item.get("foreground")!=1: return {}
	var palette: Array = presentation.palette_rgb
	if palette.size()!=16 or not integers(palette[int(item.foreground)],3,0,255): return {}
	var color: Array = palette[int(item.foreground)]
	var foreground := Color8(color[0],color[1],color[2])
	var bytes: PackedByteArray = fonts[item.font_sha256]
	var ink_points: Array[Vector2i] = []
	var contrast := false
	for i in words.length():
		for y in 6:
			for x in 6:
				var ink := (int(bytes[4+(words.unicode_at(i)-32)*6+y])&(128>>x))!=0
				var p := box.position+Vector2i(i*6+x,y)
				if ui.get_pixelv(p).r!=(1.0 if ink else 0.0): return {}
				if ink:
					if source.get_pixelv(p).to_rgba32()!=foreground.to_rgba32(): return {}
					ink_points.append(p)
				else: contrast = contrast or source.get_pixelv(p).to_rgba32()!=foreground.to_rgba32()
	if ink_points.is_empty() or not contrast: return {}
	var crop := source.get_region(box)
	crop.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	if hash.finish().hex_encode()!=item.get("pixel_sha256"): return {}
	if not outline_fonts.fonts.get(item.font_sha256) is Font: return {}
	return {"text":words,"rect":Rect2(box),"cell_size":Vector2i(6,6),"font_sha256":item.font_sha256,
		"foreground":foreground,"background":Color.TRANSPARENT,"transparent_world":true,
		"glyphs":font_geometry[item.font_sha256],"outline_font":outline_fonts.fonts[item.font_sha256],
		"kind":"world_bearing","ink_points":ink_points,"draw_sequence":item.get("draw_sequence",0)}

func set_frame(source: Image, ui: Image, presentation: Dictionary, cursor_mask: Image=null, world_camera: Rect2i=Rect2i()) -> void:
	clear_runs()
	if fonts.is_empty() or not presentation.get("text_runs") is Array or not presentation.get("palette_rgb") is Array: return
	if source==null or source.get_size()!=Vector2i(320,200) or ui==null or ui.get_size()!=Vector2i(320,200) or ui.get_format()!=Image.FORMAT_L8: return
	var candidates: Array = presentation.text_runs.duplicate()
	if candidates.size()>256: return
	if fixed_labels_enabled:
		for entry in FIXED_LABELS:
			candidates.push_front(_fixed_candidate(entry[0],Vector2i(entry[1],entry[2]),source))
	if status_numbers_enabled:
		for y in [52,60,68,76,84,92]:
			var candidate := _status_number(source,y)
			if not candidate.is_empty(): candidates.push_front(candidate)
	# Latest completed writes win when identical surviving candidates overlap.
	candidates.reverse()
	for item in candidates:
		var run := verified_run(item,source,ui,presentation.palette_rgb,cursor_mask)
		if run.is_empty() and cursor_mask==null:
			run = verified_world_bearing(item,source,ui,presentation,world_camera)
		if run.is_empty(): continue
		var overlaps := false
		for old in runs:
			if run.rect.intersects(old.rect): overlaps = true; break
		if overlaps: continue
		runs.append(run)
		if run.get("transparent_world",false): world_ink.append_array(run.ink_points)
		if runs.size()>labels.size():
			var label := RunLabel.new()
			label.clip_contents = true
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(label)
			labels.append(label)
	_layout()

func _layout() -> void:
	var scale_to_view := size/Vector2(320,200)
	for i in runs.size():
		var label: Control = labels[i]
		label.run = runs[i]
		label.position = runs[i].rect.position*scale_to_view
		label.size = runs[i].rect.size*scale_to_view
		label.show()
		label.queue_redraw()
