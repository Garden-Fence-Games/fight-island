extends Node
## Three looks at the arena, saved as PNGs: the game's own framing by day and by night, and a high
## shot for the silhouette. The night one is the only way to see whether a fight is still readable
## after dark, which no headless check can answer. Needs a window, so it is the one tool that does
## not run headless.
## Run: godot --path . --resolution 1280x720 res://tools/screenshot.tscn

const GAME_VIEW: String = "user://island_view.png"
const NIGHT_VIEW: String = "user://island_night.png"
const TOP_VIEW: String = "user://island_top.png"
## Deep enough into the wave to be well past nightfall and clear of the window where the sky is
## still turning.
const MIDNIGHT_OF_THE_WAVE: float = 0.8


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(GAME_VIEW)

	var cycle := GameState.day_cycle as DayCycle
	var director := get_node_or_null("Arena/WaveDirector")
	if cycle != null and director != null:
		# The director writes the hour every frame, so it has to stop before the hour can be posed.
		director.process_mode = Node.PROCESS_MODE_DISABLED
		GameState.day_elapsed = cycle.wave_seconds() * MIDNIGHT_OF_THE_WAVE
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(NIGHT_VIEW)

	var high := Camera3D.new()
	add_child(high)
	high.global_position = Vector3(0.0, 95.0, 60.0)
	high.look_at(Vector3.ZERO, Vector3.UP)
	high.fov = 70.0
	high.current = true
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(TOP_VIEW)

	print("saved %s, %s and %s" % [ProjectSettings.globalize_path(GAME_VIEW), NIGHT_VIEW, TOP_VIEW])
	get_tree().quit(0)
