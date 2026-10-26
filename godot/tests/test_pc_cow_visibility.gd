extends SceneTree
## Portable byte/lifecycle contracts. --native additionally draws private fixtures.
const Cow = preload("res://scripts/pc_cow_visibility.gd")
const Ownership = preload("res://scripts/pc_modern_ownership.gd")
const Camera = preload("res://scripts/pc_camera.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const Draw = preload("res://scripts/pc_draw_pass.gd")
const VehicleShader = preload("res://scripts/pc_tactical_vehicles.gdshader")
var errors: Array[String] = []
var checks: int = 0
var native: bool = false
var state: Dictionary = {"frame": 1, "epoch": 1, "allowed": true}
var output: String = ""

class SubmittedView extends Node3D:
	var valid: bool = true
	var generation: int = 1
	func cow_proof_snapshot_valid(snapshot: Dictionary) -> bool:
		if not valid or snapshot.generation != generation: return false
		for row: Dictionary in snapshot.groups:
			var node: MeshInstance3D = row.node
			if not is_instance_valid(node) or not node.is_visible_in_tree() or node.mesh != row.mesh or node.material_override != row.material or node.global_transform != row.global_transform or node.layers != row.layers or node.custom_aabb != row.custom_aabb: return false
			if row.material.shader != row.shader or row.shader.code != row.shader_code or row.material.render_priority != row.priority: return false
			for uniform: String in row.uniforms:
				if row.material.get_shader_parameter(uniform) != row.uniforms[uniform]: return false
		return true

func _initialize() -> void: run.call_deferred()
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: errors.append(why)

func mask_token(ui: Image, dimensions: Vector2i = Vector2i(320, 200), selected: Array = [1]) -> Dictionary:
	return {"size": dimensions, "clip": [0, 0, 319, 199], "ui": ui.get_data(), "selected": selected}

func rectangle(mask: Image, bounds: Rect2i, colour: Color) -> void:
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x): mask.set_pixel(x, y, colour)

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	native = "--native" in args
	if "--output" in args: output = args[args.find("--output") + 1]
	if not output.is_empty() and not output.is_absolute_path(): output = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(output)
	var ui: Image = Image.create(320, 200, false, Image.FORMAT_L8); ui.fill(Color.BLACK)
	var mask: Image = Image.create(320, 200, false, Image.FORMAT_RGBA8); mask.fill(Color.TRANSPARENT)
	var token: Dictionary = mask_token(ui)
	rectangle(mask, Rect2i(70, 50, 40, 30), Color8(1, 0, 255))
	check(Cow.visible_owners(mask, token) == [1], "visible cow interior admits its exact owner")
	mask.fill(Color8(1, 0, 0))
	check(Cow.visible_owners(mask, token).is_empty(), "visible yard/barn without visible cow stays silent")
	for colour: Color in [Color8(2, 0, 255), Color8(1, 0, 8), Color8(1, 0, 64), Color8(1, 0, 254), Color8(1, 0, 255, 254), Color8(0, 0, 255)]:
		mask.fill(colour)
		check(Cow.visible_owners(mask, token).is_empty(), "wrong owner, coverage, mixed edge, alpha or clear cannot prove cow")
	mask.fill(Color.TRANSPARENT); rectangle(mask, Rect2i(70, 50, 5, 5), Color8(1, 0, 255))
	check(Cow.visible_owners(mask, token).is_empty(), "tiny cow patch lacks separated interior witnesses")
	var restored: Image = Image.create(1280,800,false,Image.FORMAT_RGBA8); restored.fill(Color.TRANSPARENT)
	rectangle(restored,Rect2i(280,200,13,8),Color8(1,0,255))
	check(Cow.visible_owners(restored,mask_token(ui,restored.get_size())) == [1], "visible 13x8 world-raster cow qualifies despite less than four original pixels")
	ui.set_pixel(71,50,Color.WHITE)
	check(Cow.visible_owners(restored,mask_token(ui,restored.get_size())).is_empty(), "mapped original 3x3 UI neighbourhood blocks restored cow")
	ui.fill(Color.BLACK)
	var boundary: Dictionary = mask_token(ui,restored.get_size()); boundary.clip = [0,0,0,0]
	check(Cow.visible_owners(restored,boundary).is_empty(), "out-of-bounds original UI neighbourhood is rejected rather than clamped")
	mask.fill(Color.TRANSPARENT)
	rectangle(mask,Rect2i(40,50,3,3),Color8(1,0,255)); rectangle(mask,Rect2i(80,50,3,3),Color8(1,0,255))
	check(Cow.visible_owners(mask,mask_token(ui)) == [1], "two disconnected exact interiors satisfy explicit two-witness policy")
	mask.fill(Color.TRANSPARENT)
	for centre: Vector2i in [Vector2i(50,50),Vector2i(47,51),Vector2i(53,51)]: rectangle(mask,Rect2i(centre-Vector2i.ONE,Vector2i(3,3)),Color8(1,0,255))
	check(Cow.visible_owners(mask,mask_token(ui)) == [1], "complete witness scan considers pairs beyond the first interior")
	mask.fill(Color.TRANSPARENT); rectangle(mask, Rect2i(0, 0, 2, 100), Color8(1, 0, 255))
	check(Cow.visible_owners(mask, token).is_empty(), "raster boundary sliver cannot admit cow")
	mask.fill(Color.TRANSPARENT); rectangle(mask, Rect2i(70, 50, 40, 30), Color8(1, 0, 255))
	rectangle(ui, Rect2i(70, 50, 40, 30), Color.WHITE); token.ui = ui.get_data()
	check(Cow.visible_owners(mask, token).is_empty(), "original UI covering cow excludes otherwise visible farm")
	ui.fill(Color.BLACK); token = mask_token(ui, mask.get_size(), [1, 2])
	mask.fill(Color.TRANSPARENT)
	rectangle(mask, Rect2i(50, 50, 5, 5), Color8(1, 0, 255)); rectangle(mask, Rect2i(150, 50, 5, 5), Color8(2, 0, 255))
	check(Cow.visible_owners(mask, token).is_empty(), "two tiny farms cannot combine their witnesses")
	rectangle(mask, Rect2i(50, 50, 20, 20), Color8(1, 0, 255)); rectangle(mask, Rect2i(150, 50, 20, 20), Color8(2, 0, 255))
	check(Cow.visible_owners(mask, token) == [1, 2], "two independently visible farms preserve distinct owner IDs")
	var packed: Image = Image.create(320, 200, false, Image.FORMAT_RGBA8); packed.fill(Color8(1, 2, 255))
	check(Cow.visible_owners(packed, mask_token(ui, packed.get_size(), [513])) == [513], "exact owner high byte survives classifier")
	var before_classify: PackedByteArray = packed.get_data()
	var before_ui: PackedByteArray = ui.get_data()
	Cow.visible_owners(packed,mask_token(ui,packed.get_size(),[513]))
	check(packed.get_format() == Image.FORMAT_RGBA8 and packed.get_data() == before_classify and ui.get_data() == before_ui, "native RGB search leaves original proof and UI input bytes unchanged")
	for owner_id: int in [255,65281,65534]:
		packed.fill(Color8(owner_id & 255,(owner_id >> 8) & 255,0))
		check(Cow.visible_owners(packed,mask_token(ui,packed.get_size(),[owner_id])).is_empty(), "owner byte255 alone cannot become a cow tag")
		packed.fill(Color8(owner_id & 255,(owner_id >> 8) & 255,255))
		check(Cow.visible_owners(packed,mask_token(ui,packed.get_size(),[owner_id])) == [owner_id], "owner byte255 retains exact full-ID cow admission")

	ui.set_pixel(0, 0, Color8(127, 127, 127)); token.ui = ui.get_data()
	check(not Cow.valid_ui(ui) and Cow.visible_owners(mask, token).is_empty(), "ambiguous nonbinary UI is rejected")
	ui.fill(Color.BLACK)
	check(Cow.visible_owners(Image.create(16, 16, false, Image.FORMAT_RGBA8), mask_token(ui)).is_empty(), "resized/stale target denied")
	var source: String = VehicleShader.code
	var variant: String = Cow.shader_variant(source)
	check(not variant.is_empty() and variant.contains(source.substr(source.find("    // Evaluate all derivatives"), source.rfind("}") - source.find("    // Evaluate all derivatives"))), "proof preserves complete production fragment before final RGB override")
	check(variant.count("discard;") == source.count("discard;") + 1 and variant.contains("depth_draw_opaque") and not variant.contains("ALPHA"), "proof retains opaque mode/source discard and rejects cow at reversed-depth zero")
	check(variant.find("float cow_proof_z=FRAGCOORD.z;") < variant.find("discard;") and variant.contains("2.0/65535.0+abs(dFdx(cow_proof_z))+abs(dFdy(cow_proof_z))"), "pessimistic depth and full-pixel slope derivatives computed before any discard")
	check(variant.contains("DEPTH=cow_proof_z-cow_proof_margin;") and variant.contains("DEPTH=min(cow_proof_z+cow_proof_margin,1.0);"), "cow always biased away and every noncow toward the camera")
	for changed: String in [source + "\nvoid fragment() {}", source + "\nvoid unreviewed_helper() {}", source.replace("depth_draw_opaque", "depth_draw_never"), source + "\n// COLOR is now consumed", source.replace("void fragment() {", "void fragment() {\n    ALPHA=1.0;")]:
		check(Cow.shader_variant(changed).is_empty(), "unreviewed shader semantic changes fail closed")
	check(not Cow.snapshot_supported({}) and not Cow.snapshot_supported({"ok":false,"reason":"fallback"}), "missing group/fallback never schedules component work")
	var proof: RefCounted = Cow.new(); proof.setup(root)
	proof.begin_packet(); proof.before_draw(); proof.after_draw()
	check(proof.reads == 0 and proof.renders == 0 and proof.target == null and proof.admitted.is_empty(), "no farm creates no target, render or readback")
	proof.stop(); proof.release()
	await portable_submission_checks(ui)
	if native:
		if "--retained-only" not in args: await native_checks(ui)
		if "--retained-farm" in args: await retained_farm_checks(args[args.find("--retained-farm") + 1], args)
		if "--retained-list" in args:
			var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--retained-list")+1]))
			var base_output: String = output
			for index: int in cases.size():
				output = base_output.path_join(str(index));DirAccess.make_dir_recursive_absolute(output)
				await retained_farm_checks(cases[index],args)
			output = base_output
	print("PC_COW_VISIBILITY: %d checks, %d errors" % [checks, errors.size()])
	for error: String in errors: printerr("FAIL: " + error)
	quit(0 if errors.is_empty() else 1)

