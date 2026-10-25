extends SceneTree
## Regress synchronous production startup, before SceneTree nodes enter the tree.
const Draw = preload("res://scripts/pc_draw_pass.gd")
var started := Time.get_ticks_msec()
func _initialize() -> void:
	var directory:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var draw:=Draw.new()
	root.add_child(draw)
	var entered_before_load:=draw.is_inside_tree()
	var loaded: bool=draw.load_modern_assets(directory)
	var native:=DisplayServer.get_name()!="headless"
	# The regression only means something if the node has not yet entered the tree.
	if entered_before_load: printerr("FAIL: precondition: draw node already inside tree at _initialize; pre-tree startup path not exercised")
	var passed:=not entered_before_load and loaded and (not native or draw.modern_prewarmed)
	if native:
		var labels:Array=[]
		for row:Dictionary in draw.modern_prewarm_rows:
			labels.append(row.program)
			passed=passed and row.admitted
		passed=passed and ["tactical-smoke-surface","tactical-daylight","ownership","tactical-particles"].all(func(label):return label in labels)
		passed=passed and draw.tactical_effects.puffs.is_empty() and draw.tactical_effects._plume_phase==0.0 and draw.tactical_effects._dynamics_clock==0.0
		print("PC_MODERN_PREWARM: ",JSON.stringify(draw.modern_prewarm_rows))
	if not entered_before_load and not passed: printerr("FAIL: synchronous Modern startup: "+draw.modern_status)
	print("PC_MODERN_STARTUP: %s; entered_before_load=%s; native=%s; prewarmed=%s"%["PASS" if passed else "FAIL",entered_before_load,native,draw.modern_prewarmed])
	quit(0 if passed else (3 if entered_before_load else 1))
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>120000: quit(2)
	return false
