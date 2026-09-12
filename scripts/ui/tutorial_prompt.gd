class_name TutorialPrompt
extends CanvasLayer
## One line, bottom-centre, and nothing else. It never blocks, never pauses, never asks for a press
## to continue: the fight keeps running underneath, because a prompt that stops the game has
## already broken the only rule the tutorial has.
##
## It fades rather than appears, and only ever shows the line the director hands it. Deciding *when*
## is not its business — see `TutorialDirector`.

const FADE: float = 0.35

var _showing: String = ""

@onready var root: Control = $Root
@onready var line: Label = $Root/Frame/Line


func _ready() -> void:
	root.modulate.a = 0.0
	root.visible = false


## Idempotent on purpose: the director calls this every frame the step is open, and a line already
## up must not restart its fade.
func show_line(key: String) -> void:
	if key.is_empty() or _showing == key:
		return
	_showing = key
	line.text = tr(key)
	root.visible = true
	create_tween().tween_property(root, "modulate:a", 1.0, FADE)


func hide_line() -> void:
	if _showing.is_empty():
		return
	_showing = ""
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 0.0, FADE)
	tween.tween_callback(_on_faded)


func is_showing() -> bool:
	return not _showing.is_empty()


func _on_faded() -> void:
	root.visible = false
