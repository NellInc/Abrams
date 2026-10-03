extends TextureRect
## Extracted native donors only. No high-resolution art or world rerendering.
const CATALOG_SHA := "c35a2628fa44e91ea716a0522290efe3a3307a010ca96eb189ae7078bd006cc1"
var splash_aftermath_art=preload("res://scripts/pc_splash_aftermath_art.gd").new()
var newspaper_art=preload("res://scripts/pc_newspaper_art.gd").new()
var catalog: Dictionary = {}
var catalogs: Dictionary = {}
var images: Dictionary = {}
var fonts: Dictionary = {}
var active: Dictionary = {}
var loaded := false
var load_count := 0
var portrait_templates := []
var last_source_bytes := PackedByteArray()
var last_program := ""
var cached_frontend: Image
var cached_active: Dictionary = {}
# Last validated (plate, UI) mask pair. Masks rarely change between SIM frames;
# source-pixel checks (portraits, pristine plate 5) still run every frame.
var mask_keys := ["",""]
var mask_valid := false
var mask_values := PackedByteArray()
var mask_bits := PackedByteArray()
var mask_textures := []
var mask_decode_count := 0

func _init() -> void:
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var effect:=ShaderMaterial.new()
	effect.shader=preload("res://scripts/pc_native_graphics.gdshader")
	material=effect
	add_child(splash_aftermath_art)
	newspaper_art.high_resolution=false
	add_child(newspaper_art)
	newspaper_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible=false

func load_sources(root: String) -> bool:
	load_count+=1
	newspaper_art.load_sources(root)
	splash_aftermath_art.load_sources(root)
	loaded=false;catalog.clear();catalogs.clear();images.clear();fonts.clear()
	mask_keys=["",""];mask_valid=false;mask_values.clear();mask_bits.clear();mask_textures.clear()
	var path:=root.path_join("local-art/pc-graphics-native-v1/graphics.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA:return false
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for name in data.donors:
		var item:Dictionary=data.donors[name]
		path=root.path_join(item.path)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=item.sha256:return false
		var im:=Image.load_from_file(path)
		if im==null or im.get_size()!=Vector2i(item.size[0],item.size[1]):return false
		images[name]=im
	for name in data.catalogs:
		var item:Dictionary=data.catalogs[name]
		path=root.path_join(item.path)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=item.sha256:return false
		var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for source in definition.get("sources",{}):
			path=root.path_join("GAME/"+source)
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=definition.sources[source]:return false
		catalogs[name]=definition
	for name in ["6X6.FNT","8X8.FNT"]:
		path=root.path_join("GAME/"+name)
		if FileAccess.get_sha256(path)!=preload("res://scripts/pc_typography.gd").FONT_SOURCES[name]:return false
		fonts[name]=FileAccess.get_file_as_bytes(path)
	var faces:Dictionary=catalogs.portraits
	path=root.path_join("GAME/"+faces.source)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=faces.source_sha256:return false
	portrait_templates.clear()
	for id in 4:
		var face:Dictionary=faces.images[id]
		var points:=[]
		var width:=0
		for i in face.pixels.size():
			if int(face.pixels[i])==0:continue
			var x:int=i%int(face.width)
			var y:int=i/int(face.width)
			width=maxi(width,x+1)
			var rgb:Array=faces.palette_rgb[int(face.pixels[i])]
			points.append([x,y,Color8(rgb[0],rgb[1],rgb[2])])
		var native:Image=images["crew-"+["commander","gunner","driver","loader"][id]].duplicate()
		native.resize(width,int(face.height),Image.INTERPOLATE_NEAREST)
		portrait_templates.append({"points":points,"donor":native,"name":["commander","gunner","driver","loader"][id]})
	catalog=data
	material.set_shader_parameter("plate_donors",ImageTexture.create_from_image(images.plates))
	material.set_shader_parameter("plate_originals",ImageTexture.create_from_image(images.expected))
	loaded=true
	return true

static func fingerprint(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes)
	return h.finish().hex_encode()

static func box(r: Array) -> Rect2i:return Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))

