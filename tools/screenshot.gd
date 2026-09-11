extends Node
## Two looks at the arena, saved as PNGs: the game's own framing, and a high shot for the
## silhouette. Needs a window, so it is the one tool that does not run headless.
## Run: godot --path . --resolution 1280x720 res://tools/screenshot.tscn

const GAME_VIEW: String = "user://island_view.png"
const TOP_VIEW: String = "user://island_top.png"


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(GAME_VIEW)

	var high := Camera3D.new()
	add_child(high)
	high.global_position = Vector3(0.0, 95.0, 60.0)
	high.look_at(Vector3.ZERO, Vector3.UP)
	high.fov = 70.0
	high.current = true
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(TOP_VIEW)

	print("saved %s and %s" % [ProjectSettings.globalize_path(GAME_VIEW), TOP_VIEW])
	get_tree().quit(0)
