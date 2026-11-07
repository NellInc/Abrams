extends "res://scripts/pc_bridge_viewer.gd"
## Replay real all-scenario packets through the production presentation path.
## Source execution/parity is proved separately by capture_pc_session.py.
var errors: Array[String] = []
var vehicle_art_frames := 0
var checks := 0
var fixture: Dictionary
var fixture_dir: String
# Original PC station order and plate sources, shared with production compositor.
# Working if a mislabeled/stale fixture fails separately from a renderer mismatch.
const STATION_PLATES := {"gunner":1,"commander":2,"cupola":3,"driver":4}

class ReplayBridge extends RefCounted:
	var pending := true
	var failure := ""
	func start(_python, _state, _saves, _log, _backend, _audit): return true
	func close(): pass
	func has_exited(): return true
	func exit_code(): return 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--fixture" not in args or "--no-audio" not in args or "--capture" not in args:
		printerr("Scenario replay requires --fixture REPORT --capture --no-audio --play")
		quit(2)
		return
	var path := args[args.find("--fixture")+1]
	fixture_dir=path.get_base_dir()
	fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	bridge=ReplayBridge.new()
	super._initialize()
	run.call_deferred()

func _process(_delta: float) -> bool: return false

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:errors.append(why)

func run() -> void:
	var cases: Array = []
	var coverage := {}
	for sample: Dictionary in fixture.samples:
		var label: String=sample.label
		if not ["gunner","commander","cupola","driver"].any(func(station):return label.ends_with("-"+station)): continue
		var station: String = str(sample.state.get("station",""))
		var scenario := int(sample.state.get("scenario_resource_index",-1))
		var expected_plate := int(STATION_PLATES.get(station,0))
		var identity := "%d/%s"%[scenario,station]
		check(scenario in range(8) and expected_plate>0,label+": fixture has a known original scenario/station")
		check(label.ends_with("-"+station),label+": fixture label matches VGA-paired state station")
		check(not coverage.has(identity),label+": unique scenario/station fixture")
		coverage[identity]=true
		# Read the VGA-paired plate attribution, not a station inferred from label.
		# Production subsequently validates the actual presented mask/source pixels.
		var plates: Dictionary = sample.presentation.get("plate_overlay",{}).get("plates",{})
		var plate: Dictionary = plates.get(str(expected_plate),{})
		var source: Array = TandemFrame.COCKPIT_SOURCES.get(expected_plate,[])
		var fixture_plate_ok: bool = source.size()==2 and plate.get("source")==source[0] and plate.get("source_sha256")==source[1] and int(plate.get("pixels",0))>0
		for id in range(1,5):
			if id!=expected_plate and int(plates.get(str(id),{}).get("pixels",0))>0:fixture_plate_ok=false
		check(fixture_plate_ok,label+": fixture paired station plate matches original source; stale/mixed fixture is not renderer proof")
		var png := FileAccess.get_file_as_bytes(fixture_dir.path_join(sample.image))
		var message := {"state":sample.state,"program":sample.program,"presentation":sample.presentation,
			"png":Marshalls.raw_to_base64(png),"sequence":sample.frame,"fps":59.9227256774902}
		_apply_sample(message)
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		check(bridge.failure.is_empty(),label+": production packet accepted")
		check(tandem_frame.world_enabled,label+": paired high-resolution world visible")
		check(expected_plate in tandem_frame.cockpit_art_ids,label+": production renderer activates the expected paired station cockpit")
		# One tripwire per run (below), not a constant per-frame check.
		if draw_view.vehicle_art!=null: vehicle_art_frames+=1
		check(draw_view.render_warnings.is_empty(),label+": no unsupported renderer commands")
		if tandem_frame.graphics_mode=="modern":
			check(draw_view.modern_assets.max_anchor_error<=0.25,label+": source anchor tolerance")
		root.get_texture().get_image().save_png(output.path_join(label+".png"))
		# Later packets clear these mutable arrays; retain this case's diagnostics.
		cases.append({"label":label,"scenario":sample.state.scenario_resource_index,
			"station":sample.state.station,"source_frame":sample.frame,
			"cockpits":tandem_frame.cockpit_art_ids.duplicate(),"world_enabled":tandem_frame.world_enabled,
			"graphics_mode":tandem_frame.graphics_mode,"refined_faces":draw_view.modern_polygon_count,"tree_planes":draw_view.modern_tree_count,"source_fallback_faces":draw_view.modern_fallback_polygon_count,"round_forms":draw_view.source_round_count,"anchor_error":draw_view.modern_assets.max_anchor_error,
			"warnings":draw_view.render_warnings.duplicate()})
	check(cases.size()==32,"32 station fixture rows processed")
	for scenario in range(8):
		for station in STATION_PLATES:
			check(coverage.has("%d/%s"%[scenario,station]),"complete Cartesian coverage: scenario %d station %s"%[scenario,station])
	if tandem_frame.graphics_mode=="modern":
		check(cases.any(func(row):return row.refined_faces>0),"Modern catalogue used by actual source frames")
		check(cases.any(func(row):return row.tree_planes>0),"illustrated source trees used by actual source frames")
	check(vehicle_art_frames==0,"rejected vehicle panels never attached (%d frames)"%vehicle_art_frames)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"errors":errors,"cases":cases,
		"scope":"Native production-viewer rendering of 32 source-frame cases. Does not rerun simulation; original all-frame parity is recorded in the input fixture."},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_SCENARIO_FRAMES: %d checks, %d cases, %d errors"%[checks,cases.size(),errors.size()])
	quit(0 if errors.is_empty() else 1)
