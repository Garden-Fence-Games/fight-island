class_name HintLabel
extends Label
## One line of the hint bar: the glyph that fires an action, and the word for what it does.
##
## Both halves were written out by hand on nine labels across seven screens — `[B / ESC] BACK`, and
## the same again — which is wrong twice. The glyph is wrong the moment a player rebinds or picks up
## a controller, and the word is wrong in every language but this one. `MenuEntry` has had the right
## answer since the menus were built: name the **action**, and let the badge say whatever that
## action is bound to on the device in hand right now.
##
## The word is a translation key rather than text, for the other half of the same reason. A hint the
## player cannot read is a hint that is not there.

## The action whose glyph is printed. Empty prints the word alone, which is what a line that is a
## statement rather than a prompt wants.
@export var action: String = "":
	set = _set_action
## Several actions as one glyph, for the prompts that answer to more than one — the tab keys are
## two, and a wheel is two more.
@export var actions: PackedStringArray = []:
	set = _set_actions
## What the action does, as a key. Empty prints the glyph alone.
@export var label_key: String = "":
	set = _set_label_key


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	EventBus.input_device_changed.connect(_on_input_device_changed)
	EventBus.bindings_changed.connect(refresh)
	refresh()


## What it says, for whoever is holding whatever they are holding.
func refresh() -> void:
	var glyph := _glyph()
	var word := tr(label_key).to_upper() if not label_key.is_empty() else ""
	if glyph.is_empty():
		text = word
		return
	text = "[%s] %s" % [glyph, word] if not word.is_empty() else "[%s]" % glyph


func _glyph() -> String:
	if not actions.is_empty():
		return Devices.glyphs(actions)
	return Devices.glyph(action)


func _set_action(value: String) -> void:
	action = value
	if is_inside_tree():
		refresh()


func _set_actions(value: PackedStringArray) -> void:
	actions = value
	if is_inside_tree():
		refresh()


func _set_label_key(value: String) -> void:
	label_key = value
	if is_inside_tree():
		refresh()


func _on_input_device_changed(_device: int) -> void:
	refresh()
