extends SceneTree
## Capture original procedural batches for Blender, with exact content selectors.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var vehicle = load("res://scripts/vehicle.gd").new()
	vehicle.cover_detail = true
	# Bypass authored replacements while capturing the procedural source.
	vehicle.set_meta("cover_export_source", true)
	root.add_child(vehicle)
	var batches: Array = []
	for frame in [vehicle, vehicle.turret_root, vehicle.barrel, vehicle.crew]:
		var role := "hull" if frame == vehicle else ("turret" if frame == vehicle.turret_root else ("barrel" if frame == vehicle.barrel else "crew"))
		for child in frame.get_children():
			if not child is MeshInstance3D: continue
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(var_to_bytes([verts,norms,uvs,indices]))
			var colour := Color.WHITE
			var mat: Material = child.material_override
			var kind := "standard"
			if mat is StandardMaterial3D: colour = mat.albedo_color
			elif mat is ShaderMaterial:
				kind = "skin" if "BACKLIGHT" in mat.shader.code else ("cloth" if "surface_roughness" in mat.shader.code else "paint")
				for param in ["base_color","cloth_colour","colour"]:
					var value = mat.get_shader_parameter(param)
					if value is Color: colour = value; break
			var v: Array = []
			var n: Array = []
			var uv: Array = []
			for p in verts: v.append_array([p.x,p.y,p.z])
			for p in norms: n.append_array([p.x,p.y,p.z])
			if uvs != null:
				for p in uvs: uv.append_array([p.x,p.y])
			batches.append({"id":hash.finish().hex_encode(),"frame":role,"vertices":v,"normals":n,"uv":uv,"indices":Array(indices) if indices != null else [],"colour":[colour.r,colour.g,colour.b],"kind":kind})
	var file := FileAccess.open("res://../local-art/cover-blender-v1/source.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"batches":batches}))
	print("COVER_EXPORT batches=",batches.size())
	quit()