func _paste(output: Image, key: String, target: Rect2i) -> void:
	if not images.has(key):return
	var donor:Image=images[key].duplicate()
	donor.convert(Image.FORMAT_RGBA8)
	if donor.get_size()!=target.size:donor.resize(target.size.x,target.size.y,Image.INTERPOLATE_NEAREST)
	output.blend_rect(donor,Rect2i(Vector2i.ZERO,donor.get_size()),target.position)

func _dedicate(output: Image) -> void:
	output.fill_rect(Rect2i(8,164,164,30),Color8(255,85,85))
	output.fill_rect(Rect2i(9,165,162,28),Color.BLACK)
	for line in [["Dedicated to the memory of","6X6.FNT",12,168,Color8(170,170,170)],["David \"Ming\" Kenny","8X8.FNT",18,180,Color.WHITE]]:
		var font:PackedByteArray=fonts[line[1]]
		for i in line[0].length():
			var c:int=line[0].unicode_at(i)
			for y in int(font[1]):
				var bits:int=font[4+(c-int(font[2]))*int(font[1])+y]
				for x in int(font[0]):
					if bits & (128>>x):output.set_pixel(line[2]+i*int(font[0])+x,line[3]+y,line[4])

func _frontend(source: Image, program: String) -> Image:
	var bytes:=source.get_data()
	if bytes==last_source_bytes and program==last_program and cached_frontend!=null:
		active=cached_active.duplicate(true)
		return cached_frontend
	last_source_bytes=bytes;last_program=program
	var result:Image=source.duplicate();result.convert(Image.FORMAT_RGBA8)
	active={"fallback":"Original PC pixels for unmatched or dynamic regions","donors":[]}
	if program=="START":
		var sha:=fingerprint(bytes)
		for e in catalogs.intro.entries:
			if e.rgb_sha256!=sha:continue
			_paste(result,"title",Rect2i(0,0,320,200))
			if int(e.flash)>0:_paste(result,"flash-"+str(int(e.flash)),Rect2i(168,84,152,116))
			if e.has("credit_rect"):
				var original:Image=source.duplicate();original.convert(Image.FORMAT_RGBA8)
				result.blit_rect(original,box(e.credit_rect),box(e.credit_rect).position)
			if e.name=="credit-8":_dedicate(result)
			active.donors.append("intro:"+e.name)
			cached_frontend=result;cached_active=active.duplicate(true);return result
		for entry in catalog.native_information:
			if entry.rgb_sha256==sha:
				_paste(result,entry.donor,box(entry.rect));active.donors.append(entry.donor)
				cached_frontend=result;cached_active=active.duplicate(true);return result
		var info:Dictionary=catalogs.information
		sha=fingerprint(bytes.slice(0,320*int(info.recognition_height)*3))
		for e in info.entries:
			if e.rgb_sha256!=sha or (e.has("full_rgb_sha256") and e.full_rgb_sha256!=fingerprint(bytes)):continue
			for item in e.get("layers",[e]):
				var key:String=item.name
				if key in ["ax","heat","sabot"]:key="ammo-"+key+"-illustration"
				elif key in ["coax","cannon","smoke"]:key="weapon-"+key+"-illustration"
				if images.has(key):_paste(result,key,box(item.rect));active.donors.append(key)
	elif program in ["BRIEF","END"]:
		for height in catalogs.office.heights:
			var h:=int(height)
			if h<200:
				var border:=true
				for x in 320:
					if source.get_pixel(x,h)!=Color.WHITE:border=false;break
				if not border:continue
			var sha:=fingerprint(bytes.slice(0,320*h*3))
			for e in catalogs.office.templates:
				if e.hashes[str(h)]!=sha or int(e.pose)>1:continue
				var office:Image=images["office-background"].duplicate();office.convert(Image.FORMAT_RGBA8)
				_paste(office,"wilson-"+str(int(e.pose)),box(e.portrait_rect))
				result.blit_rect(office,Rect2i(0,0,320,h),Vector2i.ZERO)
				active.donors.append("office:"+e.name)
				cached_frontend=result;cached_active=active.duplicate(true);return result
	cached_frontend=result;cached_active=active.duplicate(true);return result

