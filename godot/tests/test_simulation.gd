extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	# A runtime error aborts _run before quit(); the deadline still ends the process.
	create_timer(60).timeout.connect(func(): printerr("FAIL: simulation deadline"); quit(2))
	_run.call_deferred()

func _run() -> void:
	_test_determinism()
	_test_weapons()
	_test_stations()
	_test_corrected_controls()
	_test_boundaries()
	_test_targeting()
	_test_snapshots()
	_test_completion()
	_test_contract_clauses()
	_test_range_presentation()
	_test_cover_motion()
	if failures.is_empty():
		print("SIMULATION: %d checks passed" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)

func _test_cover_motion() -> void:
	var cover = load("res://scripts/cover_scene.gd").new()
	var hero = load("res://scripts/vehicle.gd").new()
	hero.cover_detail = true
	var camera := Camera3D.new()
	root.add_child(cover);root.add_child(hero);root.add_child(camera)
	if FileAccess.file_exists(hero.COVER_BLENDER_ASSET):
		var asset: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(hero.COVER_BLENDER_ASSET))
		check(hero.authored_cover_batches==asset.batches.size(),"motion retains every authored Blender batch")
	check(hero.running_rig.get_bone_count()==119 and hero.crew_rig.get_bone_count()==5,"bounded running gear and crew rigs")
	var bound: Dictionary = {}
	for child in hero.get_children():
		if not child is MeshInstance3D or child.skin==null: continue
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for i in bones.size():
			if weights[i]>0.0: bound[bones[i]]=true
	for part in hero._running_parts:
		check(bound.has(part.bone),"every moving wheel/shoe has bound geometry: %d" % part.bone)
	for person in 2:
		for hand in hero.CREW_HANDS[person]:
			for offset in [Vector3.ZERO,Vector3.RIGHT*0.04,Vector3.UP*0.04]:
				check(hero.crew_weights(hand+offset,person).x==0.0,"crew grip remains fixed in turret space")
	cover.set_active(true)
	cover.pose(hero,camera,Vector2(1152,648))
	for rig in [hero.running_rig,hero.crew_rig]:
		rig.force_update_all_bone_transforms()
		for bone in rig.get_bone_count():
			check(rig.get_bone_global_pose(bone).is_equal_approx(rig.get_bone_global_rest(bone)),"zero-time skin preserves authored rest pose")
	var initial: Transform3D = hero.transform
	var turret_start: float = hero.turret_root.rotation.y
	cover.advance(1.0,true);cover.pose(hero,camera,Vector2(1152,648))
	check(hero.position.z < initial.origin.z and is_equal_approx(-hero.position.z,cover.TRAVEL_SPEED),"tank actually advances at cover speed")
	check(hero.basis!=initial.basis and hero.position.y!=initial.origin.y,"suspension has bounded heave and roll")
	check(hero.turret_root.rotation.y!=turret_start,"turret gently tracks")
	check((camera.position-hero.position).is_equal_approx(cover.CAMERA_POS),"camera follows at unchanged forward offset")
	check(camera.basis.is_equal_approx(Basis.from_euler(cover.CAMERA_ROT,EULER_ORDER_YXZ)),"follow camera never orbits")
	check(cover._lamp_mount.global_transform.is_equal_approx(hero.global_transform),"headlight halos stay attached to moving hull")
	for person in 2:
		check(not hero.crew_rig.get_bone_pose_rotation(1+person*2).is_equal_approx(Quaternion.IDENTITY),"both torsos move")
		check(not hero.crew_rig.get_bone_pose_rotation(2+person*2).is_equal_approx(Quaternion.IDENTITY),"both heads move independently")
	var still: Transform3D = hero.transform
	var still_camera: Transform3D = camera.transform
	var still_time: float = cover.motion_time
	cover.advance(3.0,false);cover.pose(hero,camera,Vector2(1152,648))
	check(cover.motion_time==still_time and hero.transform==still and camera.transform==still_camera,"reduced motion freezes body and follow camera exactly")
	cover.set_active(false);cover.advance(5.0,true)
	check(cover.motion_time==still_time,"hidden cover never catches up on wall time")
	hero.update_cover_motion(0.0,0.0)
	for rig in [hero.running_rig,hero.crew_rig]:
		rig.force_update_all_bone_transforms()
		for bone in rig.get_bone_count():
			check(rig.get_bone_global_pose(bone).is_equal_approx(rig.get_bone_global_rest(bone)),"range restores every motion bone to rest")
	hero.free();cover.free();camera.free()

