extends SceneTree
## Headless guard: fails the build if an expected input action or physics layer is missing.
## Run: godot --headless --path . --script tools/verify_project_config.gd

const REQUIRED_ACTIONS: PackedStringArray = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"aim_left",
	"aim_right",
	"aim_up",
	"aim_down",
	"camera_zoom_in",
	"camera_zoom_out",
	"attack",
	"parry",
	"dodge",
	"sprint",
	"interact",
	"weapon_next",
	"weapon_prev",
	"weapon_fists",
	"weapon_stick",
	"weapon_gun",
	"pause",
	"menu_options",
	"music_mute",
	"menu_new_run",
	"menu_prev_tab",
	"menu_next_tab",
	"debug_overlay",
	"debug_mix_desk",
	"debug_skip_wave",
	"debug_give_money",
]

const REQUIRED_LAYERS: PackedStringArray = [
	"world",
	"player_body",
	"enemy_body",
	"player_hitbox",
	"enemy_hitbox",
	"player_hurtbox",
	"enemy_hurtbox",
	"interactable",
	"camera_occluder",
	"spawn_blocker",
]

const GAMEPAD_EXEMPT: PackedStringArray = [
	"weapon_fists",
	"weapon_stick",
	"weapon_gun",
	"debug_overlay",
	"debug_mix_desk",
	"debug_skip_wave",
	"debug_give_money",
]

## Project settings an export preset needs, and what refuses to build without them. Held here
## rather than discovered on a tag: an export preset and a project setting can disagree for months
## while every check in this repository passes, because nothing else in the project reads either.
##
## `import_etc2_astc` is the one that caught it. Apple Silicon reads ASTC and nothing else, so a
## macOS preset set to universal or arm64 will not export at all without it — the first tag would
## have failed on "Cannot export for universal or arm64 if ETC2 ASTC texture format is disabled",
## with the release already cut and nothing to publish.
const REQUIRED_FOR_EXPORT: Dictionary[String, bool] = {
	"rendering/textures/vram_compression/import_etc2_astc": true,
}

## The mouse aims by where it *is*, not by an action — there is no key that means "look north-east".
## So the four aim actions are the stick's alone, and the cursor covers the other device.
const KEYBOARD_EXEMPT: PackedStringArray = [
	"weapon_prev",
	"aim_left",
	"aim_right",
	"aim_up",
	"aim_down",
]


func _init() -> void:
	var failures: PackedStringArray = []

	for action: String in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("missing action: %s" % action)
			continue
		var has_keyboard := false
		var has_gamepad := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				has_keyboard = true
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_gamepad = true
		if not has_keyboard and not KEYBOARD_EXEMPT.has(action):
			failures.append("no keyboard/mouse binding: %s" % action)
		if not has_gamepad and not GAMEPAD_EXEMPT.has(action):
			failures.append("no gamepad binding: %s" % action)

	for index: int in REQUIRED_LAYERS.size():
		var setting := "layer_names/3d_physics/layer_%d" % (index + 1)
		var actual := str(ProjectSettings.get_setting(setting, ""))
		if actual != REQUIRED_LAYERS[index]:
			failures.append(
				"layer %d is %s, expected %s" % [index + 1, actual, REQUIRED_LAYERS[index]]
			)

	if ProjectSettings.get_setting("application/config/version", "") == "":
		failures.append("application/config/version is not set")

	for setting: String in REQUIRED_FOR_EXPORT:
		if bool(ProjectSettings.get_setting(setting, false)) != REQUIRED_FOR_EXPORT[setting]:
			failures.append(
				(
					"%s is %s and the export presets need %s"
					% [
						setting,
						ProjectSettings.get_setting(setting, false),
						REQUIRED_FOR_EXPORT[setting]
					]
				)
			)

	failures.append_array(_raw_layer_numbers("res://scripts"))

	if failures.is_empty():
		print(
			(
				"project config OK — %d actions, %d layers, %d settings the exports need"
				% [REQUIRED_ACTIONS.size(), REQUIRED_LAYERS.size(), REQUIRED_FOR_EXPORT.size()]
			)
		)
		quit(0)
		return

	for failure: String in failures:
		printerr(failure)
	quit(1)


## Every `@export_flags_3d_physics` in `scripts/` that spells its default as a number.
##
## The layer names above are checked on one side of the coupling only: rename or renumber a layer
## and this file is edited in the same breath, every consumer that reads `PhysicsLayers.BIT_*`
## follows, and anything holding a literal quietly starts colliding with something else. No error,
## no log line — the gun simply stops hitting people.
##
## Scenes are not scanned: the editor writes those numbers itself and they are not ours to keep in
## a constant.
func _raw_layer_numbers(directory: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for name: String in DirAccess.get_directories_at(directory):
		found.append_array(_raw_layer_numbers(directory.path_join(name)))
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".gd"):
			continue
		var path := directory.path_join(name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var line_number := 0
		for line: String in file.get_as_text().split("\n"):
			line_number += 1
			if not line.contains("@export_flags_3d_physics"):
				continue
			var default := line.get_slice("=", 1).strip_edges()
			if default.is_empty() or not default.is_valid_int():
				continue
			found.append(
				(
					"%s:%d writes a physics layer as %s — name it through PhysicsLayers"
					% [path, line_number, default]
				)
			)
	return found
