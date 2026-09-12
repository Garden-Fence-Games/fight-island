extends Node
## Headless proof of the one sentence this feature exists for: **a player on a pad never reads the
## word "mouse".**
##
## Two halves, and both are invisible in a diff. The glyph has to follow the **hand** — a controller
## picked up mid-menu changes every badge on screen — and it has to follow the **binding**, because
## a badge that still names the old key is a badge the player will trust and be wrong about.
##
## Whatever is bound on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_glyphs.tscn

const TITLE: String = "res://scenes/ui/title_screen.tscn"
const PAUSE: String = "res://scenes/ui/pause_menu.tscn"
const PROMPT: String = "res://scenes/ui/tutorial_prompt.tscn"
const TUTORIAL_STEPS: PackedStringArray = [
	"01_move", "02_attack", "03_chain", "04_perfect", "05_dodge", "06_parry", "07_sprint"
]
const SETTLE_FRAMES: int = 4
## Words that name hardware the other device does not have. A prompt containing one of these while
## the pad is in hand is the exact failure this issue was opened for.
const KEYBOARD_WORDS: PackedStringArray = ["MOUSE", "CLICK", "SPACE", "SHIFT", "WASD", "ENTER"]

var _failures: PackedStringArray = []
var _kept_bindings: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	_kept_bindings = SaveManager.read_json(InputBindings.PATH)
	InputBindings.apply()
	_check_the_hand_decides()
	_check_a_stick_at_rest_is_not_a_hand()
	_check_every_action_has_a_glyph_on_both_devices()
	await _check_a_menu_follows_the_hand()
	await _check_a_prompt_never_names_the_other_device()
	_check_a_rebind_changes_the_glyph()
	_put_the_bindings_back()
	_report()


func _check_the_hand_decides() -> void:
	# From the pad, because the keyboard is where a fresh launch already is.
	Devices.force(InputBindings.Device.GAMEPAD)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	if not Devices.notice(key):
		_fail("a key press did not put the hand on the keyboard")
	if Devices.last_used() != InputBindings.Device.KEYBOARD:
		_fail("a key press left the device on the pad")
	# Saying so twice is not a change, and everything on screen redraws on a change.
	if Devices.notice(key):
		_fail("a second key press reported a device change")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	if not Devices.notice(pad):
		_fail("a pad button did not move the hand to the pad")
	if Devices.last_used() != InputBindings.Device.GAMEPAD:
		_fail("a pad button left the device on the keyboard")
	# The mouse moving is the clearest statement there is that the hand left the pad.
	if not Devices.notice(InputEventMouseMotion.new()):
		_fail("moving the mouse did not move the hand back to the keyboard")


## A resting stick drifts. Without a threshold every glyph on screen would flicker for ever, which
## is worse than showing the wrong one.
func _check_a_stick_at_rest_is_not_a_hand() -> void:
	Devices.force(InputBindings.Device.KEYBOARD)
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = Devices.STICK_WAKE * 0.5
	if Devices.notice(drift):
		_fail("a stick at rest counted as the player picking up the pad")
	drift.axis_value = Devices.STICK_WAKE + 0.1
	if not Devices.notice(drift):
		_fail("a stick pushed properly did not count as the pad")


## Not every action: some are deliberately one-device — `weapon_prev` is pad-only and the three
## direct weapon keys are keyboard-only, both written into `docs/input-map.md`. What must hold is
## narrower and more useful: **every action something on screen actually names** has a glyph on
## both devices, or that screen prints a dash at the player.
##
## The list is gathered from the menus and the tutorial data rather than typed here, so a row added
## to a screen tomorrow is covered without anyone remembering this check exists.
func _check_every_action_has_a_glyph_on_both_devices() -> void:
	for action: String in _actions_shown_on_screen():
		for device: int in [InputBindings.Device.KEYBOARD, InputBindings.Device.GAMEPAD]:
			Devices.force(device as InputBindings.Device)
			var glyph := Devices.glyph(action)
			if glyph.is_empty() or glyph == InputBindings.UNBOUND:
				_fail("%s is named on screen but has no glyph on device %d" % [action, device])


func _actions_shown_on_screen() -> PackedStringArray:
	var out: PackedStringArray = []
	for scene: String in [TITLE, PAUSE]:
		var screen := (load(scene) as PackedScene).instantiate()
		for row: Node in _rows_of(screen):
			var entry := row as MenuEntry
			for named: String in [entry.action, entry.gamepad_action]:
				if not named.is_empty() and not out.has(named):
					out.append(named)
		screen.free()
	for name: String in TUTORIAL_STEPS:
		var step := load("res://data/tutorial/%s.tres" % name) as TutorialStep
		for named: String in step.prompt_actions:
			if not out.has(named):
				out.append(named)
	return out


