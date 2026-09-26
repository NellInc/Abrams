class_name AbramsSimulation
extends RefCounted
## Deterministic, fixed-step authored range model. No scene tree, input, or clock.
const DT: float = 1.0 / 60.0
const SNAPSHOT_VERSION: int = 2
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/provisional_rules.json"))["values"]
var range_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/range.json"))
var pos: Vector2
var heading: float
var turret: float
var elevation: float
var speed: float
var station: int
var control_hull: bool
var thermal: bool
var zoom_level: int
var zoom: bool:
	get:
		return zoom_level > 0
var weapon: int
var ammo: Array
var reload_ticks: int
var mg_cooldown_ticks: int
var fuel: float
var hull: float
var smoke_count: int
var elapsed_ticks: int
var status: String
var targets: Array[Dictionary] = []
var selected_target: int
var locked: bool
var seed_value: int

func _init() -> void:
	reset()

func reset(seed: int = 1988) -> void:
	seed_value = seed # Reserved for reproducible extensions; range has no randomness.
	pos = Vector2(range_data.spawn[0], range_data.spawn[1])
	heading = float(range_data.heading)
	turret = heading
	elevation = 0.0
	speed = 0.0
	station = 0
	control_hull = true
	thermal = false
	zoom_level = 0
	weapon = 0
	ammo = rules.initial_ammo.duplicate()
	for i in ammo.size():
		ammo[i] = int(ammo[i])
	reload_ticks = 0
	mg_cooldown_ticks = 0
	fuel = 100.0
	hull = 100.0
	smoke_count = int(rules.smoke_count)
	elapsed_ticks = 0
	status = "active"
	targets.clear()
	for source in range_data.targets:
		var target: Dictionary = source.duplicate(true)
		target.pos = Vector2(source.pos[0], source.pos[1])
		target.alive = true
		targets.append(target)
	selected_target = -1
	locked = false

