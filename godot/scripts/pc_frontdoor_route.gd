extends RefCounted
## Bounded ordinary-key navigation. No guest memory, save or simulation writes.
const ROOT_LABELS := ["SCENARIO","CAMPAIGN","M1-INFO","EXIT"]
const ROOT_RECTS := [[20,12,64,8],[104,12,64,8],[188,12,56,8],[264,12,32,8]]
const BOOT_STEPS := [[3,["return"]],[600,[]],[120,[]],[3,["escape"]],[180,[]],[3,["space"]],[300,[]],[60,["return"]],[120,[]],[300,[]]]
const TextProof = preload("res://scripts/pc_frontend_music.gd")
var proof = TextProof.new()
var phase := "idle"
var destination := ""
var steps: Array = []
var booted := false
var selected := -1
var submenu := ""
var moves := 0
var failure := ""
var root_since := -1
var return_ready := false

func classify(source: Image, program: Dictionary, presentation: Dictionary) -> Dictionary:
	var result := {"selected":-1,"submenu":""}
	if source==null or source.get_size()!=Vector2i(320,200) or program.get("name")!="START" or presentation.get("frontend_program")!=program: return result
	var runs = presentation.get("text_runs")
	if not runs is Array or runs.is_empty(): return result
	var verified := proof.verified_text(source,presentation)
	# Invalid extra runs cannot prove that a modal is absent.
	if verified.size()!=runs.size(): return result
	if "MISSION:" in verified and "TIME:" in verified and "SKILL:" in verified and "BEGIN" in verified:
		result.submenu="scenario"
	elif "CAMPAIGN" in verified and runs.any(func(run):return run.text=="BEGIN" and run.rect.map(func(value):return int(value))==[116,24,40,8]):
		result.submenu="campaign"
	if runs.size()!=4: return result
	var seen: Array = []
	var active := -1
	for run in runs:
		var index := ROOT_LABELS.find(run.text)
		if index<0 or index in seen or run.rect.map(func(value):return int(value))!=ROOT_RECTS[index]: return result
		seen.append(index)
		if run.get("foreground")==4:
			if active!=-1:return result
			active=index
		elif run.get("foreground")!=1:return result
	result.selected=active
	return result

func observe(source: Image, program: Dictionary, presentation: Dictionary, sequence: int) -> void:
	var view := classify(source,program,presentation)
	if view.selected<0 or view.selected!=selected: root_since=-1
	selected=view.selected
	submenu=view.submenu
	if selected>=0 and root_since<0: root_since=sequence
	# Original dropdown painting is asynchronous. A root-like intermediate
	# frame must never replace Campaign/name entry with the cover.
	return_ready=phase=="playing" and selected>=0 and sequence-root_since>=90

func begin(choice: String) -> bool:
	if phase not in ["idle","playing"] or choice not in ["scenario","campaign"]: return false
	destination=choice;failure="";moves=0;return_ready=false
	if selected>=0:
		phase="select"
	elif not booted:
		booted=true;phase="boot"
		for step in BOOT_STEPS:
			var remaining := int(step[0])
			while remaining>0:
				var count:=mini(remaining,60)
				steps.append([count,step[1].duplicate()]);remaining-=count
	else:
		_fail()
	return true

func next_step() -> Array:
	if not steps.is_empty():return steps.pop_front()
	if phase=="boot":phase="select"
	if phase=="select":
		if selected<0:_fail();return []
		var target:=0 if destination=="scenario" else 1
		if selected==target:
			phase="open";steps=[[3,["return"]],[60,[]]]
		elif moves<3:
			moves+=1
			steps=[[3,["left" if selected>target else "right"]],[30,[]]]
		else:_fail();return []
		return steps.pop_front()
	if phase=="open":
		if submenu==destination:phase="playing"
		else:_fail()
	return []

func _fail() -> void:
	steps.clear();phase="fallback"
	failure="Could not open the selected menu. Continue in the original game."

func rest() -> void:
	phase="idle";return_ready=false