func _has_event(events: Array, kind: String) -> bool:
	for event in events:
		if event.type == kind:
			return true
	return false

func _test_determinism() -> void:
	var a = Sim.new()
	var b = Sim.new()
	a.reset(77)
	b.reset(77)
	for tick in 900:
		var commands: Dictionary = {"throttle": 0.7, "steer": sin(float(tick) * 0.03), "fire": tick % 61 == 0, "select_weapon": tick % 4}
		check(a.tick(commands) == b.tick(commands), "deterministic events tick %d" % tick)
	check(a.snapshot() == b.snapshot(), "deterministic final snapshot")
	var exported: Dictionary = a.snapshot()
	exported.ammo[0] = 999
	check(a.ammo[0] != 999, "snapshot does not alias ammo")

func _test_weapons() -> void:
	var sim = Sim.new()
	var initial: int = sim.ammo[0]
	check(_has_event(sim.tick({"fire": true}), "fire"), "main gun fires")
	check(sim.ammo[0] == initial - 1, "exactly one round consumed")
	check(not _has_event(sim.tick({"fire": true}), "fire"), "reload blocks next shot")
	check(sim.ammo[0] == initial - 1, "blocked shot consumes nothing")
	check(_has_event(sim.tick({"select_weapon": 3, "fire": true}), "fire"), "MG independent during main reload")
	check(sim.mg_cooldown_ticks == 6 and sim.reload_ticks > 0, "independent reload counters")
	check(not _has_event(sim.tick({"fire": true}), "fire"), "MG cadence gated")
	sim.ammo[3] = 0
	for tick in 20:
		sim.tick({"fire": true})
	check(sim.ammo[3] == 0, "empty weapon never negative")
	sim.reset()
	for tick in 2000:
		sim.tick({"fire": true, "smoke": true})
	check(sim.ammo[0] >= 0 and sim.smoke_count == 0, "resource conservation")
	sim.reset()
	sim.weapon = 2
	sim.turret = sim.bearing_to(sim.targets[0].pos)
	sim.tick({"fire": true})
	check(sim.targets[0].alive, "AX minimum range enforced")

func _test_stations() -> void:
	for station in 4:
		var sim = Sim.new()
		var before: Vector2 = sim.pos
		var events: Array = sim.tick({"station": station, "fire": true, "smoke": true, "toggle_thermal": true, "toggle_zoom": true, "throttle": 1.0})
		check(_has_event(events, "fire") == (station == 0), "fire station %d" % station)
		check((sim.smoke_count == 3) == (station == 0), "smoke station %d" % station)
		check(sim.thermal == (station <= 1) and sim.zoom == (station == 0), "optics station %d" % station)
		check((sim.pos != before) == (station != 2), "movement station %d" % station)
		sim.tick({"toggle_control": true, "turret_axis": 1.0})
		check(sim.turret != 0.0, "turret available station %d" % station)
	for station in [1, 2, 3]:
		var sim = Sim.new()
		sim.weapon = 3
		check(not _has_event(sim.tick({"station": station, "fire": true}), "fire"), "MG restricted to gunner station %d" % station)

func _test_boundaries() -> void:
	var sim = Sim.new()
	sim.pos = Vector2(0, -1800)
	sim.speed = 12
	sim.tick({"throttle": 1.0})
	check(sim.pos.y == -1800 and sim.speed == 0, "boundary clamps and stops")
	sim.tick({"throttle": NAN, "steer": INF, "turret_axis": "bad"})
	check(is_finite(sim.pos.x) and is_finite(sim.heading), "invalid axes contained")
	sim.tick({"select_weapon": 900, "station": -1})
	check(sim.weapon == 0 and sim.station == 0, "invalid enum commands ignored")
	sim.fuel = 0.00001
	sim.tick({})
	check(sim.fuel == 0.0, "fuel clamped to zero")

