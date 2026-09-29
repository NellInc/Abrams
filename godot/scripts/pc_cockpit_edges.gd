extends Control
## Source-profile reconstruction only at the driver/cupola outer silhouette.
## No additional camera area or hidden world sample is introduced.
const BAND := 1.65
const ERROR := 0.98
var active := false
var mesh: ArrayMesh
var profiles: Array = []
var build_count := 0
var _tags := PackedByteArray()
var _assembly := PackedByteArray()
var _key := ""

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

func set_frame(ui:Image,tags:Image,camera:Rect2i,donor:Texture2D,assembly:Image,station:int,modern:bool,rail:bool,world:Texture2D) -> void:
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
	var roof:=assembly.get_data() if assembly!=null else PackedByteArray()
	var key:=str(station)+str(rail)
	if bits!=_tags or roof!=_assembly or key!=_key:
		# Do not infer an outline from a mixed station transition.
		if bits.count(0)+bits.count(station)!=bits.size():return
		profiles.clear();mesh=null
		var lower:=PackedFloat32Array();lower.resize(320);lower.fill(camera.end.y)
		var upper:=PackedFloat32Array();upper.resize(320)
		for x in 320:
			for y in camera.end.y:
				var at:=y*320+x
				var claimed:bool=int(bits[at])==station
				if station==4 and not roof.is_empty():claimed=claimed or roof[at*3+2]==255
				if station==3 and rail and y>=111 and y<117 and x>=159 and x<[183,206,230,242,264,286][y-111]:claimed=true
				if not claimed:continue
				if station==4 and y<77:upper[x]=y+1
				elif y<lower[x]:lower[x]=y
		if station==4:profiles.append({"upper":true,"points":fit(upper)})
		profiles.append({"upper":false,"points":fit(lower)})
		_tags=bits;_assembly=roof;_key=key
		_build_mesh();build_count+=1
	material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(ui))
	material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(tags))
	material.set_shader_parameter("driver_mask",ImageTexture.create_from_image(assembly) if assembly!=null else null)
	material.set_shader_parameter("driver_enabled",assembly!=null)
	material.set_shader_parameter("donor",donor)
	material.set_shader_parameter("world_texture",world)
	material.set_shader_parameter("station",station)
	material.set_shader_parameter("modern",modern)
	material.set_shader_parameter("rail_verified",rail)
	material.set_shader_parameter("camera_size",Vector2(camera.size))
	active=mesh!=null;visible=active
	_layout()

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