func tick(commands: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if status != "active":
		return events
	elapsed_ticks += 1
	mg_cooldown_ticks = maxi(0, mg_cooldown_ticks - 1)
	if reload_ticks > 0:
		reload_ticks -= 1
		if reload_ticks == 0:
			events.append({"type": "reload", "text": "Weapon ready", "cue": "ready"})
	if commands.has("station") and _integer_between(commands.station, 0, 3):
		station = int(commands.station)
	if commands.get("toggle_control", false):
		control_hull = not control_hull
	if station <= 1:
		if commands.get("toggle_thermal", false):
			thermal = not thermal
	if station == 0 and commands.get("toggle_zoom", false):
		zoom_level = (zoom_level + 1) % 3
	if station == 0 and commands.has("select_weapon") and _integer_between(commands.select_weapon, 0, 3):
		weapon = int(commands.select_weapon)
	var previous_heading: float = heading
	var throttle: float = _axis(commands.get("throttle", 0.0)) if control_hull and station != 2 else 0.0
	var steer: float = _axis(commands.get("steer", 0.0)) if control_hull and station != 2 else 0.0
	if fuel <= 0.0:
		throttle = 0.0
		steer = 0.0
	var stopping: bool = commands.get("stop", false) and station != 2
	if stopping:
		throttle = 0.0
		steer = 0.0
	var desired_speed: float = throttle * (float(rules.max_forward_speed) if throttle >= 0 else float(rules.max_reverse_speed))
	var rate: float = float(rules.acceleration) if absf(desired_speed) > absf(speed) else float(rules.braking)
	speed = 0.0 if stopping else move_toward(speed, desired_speed, rate * DT)
	heading = wrapf(heading + steer * float(rules.hull_turn_rate) * DT, -PI, PI)
	# Unlocked turret moves with hull; a lock stabilises its world bearing.
	if not locked:
		turret = wrapf(turret + angle_difference(previous_heading, heading), -PI, PI)
	var proposed: Vector2 = pos + Vector2(-sin(heading), -cos(heading)) * speed * DT
	var bounds: Array = range_data.bounds
	var bounded: Vector2 = Vector2(clampf(proposed.x, bounds[0], bounds[1]), clampf(proposed.y, bounds[2], bounds[3]))
	var moved: float = pos.distance_to(bounded)
	if bounded != proposed:
		speed = 0.0
	pos = bounded
	fuel = maxf(0.0, fuel - float(rules.fuel_per_second) * DT - moved * float(rules.fuel_per_metre))
	_validate_selection()
	if not control_hull:
		var sight_axis: float = _axis(commands.get("sight_axis", 0.0))
		if sight_axis != 0.0:
			locked = false
			elevation = clampf(elevation + sight_axis * float(rules.sight_turn_rate) * DT, float(rules.min_elevation), float(rules.max_elevation))
		var axis: float = _axis(commands.get("turret_axis", 0.0))
		if axis != 0.0:
			locked = false
			turret = wrapf(turret + axis * float(rules.turret_turn_rate) * DT, -PI, PI)
	if commands.get("align_turret", false):
		turret = heading
		locked = false
	if station == 0:
		if commands.get("select_target", false):
			_select_target()
		if commands.get("lock_target", false):
			locked = not locked if selected_target >= 0 else false
	if locked and selected_target >= 0:
		turret = bearing_to(targets[selected_target].pos)
		elevation = elevation_to(targets[selected_target].pos)
	if station == 0 and commands.get("smoke", false) and smoke_count > 0:
		smoke_count -= 1
		events.append({"type": "smoke", "position": pos, "text": "Smoke deployed", "cue": "smoke"})
	if station <= 1 and commands.get("radio", false):
		events.append({"type": "voice", "text": "Range control. Clear to engage practice targets.", "cue": "radio"})
	# Scan bearings are viewing commands; scene/UI owns camera bearing, not ballistics.
	if station == 0 and commands.get("fire", false):
		_fire(events)
	if station == 0 and commands.get("machinegun", false):
		_fire(events, 3)
	_validate_selection()
	var remaining: int = 0
	for target in targets:
		if target.alive:
			remaining += 1
	if remaining == 0:
		status = "won"
		speed = 0.0
		events.append({"type": "won", "text": "Range complete. All practice targets neutralised.", "cue": "complete"})
	elif hull <= 0.0 or fuel <= 0.0:
		status = "lost"
		speed = 0.0
		events.append({"type": "lost", "text": "Exercise ended. Vehicle unavailable.", "cue": "lost"})
	return events

func bearing_to(point: Vector2) -> float:
	var delta: Vector2 = point - pos
	return atan2(-delta.x, -delta.y)

func elevation_to(point: Vector2) -> float:
	return clampf(atan2(float(rules.target_center_height) - float(rules.sight_height), pos.distance_to(point)), float(rules.min_elevation), float(rules.max_elevation))

func _select_target() -> void:
	var candidates: Array[int] = []
	for i in targets.size():
		if targets[i].alive and pos.distance_to(targets[i].pos) <= float(rules.lock_range) and absf(angle_difference(turret, bearing_to(targets[i].pos))) <= float(rules.selection_half_angle) and absf(elevation - elevation_to(targets[i].pos)) <= float(rules.selection_half_angle):
			candidates.append(i)
	if candidates.is_empty():
		selected_target = -1
	else:
		var next: int = candidates.find(selected_target) + 1
		selected_target = candidates[next] if next < candidates.size() else -1
	locked = false

func _validate_selection() -> void:
	if selected_target < 0 or selected_target >= targets.size() or not targets[selected_target].alive or pos.distance_to(targets[selected_target].pos) > float(rules.lock_range):
		selected_target = -1
		locked = false

func _fire(events: Array[Dictionary], weapon_override: int = -1) -> void:
	var firing_weapon: int = weapon if weapon_override < 0 else weapon_override
	if firing_weapon < 0 or firing_weapon > 3:
		return
	if (mg_cooldown_ticks > 0 if firing_weapon == 3 else reload_ticks > 0) or ammo[firing_weapon] <= 0:
		return
	ammo[firing_weapon] -= 1
	if firing_weapon == 3:
		mg_cooldown_ticks = int(rules.reload_ticks[firing_weapon])
	else:
		reload_ticks = int(rules.reload_ticks[firing_weapon])
	events.append({"type": "fire", "position": pos, "weapon": firing_weapon, "cue": "machine_gun" if firing_weapon == 3 else "cannon"})
	var forward: Vector2 = Vector2(-sin(turret), -cos(turret))
	var distance: float = float(rules.weapon_ranges[firing_weapon])
	var hit: int = -1
	for i in targets.size():
		if not targets[i].alive:
			continue
		var delta: Vector2 = targets[i].pos - pos
		var along: float = delta.dot(forward)
		var across: float = absf(delta.cross(forward))
		var vertical_error: float = absf(float(rules.sight_height) + tan(elevation) * along - float(rules.target_center_height))
		if along > float(rules.weapon_min_ranges[firing_weapon]) and along <= distance and across <= float(rules.target_radius) and vertical_error <= float(rules.target_vertical_radius):
			distance = along
			hit = i
	var impact: Vector2 = pos + forward * distance
	events.append({"type": "impact", "position": impact, "target": hit, "weapon": firing_weapon, "height": float(rules.sight_height) + tan(elevation) * distance})
	if hit >= 0:
		var target: Dictionary = targets[hit]
		target.hp = maxf(0.0, float(target.hp) - float(rules.weapon_damage[firing_weapon]))
		target.alive = target.hp > 0.0
		events.append({"type": "hit", "position": target.pos, "target": hit, "destroyed": not target.alive, "text": "%s: %s" % [target.name, "neutralised" if not target.alive else "hit"], "cue": "target_hit"})

func _axis(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), -1.0, 1.0)
	return 0.0