func source_data(blocked: bool = false) -> Dictionary:
	var frame: Dictionary = {"center": [160, 100], "clip": [0, 0, 319, 199], "near_raw": 16, "focal_pixels": 128,
		"matrix_q14_columns": [16384,0,0,0,16384,0,0,0,16384], "world_position_raw": [0,0,0]}
	var points: Array = []
	for point: Vector2 in [Vector2(70, 45), Vector2(250, 45), Vector2(250, 155), Vector2(70, 155)]: points.append(Geometry.unproject(point, 512, frame))
	var object: Dictionary = {"shape_index":157,"root":28643,"static_path":true,"dynamic_instance":false,"polygons":[{"primitive":28751,"fill_mode":1,"colors":[4,4],"camera_vertices":points}],"round_forms":[]}
	var data: Dictionary = {"camera":frame,"objects":[object],"unsupported":[]}
	if blocked:
		var other: Dictionary = object.duplicate(true); other.shape_index = 0
		data.objects.append(other)
	return data

func triangle_mesh(frame: Dictionary, depth: float, cow_tag: bool, proof: bool, right_depth: float = -1.0) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var colours: PackedColorArray = PackedColorArray()
	var uv: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in [Vector2(80,55),Vector2(240,55),Vector2(240,145),Vector2(80,55),Vector2(240,145),Vector2(80,145)]:
		var raw: Array = Geometry.unproject(point, right_depth if right_depth > 0 and point.x >= 240 else depth, frame)
		vertices.append(Vector3(raw[0], raw[1], raw[2])); uv.append(Vector2.ZERO)
		colours.append(Color(1 if cow_tag else 0, 0, 0, 1))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_TEX_UV2] = uv
	if proof: arrays[Mesh.ARRAY_COLOR] = colours
	var mesh: ArrayMesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func fixture_group(view: SubmittedView, owner_id: int, group: int, frame: Dictionary, depth: float, cow_tag: bool, ownership: SubViewport, right_depth: float = -1.0) -> Dictionary:
	var node: MeshInstance3D = MeshInstance3D.new(); view.add_child(node)
	node.mesh = triangle_mesh(frame, depth, cow_tag, false, right_depth)
	node.custom_aabb = AABB(Vector3(-100000,-100000,-100000), Vector3(200000,200000,200000))
	var uniforms: Dictionary = {"source_group":true,"source_piecewise":false,"source_round":false,"strict_source_coverage":true,"instance_owner":float(owner_id),
		"source_group_basis":Basis.IDENTITY,"source_group_origin":Vector3.ZERO,"source_ownership":ownership.get_texture(),"camera_basis_ready":false}
	var material: ShaderMaterial = ShaderMaterial.new(); material.shader = VehicleShader
	for uniform: String in uniforms: material.set_shader_parameter(uniform, uniforms[uniform])
	node.material_override = material
	return {"owner":owner_id,"group":group,"node":node,"mesh":node.mesh,"proof_mesh":triangle_mesh(frame, depth, cow_tag, true, right_depth),"material":material,
		"shader":VehicleShader,"shader_code":VehicleShader.code,"uniforms":uniforms,"global_transform":node.global_transform,"custom_aabb":node.custom_aabb,
		"layers":node.layers,"priority":0,"triangles":2,"cow_triangles":2 if cow_tag else 0,"ambiguous_cow_triangles":0}