func _test_targeting() -> void:
	var sim = Sim.new()
	sim.turret = sim.bearing_to(sim.targets[0].pos)
	sim.tick({"select_target": true, "lock_target": true})
	check(sim.selected_target >= 0 and sim.locked, "target selection and lock")
	sim.tick({"fire": true})
	check(sim.selected_target == -1 and not sim.locked, "destroyed lock invalidated")
	sim.reset()
	sim.selected_target = 0
	sim.locked = true
	sim.pos = Vector2(1200, -1800)
	sim.tick({})
	check(sim.selected_target == -1 and not sim.locked, "out of range lock invalidated")
	sim.reset()
	sim.turret = PI
	sim.tick({"select_target": true, "lock_target": true})
	check(sim.selected_target == -1 and not sim.locked, "no target behind sight")
	sim.reset()
	var cycled_none: bool = false
	for i in 5:
		sim.tick({"select_target": true})
		if sim.selected_target == -1:
			cycled_none = true
	check(cycled_none, "selection cycle includes none")

func _test_snapshots() -> void:
	var sim = Sim.new()
	for i in 91:
		sim.tick({"throttle": 1, "steer": 0.2, "fire": i == 0})
	sim.tick({"toggle_control": true, "toggle_zoom": true, "sight_axis": 1.0})
	var saved: Dictionary = sim.snapshot()
	var restored = Sim.new()
	check(restored.restore(saved), "snapshot restore accepted")
	check(restored.snapshot() == saved, "snapshot exact roundtrip")
	var json_saved: Dictionary = JSON.parse_string(JSON.stringify(saved, "", true, true))
	check(restored.restore(json_saved), "JSON snapshot accepted")
	check(is_equal_approx(restored.fuel, sim.fuel), "JSON numeric equivalence")
	check(restored.restore(bytes_to_var(var_to_bytes(saved))), "lossless binary snapshot accepted")
	for i in 20:
		check(sim.tick({"steer": 0.2}) == restored.tick({"steer": 0.2}), "restored event trajectory %d" % i)
	check(sim.snapshot() == restored.snapshot(), "restored state trajectory")
	var wide_seed = Sim.new()
	wide_seed.reset(9223372036854775807)
	check(Sim.new().restore(wide_seed.snapshot()), "full-width integer seed restore")
	var bad_variants: Array = []
	for key in saved.keys():
		var bad: Dictionary = saved.duplicate(true)
		bad.erase(key)
		bad_variants.append(bad)
	for pair in [["ammo", [-1, 1, 1, 1]], ["ammo", [1]], ["pos", [NAN, 0]], ["pos", [9000, 0]], ["heading", INF], ["station", 2.5], ["locked", true], ["fuel", -1], ["status", "won"], ["version", 99], ["targets", []], ["elevation", INF], ["elevation", -1], ["elevation", 1], ["zoom_level", 3], ["zoom_level", 1.5], ["zoom_level", 0], ["zoom", false],
			["version", "2"], ["range_id", 5], ["zoom", "yes"], ["seed", "1"], ["status", 1], ["control_hull", 1], ["targets", "t01"]]:
		var bad: Dictionary = saved.duplicate(true)
		bad[pair[0]] = pair[1]
		bad_variants.append(bad)
	for pair in [["id", 1], ["name", 5], ["kind", null], ["alive", 1]]:
		var bad: Dictionary = saved.duplicate(true)
		bad.targets[0][pair[0]] = pair[1]
		bad_variants.append(bad)
	for bad in bad_variants:
		var before: Dictionary = restored.snapshot()
		check(not restored.restore(bad), "malformed snapshot rejected")
		check(restored.snapshot() == before, "rejection transactional")
	check(restored.restore(saved), "valid restore after rejection")
	saved.targets[0].hp = 1
	check(restored.targets[0].hp != 1, "restore target isolation")

