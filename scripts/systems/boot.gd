extends Node
## Nothing but a door. Keeping the first scene empty means the window is up before anything heavy
## loads, and it gives the project one place to branch later.
##
## It is also where saved input bindings reach the InputMap: every other script asks the map what a
## key does, so the map has to be right before any of them run.

const INTRO_SCENE: String = "res://scenes/boot/intro.tscn"


func _ready() -> void:
	InputBindings.apply()
	Settings.apply_all()
	# Deferred because the tree is still busy building this scene when _ready runs.
	get_tree().change_scene_to_file.call_deferred(INTRO_SCENE)