func portable_submission_checks(ui: Image) -> void:
	var world: SubViewport = SubViewport.new(); world.own_world_3d = true; world.size = Vector2i(640,400)
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED; root.add_child(world)
	var camera: Camera3D = Camera3D.new(); world.add_child(camera); camera.make_current()
	var ownership: SubViewport = Ownership.new(); root.add_child(ownership)
	var data: Dictionary = source_data(); Camera.apply(camera, data.camera, Vector3.ZERO)
	ownership.prepare(data, world.size, null, {}, {1:true})
	ownership.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var view: SubmittedView = SubmittedView.new(); world.add_child(view)
	var row: Dictionary = fixture_group(view,1,28745,data.camera,512.0,true,ownership)
	var snapshot: Dictionary = {"ok":true,"view":view,"generation":1,"assets":RefCounted.new(),"revision":1,"owners":[1],"groups":[row],"triangles":2}
	check(Cow.snapshot_supported(snapshot), "complete tagged canonical group is supported")
	var bad: Dictionary = snapshot.duplicate(true); bad.owners = [1,2,3,4,5]
	check(not Cow.snapshot_supported(bad), "candidate owner cap enforced before private target work")
	bad = snapshot.duplicate(true); bad.groups.resize(33)
	check(not Cow.snapshot_supported(bad), "group cap enforced before private target work")
	bad = snapshot.duplicate(true); bad.triangles = 32769
	check(not Cow.snapshot_supported(bad), "triangle cap enforced before private target work")
	bad = snapshot.duplicate(true); bad.groups[0].cow_triangles = 0
	check(not Cow.snapshot_supported(bad), "missing cow group/tag cannot qualify visible yard")
	var other: Dictionary = row.duplicate(true); other.group = 28670; other.cow_triangles = 0
	other.uniforms.source_group_origin = Vector3.ONE
	bad = snapshot.duplicate(true); bad.groups.append(other); bad.triangles = 4
	check(Cow.snapshot_supported(bad), "distinct actual group fits retained under conservative private depth proof")
	var proof: RefCounted = Cow.new(); proof.setup(root)
	var current: Callable = func() -> Array: return [state.frame, state.epoch]
	var guard: Callable = func() -> bool: return state.allowed
	check(proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard), "portable actual-node snapshot prepares without GPU read")
	check(proof.reads == 0 and proof.renders == 0, "preparation alone never reads or claims completed rendering")
	# Portable cache injection exercises lifecycle only; native mode proves bytes.
	var retained_mask: Image = Image.create(640,400,false,Image.FORMAT_RGBA8); retained_mask.fill(Color8(1,0,255))
	proof._proof_mask = retained_mask; proof._proof_key = proof.pending.proof_key.duplicate(true)
	proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
	check(proof.pending.has("reuse_mask"), "unchanged retained source frame queues exact immutable cached proof")
	proof.before_draw(); proof.after_draw()
	check(proof.admitted == [1] and proof.reads == 0 and proof.cache_hits == 1, "cached bytes require pre/postdraw and current token")
	var mutations: Array[String] = ["origin","generation","frame","epoch","mute","resize","camera","mesh","ui","private","reset"]
	for mutation: String in mutations:
		check(proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard), "fresh current token prepares: " + mutation)
		proof.before_draw()
		match mutation:
			"origin": row.material.set_shader_parameter("source_group_origin", Vector3.ONE)
			"generation": view.generation += 1
			"frame": state.frame += 1
			"epoch": state.epoch += 1
			"mute": state.allowed = false
			"resize": world.size = Vector2i(320,200)
			"camera": camera.h_offset = 0.25
			"mesh": row.node.mesh = null
			"ui": ui.fill(Color.WHITE)
			"private": proof.camera.h_offset = 0.5
			"reset": proof.stop()
		proof.after_draw()
		check(proof.admitted.is_empty() and proof.reads == 0, "post-arm stale mutation cannot read or admit: " + mutation)
		row.material.set_shader_parameter("source_group_origin", Vector3.ZERO); view.generation = 1; state = {"frame":1,"epoch":1,"allowed":true}
		world.size = Vector2i(640,400); camera.h_offset = 0.0; row.node.mesh = row.mesh; ui.fill(Color.BLACK)
	proof.release(); world.queue_free(); ownership.queue_free(); await process_frame