func _test_completion() -> void:
	var sim = Sim.new()
	for i in sim.targets.size():
		sim.turret = sim.bearing_to(sim.targets[i].pos)
		var events: Array = sim.tick({"fire": true})
		if i == sim.targets.size() - 1:
			check(_has_event(events, "won"), "completion emits win event")
		else:
			for tick in 240:
				sim.tick({})
	check(sim.status == "won", "all targets complete exercise")
	var saved: Dictionary = sim.snapshot()
	check(sim.tick({"fire": true, "throttle": 1}).is_empty() and sim.snapshot() == saved, "win terminal and immutable")
	check(Sim.new().restore(saved), "winning snapshot restorable")
	sim.reset()
	sim.fuel = 0.000001
	check(_has_event(sim.tick({}), "lost") and sim.status == "lost", "fuel exhaustion loses exercise")
	saved = sim.snapshot()
	check(sim.tick({}).is_empty() and sim.snapshot() == saved, "loss terminal and immutable")
	check(Sim.new().restore(saved), "losing snapshot restorable")

func _test_corrected_controls() -> void:
	var sim = Sim.new()
	sim.tick({"select_weapon": 1, "fire": true})
	var main_remaining: int = sim.ammo[1]
	var reload_before: int = sim.reload_ticks
	var mg_before: int = sim.ammo[3]
	var events: Array = sim.tick({"machinegun": true})
	check(_has_event(events, "fire") and sim.ammo[3] == mg_before - 1, "M fires MG directly")
	check(sim.weapon == 1 and sim.ammo[1] == main_remaining, "M preserves selected main gun and ammo")
	check(sim.reload_ticks == reload_before - 1, "M leaves main reload independent")
	check(not _has_event(sim.tick({"machinegun": true}), "fire"), "direct MG observes cooldown")
	for station in [1, 2, 3]:
		sim.reset()
		check(not _has_event(sim.tick({"station": station, "machinegun": true}), "fire"), "direct MG station gate %d" % station)
	sim.reset()
	for level in [1, 2, 0, 1]:
		sim.tick({"toggle_zoom": true})
		check(sim.zoom_level == level and sim.zoom == (level > 0), "gunner zoom cycles level %d" % level)
	sim.tick({"station": 1, "toggle_zoom": true})
	check(sim.zoom_level == 1, "commander map toggle cannot change gunner zoom")
	sim.reset()
	for i in 30:
		sim.tick({"throttle": 1})
	var before: Vector2 = sim.pos
	sim.tick({"stop": true, "throttle": 1, "steer": 1})
	check(sim.speed == 0 and sim.pos == before and sim.heading == 0, "stop overrides simultaneous hull movement")
	sim.reset()
	sim.tick({"sight_axis": 1})
	check(sim.elevation == 0, "sight elevation inactive in hull mode")
	sim.tick({"toggle_control": true, "sight_axis": 1})
	check(sim.elevation > 0, "positive sight axis raises elevation")
	for i in 300:
		sim.tick({"sight_axis": 1})
	check(sim.elevation == float(sim.rules.max_elevation), "elevation upper clamp")
	for i in 300:
		sim.tick({"sight_axis": -1})
	check(sim.elevation == float(sim.rules.min_elevation), "elevation lower clamp")
	sim.tick({"sight_axis": NAN})
	check(is_finite(sim.elevation), "invalid sight axis contained")
	for station in 4:
		sim.reset()
		sim.tick({"station": station, "toggle_control": true, "sight_axis": 1})
		check(sim.elevation > 0, "sight elevation available station %d" % station)
	for pitch in [-0.1, 0.1]:
		sim.reset()
		sim.elevation = pitch
		sim.turret = sim.bearing_to(sim.targets[0].pos)
		check(not _has_event(sim.tick({"fire": true}), "hit"), "vertical miss pitch %s" % pitch)
	sim.reset()
	sim.turret = sim.bearing_to(sim.targets[0].pos)
	sim.elevation = sim.elevation_to(sim.targets[0].pos)
	check(_has_event(sim.tick({"fire": true}), "hit"), "center-height aimed shot hits")
	sim.reset()
	sim.tick({"select_target": true, "lock_target": true})
	check(sim.locked and sim.elevation == sim.elevation_to(sim.targets[sim.selected_target].pos), "lock follows target elevation")
	sim.tick({"toggle_control": true, "sight_axis": 1})
	check(not sim.locked, "manual sight elevation releases lock")

