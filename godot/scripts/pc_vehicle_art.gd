extends RefCounted
## Cosmetic track/armour panels on six original visible faces. Never adds actors.
const Colour = preload("res://scripts/pc_colour.gd")
const PC_PALETTE = preload("res://scripts/pc_tandem_frame.gd").ART_PALETTE
const SOURCE_HASH := "81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193"
const ASSETS := [
	["t62-track-v1.png","f5d8d0f6f93ec3d9a277e1d68cc2e48bdd567fb3b725375f774779e5bb31e992",[2046,768],[70,185,1940,400]],
	["m1a1-track-v1.png","a6c9099b3381a781f43ea5df661da48438767a70886a6b48670b1bbc3e150369",[2103,748],[57,232,2004,339]],
	["m113-track-v1.png","252d361c4dd04fd8d6a4e374ab81dd273ca417cb0a9337f5946aa20dddc09a61",[2048,768],[157,108,1753,568]]]
# Source vertices in the SAME order as the observed camera_vertices. No inverse
# of the PC's rounded/quirky matrix arithmetic is needed to attach surface UVs.
const MODELS := {
	115:[13289,0,{
		13323:[[-58,85,-31],[-58,-68,-31],[-58,-97,-22],[-58,-102,17],[-58,119,17],[-58,125,-3]],
		13333:[[58,-102,17],[58,-97,-22],[58,-68,-31],[58,85,-31],[58,125,-3],[58,119,17]]}],
	125:[17420,1,{
		17464:[[-40,60,-26],[-40,90,-12],[-40,92,0],[-40,-72,0],[-40,-72,-12],[-40,-52,-26]],
		17490:[[40,92,0],[40,-72,0],[40,-72,-12],[40,-52,-26],[40,60,-26],[40,90,-12]]}],
	129:[19158,2,{
		19188:[[-38,52,-20],[-38,-44,-20],[-38,-64,-12],[-38,-64,20],[-38,42,20],[-38,66,-6]],
		19198:[[38,-64,20],[38,-64,-14],[38,-44,-20],[38,52,-20],[38,66,-6],[38,42,20]]}]}
const LEVELS := 65
# Other dark-grey faces on these same three source models receive the actual
# Genesis model shade, not the road-specific bank-3 entry 13 used by world art.
# Values are [original outline material, original vertex count].
const PLAIN_FACES := {
	115:{13405:[3,4],13437:[3,4],13480:[3,4],13488:[3,4]},
	125:{17576:[2,4],17630:[3,4],17646:[3,4]},
	129:{}}
const GENESIS_DARK := [65,68,65]
var atlas: Texture2D
var genesis_palette: Array=[]
var regions: Array[Rect2] = []
var palette_texture: Texture2D
var palette_key := ""

func load_assets(root: String) -> bool:
	atlas=null
	regions.clear()
	palette_texture=null
	palette_key=""
	genesis_palette.clear()
	var source:=root.path_join("GAME/SHAPE.TBL")
	if not FileAccess.file_exists(source) or FileAccess.get_sha256(source)!=SOURCE_HASH: return false
	var style:=preload("res://scripts/pc_genesis_style.gd").new()
	if not style.load_palette(root.path_join("reference/genesis/extracted/gunner/palette.gpl")): return false
	genesis_palette=style.palette
	var images: Array[Image]=[]
	var width:=0
	var height:=0
	for asset: Array in ASSETS:
		var path:=root.path_join("local-art/genesis/remastered/vehicles-v1/"+asset[0])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=asset[1]: return false
		var image:=Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(asset[2][0],asset[2][1]): return false
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
		width=maxi(width,image.get_width()+128)
		height+=image.get_height()+128
	# Runtime packing only. Original PNG bytes stay unchanged. Transparent gutters
	# plus distance fade prevent a mip footprint from selecting a neighbouring row.
	var packed:=Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
	var y:=64
	for image: Image in images:
		packed.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(64,y))
		regions.append(Rect2(Vector2(64,y)/Vector2(width,height),Vector2(image.get_size())/Vector2(width,height)))
		y+=image.get_height()+128
	packed.generate_mipmaps()
	atlas=ImageTexture.create_from_image(packed)
	return true