func snapshot() -> Dictionary:
	var saved_targets: Array = []
	for target in targets:
		var saved: Dictionary = target.duplicate(true)
		saved.pos = [target.pos.x, target.pos.y]
		saved_targets.append(saved)
	return {"version": SNAPSHOT_VERSION, "range_id": range_data.id, "seed": seed_value,
		"pos": [pos.x, pos.y], "heading": heading, "turret": turret, "elevation": elevation, "speed": speed,
		"station": station, "control_hull": control_hull, "thermal": thermal, "zoom": zoom, "zoom_level": zoom_level,
		"weapon": weapon, "ammo": ammo.duplicate(), "reload_ticks": reload_ticks, "mg_cooldown_ticks": mg_cooldown_ticks,
		"fuel": fuel, "hull": hull, "smoke_count": smoke_count, "elapsed_ticks": elapsed_ticks,
		"status": status, "targets": saved_targets, "selected_target": selected_target, "locked": locked}

func restore(saved: Dictionary) -> bool:
	if not _valid_snapshot(saved):
		return false
	# All validation precedes mutation, and nested structures are copied.
	seed_value = int(saved.seed)
	pos = Vector2(saved.pos[0], saved.pos[1])
	heading = float(saved.heading)
	turret = float(saved.turret)
	elevation = float(saved.elevation)
	speed = float(saved.speed)
	station = int(saved.station)
	control_hull = saved.control_hull
	thermal = saved.thermal
	zoom_level = int(saved.zoom_level)
	weapon = int(saved.weapon)
	ammo = saved.ammo.duplicate()
	for i in ammo.size():
		ammo[i] = int(ammo[i])
	reload_ticks = int(saved.reload_ticks)
	mg_cooldown_ticks = int(saved.mg_cooldown_ticks)
	fuel = float(saved.fuel)
	hull = float(saved.hull)
	smoke_count = int(saved.smoke_count)
	elapsed_ticks = int(saved.elapsed_ticks)
	status = saved.status
	selected_target = int(saved.selected_target)
	locked = saved.locked
	targets.clear()
	for source in saved.targets:
		var target: Dictionary = source.duplicate(true)
		target.pos = Vector2(source.pos[0], source.pos[1])
		targets.append(target)
	return true