func _test_contract_clauses() -> void:
	var sim = Sim.new()
	var fired: Array = []
	for event in sim.tick({"fire": true, "machinegun": true}):
		if event.type == "fire":
			fired.append(event.weapon)
	check(fired == [0, 3], "fire and machinegun both fire in one tick")
	var main_reload: int = int(sim.rules.reload_ticks[0])
	var reloads: int = 0
	var reload_tick: int = -1
	for tick in main_reload + 30:
		if _has_event(sim.tick({}), "reload"):
			reloads += 1
			reload_tick = tick
	check(reloads == 1 and reload_tick == main_reload - 1, "reload event once when main reload completes")
	sim.reset()
	sim.turret = 0.3
	for i in 30:
		sim.tick({"steer": 1.0})
	check(sim.heading > 0.0 and is_equal_approx(angle_difference(sim.heading, sim.turret), 0.3), "hull turning carries unlocked turret")
	sim.reset()
	sim.turret = sim.bearing_to(sim.targets[0].pos)
	sim.tick({"select_target": true, "lock_target": true})
	for i in 30:
		sim.tick({"steer": 1.0})
	check(sim.locked and sim.heading > 0.0 and is_equal_approx(sim.turret, sim.bearing_to(sim.targets[sim.selected_target].pos)), "lock holds target bearing while hull turns")
	sim.tick({"align_turret": true})
	check(not sim.locked and sim.turret == sim.heading, "align_turret releases lock")
	var plain = Sim.new()
	var scanned = Sim.new()
	var same: bool = true
	for i in 120:
		var commands: Dictionary = {"throttle": 1.0, "steer": 0.3, "fire": i == 0}
		var plain_events: Array = plain.tick(commands)
		commands.scan_bearing = [0.0, PI / 2, PI, -PI / 2][i % 4]
		same = same and plain_events == scanned.tick(commands)
	check(same and plain.snapshot() == scanned.snapshot(), "scan_bearing ignored by simulation")
	for station in 4:
		sim = Sim.new()
		var events: Array = sim.tick({"station": station, "radio": true, "toggle_thermal": true})
		check(_has_event(events, "voice") == (station <= 1) and sim.thermal == (station <= 1), "radio and thermal station %d" % station)
	# The cone is vertical too: at the upper elevation clamp every target's center pitch is outside it.
	sim.reset()
	var pitch: float = sim.elevation_to(sim.targets[0].pos)
	var half: float = float(sim.rules.selection_half_angle)
	for case in [[0.0, 0], [pitch + half * 0.9, 0], [float(sim.rules.max_elevation), -1]]:
		sim.reset()
		sim.turret = sim.bearing_to(sim.targets[0].pos)
		sim.elevation = case[0]
		sim.tick({"select_target": true})
		check(sim.selected_target == case[1], "vertical selection cone elevation %s" % case[0])

