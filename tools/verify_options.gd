extends Node
## Headless proof that the options screen is wired to the thing it claims to change: every setting
## in the table exists, a row writes through to `Settings` and survives a reload, the controls tab
## lists every rebindable action and no debug one, and a rebind really does move the InputMap and
## come back on a reset.
##
## Whatever is on this machine is put back at the end — a check that leaves the player's settings
## changed is worse than no check.
## Run: godot --headless --path . res://tools/verify_options.tscn

const SCREEN: String = "res://scenes/ui/options_screen.tscn"
const SETTLE_FRAMES: int = 4

var _failures: PackedStringArray = []
var _screen: OptionsScreen = null
var _restore: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	for key: StringName in Settings.DEFAULTS:
		_restore[key] = Settings.get_value(key)
	_screen = (load(SCREEN) as PackedScene).instantiate() as OptionsScreen
	add_child(_screen)
	await get_tree().process_frame

	_check_every_setting_has_a_row()
	_check_tabs_switch()
	_check_a_toggle_writes_through()
	_check_a_picker_keeps_its_type()
	_check_a_slider_clamps()
	_check_bindings_are_listed()
	_check_a_rebind_moves_the_map()
	_restore_settings()
	_report()


## The table in the screen and the table in Settings are two lists that have to agree, and nothing
## but this notices when they stop.
func _check_every_setting_has_a_row() -> void:
	var listed: Dictionary = {}
	for page: Dictionary in OptionsScreen.PAGES:
		for row: Dictionary in page["rows"]:
			listed[row["setting"]] = true
	for key: StringName in Settings.DEFAULTS:
		if not listed.has(key):
			_fail("%s has no row on the options screen" % key)
	for key: StringName in listed:
		if not Settings.DEFAULTS.has(key):
			_fail("%s has a row but is not a setting" % key)


func _check_tabs_switch() -> void:
	var pages: Array[Control] = []
	for child: Node in _screen.page_box.get_children():
		pages.append(child as Control)
	if pages.size() != OptionsScreen.PAGES.size():
		_fail("expected %d pages, built %d" % [OptionsScreen.PAGES.size(), pages.size()])
		return
	for index: int in pages.size():
		_screen.show_page(index)
		for other: int in pages.size():
			if pages[other].visible != (other == index):
				_fail("page %d should be the only one shown on tab %d" % [other, index])
				return


func _check_a_toggle_writes_through() -> void:
	var row := _find_row(&"gameplay_damage_numbers")
	if row == null:
		_fail("no row for the damage numbers toggle")
		return
	var before := bool(Settings.get_value(&"gameplay_damage_numbers"))
	row.pressed.emit()
	var after := bool(Settings.get_value(&"gameplay_damage_numbers"))
	if after == before:
		# The whole point of the screen: nothing here has an Apply button.
		_fail("pressing the toggle did not change the setting")
	var stored: Variant = SaveManager.read_settings().get("gameplay_damage_numbers")
	if bool(stored) != after:
		_fail("the toggle did not reach the file")


func _check_a_picker_keeps_its_type() -> void:
	var row := _find_row(&"video_frame_cap")
	if row == null:
		_fail("no row for the frame cap")
		return
	row.nudge(1)
	if typeof(Settings.get_value(&"video_frame_cap")) != TYPE_INT:
		_fail("the frame cap picker stored something other than an int")
	if Engine.max_fps != int(Settings.get_value(&"video_frame_cap")):
		_fail("the frame cap did not apply to the engine")


func _check_a_slider_clamps() -> void:
	var row := _find_row(&"audio_master")
	if row == null:
		_fail("no row for the master volume")
		return
	for _step: int in 20:
		row.nudge(-1)
	if int(Settings.get_value(&"audio_master")) != 0:
		_fail("the master volume did not clamp to its minimum")
	for _step: int in 20:
		row.nudge(1)
	if int(Settings.get_value(&"audio_master")) != 100:
		_fail("the master volume did not clamp to its maximum")


func _check_bindings_are_listed() -> void:
	var listed := InputBindings.rebindable()
	for action: StringName in InputMap.get_actions():
		var name := String(action)
		var hidden: bool = name.begins_with("ui_") or name.begins_with("debug_")
		if hidden and listed.has(name):
			_fail("%s is a debug or engine action and should not be rebindable" % name)
		if not hidden and not listed.has(name):
			_fail("%s is missing from the controls tab" % name)


func _check_a_rebind_moves_the_map() -> void:
	var action := "dodge"
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F9
	InputBindings.bind(action, event)
	if not InputMap.action_has_event(action, event):
		_fail("the rebind did not reach the InputMap")
	if InputBindings.describe(action, InputBindings.Device.KEYBOARD) != "F9":
		_fail("the row would not show the new binding")
	# The other device must not have been touched by a keyboard rebind.
	if InputBindings.describe(action, InputBindings.Device.GAMEPAD) == InputBindings.UNBOUND:
		_fail("rebinding the keyboard cleared the gamepad")
	InputBindings.reset_device(InputBindings.Device.KEYBOARD)
	if InputMap.action_has_event(action, event):
		_fail("the reset left the rebound key in the map")


func _find_row(setting: StringName) -> OptionRow:
	for page: Node in _screen.page_box.get_children():
		for child: Node in page.get_children():
			var row := child as OptionRow
			if row != null and row.setting == setting:
				return row
	return null


func _restore_settings() -> void:
	for key: StringName in _restore:
		Settings.set_value(key, _restore[key])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().process_frame
	if _failures.is_empty():
		print("options OK — every setting listed, rows write through, bindings move and reset")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
