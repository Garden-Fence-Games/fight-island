extends Control
## The studio sting, and the only thing that plays before the title. Any button skips it — an intro
## a returning player cannot get past is a loading screen with a logo on it.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const FADE_OUT: float = 0.3
const HINT_DELAY: float = 1.6
const HINT_FADE: float = 0.5

var _leaving: bool = false

@onready var video: VideoStreamPlayer = $Ratio/Video
@onready var hint: Label = $Hint
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	video.finished.connect(_leave)
	video.play()
	var tween: Tween = create_tween()
	tween.tween_interval(HINT_DELAY)
	tween.tween_property(hint, "modulate:a", 1.0, HINT_FADE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event.is_echo() or not event.is_pressed():
		return
	_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	video.stop()
	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.tween_property(fade, "color:a", 1.0, FADE_OUT)
	tween.tween_property(hint, "modulate:a", 0.0, FADE_OUT)
	tween.chain().tween_callback(_change_to_title)


func _change_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