# Protect the observed separate-tube shoulder defect using real source topology.
# Working if each hip and both sleeve ends belong to one connected garment.
func _check_menu_shirt_connections(hero: Node3D) -> void:
	var matched := 0
	for child in hero.crew.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
		var colour = child.material_override.get_shader_parameter("base_color")
		if not colour is Color: continue
		var commander: bool = colour.is_equal_approx(Color("c9c9ba"))
		if not commander and not colour.is_equal_approx(Color("b09a76")): continue
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.size() < 3000: continue
		matched += 1
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var links: Dictionary = {}
		for i in range(0,indices.size(),3):
			for edge in range(3):
				var a := vertices[indices[i+edge]].snapped(Vector3.ONE*0.000001)
				var b := vertices[indices[i+(edge+1)%3]].snapped(Vector3.ONE*0.000001)
				if not links.has(a): links[a] = {}
				if not links.has(b): links[b] = {}
				links[a][b] = true
				links[b][a] = true
		var hip := Vector3(0.7,0.98,0.48) if commander else Vector3(-0.72,0.96,0.56)
		var seed: Vector3 = links.keys()[0]
		for point in links:
			if point.distance_squared_to(hip) < seed.distance_squared_to(hip): seed = point
		var seen := {seed:true}
		var pending: Array = [seed]
		while not pending.is_empty():
			var at: Vector3 = pending.pop_back()
			for point in links[at]:
				if not seen.has(point): seen[point] = true; pending.append(point)
		var contacts := [[Vector3(0.96,1.17,0.58),Vector3(0.98,1.34,0.3)],[Vector3(0.52,1.24,0.02),Vector3(0.74,1.36,0.02)]] if commander else [[Vector3(-0.36,1.04,0.15),Vector3(-0.58,0.858,-0.12)],[Vector3(-1.02,1.035,0.19),Vector3(-0.96,0.858,-0.13)]]
		for contact in contacts:
			var target: Vector3 = contact[1]-(contact[1]-contact[0]).normalized()*0.035
			var nearest: Vector3 = seed
			for point in links:
				if point.distance_squared_to(target) < nearest.distance_squared_to(target): nearest = point
			check(nearest.distance_to(target) < 0.003 and seen.has(nearest),"menu shirt joins hip to sleeve end, commander=%s" % commander)
	check(matched == 2,"both menu shirts have joined shoulder topology")

