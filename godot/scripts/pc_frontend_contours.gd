extends TextureRect
## Current FRAME contents only. No inferred map, labels, palette or objects.
const REGION := Rect2i(10,10,300,166)
const FrontendContoursShader = preload("res://scripts/pc_frontend_contours.gdshader")
var _key := PackedByteArray()
var surface: Image
var _crop_texture: ImageTexture
var _surface_texture: ImageTexture
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var effect:=ShaderMaterial.new()
	effect.shader=FrontendContoursShader
	material=effect
	hide()
func clear() -> void: hide()
func set_frame(source: Image,protected: Array,cursor: Image) -> bool:
	var crop:=source.get_region(REGION)
	var rgb:=crop.get_data()
	var key:=rgb.duplicate()
	key.append_array(var_to_bytes(protected))
	if cursor!=null: key.append_array(cursor.get_data())
	if key!=_key:
		_key=key
		var n:=REGION.size.x*REGION.size.y
		var seen:=PackedByteArray();seen.resize(n)
		var rgba:=PackedByteArray();rgba.resize(n*4)
		for i in n:
			for channel in 3: rgba[i*4+channel]=rgb[i*3+channel]
		for seed in n:
			if seen[seed]: continue
			var cells:=PackedInt32Array([seed]);seen[seed]=1
			var at:=0
			while at<cells.size():
				var cell:=cells[at];at+=1
				var x:=cell%REGION.size.x
				for next in [cell-1,cell+1,cell-REGION.size.x,cell+REGION.size.x]:
					if next<0 or next>=n or seen[next] or (next==cell-1 and x==0) or (next==cell+1 and x==REGION.size.x-1): continue
					if rgb[next*3]!=rgb[seed*3] or rgb[next*3+1]!=rgb[seed*3+1] or rgb[next*3+2]!=rgb[seed*3+2]: continue
					seen[next]=1;cells.append(next)
			# Small symbols and isolated strokes keep their exact raster footprint.
			if cells.size()>=32:
				for cell in cells: rgba[cell*4+3]=255
		for box in protected:
			var clipped:Rect2i=box.grow(1).intersection(REGION)
			for y in range(clipped.position.y,clipped.end.y):
				for x in range(clipped.position.x,clipped.end.x):rgba[((y-REGION.position.y)*REGION.size.x+x-REGION.position.x)*4+3]=0
		if cursor!=null:
			if cursor.get_format()==Image.FORMAT_L8 and cursor.get_size()==Vector2i(320,200):
				var cursor_bytes:=cursor.get_region(REGION).get_data()
				if cursor_bytes.count(0)!=n:
					var c_at:=cursor_bytes.find(255,0)
					while c_at>=0:
						rgba[c_at*4+3]=0
						c_at=cursor_bytes.find(255,c_at+1)
			else:
				for y in REGION.size.y:
					for x in REGION.size.x:
						if cursor.get_pixel(x+REGION.position.x,y+REGION.position.y).r>0.0: rgba[(y*REGION.size.x+x)*4+3]=0
		surface=Image.create_from_data(REGION.size.x,REGION.size.y,false,Image.FORMAT_RGBA8,rgba)
		if _crop_texture==null or DisplayServer.get_name()=="headless" or Vector2i(_crop_texture.get_size())!=crop.get_size() or _crop_texture.get_format()!=crop.get_format():
			_crop_texture=ImageTexture.create_from_image(crop)
		else:
			_crop_texture.update(crop)
		if _surface_texture==null or DisplayServer.get_name()=="headless" or Vector2i(_surface_texture.get_size())!=surface.get_size() or _surface_texture.get_format()!=surface.get_format():
			_surface_texture=ImageTexture.create_from_image(surface)
		else:
			_surface_texture.update(surface)
		texture=_crop_texture
		material.set_shader_parameter("surface_pixels",_surface_texture)
	show()
	return true
func fit_to(extent: Vector2) -> void:
	var scale:=extent/Vector2(320,200)
	position=Vector2(REGION.position)*scale
	size=Vector2(REGION.size)*scale
