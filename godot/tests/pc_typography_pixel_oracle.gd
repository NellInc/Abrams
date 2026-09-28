extends "res://scripts/pc_typography.gd"
## Frozen pre-optimization pixel-loop definition from commit 1bc962e.
## Test oracle only; production never loads this script.
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