func _rows_of(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	if node is MenuEntry:
		out.append(node)
	for child: Node in node.get_children():
		out.append_array(_rows_of(child))
	return out


func _check_a_menu_follows_the_hand() -> void:
	Devices.force(InputBindings.Device.KEYBOARD)
	var title := (load(TITLE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	var quit := title.get_node_or_null("Content/Column/Menu/Quit") as MenuEntry
	if quit == null:
		_fail("the title screen has no Quit row to read")
		title.queue_free()
		return
	var on_keys := quit.key.text
	if on_keys != "ESC":
		_fail("Quit reads %s on a keyboard, expected ESC" % on_keys)
	# The whole feature: a controller picked up changes the badge without anything being reopened.
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	EventBus._input(pad)
	await get_tree().process_frame
	if quit.key.text == on_keys:
		_fail("picking up a pad left Quit reading %s" % on_keys)
	if quit.key.text != "B":
		_fail("Quit reads %s on a pad, expected B" % quit.key.text)
	title.queue_free()
	await get_tree().process_frame


## The sentence the issue was opened for, checked literally.
func _check_a_prompt_never_names_the_other_device() -> void:
	var prompt := (load(PROMPT) as PackedScene).instantiate() as TutorialPrompt
	add_child(prompt)
	await get_tree().process_frame
	var dodge := load("res://data/tutorial/05_dodge.tres") as TutorialStep
	var move := load("res://data/tutorial/01_move.tres") as TutorialStep

	Devices.force(InputBindings.Device.GAMEPAD)
	prompt.show_line(dodge.prompt_key, dodge.prompt_actions)
	var on_pad := prompt.text().to_upper()
	for word: String in KEYBOARD_WORDS:
		if on_pad.contains(word):
			_fail('a pad player reads "%s" in: %s' % [word, prompt.text()])
	var pad_line := prompt.text()
	Devices.force(InputBindings.Device.KEYBOARD)
	prompt.hide_line()
	prompt.show_line(dodge.prompt_key, dodge.prompt_actions)
	if prompt.text() == pad_line:
		_fail("the dodge prompt reads the same on both devices: %s" % pad_line)
	Devices.force(InputBindings.Device.GAMEPAD)

	# Four actions, one stick: the player moves with a thumb, not with four axes.
	prompt.hide_line()
	prompt.show_line(move.prompt_key, move.prompt_actions)
	if prompt.text().to_upper().count("L-STICK") != 1:
		_fail("the movement prompt on a pad is not one stick: %s" % prompt.text())

	Devices.force(InputBindings.Device.KEYBOARD)
	prompt.hide_line()
	prompt.show_line(move.prompt_key, move.prompt_actions)
	var keys := prompt.text().to_upper()
	for letter: String in ["W", "A", "S", "D"]:
		if not keys.contains(letter):
			_fail("the movement prompt on a keyboard is missing %s: %s" % [letter, prompt.text()])

	# A lesson about timing names no button, and must not gain an empty glyph.
	var chain := load("res://data/tutorial/03_chain.tres") as TutorialStep
	prompt.hide_line()
	prompt.show_line(chain.prompt_key, chain.prompt_actions)
	if prompt.text() != tr(chain.prompt_key):
		_fail("a prompt with no button to name was rewritten: %s" % prompt.text())
	prompt.queue_free()
	await get_tree().process_frame


func _check_a_rebind_changes_the_glyph() -> void:
	Devices.force(InputBindings.Device.KEYBOARD)
	var before := Devices.glyph("dodge")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_F
	InputBindings.bind("dodge", rebound)
	var after := Devices.glyph("dodge")
	if after == before:
		_fail("rebinding dodge left its glyph reading %s" % before)
	if after != "F":
		_fail("dodge rebound to F reads %s" % after)
	InputBindings.reset_device(InputBindings.Device.KEYBOARD)
	if Devices.glyph("dodge") != before:
		_fail("resetting the keyboard did not put the dodge glyph back")


func _put_the_bindings_back() -> void:
	if _kept_bindings.is_empty():
		SaveManager.erase(InputBindings.PATH)
		return
	SaveManager.write_json(InputBindings.PATH, _kept_bindings)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print("glyphs OK — the badge follows the hand, and the hand follows the binding")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
