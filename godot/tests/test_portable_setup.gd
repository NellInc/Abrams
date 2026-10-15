extends "res://scripts/portable_setup.gd"
## Run after installing the candidate in a disposable project. No runtime executes.
var failures: Array[String] = []
var available := false
var starts := 0

func _runtime_available() -> bool:
    return available

func _start_worker(_work: Callable) -> Error:
    starts += 1
    return ERR_CANT_CREATE

func check(ok: bool, label: String) -> void:
    if not ok: failures.append(label)

func _initialize() -> void:
    super._initialize()
    run.call_deferred()

func run() -> void:
    check(not busy and starts == 0 and not recheck.disabled, "missing runtime returns immediately without worker and allows recheck")
    check(play.disabled and genesis.disabled and not pc.disabled, "missing runtime leaves safe import controls")
    check("Restore or reinstall" in message.text, "missing runtime names recovery")
    available = true
    _request(["--status"])
    check(starts == 1 and not busy and thread == null, "thread start failure clears thread and busy")
    check(not recheck.disabled and not pc.disabled and play.disabled, "thread start failure restores safe controls")
    check("Recheck installation" in message.text, "thread failure names recovery")
    busy = true
    _sync_controls()
    _request(["--status"])
    check(starts == 1 and recheck.disabled and play.disabled and pc.disabled and genesis.disabled, "busy state prevents all duplicate runtime actions")
    busy = false
    for invalid in ["null", "[]", "{}", '{"pc_installed":"true","genesis_enabled":false}', '{"pc_installed":1,"genesis_enabled":false}', '{"pc_installed":true,"genesis_enabled":1}', '{"pc_installed":true}', '{"pc_installed":null,"genesis_enabled":false}']:
        installed = true
        _completed(0, invalid, false)
        check(not installed and play.disabled and genesis.disabled, "malformed status cannot reuse prior installation proof: " + invalid)
        check("unexpected response" in message.text and "Verified" not in pc_state.text, "malformed success remains visibly unverified")
    _completed(0, '{"pc_installed":false,"genesis_enabled":false}', false)
    check(not installed and play.disabled and genesis.disabled and not recheck.disabled, "valid absent installation remains importable")
    _completed(0, '{"pc_installed":true,"genesis_enabled":true}', false)
    check(installed and not play.disabled and not genesis.disabled and "Enabled" in genesis_state.text, "boolean verified proof enables play and optional import")
    _completed(1, '{"error":"Synthetic verification failed"}', false)
    check(not installed and play.disabled and "Synthetic verification failed" == message.text, "failed recheck invalidates prior proof and preserves error")
    _pick("genesis")
    check(dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE and dialog.filters.size() == 1, "ROM picker supports raw file filters")
    check("*.md" in dialog.filters[0] and "*.bin" in dialog.filters[0] and "*.gen" in dialog.filters[0] and "*.smd" not in dialog.filters[0], "raw ROM guidance excludes interleaved SMD")
    dialog.hide()
    _pick("pc")
    check(dialog.file_mode == FileDialog.FILE_MODE_OPEN_DIR and dialog.filters.is_empty(), "PC picker clears ROM filters and selects folder")
    check("ABRAMS.COM" in dialog.title and "SIM.EXE" in dialog.title, "PC picker names required files")
    dialog.hide()
    for close_signal in ["confirmed", "close_requested", "canceled"]:
        _about()
        var about: AcceptDialog = null
        for child in root.get_children():
            if child is AcceptDialog and not child is FileDialog: about = child
        check(about != null, "About created")
        if about != null:
            about.emit_signal(close_signal)
            await process_frame
            check(not is_instance_valid(about), "About frees on " + close_signal)
    root.size = root.min_size
    await process_frame
    var scrolls := root.find_children("*", "ScrollContainer", true, false).filter(func(node): return node.is_visible_in_tree())
    check(scrolls.size() == 1, "one setup content scroller")
    if scrolls.size() == 1:
        var scroll: ScrollContainer = scrolls[0]
        check(scroll.follow_focus and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "keyboard follows content without horizontal overflow")
        check(scroll.size.y > 0 and not scroll.is_ancestor_of(play) and not scroll.is_ancestor_of(recheck), "action controls stay outside small-window scroll content")
    pc.grab_focus()
    check(pc.has_focus(), "PC import has reachable keyboard focus")
    # A chosen path reaches the runtime byte for byte: no shell expands $,
    # backticks or quotes. /bin/echo stands in for the bundled runtime.
    if FileAccess.file_exists("/bin/echo"):
        var saved_runtime := runtime
        runtime = "/bin/echo"
        var hostile := "/tmp/M1 Abrams ($5 bundle) `id` \"quoted\" 'single' \\back"
        var result := _run_runtime(PackedStringArray(["--launcher", "--invoke", "--game", hostile]))
        check(result[0] == 0, "argument echo runtime exits cleanly")
        check(result[1] == "--launcher --invoke --game " + hostile + "\n", "chosen path is passed without shell interpretation: " + str(result[1]))
        runtime = "/nonexistent/abrams-runtime"
        result = _run_runtime(PackedStringArray(["--status"]))
        check(result[0] != 0 and str(result[1]) != "", "missing runtime executable reports a failure instead of hanging")
        runtime = saved_runtime
    if failures.is_empty(): print("PORTABLE_SETUP_RECOVERY: PASS")
    else:
        for failure in failures: printerr("FAIL: " + failure)
    quit(0 if failures.is_empty() else 1)