func _test_range_presentation() -> void:
	# Presentation helpers only: none of these feed the simulation.
	var cover = load("res://scripts/cover_scene.gd").new()
	root.add_child(cover)
	check(cover.has_method("advance"), "cover exposes a reduced-motion atmosphere clock")
	if not cover.has_method("advance"):
		cover.free()
		return
	cover.set_active(true)
	cover.advance(0.5, false)
	var still_time: float = cover.atmosphere_time
	cover.advance(1.0, false)
	check(cover.atmosphere_time == still_time, "reduced motion freezes cover atmosphere")
	var particle_budget := 0
	for particles in cover._particles:
		particle_budget += particles.amount
		check(particles.speed_scale == 0.0, "reduced motion freezes cover particles")
	check(particle_budget <= 10000, "cover particles stay within title-screen budget")
	var rising_smoke_count := 0
	for particles in cover._particles:
		if String(particles.name).begins_with("RisingSmoke"):
			rising_smoke_count += 1
			check(particles.direction.y > 0.8 and particles.direction.x > 0.2 and particles.initial_velocity_min >= 0.5,"smoke visibly rises and drifts")
	check(rising_smoke_count == 2,"both flanks carry rising smoke")
	cover.advance(0.5, true)
	check(cover.atmosphere_time > still_time, "cover atmosphere resumes motion")
	cover.set_active(false)
	var hidden_time: float = cover.atmosphere_time
	cover.advance(1.0, true)
	check(cover.atmosphere_time == hidden_time, "hidden cover does not advance")
	for particles in cover._particles:
		check(not particles.emitting and particles.speed_scale == 0.0, "hidden cover suspends particles")
	cover.free()
	# Authored-cover input is optional. Malformed or mismatched data preserves source meshes.
	var hero = load("res://scripts/vehicle.gd").new()
	hero.cover_detail = true
	if FileAccess.file_exists(hero.COVER_BLENDER_ASSET):
		check(not hero._cover_authored_batches().is_empty(),"Blender cover asset loads")
	else:
		check(hero._cover_authored_batches().is_empty(),"source-only kit retains optional cover fallback")
	var probe := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD])
	probe.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var selector: String = hero._cover_batch_selector(probe.surface_get_arrays(0))
	var valid := {"frame":"hull","count":3,"vertices":[0,0,0,1,0,0,0,1,0],"normals":[0,0,-1,0,0,-1,0,0,-1]}
	check(hero._authored_cover_mesh(probe,"hull",{selector:valid}) != probe,"valid authored batch replaces source")
	for malformed in [null,[],"invalid",3]:
		check(hero._authored_cover_mesh(probe,"hull",{selector:malformed}) == probe,"malformed authored batch falls back")
	for field in ["vertices","normals","count","frame"]:
		for bad in [null,"invalid",[],true]:
			var malformed: Dictionary = valid.duplicate(true)
			malformed[field] = bad
			check(hero._authored_cover_mesh(probe,"hull",{selector:malformed}) == probe,"malformed authored %s falls back" % field)
	for bad in [null,"invalid",true]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.vertices[0] = bad
		check(hero._authored_cover_mesh(probe,"hull",{selector:malformed}) == probe,"malformed authored component falls back")
	var malformed_path := OS.get_cache_dir().path_join("abrams-cover-malformed-%d.json" % OS.get_process_id())
	for malformed in ["{", "[]", '{"schema":1,"batches":[]}', '{"schema":[],"batches":{}}', '{"schema":true,"batches":{}}', '{"schema":"1","batches":{}}']:
		var file := FileAccess.open(malformed_path,FileAccess.WRITE)
		file.store_string(malformed)
		file.close()
		check(hero._cover_authored_batches(malformed_path).is_empty(),"malformed cover file falls back")
	DirAccess.remove_absolute(malformed_path)
	# The loader weapon must have a continuous axial silhouette and a mount
	# clear of the braced hand. Protect both joins and the nearby contact pose.
	var weapon_frame := Node3D.new()
	hero._loader_weapon(weapon_frame)
	check(hero._batches.size() == 1,"loader weapon is one material/frame assembly")
	var weapon_mesh: ArrayMesh = hero._batches.values()[0].st.commit()
	var weapon_faces: PackedVector3Array = weapon_mesh.get_faces()
	var gun_frame := Transform3D(Basis(Vector3.RIGHT,0.45),Vector3(-0.98,1.25,-0.40))
	var continuous := true
	for station in range(107):
		var point := gun_frame*Vector3(0,0.075,-0.97+station*0.01)
		var found := false
		for triangle in range(0,weapon_faces.size(),3):
			if Geometry3D.segment_intersects_triangle(point+Vector3.RIGHT*0.2,point-Vector3.RIGHT*0.2,weapon_faces[triangle],weapon_faces[triangle+1],weapon_faces[triangle+2]) != null:
				found = true
				break
		continuous = continuous and found
	check(continuous,"loader barrel and receiver have no axial gap")
	var hand_clear := true
	for point in weapon_faces:
		if point.y < 0.94:
			hand_clear = hand_clear and Vector2(point.x,point.z).distance_to(Vector2(-0.96,-0.13)) > 0.11
	check(hand_clear,"loader gun pedestal clears the braced hand")
	# Use centimetres for this tiny-lip predicate: Godot uses an absolute
	# determinant epsilon. Uniform scaling preserves every segment and hit.
	for bore_check in [[0.0,-0.985,-0.955,false],[0.024,-0.985,-0.955,true],[0.0,-0.94,-0.90,true]]:
		var from := gun_frame*Vector3(bore_check[0],0.075,bore_check[1])
		var to := gun_frame*Vector3(bore_check[0],0.075,bore_check[2])
		var hit := false
		for triangle in range(0,weapon_faces.size(),3):
			if Geometry3D.segment_intersects_triangle(from*100.0,to*100.0,weapon_faces[triangle]*100.0,weapon_faces[triangle+1]*100.0,weapon_faces[triangle+2]*100.0) != null:
				hit = true
				break
		check(hit == bore_check[3],"loader muzzle has an open centre, solid lip and recessed back: %s" % str(bore_check))
	weapon_frame.free()
	hero._batches.clear()
	hero.set_meta("cover_export_source",true)
	root.add_child(hero)
	_check_menu_shirt_connections(hero)
	hero.free()
	var main = load("res://scripts/main.gd").new()
	main.sim.turret = 0.4
	main.sim.heading = -0.3
	main.scan_angle = PI
	for station in 4:
		main.sim.station = station
		var expected: float = -0.3 if station == 3 else 0.4 + (PI if station == 1 else 0.0)
		check(is_equal_approx(main.view_bearing(), expected), "scan offset commander-only, station %d" % station)
	main.free()
	# Capture outputs anchor to the repo root and never land in res:// or the original sources.
	var main_script = load("res://scripts/main.gd")
	var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	check(main_script.capture_directory("artifacts/art-pass") == repo.path_join("artifacts/art-pass"), "relative capture anchored to repo root")
	check(main_script.capture_directory("/tmp/art review") == "/tmp/art review", "absolute capture kept")
	check(not main_script.capture_directory("user://captures").is_empty(), "user capture default allowed")
	for refused in ["godot/artifacts/x", "res://artifacts/x", "artifacts/../godot/x", "GAME/x", "game", "Genesis/art", repo.path_join("GAME"), "", "  ", ".", repo, "artifacts/.."]:
		check(main_script.capture_directory(refused).is_empty(), "capture refused inside project or sources: '%s'" % refused)
	# A symlink outside the repo that points into res:// is refused through its resolved target.
	var link_home := OS.get_cache_dir().path_join("abrams-capture-link-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(link_home)
	var link := link_home.path_join("into-project")
	var linked := DirAccess.open(link_home).create_link(ProjectSettings.globalize_path("res://").trim_suffix("/"), link) == OK
	var dangling := link_home.path_join("dangling")
	var dangled := DirAccess.open(link_home).create_link(repo.path_join("zz-missing-capture-target"), dangling) == OK
	if linked:
		check(main_script.capture_directory(link).is_empty(), "capture refused through a symlink into res://")
		check(main_script.capture_directory(link.path_join("new/out")).is_empty(), "capture refused below a symlink into res://")
	if dangled:
		check(main_script.capture_directory(dangling.path_join("out")).is_empty(), "capture refused through a dangling symlink")
	check(main_script.capture_directory(link_home.path_join("plain")) == link_home.path_join("plain"), "capture beside the links allowed")
	for name in ["into-project", "dangling"]:
		DirAccess.remove_absolute(link_home.path_join(name))
	DirAccess.remove_absolute(link_home)
	check(not DirAccess.dir_exists_absolute(link_home), "capture link probe cleaned up")
	var ui_script = load("res://scripts/interface.gd")
	var inner := Rect2(100, 200, 400, 300)
	var b: Array = Sim.new().range_data.bounds
	var overview := Rect2(b[0] - 100, b[2] - 100, b[1] - b[0] + 200, b[3] - b[2] + 200)
	for corner in [Vector2(b[0], b[2]), Vector2(b[1], b[3]), Vector2(b[0], b[3]), Vector2(b[1], b[2])]:
		var p: Vector2 = ui_script.map_point(corner, inner, overview)
		check(inner.has_point(p), "overview map shows range corner %s" % corner)
	var close := Rect2(-450, -1400, 900, 1750)
	check(ui_script.map_point(Vector2(500, 0), inner, close) == Vector2(500, 200 + 1400.0 / 1750.0 * 300), "close map clamps off-map tank to right edge")
	check(ui_script.map_point(Vector2(-450, -1400), inner, close) == inner.position, "close map origin")
	var ui = ui_script.new()
	var sim = Sim.new()
	for weapon in [2, 0, 1]:
		sim.tick({"select_weapon": weapon, "fire": true})
		ui.reload_fraction(sim.reload_ticks)
		sim.tick({})
		var span: float = float(sim.rules.reload_ticks[weapon])
		check(is_equal_approx(ui.reload_fraction(sim.reload_ticks), 1.0 / span), "reload bar uses weapon %d reload length" % weapon)
		sim.tick({"select_weapon": 3})
		while sim.reload_ticks > 1:
			ui.reload_fraction(sim.reload_ticks)
			sim.tick({})
	check(is_equal_approx(ui.reload_fraction(sim.reload_ticks), 1.0 - 1.0 / float(sim.rules.reload_ticks[1])), "reload bar span survives weapon switch")
	ui.free()