func mapping(object: Dictionary, polygon: Dictionary, palette: Array) -> Dictionary:
	if atlas==null or palette.size()!=16: return {}
	for i in 16:
		if not palette[i] is Array or palette[i].size()!=3: return {}
		for c in 3:
			if palette[i][c]!=PC_PALETTE[i][c]: return {}
	var shape:=int(object.get("shape_index",-1))
	if shape not in MODELS or int(object.get("root",-1))!=MODELS[shape][0]: return {}
	var primitive:=int(polygon.get("primitive",-1))
	if int(polygon.get("fill_mode",0))!=1: return {}
	var colors: Array=polygon.get("colors",[])
	var points: Array=polygon.get("camera_vertices",[])
	for point in points:
		if not point is Array or point.size()!=3: return {}
		for value in point:
			if not (value is int or value is float) or not is_finite(float(value)): return {}
	if primitive in PLAIN_FACES[shape]:
		var plain: Array=PLAIN_FACES[shape][primitive]
		if colors.size()==2 and colors[0]==plain[0] and colors[1]==3 and polygon.get("camera_vertices",[]).size()==plain[1]:
			return {"kind":13,"uv":[]}
		return {}
	if primitive not in MODELS[shape][2]: return {}
	if colors.size()!=2 or colors[0]!=3 or colors[1]!=3: return {}
	var source: Array=MODELS[shape][2][primitive]
	if points.size()!=source.size(): return {}
	var donor: int=MODELS[shape][1]
	return {"kind":10+donor,"uv":face_uvs(source,donor)}

func face_uvs(source: Array, donor: int) -> Array:
	var lo:=Vector2(INF,INF)
	var hi:=Vector2(-INF,-INF)
	for p: Array in source:
		var yz:=Vector2(p[1],-p[2])
		lo=lo.min(yz)
		hi=hi.max(yz)
	var extent:=hi-lo
	var a: Array=ASSETS[donor]
	var crop:=Rect2(a[3][0],a[3][1],a[3][2],a[3][3])
	var fit:=minf(extent.x/crop.size.x,extent.y/crop.size.y)
	var inset: Vector2=(extent-crop.size*fit)*0.5
	var result: Array=[]
	for p: Array in source:
		var pixel: Vector2=crop.position+(Vector2(p[1],-p[2])-lo-inset)/fit
		result.append(regions[donor].position+pixel/Vector2(a[2][0],a[2][1])*regions[donor].size)
	return result

static func detail_rgb(rgb: Array, level: int) -> Array:
	var factor:=0.25+1.5*float(clampi(level,0,64))/64.0
	return [clampi(roundi(rgb[0]*factor),0,255),clampi(roundi(rgb[1]*factor),0,255),clampi(roundi(rgb[2]*factor),0,255)]

func colours(palette: Array, materials: Array) -> Texture2D:
	var key:=JSON.stringify([palette,materials])
	if key==palette_key: return palette_texture
	var compatible:=RenderingServer.get_current_rendering_method()=="gl_compatibility"
	var model_palette:=palette.duplicate(true)
	var genesis: bool=genesis_palette.size()==16 and palette.size()==16
	if genesis:
		for i in 16:
			for c in 3:
				if palette[i][c]!=genesis_palette[i][c]: genesis=false
	if genesis: model_palette[3]=GENESIS_DARK.duplicate()
	var image:=Image.create(materials.size(),LEVELS,false,Image.FORMAT_RGBAF if compatible else Image.FORMAT_RGBA8)
	for i in materials.size():
		var mean: Array=preload("res://scripts/pc_terrain_style.gd").material_mean(model_palette,materials[i])
		for level in LEVELS: image.set_pixel(i,level,Colour.input_color(detail_rgb(mean,level),compatible))
	palette_texture=ImageTexture.create_from_image(image)
	palette_key=key
	return palette_texture
