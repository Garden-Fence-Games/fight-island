class_name TutorialPrompt
extends CanvasLayer
## One line, bottom-centre, and nothing else. It never blocks, never pauses, never asks for a press
## to continue: the fight keeps running underneath, because a prompt that stops the game has
## already broken the only rule the tutorial has.
##
## The glyph in the line is **the one on the device in hand**, not both. A player on a pad reading
## "SPACE" goes looking for a key that is not there, which is worse than no prompt at all — so the
## line is rebuilt when the hand moves and when a binding changes.
##
## It fades rather than appears, and only ever shows the line the director hands it. Deciding *when*
## is not its business — see `TutorialDirector`.

const FADE: float = 0.35

var _key: String = ""
var _actions: PackedStringArray = []
## The fade running now. One at a time: a fade out still running when the next line fades in would
## finish afterwards and hide the line that was just shown.
var _fade: Tween = null

@onready var root: Control = $Root
@onready var line: Label = $Root/Frame/Line


func _ready() -> void:
	root.modulate.a = 0.0
	root.visible = false
	EventBus.input_device_changed.connect(_on_input_device_changed)
	EventBus.bindings_changed.connect(_rewrite)


## Idempotent on purpose: a line already up must not restart its fade.
func show_line(key: String, actions: PackedStringArray = PackedStringArray()) -> void:
	if key.is_empty() or _key == key:
		return
	_key = key
	_actions = actions
	_rewrite()
	root.visible = true
	_restart_fade().tween_property(root, "modulate:a", 1.0, FADE)


func hide_line() -> void:
	if _key.is_empty():
		return
	_key = ""
	_actions = PackedStringArray()
	var tween := _restart_fade()
	tween.tween_property(root, "modulate:a", 0.0, FADE)
	tween.tween_callback(_on_faded)


func is_showing() -> bool:
	return not _key.is_empty()


## What the player is actually reading, for the headless check.
func text() -> String:
	return line.text


## One glyph per action, each in its own placeholder: "{0} to punch and {1} to dodge". A line that
## names no button has no placeholder and is left exactly as written.
func _rewrite() -> void:
	if _key.is_empty():
		return
	var glyphs: Array[String] = []
	for action: String in _actions:
		glyphs.append(Devices.glyph(action))
	line.text = tr(_key).format(glyphs)


func _on_input_device_changed(_device: int) -> void:
	_rewrite()


func _restart_fade() -> Tween:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	return _fade


func _on_faded() -> void:
	if _key.is_empty():
		root.visible = false
