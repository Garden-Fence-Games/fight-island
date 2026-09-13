@tool
extends Node
## The application icon, drawn from the logo rather than stored twice. Godot's default `icon.svg`
## was still what the dock, the taskbar and the launcher showed.
##
## Rendered rather than hand-written: the mark is an SVG of 70 kB whose paths cannot be re-nested
## inside another SVG without trusting one rasteriser to agree with another about a nested
## viewBox. A square PNG is what both export presets want anyway — macOS builds the `.icns` from
## it and Windows the `.ico`.
## Run: godot --path . res://tools/build_icon.tscn

const LOGO: String = "res://assets/logo/fight_island_logo_1.svg"
const OUT: String = "res://icon.png"
const SIDE: int = 1024
## macOS rounds nothing for you and Windows rounds nothing either, so the corner is drawn. A tenth
## of the side is the radius Apple's own grid uses.
const CORNER: int = 102
## The sea at the edge of the menu's backdrop, so the icon and the first screen are the same colour.
const GROUND: Color = Color(0.055, 0.075, 0.106)
## How much of the square the mark is allowed. The rest is the margin that keeps it readable at the
## 32 px the taskbar draws it at.
const MARK: float = 0.72


func _ready() -> void:
	var frame := SubViewport.new()
	frame.size = Vector2i(SIDE, SIDE)
	frame.transparent_bg = true
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(frame)

	var square := StyleBoxFlat.new()
	square.bg_color = GROUND
	square.set_corner_radius_all(CORNER)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", square)
	frame.add_child(panel)

	var mark := TextureRect.new()
	mark.texture = load(LOGO) as Texture2D
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := SIDE * (1.0 - MARK) * 0.5
	for side: String in ["left", "top"]:
		mark.set("offset_%s" % side, inset)
	for side: String in ["right", "bottom"]:
		mark.set("offset_%s" % side, -inset)
	panel.add_child(mark)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := frame.get_texture().get_image()
	shot.save_png(OUT)
	print("saved %s at %dx%d" % [OUT, shot.get_width(), shot.get_height()])
	get_tree().quit(0)
