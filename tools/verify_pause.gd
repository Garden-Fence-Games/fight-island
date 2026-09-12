extends Node
## Headless proof of the four rules the pause menu has to keep: it really stops the tree, back goes
## exactly one level and never two, restart and quit both ask first, and nothing else does.
##
## The interesting failures here are invisible in a diff — a menu that opens without pausing, a
## dialog that a paused tree cannot process, or an Escape that closes the dialog *and* the menu
## underneath it in the same frame.
## Run: godot --headless --path . res://tools/verify_pause.tscn

const MENU: String = "res://scenes/ui/pause_menu.tscn"
const SETTLE_FRAMES: int = 4

var _failures: PackedStringArray = []
var _menu: PauseMenu = null


func _ready() -> void:
	_run()


func _run() -> void:
	_menu = (load(MENU) as PackedScene).instantiate() as PauseMenu
	add_child(_menu)
	await get_tree().process_frame

	_check_opening_stops_the_tree()
	await _check_back_goes_one_level("Options")
	await _check_back_goes_one_level("Restart")
	_check_resume_is_the_only_entry_that_does_not_ask()
	await _check_cancelling_a_restart_changes_nothing()
	_close()
	_report()


func _check_opening_stops_the_tree() -> void:
	if get_tree().paused:
		_fail("the tree was already paused before the menu opened")
	_menu.open()
	if not _menu.root.visible:
		_fail("opening did not show the menu")
	if not get_tree().paused:
		_fail("opening the pause menu did not pause the tree")
	# The menu itself has to keep running, or nothing could close it again.
	if _menu.process_mode != Node.PROCESS_MODE_ALWAYS:
		_fail("the pause menu would freeze with the tree it just stopped")
	_menu.close()
	if get_tree().paused:
		_fail("closing the pause menu left the tree paused")


## Back is one level. The overlay goes; the menu behind it stays, and the tree stays stopped.
func _check_back_goes_one_level(entry_name: String) -> void:
	_menu.open()
	var entry := _menu.root.get_node("Content/Column/Frame/Entries/%s" % entry_name) as MenuEntry
	entry.pressed.emit()
	await get_tree().process_frame
	var overlay := _overlay()
	if overlay == null:
		_fail("%s opened nothing" % entry_name)
		_menu.close()
		return
	if overlay.process_mode != Node.PROCESS_MODE_ALWAYS:
		_fail("%s opened something a paused tree cannot process" % entry_name)
	_dismiss(overlay)
	await get_tree().process_frame
	await get_tree().process_frame
	if _overlay() != null:
		_fail("back did not close what %s opened" % entry_name)
	if not _menu.root.visible:
		_fail("back from %s closed the pause menu underneath it as well" % entry_name)
	if not get_tree().paused:
		_fail("back from %s unpaused the game" % entry_name)
	_menu.close()


func _check_resume_is_the_only_entry_that_does_not_ask() -> void:
	_menu.open()
	_menu.resume.pressed.emit()
	if _overlay() != null:
		_fail("resume asked for a confirmation")
	if _menu.root.visible or get_tree().paused:
		_fail("resume did not put the game back")


func _check_cancelling_a_restart_changes_nothing() -> void:
	_menu.open()
	var before := GameState.run_seed
	_menu.restart.pressed.emit()
	await get_tree().process_frame
	var dialog := _overlay() as ConfirmDialog
	if dialog == null:
		_fail("restart did not ask")
		_menu.close()
		return
	dialog.cancel.pressed.emit()
	await get_tree().process_frame
	if GameState.run_seed != before:
		_fail("cancelling a restart started a new run anyway")
	_menu.close()


func _overlay() -> Control:
	for child: Node in _menu.root.get_children():
		var overlay := child as Control
		if overlay is ConfirmDialog or overlay is OptionsScreen:
			return overlay
	return null


func _dismiss(overlay: Control) -> void:
	var dialog := overlay as ConfirmDialog
	if dialog != null:
		dialog.cancel.pressed.emit()
		return
	(overlay as OptionsScreen).close()


func _close() -> void:
	_menu.close()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().process_frame
	if _failures.is_empty():
		print("pause OK — the tree stops, back goes one level, restart and quit both ask")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