func set_frame(source: Image, presentation: Dictionary, program: Dictionary) -> void:
	newspaper_art.clear()
	material.set_shader_parameter("plates_enabled",false)
	active={"fallback":"Native donor pack unavailable","donors":[]}
	if source==null:
		texture=null
		return
	if not loaded or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8:
		texture=ImageTexture.create_from_image(source);return
	var composed:Image=_frontend(source,str(program.get("name",""))).duplicate()
	var aftermath:Image=splash_aftermath_art.native_frame(source,program)
	if aftermath!=source:
		composed=aftermath.duplicate()
		active.donors.append("aftermath:"+splash_aftermath_art.match_frame(source,program).name)
	texture=ImageTexture.create_from_image(composed)
	if newspaper_art.set_frame(source,program): active.donors.append("newspaper:"+newspaper_art.active.name)
	var plate=presentation.get("plate_overlay",{})
	var ui=presentation.get("ui_overlay",{})
	if not plate is Dictionary or not ui is Dictionary:return
	if plate.get("width")!=320 or plate.get("height")!=200 or ui.get("width")!=320 or ui.get("height")!=200:return
	if not plate.get("mask_png") is String or not ui.get("mask_png") is String:return
	if plate.mask_png!=mask_keys[0] or ui.mask_png!=mask_keys[1]:_validate_masks(plate.mask_png,ui.mask_png)
	if not mask_valid:return
	var values:=mask_values;var bits:=mask_bits
	if program.get("name")=="SIM":
		for item in portrait_templates:
			var matches:=true
			for point in item.points:
				var x:int=37+point[0];var y:int=59+point[1]
				if bits[y*320+x]!=255 or source.get_pixel(x,y)!=point[2]:matches=false;break
			if not matches:continue
			for point in item.points:composed.set_pixel(37+point[0],59+point[1],item.donor.get_pixel(point[0],point[1]))
			(texture as ImageTexture).update(composed)
			active.donors.append("portrait:"+item.name)
			break
	var enabled:=0
	for slot in catalog.plates:
		var id:=8 if slot=="6" else int(slot)
		var claimed:Dictionary=plate.get("plates",{}).get(str(id),{})
		var expected:Dictionary=catalog.plates[slot]
		if claimed.get("source")==expected.source and claimed.get("source_sha256")==expected.source_sha256:
			if id==5:
				var pristine:=true
				for y in range(37,100):
					for x in range(123,305):
						if values[y*320+x]!=5 or source.get_pixel(x,y)!=images.expected.get_pixel(x,800+y):pristine=false;break
					if not pristine:break
				if not pristine:continue
			enabled|=1<<id
	material.set_shader_parameter("plate_tags",mask_textures[0])
	material.set_shader_parameter("ui_mask",mask_textures[1])
	material.set_shader_parameter("enabled_bits",enabled)
	material.set_shader_parameter("plates_enabled",enabled!=0)
	active["plate_bits"]=enabled

# Keys are stored even on failure, so a repeated invalid pair stays rejected.
func _validate_masks(plate_png: String, ui_png: String) -> void:
	mask_decode_count+=1
	mask_keys=[plate_png,ui_png];mask_valid=false;mask_values.clear();mask_bits.clear();mask_textures.clear()
	var tags:=Image.new();var mask:=Image.new()
	if tags.load_png_from_buffer(Marshalls.base64_to_raw(plate_png))!=OK or mask.load_png_from_buffer(Marshalls.base64_to_raw(ui_png))!=OK:return
	if tags.get_size()!=Vector2i(320,200) or mask.get_size()!=Vector2i(320,200) or tags.get_format()!=Image.FORMAT_L8 or mask.get_format()!=Image.FORMAT_L8:return
	var values:=tags.get_data();var bits:=mask.get_data()
	if bits.count(0)+bits.count(255)!=bits.size():return
	var tagged:=0
	for id in 9:tagged+=values.count(id)
	if tagged!=values.size():return
	for i in values.size():
		if values[i]!=0 and bits[i]!=255:return
	mask_values=values;mask_bits=bits
	mask_textures=[ImageTexture.create_from_image(tags),ImageTexture.create_from_image(mask)]
	mask_valid=true