func native_checks(ui: Image) -> void:
	var world: SubViewport = SubViewport.new(); world.own_world_3d = true; world.size = Vector2i(640,400)
	world.msaa_3d = Viewport.MSAA_4X; world.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(world)
	var camera: Camera3D = Camera3D.new(); world.add_child(camera); camera.make_current()
	var ownership: SubViewport = Ownership.new(); root.add_child(ownership)
	var data: Dictionary = source_data(); Camera.apply(camera, data.camera, Vector3.ZERO)
	ownership.prepare(data, world.size, null, {}, {1:true})
	var view: SubmittedView = SubmittedView.new(); world.add_child(view)
	var row: Dictionary = fixture_group(view, 1, 28745, data.camera, 512.0, true, ownership)
	var snapshot: Dictionary = {"ok":true,"view":view,"generation":1,"assets":RefCounted.new(),"revision":1,"owners":[1],"groups":[row],"triangles":2}
	# Two independent no-companion draws distinguish initial viewport upload
	# settling from a pixel change caused by enabling the private proof.
	await RenderingServer.frame_post_draw
	var startup_world: Image = world.get_texture().get_image()
	var startup_owners: Image = ownership.get_texture().get_image()
	await RenderingServer.frame_post_draw
	var baseline_world_image: Image = world.get_texture().get_image()
	var baseline_owner_image: Image = ownership.get_texture().get_image()
	var baseline_world: PackedByteArray = baseline_world_image.get_data()
	var baseline_owners: PackedByteArray = baseline_owner_image.get_data()
	var startup_changed: bool = startup_world.get_data() != baseline_world or startup_owners.get_data() != baseline_owners
	if startup_changed:
		await RenderingServer.frame_post_draw
		check(world.get_texture().get_image().get_data() == baseline_world,"generated no-companion world baseline settles before proof is enabled")
		check(ownership.get_texture().get_image().get_data() == baseline_owners,"generated no-companion owner baseline settles before proof is enabled")
		if not output.is_empty():
			DirAccess.make_dir_recursive_absolute(output)
			startup_world.save_png(output.path_join("generated-startup-world.png")); startup_owners.save_png(output.path_join("generated-startup-owners.png"))
			baseline_world_image.save_png(output.path_join("generated-settled-world.png")); baseline_owner_image.save_png(output.path_join("generated-settled-owners.png"))
	var baseline_ui: PackedByteArray = ui.get_data()
	var baseline_source: String = JSON.stringify(data)
	var proof: RefCounted = Cow.new(); proof.setup(root)
	RenderingServer.frame_pre_draw.connect(proof.before_draw); RenderingServer.frame_post_draw.connect(proof.after_draw)
	var current: Callable = func() -> Array: return [state.frame, state.epoch]
	var guard: Callable = func() -> bool: return state.allowed
	check(proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard), "actual live group fixture schedules exact companion")
	await RenderingServer.frame_post_draw
	check(proof.admitted == [1] and proof.reads == 1, "native visible cow proof admits after actual draw")
	var after_world: Image = world.get_texture().get_image()
	var after_owners: Image = ownership.get_texture().get_image()
	var world_unchanged: bool = after_world.get_data() == baseline_world
	var owners_unchanged: bool = after_owners.get_data() == baseline_owners
	check(world_unchanged,"generated private companion leaves production world RGBA unchanged")
	check(owners_unchanged,"generated private companion leaves original ownership RGBA unchanged")
	check(ui.get_data() == baseline_ui,"generated private companion leaves original UI bytes unchanged")
	check(JSON.stringify(data) == baseline_source,"generated private companion leaves source packet unchanged")
	if (not world_unchanged or not owners_unchanged) and not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		baseline_world_image.save_png(output.path_join("generated-baseline-world.png")); after_world.save_png(output.path_join("generated-after-world.png"))
		baseline_owner_image.save_png(output.path_join("generated-baseline-owners.png")); after_owners.save_png(output.path_join("generated-after-owners.png"))
	var read_count: int = proof.reads
	for retained: int in 3:
		proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
		await RenderingServer.frame_post_draw
		check(proof.admitted == [1] and proof.reads == read_count, "retained identical frame reuses exact proof after postdraw")
	ui.fill(Color.WHITE); proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
	await RenderingServer.frame_post_draw
	check(proof.admitted.is_empty() and proof.reads == read_count, "UI-only change reclassifies cache without GPU read")
	ui.fill(Color.BLACK)
	# In the very next draw, the current production owner texture must win.
	ownership.prepare(source_data(true),world.size,null,{}, {1:true,2:true})
	proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
	await RenderingServer.frame_post_draw
	check(proof.admitted.is_empty() and proof.reads == read_count + 1, "same-draw later owner blocks cow, no old owner texture authority")
	ownership.prepare(data,world.size,null,{}, {1:true})
	var barn: Dictionary = fixture_group(view,1,28670,data.camera,384.0,false,ownership)
	snapshot.groups.append(barn); snapshot.triangles = 4
	proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
	await RenderingServer.frame_post_draw
	check(proof.admitted.is_empty(), "visible noncow barn writes depth and hides cow")
	snapshot.groups.reverse()
	proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
	await RenderingServer.frame_post_draw
	check(proof.admitted.is_empty(), "reversed opaque submission retains interior barn depth winner")
	snapshot.groups.reverse()
	barn.node.visible = false; snapshot.groups.pop_back(); snapshot.triangles = 2
	proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
	await RenderingServer.frame_post_draw
	check(proof.admitted == [1], "cow-only negative control demonstrates why complete noncow depth is required")
	for mutation: String in ["origin","generation","frame","epoch","mute","resize","camera","mesh","reset"]:
		proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,state.frame,state.epoch,current,guard)
		match mutation:
			"origin": row.material.set_shader_parameter("source_group_origin", Vector3.ONE)
			"generation": view.generation += 1
			"frame": state.frame += 1
			"epoch": state.epoch += 1
			"mute": state.allowed = false
			"resize": world.size = Vector2i(320,200)
			"camera": camera.h_offset = 0.25
			"mesh": row.node.mesh = null
			"reset": proof.stop()
		await RenderingServer.frame_post_draw
		check(proof.admitted.is_empty(), "queued/cached proof invalidated before draw: " + mutation)
		row.material.set_shader_parameter("source_group_origin", Vector3.ZERO); view.generation = 1; state = {"frame":1,"epoch":1,"allowed":true}
		world.size = Vector2i(640,400); camera.h_offset = 0.0; row.node.mesh = row.mesh
	# Pessimistic reversed depth must deny every full hidden-cow fixture,
	# including exact ties, crossing slopes and near/far saturation.
	for aa: int in [Viewport.MSAA_DISABLED, Viewport.MSAA_4X]:
		world.msaa_3d = aa
		for sample: Dictionary in [{"case":"coplanar","left":512.0,"right":512.0}, {"case":"steep-hidden","left":64.0,"right":500.0}, {"case":"steep-crossing","left":64.0,"right":1024.0}, {"case":"near-saturation","left":16.0,"right":16.0}]:
			var blocker: Dictionary = fixture_group(view,1,28670,data.camera,sample.left,false,ownership,sample.right)
			snapshot.groups = [row,blocker]; snapshot.triangles = 4
			for reversed_order: bool in [false,true]:
				if reversed_order: snapshot.groups.reverse()
				proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
				await RenderingServer.frame_post_draw
				if sample.case == "steep-crossing":
					# Only the physically hidden left half is an absolute negative.
					var cow_pixels: bool = false
					if proof._proof_mask != null:
						var image: Image = proof._proof_mask
						for py: int in range(115,285):
							for px: int in range(165,250):
								if image.get_pixel(px,py).b8 == 255 and image.get_pixel(px,py).a8 == 255: cow_pixels = true
					check(not cow_pixels,"steep crossing has no hidden cow pixels, MSAA=%d reverse=%s" % [aa,reversed_order])
				else: check(proof.admitted.is_empty(),"hidden cow stays silent: %s MSAA=%d reverse=%s" % [sample.case,aa,reversed_order])
			blocker.node.visible = false
		# A surviving zero/small reversed depth must never win the clear value.
		var distant: Dictionary = fixture_group(view,1,28745,data.camera,camera.far*64.0*0.99,true,ownership)
		row.node.visible = false; snapshot.groups = [distant]; snapshot.triangles = 2
		proof.prepare(snapshot,world,camera,ownership,ui,data.camera.clip,1,1,current,guard)
		await RenderingServer.frame_post_draw
		check(proof.admitted.is_empty(),"far saturation discards cow before GEQUAL can accept zero, MSAA=%d" % aa)
		distant.node.visible = false; row.node.visible = true; snapshot.groups = [row]; snapshot.triangles = 2
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("cow-native.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"reads":proof.reads,"renders":proof.renders,"cache_hits":proof.cache_hits,"startup_changed_before_companion":startup_changed,"source":"generated actual-submission fixture; no guest launch or actual-farm angle acceptance"},"  "))
	RenderingServer.frame_pre_draw.disconnect(proof.before_draw); RenderingServer.frame_post_draw.disconnect(proof.after_draw)
	proof.release(); world.queue_free(); ownership.queue_free(); await process_frame

func retained_farm_checks(path: String, args: PackedStringArray) -> void:
	# Optional full production drawpass replay from already retained original
	# bytes. This reads no guest/core and is launched only by the root owner.
	var capture: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(capture is Dictionary and capture.get("presentation") is Dictionary, "retained source capture loads")
	if not capture is Dictionary or not capture.get("presentation") is Dictionary: return
	var data: Dictionary = capture.presentation.get("draw_pass", {})
	var overlay: Dictionary = capture.presentation.get("ui_overlay", {})
	var ui: Image = Image.new()
	check(ui.load_png_from_buffer(Marshalls.base64_to_raw(str(overlay.get("mask_png","")))) == OK, "retained original UI decodes")
	check(Cow.valid_ui(ui), "retained original UI remains binary L8")
	if not Cow.valid_ui(ui): return
	var root_dir: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var world: SubViewport = SubViewport.new(); world.own_world_3d = true
	world.msaa_3d = Viewport.MSAA_4X; world.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(world)
	var camera: Camera3D = Camera3D.new(); world.add_child(camera); camera.make_current()
	var draw: Node3D = Draw.new(); camera.add_child(draw)
	draw.solid_enabled = true; draw.modern_enabled = true; draw.tactical_landscape = true
	print("COW_RETAINED_STAGE: assets_load")
	check(draw.load_modern_assets(root_dir), "retained native full production assets load")
	print("COW_RETAINED_STAGE: assets_ready")
	var frame: Dictionary = data.camera.duplicate(true)
	frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]; frame.world_position_raw = [0,0,0]
	world.size = Camera.apply(camera,frame,Vector3.ZERO) * 5
	print("COW_RETAINED_STAGE: apply_source")
	draw.apply_pass(data)
	print("COW_RETAINED_STAGE: source_ready")
	var snapshot: Dictionary = draw.tactical_vehicle_view.cow_proof_snapshot(draw.tactical_vehicle_assets,data)
	check(snapshot.ok and Cow.snapshot_supported(snapshot), "actual retained farm complete groups and independently rounded fits accepted")
	if not snapshot.ok:
		world.queue_free(); await process_frame; return
	await RenderingServer.frame_post_draw
	print("COW_RETAINED_STAGE: baseline_drawn")
	var baseline: PackedByteArray = world.get_texture().get_image().get_data()
	var owners: PackedByteArray = draw.ownership.get_texture().get_image().get_data()
	var source_bytes: String = JSON.stringify(data)
	var proof: RefCounted = Cow.new(); proof.setup(root)
	RenderingServer.frame_pre_draw.connect(proof.before_draw); RenderingServer.frame_post_draw.connect(proof.after_draw)
	state = {"frame":1,"epoch":1,"allowed":true}
	var current: Callable = func() -> Array: return [state.frame,state.epoch]
	var guard: Callable = func() -> bool: return state.allowed
	var first_start: int = Time.get_ticks_usec()
	check(proof.prepare(snapshot,world,camera,draw.ownership,ui,data.camera.clip,1,1,current,guard), "retained exact source proof prepares")
	var first_prepare: int = Time.get_ticks_usec() - first_start
	await RenderingServer.frame_post_draw
	print("COW_RETAINED_STAGE: proof_drawn")
	var first_read: int = proof.last_read_usec
	var first_phases: Dictionary = {"prepare":proof.last_prepare_usec,"before_draw":proof.last_before_usec,"after_draw":proof.last_after_usec,"readback":proof.last_read_usec,"classification":proof.last_classify_usec}
	check(world.get_texture().get_image().get_data() == baseline and draw.ownership.get_texture().get_image().get_data() == owners and JSON.stringify(data) == source_bytes, "retained actual production RGBA, owner and source bytes unchanged")
	if "--expect-visible-cow" in args: check(not proof.admitted.is_empty(), "actual retained visible cow has a conservative component proof")
	if "--expect-hidden-cow" in args: check(proof.admitted.is_empty(), "actual retained hidden cow stays silent")
	var diagnostic: Dictionary = {}
	if "--unbiased-control" in args:
		# Attribution only: ordinary production depth, all groups retained. Never
		# changes live shaders/materials or qualifies a shipping visibility rule.
		var biased: Image = proof._proof_mask.duplicate() as Image
		var original_code: String = VehicleShader.code
		var ending: int = original_code.rfind("}")
		var control_code: String = original_code.substr(0,ending)+"    ALBEDO=vec3(cow_proof_owner,COLOR.r);\n}"
		control_code = control_code.replace("void vertex() {","uniform vec2 cow_proof_owner;\nvoid vertex() {")
		proof._shader.code = control_code;proof._proof_mask = null
		check(proof.prepare(snapshot,world,camera,draw.ownership,ui,data.camera.clip,1,1,current,guard), "unbiased private attribution control prepares")
		await RenderingServer.frame_post_draw
		var control: Image = proof._proof_mask
		var counts: Array = []
		for sample: Image in [biased,control]:
			var count: int = 0
			var low: Vector2i = sample.get_size();var high: Vector2i = Vector2i(-1,-1)
			var bytes: PackedByteArray = sample.get_data()
			for index: int in sample.get_width()*sample.get_height():
				if bytes[index*4+2] == 255 and bytes[index*4+3] == 255:
					var pixel: Vector2i = Vector2i(index%sample.get_width(),index/sample.get_width())
					count+=1;low=low.min(pixel);high=high.max(pixel)
			counts.append({"exact_cow_pixels":count,"minimum":[low.x,low.y],"maximum":[high.x,high.y]})
		diagnostic = {"kind":"unbiased attribution control, never shipping acceptance","biased":counts[0],"control":counts[1]}
		biased.save_png(output.path_join("retained-biased.png"));control.save_png(output.path_join("retained-unbiased-control.png"))
		FileAccess.open(output.path_join("unbiased-diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify(diagnostic,"  "))
		check(world.get_texture().get_image().get_data()==baseline and draw.ownership.get_texture().get_image().get_data()==owners and JSON.stringify(data)==source_bytes, "unbiased private diagnostic preserves all production and source bytes")
		# Restore the originally reviewed proof before cache/cost checks below.
		proof._shader.code=Cow.shader_variant(original_code);proof._proof_mask=null
		proof.prepare(snapshot,world,camera,draw.ownership,ui,data.camera.clip,1,1,current,guard)
		await RenderingServer.frame_post_draw
	var first_admitted: Array = proof.admitted.duplicate()
	var before_cache_reads: int = proof.reads
	var before_cache_hits: int = proof.cache_hits
	var cached_start: int = Time.get_ticks_usec()
	proof.prepare(snapshot,world,camera,draw.ownership,ui,data.camera.clip,1,1,current,guard)
	var cache_prepare: int = Time.get_ticks_usec() - cached_start
	await RenderingServer.frame_post_draw
	check(proof.admitted == first_admitted and proof.reads == before_cache_reads and proof.cache_hits == before_cache_hits+1, "actual retained source frame reuses exact component mask")
	var cache_phases: Dictionary = {"prepare":proof.last_prepare_usec,"before_draw":proof.last_before_usec,"after_draw":proof.last_after_usec,"readback":proof.last_read_usec,"classification":proof.last_classify_usec}
	state.frame = 2
	var changed_start: int = Time.get_ticks_usec()
	proof.prepare(snapshot,world,camera,draw.ownership,ui,data.camera.clip,2,1,current,guard)
	var changed_prepare: int = Time.get_ticks_usec() - changed_start
	await RenderingServer.frame_post_draw
	check(proof.reads == before_cache_reads+1, "changed source frame gets a fresh component proof")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		if proof._proof_mask != null: proof._proof_mask.save_png(output.path_join("retained-farm-component.png"))
		world.get_texture().get_image().save_png(output.path_join("retained-farm-world.png"))
		draw.ownership.get_texture().get_image().save_png(output.path_join("retained-farm-owners.png"))
		var groups: Array[Dictionary] = []
		for index: int in snapshot.groups.size():
			var row: Dictionary = snapshot.groups[index]
			var clone: MeshInstance3D = proof._nodes[index]
			groups.append({"group":row.group,"owner":row.owner,"triangles":row.triangles,"cow_triangles":row.cow_triangles,
				"live_path":str(row.node.get_path()),"live_global":transform_values(row.node.global_transform),"clone_global":transform_values(clone.global_transform),
				"live_group_basis":str(row.material.get_shader_parameter("source_group_basis")),"clone_group_basis":str(clone.material_override.get_shader_parameter("source_group_basis")),
				"live_group_origin":str(row.material.get_shader_parameter("source_group_origin")),"clone_group_origin":str(clone.material_override.get_shader_parameter("source_group_origin")),
				"live_instance_owner":row.material.get_shader_parameter("instance_owner"),"clone_instance_owner":clone.material_override.get_shader_parameter("instance_owner"),
				"live_source_group":row.material.get_shader_parameter("source_group"),"clone_source_group":clone.material_override.get_shader_parameter("source_group"),
				"live_strict_coverage":row.material.get_shader_parameter("strict_source_coverage"),"clone_strict_coverage":clone.material_override.get_shader_parameter("strict_source_coverage"),
				"live_layers":row.node.layers,"clone_layers":clone.layers,"live_visible":row.node.is_visible_in_tree(),"clone_visible":clone.is_visible_in_tree(),
				"live_aabb":str(row.node.custom_aabb),"clone_aabb":str(clone.custom_aabb),"clone_mesh_matches":clone.mesh==row.proof_mesh,
				"live_owner_texture_matches":row.material.get_shader_parameter("source_ownership")==draw.ownership.get_texture(),"clone_owner_texture_matches":clone.material_override.get_shader_parameter("source_ownership")==draw.ownership.get_texture()})
		var cameras: Dictionary = {"original_source_camera":data.camera,"world_size":str(world.size),"proof_size":str(proof.target.size),"owner_size":str(draw.ownership.size),
			"live_global":transform_values(camera.global_transform),"clone_global":transform_values(proof.camera.global_transform),
			"live_effective":transform_values(camera.get_camera_transform()),"clone_effective":transform_values(proof.camera.get_camera_transform()),
			"live_projection":str(camera.get_camera_projection()),"clone_projection":str(proof.camera.get_camera_projection()),
			"live_cull_mask":camera.cull_mask,"clone_cull_mask":proof.camera.cull_mask,"ownership_camera":transform_values(draw.ownership.camera.global_transform)}
		FileAccess.open(output.path_join("retained-farm.json"),FileAccess.WRITE).store_string(JSON.stringify({"source":path,"source_sha256":FileAccess.get_sha256(path),"owners":snapshot.owners,"groups":snapshot.groups.size(),"emitted_groups":groups,"cameras":cameras,"triangles":snapshot.triangles,"admitted":proof.admitted,"first_prepare_usec":first_prepare,"first_read_usec":first_read,"cpu_phases_usec":{"first":first_phases,"cache":cache_phases,"changed_frame":{"prepare":proof.last_prepare_usec,"before_draw":proof.last_before_usec,"after_draw":proof.last_after_usec,"readback":proof.last_read_usec,"classification":proof.last_classify_usec}},"cache_prepare_usec":cache_prepare,"changed_frame_prepare_usec":changed_prepare,"changed_frame_read_usec":proof.last_read_usec,"reads":proof.reads,"cache_hits":proof.cache_hits,"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name()},"  "))
	RenderingServer.frame_pre_draw.disconnect(proof.before_draw); RenderingServer.frame_post_draw.disconnect(proof.after_draw)
	proof.release(); world.queue_free(); await process_frame

func transform_values(value: Transform3D) -> Dictionary:
	return {"basis":[[value.basis.x.x,value.basis.x.y,value.basis.x.z],[value.basis.y.x,value.basis.y.y,value.basis.y.z],[value.basis.z.x,value.basis.z.y,value.basis.z.z]],"origin":[value.origin.x,value.origin.y,value.origin.z]}
