extends Control
## Source-profile reconstruction only at the driver/cupola outer silhouette.
## No additional camera area or hidden world sample is introduced.
const BAND := 1.65
const ERROR := 0.98
var active := false
var mesh: ArrayMesh
var profiles: Array = []
var build_count := 0
# One exact, validated geometry snapshot per supported station.
var _geometry_cache: Dictionary = {}

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var effect:=ShaderMaterial.new()
	effect.shader=preload("res://scripts/pc_cockpit_edges.gdshader")
	material=effect
	resized.connect(_layout)
	clear()

func clear() -> void:
	active=false;hide()

func _layout() -> void:
	material.set_shader_parameter("frame_size",size)
	queue_redraw()

static func _fit(points: PackedVector2Array, first:int, last:int, result:PackedVector2Array) -> void:
	var at:=-1;var error:=ERROR
	for i in range(first+1,last):
		var ratio:float=(points[i].x-points[first].x)/(points[last].x-points[first].x)
		var distance:=absf(points[i].y-lerpf(points[first].y,points[last].y,ratio))
		if distance>error:error=distance;at=i
	if at<0:result.append(points[last]);return
	_fit(points,first,at,result);_fit(points,at,last,result)

static func fit(heights: PackedFloat32Array) -> PackedVector2Array:
	var points:=PackedVector2Array([Vector2(0,heights[0])])
	for x in heights.size():points.append(Vector2(x+0.5,heights[x]))
	points.append(Vector2(320,heights[319]))
	var result:=PackedVector2Array([points[0]])
	_fit(points,0,points.size()-1,result)
	return result

func set_frame(ui:Image,tags:Image,camera:Rect2i,donor:Texture2D,assembly:Image,station:int,modern:bool,rail:bool,world:Texture2D,
		ui_texture:Texture2D=null,tags_texture:Texture2D=null,assembly_texture:Texture2D=null) -> void:
	# Optional textures are the compositor's uploads of these exact images.
	clear()
	if station not in [3,4] or donor==null or world==null:return
	if camera!=Rect2i(0,0,320,117 if station==3 else 136):return
	for img in [ui,tags]:
		if img==null or img.get_size()!=Vector2i(320,200) or img.get_format()!=Image.FORMAT_L8:return
	if assembly!=null and (assembly.get_size()!=Vector2i(320,200) or assembly.get_format()!=Image.FORMAT_RGB8):return
	var bits:=tags.get_data()
	# A clipped fragment of an old station is insufficient outline evidence.
	for p in [Vector2i(0,199),Vector2i(319,199)]:
		if bits[p.y*320+p.x]!=station:return
	var roof:=assembly.get_data() if station==4 and assembly!=null else PackedByteArray()
	var cached:Dictionary=_geometry_cache.get(station,{})
	# Exact native byte comparisons first: identical masks, or a traverse that
	# changes only turret offset bytes (same B ownership plane), reuse the
	# validated outline without any column work.
	var claims:Image=null
	var same:bool=not cached.is_empty() and rail==cached.rail and bits==cached.tags
	if same and roof!=cached.roof:
		claims=claim_plane(assembly) if not roof.is_empty() else null
		same=(claims.get_data() if claims!=null else PackedByteArray())==cached.claims
	if same:
		# Copy profiles so public inspection cannot mutate the cached snapshot.
		profiles=cached.profiles.duplicate(true);mesh=cached.mesh
		cached.roof=roof
	else:
		# The plate changes far less often than the turret-borne assembly; an
		# identical plate already passed the mixed-station check.
		var plate_known:bool=not cached.is_empty() and bits==cached.tags
		# Do not infer an outline from a mixed station transition.
		if not plate_known and bits.count(0)+bits.count(station)!=bits.size():return
		if claims==null and not roof.is_empty():claims=claim_plane(assembly)
		var plate:Array=cached.plate if plate_known else claim_extents(tags,station,station,camera.end.y)
		var extents:=column_extents(tags,assembly,station,rail,camera.end.y,plate,claims)
		var key:=[station,rail,extents[0],extents[1]]
		if not cached.is_empty() and key==cached.key:
			# The outline depends only on these column extents.
			profiles=cached.profiles.duplicate(true);mesh=cached.mesh
		else:
			profiles.clear();mesh=null
			if station==4:profiles.append({"upper":true,"points":fit(extents[0])})
			profiles.append({"upper":false,"points":fit(extents[1])})
			_build_mesh();build_count+=1
		_geometry_cache[station]={"tags":bits,"roof":roof,"claims":claims.get_data() if claims!=null else PackedByteArray(),"rail":rail,
				"plate":plate,"key":key,"profiles":profiles.duplicate(true),"mesh":mesh}
	material.set_shader_parameter("ui_mask",ui_texture if ui_texture!=null else ImageTexture.create_from_image(ui))
	material.set_shader_parameter("plate_mask",tags_texture if tags_texture!=null else ImageTexture.create_from_image(tags))
	material.set_shader_parameter("driver_mask",(assembly_texture if assembly_texture!=null else ImageTexture.create_from_image(assembly)) if assembly!=null else null)
	material.set_shader_parameter("driver_enabled",assembly!=null)
	material.set_shader_parameter("donor",donor)
	material.set_shader_parameter("world_texture",world)
	material.set_shader_parameter("station",station)
	material.set_shader_parameter("modern",modern)
	material.set_shader_parameter("rail_verified",rail)
	material.set_shader_parameter("camera_size",Vector2(camera.size))
	active=mesh!=null;visible=active
	_layout()

