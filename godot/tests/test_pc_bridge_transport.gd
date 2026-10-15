extends SceneTree
## Reproduce the observed native 512-byte pipe fragmentation without a guest.
const Bridge=preload("res://scripts/pc_bridge.gd")
var errors: Array[String]=[]
var checks:=0
class Pipe extends RefCounted:
	var raw:=PackedByteArray()
	var read_count:=0
	var width:=512
	var replenish:=false
	var was_read:=false
	func get_buffer(_maximum: int) -> PackedByteArray:
		read_count+=1
		if replenish and was_read:
			was_read=false
			return PackedByteArray()
		var result:=raw.slice(0,width)
		raw=raw.slice(result.size())
		was_read=not result.is_empty()
		return result
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: errors.append(why)
func _initialize() -> void:
	var bridge:=Bridge.new()
	var pipe:=Pipe.new()
	bridge.process={"stdio":pipe,"stderr":Pipe.new(),"pid":OS.get_process_id()}
	bridge.expected_protocol=4
	# This fixture exercises parsing, not native child liveness or deadlines.
	bridge.closing=true
	bridge.request_started=Time.get_ticks_msec()
	var value: Dictionary={"type":"ready","id":-1,"protocol":4,"payload":"a".repeat(54000)}
	pipe.raw=(JSON.stringify(value)+"\n").to_utf8_buffer()
	var messages:=bridge.poll()
	var polls:=1
	while messages.is_empty() and polls<16:
		messages.append_array(bridge.poll())
		polls+=1
	check(messages.size()==1 and messages[0].payload==value.payload and messages[0].type=="ready" and int(messages[0].id)==-1,"54 KB reply drains within bounded polls despite 512-byte fragmentation")
	check(polls<16,"available fragments drain faster than one read per poll")
	check(pipe.read_count>100 and pipe.read_count<=polls*256,"drain uses bounded available fragments")
	check(not bridge.pending and bridge.failure.is_empty(),"ordinary pending/sequence contract preserved")
	check(bridge.poll().is_empty(),"consumed reply never delivered twice")
	# Match the observed empty-after-each-fragment writer backpressure.
	bridge.pending=true;pipe.replenish=true;pipe.was_read=false
	pipe.raw=(JSON.stringify(value)+"\n").to_utf8_buffer()
	messages.clear();polls=0
	while messages.is_empty() and polls<16:
		messages.append_array(bridge.poll());polls+=1
	check(messages.size()==1 and messages[0].payload==value.payload,"brief empty reads preserve and complete the exact reply")
	check(polls<16,"writer replenishment cannot force one frame per fragment")
	pipe.replenish=false
	bridge.pending=true
	bridge.waiting_id=1
	pipe.raw="{\"type\":\"sample\",\"id\":0}\n".to_utf8_buffer()
	check(bridge.poll().is_empty() and bridge.failure=="Unexpected PC bridge response sequence.","wrong sequence remains fatal")
	bridge.failure="";pipe.width=65536
	pipe.raw="a".repeat(2*1024*1024+1).to_utf8_buffer()
	for _poll in 64:
		bridge.poll()
		if not bridge.failure.is_empty(): break
	check(bridge.failure=="Oversized PC bridge response.","oversized fragmented reply remains rejected")
	for error in errors: printerr("FAIL: "+error)
	print("PC_BRIDGE_TRANSPORT: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