func _valid_snapshot(saved: Dictionary) -> bool:
	var required: Array = snapshot().keys()
	if saved.size() != required.size():
		return false
	for key in required:
		if not saved.has(key):
			return false
	if saved.version != SNAPSHOT_VERSION or saved.range_id != range_data.id or not (saved.seed is int or _integer_between(saved.seed, -9007199254740991, 9007199254740991)):
		return false
	if not _valid_position(saved.pos) or not _number_between(saved.heading, -PI, PI) or not _number_between(saved.turret, -PI, PI) or not _number_between(saved.speed, -float(rules.max_reverse_speed), float(rules.max_forward_speed)):
		return false
	if not _integer_between(saved.station, 0, 3) or not _integer_between(saved.weapon, 0, 3) or not _integer_between(saved.reload_ticks, 0, int(rules.reload_ticks.max())) or not _integer_between(saved.mg_cooldown_ticks, 0, int(rules.reload_ticks[3])) or not _integer_between(saved.elapsed_ticks, 0, 2147483647):
		return false
	if not _number_between(saved.elevation, float(rules.min_elevation), float(rules.max_elevation)) or not _integer_between(saved.zoom_level, 0, 2):
		return false
	if saved.zoom != (saved.zoom_level > 0):
		return false
	for key in ["control_hull", "thermal", "zoom", "locked"]:
		if not saved[key] is bool:
			return false
	if not _number_between(saved.fuel, 0, 100) or not _number_between(saved.hull, 0, 100) or not _integer_between(saved.smoke_count, 0, int(rules.smoke_count)):
		return false
	if not saved.ammo is Array or saved.ammo.size() != 4:
		return false
	for i in 4:
		if not _integer_between(saved.ammo[i], 0, int(rules.initial_ammo[i])):
			return false
	if not saved.status is String or not saved.status in ["active", "won", "lost"] or not saved.targets is Array or saved.targets.size() != range_data.targets.size():
		return false
	var remaining: int = 0
	for i in saved.targets.size():
		var target: Variant = saved.targets[i]
		var source: Dictionary = range_data.targets[i]
		if not target is Dictionary or target.size() != 7:
			return false
		for key in ["id", "name", "pos", "hp", "kind", "team", "alive"]:
			if not target.has(key):
				return false
		for key in ["id", "name", "kind", "team"]:
			if target[key] != source[key]:
				return false
		if not _valid_position(target.pos) or target.pos != source.pos or not _number_between(target.hp, 0, float(source.hp)) or not target.alive is bool or target.alive != (target.hp > 0):
			return false
		if target.alive:
			remaining += 1
	if not _integer_between(saved.selected_target, -1, saved.targets.size() - 1):
		return false
	if saved.selected_target >= 0:
		var selected: Dictionary = saved.targets[int(saved.selected_target)]
		if not selected.alive or Vector2(saved.pos[0], saved.pos[1]).distance_to(Vector2(selected.pos[0], selected.pos[1])) > float(rules.lock_range):
			return false
	elif saved.locked:
		return false
	if saved.status == "won" and remaining != 0:
		return false
	if saved.status == "active" and (remaining == 0 or saved.fuel <= 0 or saved.hull <= 0):
		return false
	if saved.status == "lost" and (remaining == 0 or (saved.fuel > 0 and saved.hull > 0)):
		return false
	if saved.status != "active" and saved.speed != 0:
		return false
	return true

func _valid_position(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	var bounds: Array = range_data.bounds
	return _number_between(value[0], bounds[0], bounds[1]) and _number_between(value[1], bounds[2], bounds[3])

func _number_between(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

func _integer_between(value: Variant, low: int, high: int) -> bool:
	return _number_between(value, low, high) and float(value) == floorf(float(value))
