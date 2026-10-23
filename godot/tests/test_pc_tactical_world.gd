extends SceneTree
## Bounded Blender presentation assets, independent of placement/admission logic.
const Foliage=preload("res://scripts/pc_tactical_foliage.gd")
var checks:=0
var errors:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label)
func leaf_patches(mesh:ArrayMesh)->Array[int]:
	var arrays:=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
	var adjacency:Dictionary={}
	for i in range(0,vertices.size(),3):
		if floorf(tags[i].x*2.0)/2.0!=0.0:continue
		for j in 3:
			var a:Vector3=vertices[i+j];var b:Vector3=vertices[i+(j+1)%3]
			if not adjacency.has(a):adjacency[a]={}
			adjacency[a][b]=true
	var visited:Dictionary={};var patches:Array[int]=[]
	for point:Vector3 in adjacency:
		if visited.has(point):continue
		var pending:Array[Vector3]=[point];var count:=0
		while not pending.is_empty():
			var at:Vector3=pending.pop_back()
			if visited.has(at):continue
			visited[at]=true;count+=1
			for neighbour:Vector3 in adjacency[at]:
				if not visited.has(neighbour):pending.append(neighbour)
		patches.append(count)
	return patches
func _initialize()->void:
	for name:String in ["shrub","grass"]:
		var mesh:=Foliage._authored_mesh(name)
		if not ResourceLoader.exists("res://assets/tactical_world_v1/"+name+".tres"):
			var fallback:=Foliage._shrub() if name=="shrub" else Foliage._grass()
			check(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==fallback.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],name+": source-only kit retains exact optional fallback")
			continue
		check(Foliage._valid_authored_mesh(mesh,name),name+": installed native mesh validates author, geometry and exact footprint")
		check(mesh.get_meta("author_sha256","")==Foliage.WORLD_AUTHOR_SHA,name+": genuine authored resource selected")
		if name=="shrub":
			var patches:=leaf_patches(mesh)
			check(patches.size()>=24,"shrub canopy consists of many individual leaf pairs")
			check(not patches.is_empty() and patches.max()<=12,"leaf pairs replace large closed crown lumps")
		var stale:ArrayMesh=mesh.duplicate()
		stale.set_meta("author_sha256","stale")
		check(not Foliage._valid_authored_mesh(stale,name),name+": stale author rejected")
		stale=mesh.duplicate();stale.set_meta("tactical_world_revision",2)
		check(not Foliage._valid_authored_mesh(stale,name),name+": unsupported revision rejected")
		var arrays:=mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
		vertices[0]=vertices[0]+Vector3.RIGHT;arrays[Mesh.ARRAY_VERTEX]=vertices
		var shifted:=ArrayMesh.new();shifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		shifted.set_meta("author_sha256",Foliage.WORLD_AUTHOR_SHA);shifted.set_meta("tactical_world_revision",1)
		check(not Foliage._valid_authored_mesh(shifted,name),name+": modified footprint rejected")
	check(not Foliage._valid_authored_mesh(ArrayMesh.new(),"shrub"),"empty resource rejected safely")
	check(Foliage._authored_mesh("unavailable").surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==Foliage._grass().surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"absent resource uses exact incumbent fallback")
	var plants:=Foliage.new()
	check(plants.plants.size()==2,"exact two foliage MultiMesh batches retained")
	for layer in 2:
		var cells:int=2*ceili(Foliage.LAYERS[layer][1]/Foliage.LAYERS[layer][0])+1
		check(plants.plants[layer].multimesh.instance_count==cells*cells,"original grid allocation retained")
	plants.free()
	print("PC_TACTICAL_WORLD: %d checks, %d errors"%[checks,errors.size()])
	for error in errors:printerr("FAIL: "+error)
	quit(0 if errors.is_empty() else 1)
