class_name InputBindings
extends RefCounted
## Rebinding, and the only thing that writes to the `InputMap` at runtime. Static for the same
## reason `Settings` is — ADR 0004 allows three autoloads and this is not one of them.
##
## **Only what the player changed is stored.** The file holds overrides, not a copy of the map, so
## an action that gains a better default in a later build reaches a player who already has a saved
## file. It also means a corrupt entry costs one binding rather than the whole scheme.
##
## Debug actions and Godot's own `ui_*` are neither listed nor rebindable: one is not the player's
## business, and the other is what makes the menus work at all.

enum Device { KEYBOARD, GAMEPAD }

const PATH: String = "user://bindings.json"
const HIDDEN_PREFIXES: PackedStringArray = ["ui_", "debug_"]

## Xbox names, because that is what the on-screen glyphs use. A pad that calls them something else
## still reports the same indices.
const PAD_BUTTONS: Dictionary = {
	0: "A",
	1: "B",
	2: "X",
	3: "Y",
	4: "BACK",
	5: "GUIDE",
	6: "START",
	7: "L-STICK",
	8: "R-STICK",
	9: "LB",
	10: "RB",
	11: "D-UP",
	12: "D-DOWN",
	13: "D-LEFT",
	14: "D-RIGHT",
}

const PAD_AXES: Dictionary = {
	0: "L-STICK X",
	1: "L-STICK Y",
	2: "R-STICK X",
	3: "R-STICK Y",
	4: "LT",
	5: "RT",
}

const MOUSE_BUTTONS: Dictionary = {
	MOUSE_BUTTON_LEFT: "L-CLICK",
	MOUSE_BUTTON_RIGHT: "R-CLICK",
	MOUSE_BUTTON_MIDDLE: "M-CLICK",
	MOUSE_BUTTON_WHEEL_UP: "WHEEL UP",
	MOUSE_BUTTON_WHEEL_DOWN: "WHEEL DOWN",
}

const UNBOUND: String = "—"
## The one display server with no keyboard layout to ask, and the one the checks run on.
const HEADLESS: String = "headless"

static var _defaults: Dictionary = {}
static var _loaded: bool = false


## Every action the player may see and change, in the order `project.godot` declares them.
static func rebindable() -> PackedStringArray:
	var out: PackedStringArray = []
	for action: StringName in InputMap.get_actions():
		if not _is_hidden(action):
			out.append(String(action))
	return out


## Reads the saved overrides and puts them into the InputMap. Call it once, at boot, before
## anything can read a binding.
static func apply() -> void:
	_remember_defaults()
	var stored := SaveManager.read_json(PATH)
	for action: String in stored:
		if not InputMap.has_action(action) or _is_hidden(StringName(action)):
			continue
		var entry: Variant = stored[action]
		if not entry is Dictionary:
			continue
		for device: int in [Device.KEYBOARD, Device.GAMEPAD]:
			var event := _from_json((entry as Dictionary).get(_device_key(device)))
			if event != null:
				_replace(action, device, event)


static func bind(action: String, event: InputEvent) -> void:
	var device := device_of(event)
	if device < 0 or not InputMap.has_action(action):
		return
	_remember_defaults()
	_replace(action, device, event)
	_store(action, device, event)


## Puts one device back to what `project.godot` says, for every action at once. A player who has
## bound two things to the same key needs a way out that is not deleting a file.
static func reset_device(device: Device) -> void:
	_remember_defaults()
	var stored := SaveManager.read_json(PATH)
	for action: String in rebindable():
		_restore_default(action, device)
		if stored.has(action) and stored[action] is Dictionary:
			(stored[action] as Dictionary).erase(_device_key(device))
			if (stored[action] as Dictionary).is_empty():
				stored.erase(action)
	SaveManager.write_json(PATH, stored)


## What the chip on the row says. Empty actions read as a dash rather than as nothing, because a
## blank cell looks like a layout bug.
static func describe(action: String, device: Device) -> String:
	if not InputMap.has_action(action):
		return UNBOUND
	for event: InputEvent in InputMap.action_get_events(action):
		if device_of(event) == device:
			return _describe_event(event)
	return UNBOUND


static func device_of(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return Device.KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Device.GAMEPAD
	return -1


static func _is_hidden(action: StringName) -> bool:
	for prefix: String in HIDDEN_PREFIXES:
		if String(action).begins_with(prefix):
			return true
	return false


static func _device_key(device: Device) -> String:
	return "keyboard" if device == Device.KEYBOARD else "gamepad"


## The map as the project ships it, captured before anything overwrites it — which is the only copy
## a reset can be restored from once the InputMap itself has been changed.
static func _remember_defaults() -> void:
	if _loaded:
		return
	_loaded = true
	for action: String in rebindable():
		_defaults[action] = InputMap.action_get_events(action).duplicate()


static func _replace(action: String, device: Device, event: InputEvent) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if device_of(existing) == device:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)


static func _restore_default(action: String, device: Device) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if device_of(existing) == device:
			InputMap.action_erase_event(action, existing)
	for original: InputEvent in _defaults.get(action, [] as Array[InputEvent]):
		if device_of(original) == device:
			InputMap.action_add_event(action, original)


static func _store(action: String, device: Device, event: InputEvent) -> void:
	var stored := SaveManager.read_json(PATH)
	var entry: Dictionary = stored.get(action, {})
	entry[_device_key(device)] = _to_json(event)
	stored[action] = entry
	SaveManager.write_json(PATH, stored)


## Four shapes, named rather than numbered, so a hand-edited file is readable and a future shape
## can be added without the old ones changing meaning.
static func _to_json(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": (event as InputEventKey).physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "pad", "button": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {"type": "axis", "axis": motion.axis, "value": signf(motion.axis_value)}
	return {}


static func _from_json(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	var entry := data as Dictionary
	match str(entry.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(entry.get("code", 0)) as Key
			return key if key.physical_keycode != KEY_NONE else null
		"mouse":
			var click := InputEventMouseButton.new()
			click.button_index = int(entry.get("button", 0)) as MouseButton
			return click
		"pad":
			var button := InputEventJoypadButton.new()
			button.button_index = int(entry.get("button", 0)) as JoyButton
			return button
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(entry.get("axis", 0)) as JoyAxis
			motion.axis_value = float(entry.get("value", 1.0))
			return motion
	return null


static func _describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		# Bindings are stored physically, so an AZERTY player sees A where a QWERTY player sees Q.
		# A headless display server has no layout to ask, and that is where the checks run.
		var code := (event as InputEventKey).physical_keycode
		if DisplayServer.get_name() != HEADLESS:
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code).to_upper()
	if event is InputEventMouseButton:
		var index := (event as InputEventMouseButton).button_index
		return str(MOUSE_BUTTONS.get(index, "MOUSE %d" % index))
	if event is InputEventJoypadButton:
		var button := (event as InputEventJoypadButton).button_index
		return str(PAD_BUTTONS.get(button, "PAD %d" % button))
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var name := str(PAD_AXES.get(motion.axis, "AXIS %d" % motion.axis))
		# A trigger only travels one way, so a sign on it would be noise.
		if motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			return name
		return "%s %s" % [name, "+" if motion.axis_value > 0.0 else "-"]
	return UNBOUND
