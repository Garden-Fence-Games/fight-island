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
	"reload",
	"interact",
	"weapon_next",
	"weapon_prev",
	"weapon_fists",
	"weapon_stick",
	"weapon_gun",
	"pause",
	"debug_overlay",
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
	"debug_skip_wave",
	"debug_give_money",
]

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

	if failures.is_empty():
		print(
			(
				"project config OK — %d actions, %d layers"
				% [REQUIRED_ACTIONS.size(), REQUIRED_LAYERS.size()]
			)
		)
		quit(0)
		return

	for failure: String in failures:
		printerr(failure)
	quit(1)
