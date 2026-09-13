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
## Fewer hints than this means the search stopped finding scenes rather than that the game stopped
## having hints.
const HINTS_AT_LEAST: int = 6
const TUTORIAL_STEPS: PackedStringArray = ["01_angry", "02_fight", "03_sprint", "04_survive"]
const SETTLE_FRAMES: int = 4
## Words that name hardware the other device does not have. A prompt containing one of these while
## the pad is in hand is the exact failure this issue was opened for.
const KEYBOARD_WORDS: PackedStringArray = ["MOUSE", "CLICK", "SPACE", "SHIFT", "WASD", "ENTER"]

## How far a stick that nobody is touching wanders, and how far one somebody is. Absolute rather
## than scaled off `Devices.STICK_WAKE` — see `_check_a_stick_at_rest_is_not_a_hand`.
const A_RESTING_STICK: float = 0.25
const A_PUSHED_STICK: float = 0.6

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
	_check_no_scene_writes_a_glyph_out_by_hand()
	await _check_a_hint_says_a_key_and_a_word()
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
##
## The two pushes are **absolute, not multiples of `STICK_WAKE`**. Scaled off the threshold, this
## passed with the threshold at a thousandth: a drift of half of nothing is still nothing, and a
## push of a thousandth plus a tenth is still a push. Both figures move only when somebody moves
## them on purpose.
func _check_a_stick_at_rest_is_not_a_hand() -> void:
	Devices.force(InputBindings.Device.KEYBOARD)
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = A_RESTING_STICK
	if Devices.notice(drift):
		_fail("a stick sitting at %.2f counted as the player picking up the pad" % A_RESTING_STICK)
	drift.axis_value = A_PUSHED_STICK
	if not Devices.notice(drift):
		_fail("a stick pushed to %.2f did not count as the pad" % A_PUSHED_STICK)


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
	var fight := load("res://data/tutorial/02_fight.tres") as TutorialStep

	Devices.force(InputBindings.Device.GAMEPAD)
	prompt.show_line(fight.prompt_key, fight.prompt_actions)
	var on_pad := prompt.text().to_upper()
	for word: String in KEYBOARD_WORDS:
		if on_pad.contains(word):
			_fail('a pad player reads "%s" in: %s' % [word, prompt.text()])
	var pad_line := prompt.text()
	Devices.force(InputBindings.Device.KEYBOARD)
	prompt.hide_line()
	prompt.show_line(fight.prompt_key, fight.prompt_actions)
	if prompt.text() == pad_line:
		_fail("the fight prompt reads the same on both devices: %s" % pad_line)

	# Two actions, two placeholders: each button lands in its own place in the sentence.
	for action: String in fight.prompt_actions:
		if not prompt.text().contains(Devices.glyph(action)):
			_fail("the fight prompt does not name %s: %s" % [action, prompt.text()])
	if prompt.text().contains("{"):
		_fail("the fight prompt kept a placeholder: %s" % prompt.text())

	# A line that names no button must not gain an empty glyph.
	var angry := load("res://data/tutorial/01_angry.tres") as TutorialStep
	prompt.hide_line()
	prompt.show_line(angry.prompt_key, angry.prompt_actions)
	if prompt.text() != tr(angry.prompt_key):
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


## A glyph typed into a scene is a glyph that stops being true the moment a player rebinds or picks
## up a controller — and nine of them were, across seven screens: `[B / ESC] BACK`, and the same
## again. Read off the scenes rather than from a running one, because what is being held is that
## nobody wrote it, and a screen that is never opened would never be asked.
func _check_no_scene_writes_a_glyph_out_by_hand() -> void:
	var bracket := RegEx.new()
	bracket.compile('text = "\\[[^"]*"')
	_walk_scenes("res://scenes", bracket)


func _walk_scenes(directory: String, bracket: RegEx) -> void:
	for name: String in DirAccess.get_directories_at(directory):
		_walk_scenes("%s/%s" % [directory, name], bracket)
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".tscn"):
			continue
		var path := "%s/%s" % [directory, name.trim_suffix(".remap")]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		for found: RegExMatch in bracket.search_all(file.get_as_text()):
			_fail(
				(
					(
						"%s writes a glyph out by hand: %s — name the action instead, the way "
						+ "HintLabel and MenuEntry do"
					)
					% [path.get_file(), found.get_string(0)]
				)
			)


## And the other half: a hint that names an action has to end up saying something. A label that
## found neither a glyph nor a translation prints an empty string, and an empty hint bar looks
## exactly like a hint bar nobody wrote.
func _check_a_hint_says_a_key_and_a_word() -> void:
	var hints := 0
	for path: String in _scenes_with_hints():
		hints += await _check_the_hints_of(path)
	if hints < HINTS_AT_LEAST:
		_fail("only %d hint labels were found, which is fewer than there are" % hints)


## Every scene that carries one, found rather than listed. The first version asked the options
## screen alone and passed while the credits screen shipped a hint reading "SCROLL" with no key in
## front of it — the arrow keys described to an empty string, which is not `UNBOUND`, so nothing
## anywhere noticed.
func _scenes_with_hints() -> PackedStringArray:
	var found := PackedStringArray()
	_look_for_hints("res://scenes", found)
	return found


func _look_for_hints(directory: String, found: PackedStringArray) -> void:
	for name: String in DirAccess.get_directories_at(directory):
		_look_for_hints("%s/%s" % [directory, name], found)
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".tscn"):
			continue
		var path := "%s/%s" % [directory, name.trim_suffix(".remap")]
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_as_text().contains("hint_label.gd"):
			found.append(path)


func _check_the_hints_of(path: String) -> int:
	var screen := (load(path) as PackedScene).instantiate() as Control
	if screen == null:
		return 0
	add_child(screen)
	await get_tree().process_frame
	var hints := 0
	for node: Node in _every_child(screen):
		var hint := node as HintLabel
		if hint == null:
			continue
		hints += 1
		var names := hint.action if not hint.action.is_empty() else ", ".join(hint.actions)
		if hint.text.strip_edges().is_empty():
			_fail("a hint for %s in %s came out empty" % [names, path.get_file()])
		elif not hint.text.contains("["):
			_fail('%s reads "%s" with no key in front of it' % [path.get_file(), hint.text])
		elif hint.text.contains(hint.label_key):
			_fail('%s prints its own key: "%s"' % [path.get_file(), hint.text])
	screen.queue_free()
	await get_tree().process_frame
	return hints


func _every_child(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found.append_array(_every_child(child))
	return found


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"glyphs OK — the badge follows the hand, the hand follows the binding, and no "
				+ "scene writes a glyph out by hand"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
