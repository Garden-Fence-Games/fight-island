class_name Devices
extends RefCounted
## Which device the player is actually holding, and the glyph an action wears on it.
##
## **A player on a pad must never read the word "mouse".** That is the whole feature, and it is not
## a preference: the prompts in wave 1 are a verb and a glyph, and a glyph naming the wrong hardware
## is worse than no glyph, because the player goes looking for a key that is not there.
##
## The device is the **last one touched**, not one chosen at launch. Somebody with a keyboard and a
## pad in front of them is the normal case, not the edge one, and the answer has to follow the hand
## that just moved. The noticing happens on `EventBus`, which is the one node that sees every event
## in every scene; the state lives here, so the bus keeps holding none.
##
## Static for the same reason `Settings` and `InputBindings` are — ADR 0004 allows three autoloads
## and this is not one of them.

## A stick is one thing to the player even though the engine reports it as four half-axes, so the
## direction and then the axis letter come off before a glyph is shown. "L-STICK Y -" and
## "L-STICK X +" are the same thumb, and a prompt that lists both has described a shape nobody has.
const DIRECTIONS: PackedStringArray = [" +", " -"]
const AXIS_SUFFIXES: PackedStringArray = [" X", " Y"]
## What a true name is shortened to **on a badge**. `InputBindings.describe` answers with the name
## the options screen prints, which has a column to print it in; a chip beside a menu row does not,
## and the design draws `[B / ESC]` rather than `[B / ESCAPE]`.
const SHORTENED: Dictionary = {
	"ESCAPE": "ESC",
	"BACKSPACE": "BKSP",
	"DELETE": "DEL",
	"PAGEUP": "PGUP",
	"PAGEDOWN": "PGDN",
}
## How far a stick must move to count as the player touching the pad. A resting stick drifts, and a
## drifting stick would flip every glyph on screen back and forth for ever.
const STICK_WAKE: float = 0.5

static var _last: InputBindings.Device = InputBindings.Device.KEYBOARD


static func last_used() -> InputBindings.Device:
	return _last


## The pad that was answering is gone. Whether anything changed.
##
## A controller that is unplugged sends no input event, so nothing moved `_last` and every badge in
## the game went on printing pad glyphs for hardware that is not there — the exact failure this
## class exists to prevent, arrived from the other direction. Asked rather than assumed: a second
## pad still connected is still a pad, and only an empty hand falls back to the keyboard.
static func forget_a_lost_pad() -> bool:
	if _last != InputBindings.Device.GAMEPAD:
		return false
	if not Input.get_connected_joypads().is_empty():
		return false
	_last = InputBindings.Device.KEYBOARD
	return true


## Whether the device changed. Called from the bus for every event there is, so it is written to be
## cheap and to say no quickly.
static func notice(event: InputEvent) -> bool:
	var device := _device_behind(event)
	if device < 0 or device == _last:
		return false
	_last = device as InputBindings.Device
	return true


## The glyph for one action on the device in hand — "ENTER" or "A", never both. Empty for an action
## that does not exist, so a caller can hide its badge rather than print a dash in a menu.
static func glyph(action: String) -> String:
	if action.is_empty() or not InputMap.has_action(action):
		return ""
	return _trimmed(InputBindings.describe(action, _last))


## Several actions as one glyph, deduplicated: "W A S D" on a keyboard, and a single "L-STICK" on a
## pad, because that is what the player has to move.
static func glyphs(actions: PackedStringArray) -> String:
	var seen: PackedStringArray = []
	for action: String in actions:
		var one := glyph(action)
		if one.is_empty() or one == InputBindings.UNBOUND or seen.has(one):
			continue
		seen.append(one)
	return " ".join(seen)


## For the headless checks, which have to drive both sides of a swap.
static func force(device: InputBindings.Device) -> void:
	_last = device


## A mouse moving counts: it is the clearest statement there is that the hand is on the mouse. A
## stick at rest does not, or noise would flip the glyphs for ever.
static func _device_behind(event: InputEvent) -> int:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return InputBindings.Device.GAMEPAD if absf(motion.axis_value) >= STICK_WAKE else -1
	if event is InputEventMouseMotion:
		return InputBindings.Device.KEYBOARD
	return InputBindings.device_of(event)


static func _trimmed(label: String) -> String:
	var out := label
	for suffix: String in DIRECTIONS:
		if out.ends_with(suffix):
			out = out.substr(0, out.length() - suffix.length())
	for suffix: String in AXIS_SUFFIXES:
		if out.ends_with(suffix):
			out = out.substr(0, out.length() - suffix.length())
	return str(SHORTENED.get(out, out))
