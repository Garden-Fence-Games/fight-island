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
## Where the volumes live. Written out rather than searched for, so a page that is reordered fails
## here rather than quietly measuring whatever ended up fourth.
const AUDIO_PAGE: int = 3
const CONTROLS_PAGE: int = 1

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
	await _check_a_slider_answers_the_mouse()
	_check_bindings_are_listed()
	_check_a_rebind_moves_the_map()
	await _check_a_capture_does_not_outlive_its_row()
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


## **A volume has to be settable with the mouse.** Every other row takes a click because it has one
## next value; a slider has ten, so it took none at all — `_on_pressed` covered toggles and pickers
## and silently did nothing for a slider. The meter looked like a control and was not one, and the
## four rows it affects are the volumes, which is the first thing anybody touches.
##
## Driven through `_gui_input` rather than the viewport: a headless run does not route synthetic
## clicks to a `Button` at all, so going through the window would prove nothing either way.
func _check_a_slider_answers_the_mouse() -> void:
	var row := _find_row(&"audio_sfx")
	if row == null:
		_fail("there is no master SFX row to click on")
		return
	if row.kind != OptionRow.Kind.SLIDER:
		_fail("audio_sfx stopped being a slider, so this is measuring the wrong thing")
		return
	# The audio page, so the meter has a real width to divide up.
	_screen.show_page(AUDIO_PAGE)
	for _index: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var meter: Control = row.segment_box
	var origin := meter.global_position - row.global_position
	for wanted: Array in [[0.0, row.minimum], [1.0, row.maximum]]:
		row._gui_input(_click_at(origin + Vector2(meter.size.x * float(wanted[0]), 1.0)))
		var got := float(Settings.get_value(&"audio_sfx"))
		if not is_equal_approx(got, float(wanted[1])):
			_fail(
				(
					(
						"clicking the meter at %.0f%% left audio_sfx at %.0f, and %.0f is what that end "
						+ "of it means"
					)
					% [float(wanted[0]) * 100.0, got, float(wanted[1])]
				)
			)
	# And the name of the setting is not part of the control. Clicking it used to run the volume to
	# zero, because the meter was being compared in its parent's coordinates rather than the row's.
	var held := float(Settings.get_value(&"audio_sfx"))
	row._gui_input(_click_at(Vector2(2.0, 2.0)))
	if not is_equal_approx(float(Settings.get_value(&"audio_sfx")), held):
		_fail("clicking the row's label moved the volume, and the label is not the meter")


func _click_at(spot: Vector2) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = spot
	return click


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


## A row that is listening for a key and then stops being on screen, or stops being the row the
## player is on, has to stop listening. Nothing else can: the capture is invisible once the row is,
## and the only symptom a player gets is an Escape that does nothing — followed by a control they
## never meant to touch being rewritten by the next key they press.
##
## Asked through `is_processing_unhandled_input`, which is the capture's whole footprint on the
## world: a row that is not processing cannot bind anything.
func _check_a_capture_does_not_outlive_its_row() -> void:
	var rows := _keybind_rows()
	if rows.size() < 2:
		_fail("the controls page has fewer than two rebindable rows, so this check proves nothing")
		return

	# Hidden with a capture open: the tab strip is clickable without taking focus, so this is one
	# mouse click away at any moment.
	if not await _listening(rows[0]):
		return
	_screen.show_page(AUDIO_PAGE)
	await get_tree().process_frame
	if rows[0].is_processing_unhandled_input():
		_fail("a row left listening on a page nobody is looking at would bind the next key pressed")
	_screen.show_page(CONTROLS_PAGE)
	await get_tree().process_frame

	# Two rows at once: click one, click the next. Which one gets the key is a coin toss.
	if not await _listening(rows[0]):
		return
	rows[1].grab_focus()
	await get_tree().process_frame
	if rows[0].is_processing_unhandled_input():
		_fail("two rows were listening at once, so the next key would land on whichever won")
	# And the row that took over has to let go too, when the screen moves on from it.
	if not await _listening(rows[1]):
		return
	rows[1].release_focus()
	await get_tree().process_frame
	if rows[1].is_processing_unhandled_input():
		_fail("a row kept listening after the screen moved on from it")


## Puts a row into the listening state and says whether it got there, because every assertion above
## is worthless if it never started.
func _listening(row: KeybindRow) -> bool:
	row.grab_focus()
	row.pressed.emit()
	# `_start_capture` arms the listening a frame late on purpose, so the press that opened it is
	# not the press that closes it.
	await get_tree().process_frame
	await get_tree().process_frame
	if not row.is_processing_unhandled_input():
		_fail("a row would not start listening at all, so the capture cannot be tested")
		return false
	return true


func _keybind_rows() -> Array[KeybindRow]:
	var found: Array[KeybindRow] = []
	for page: Node in _screen.page_box.get_children():
		for child: Node in page.get_children():
			var row := child as KeybindRow
			if row != null:
				found.append(row)
	return found


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
		print(
			(
				"options OK — every setting listed, rows write through, a volume answers the "
				+ "mouse, bindings move and reset"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