# Per-column claimed extents above the camera's lower edge: [upper, lower].
# upper[x] is one past the last claimed driver-roof row below y 77 (0 if none);
# lower[x] is the first claimed row at or after y 77 for the driver, or y 0 for
# the cupola (camera_end if none). A claim is a station plate pixel, a driver
# assembly pixel (B==255) or the verified cupola rail span. The union of the
# plate and assembly claims has the max/min of their separate extents, so each
# plane is scanned on its own; plate may carry an earlier exact plate result.
static func column_extents(tags:Image,assembly:Image,station:int,rail:bool,camera_end:int,plate:Array=[],claims:Image=null) -> Array:
	if plate.is_empty():plate=claim_extents(tags,station,station,camera_end)
	var upper:PackedFloat32Array=plate[0].duplicate()
	var lower:PackedFloat32Array=plate[1].duplicate()
	if station==4 and assembly!=null:
		var roof:=claim_extents(claims if claims!=null else claim_plane(assembly),255,station,camera_end)
		for x in 320:
			upper[x]=maxf(upper[x],roof[0][x]);lower[x]=minf(lower[x],roof[1][x])
	if station==3 and rail:
		# Rows 111..116 claim x in [159, limit); the first admitting row wins.
		var limits:=[183,206,230,242,264,286]
		for y in range(111,mini(117,camera_end)):
			for x in range(159,limits[y-111]):
				if y<lower[x]:lower[x]=y
	return [upper,lower]

# One plane's per-column extents for pixels exactly equal to value. Each
# column is copied out natively and searched with find/rfind, never per pixel.
static func claim_extents(plane:Image,value:int,station:int,camera_end:int) -> Array:
	var upper:=PackedFloat32Array();upper.resize(320)
	var lower:=PackedFloat32Array();lower.resize(320);lower.fill(camera_end)
	var start:=77 if station==4 else 0
	var split:=mini(77,camera_end)
	for x in 320:
		var column:=plane.get_region(Rect2i(x,0,1,camera_end)).get_data()
		if station==4 and split>0:
			var last:=column.rfind(value,split-1)
			if last>=0:upper[x]=last+1
		var first:=column.find(value,start)
		if first>=0:lower[x]=first
	return [upper,lower]

# The exact B byte of each RGB8 assembly pixel as one byte per pixel: drop the
# first two bytes so every pixel's R byte is the original B, then keep R.
static func claim_plane(assembly:Image) -> Image:
	var bytes:=assembly.get_data().slice(2)
	bytes.append_array(PackedByteArray([0,0]))
	var plane:=Image.create_from_data(320,200,false,Image.FORMAT_RGB8,bytes)
	plane.convert(Image.FORMAT_R8)
	return plane

func _build_mesh() -> void:
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var colours:=PackedColorArray();var indices:=PackedInt32Array()
	for profile:Dictionary in profiles:
		var points:PackedVector2Array=profile.points
		for i in range(points.size()-1):
			var start:=vertices.size()
			for pair in [[points[i],-BAND],[points[i+1],-BAND],[points[i+1],BAND],[points[i],BAND]]:
				var p:Vector2=pair[0]
				vertices.append(Vector3(p.x,p.y+pair[1],0));uv.append(p)
				colours.append(Color(1.0 if profile.upper else 0.0,0,0))
			indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colours;arrays[Mesh.ARRAY_INDEX]=indices
	mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func _draw() -> void:
	if not active or mesh==null:return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	draw_mesh(mesh,null)
	draw_set_transform(Vector2.ZERO)
