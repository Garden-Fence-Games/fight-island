class_name Settings
extends RefCounted
## Every player-facing setting, applied the moment it changes and written straight back to disk.
## There is no Apply button and nothing here needs a restart: a setting that cannot apply live is
## built wrong.
##
## Static, not an autoload — ADR 0004 allows three and this is not one of them. Nothing subscribes
## to a setting either: every reader asks for the value it needs at the moment it needs it, which
## is why no signal is missing here.
##
## The first read loads the file and applies everything, so a scene launched straight from the
## editor behaves exactly like one reached through boot.

## Written once so a hand-edited file that predates a new setting still loads: anything missing
## falls back to the value here rather than to null.
const DEFAULTS: Dictionary = {
	&"gameplay_sprint_mode": "auto",
	&"gameplay_aim_assist": "soft",
	&"gameplay_tutorial_prompts": true,
	&"gameplay_damage_numbers": false,
	&"controls_mouse_sensitivity": 12.0,
	&"controls_stick_sensitivity": 180.0,
	&"controls_invert_y": false,
	&"video_window_mode": "windowed",
	&"video_resolution": "1920x1080",
	&"video_vsync": "on",
	&"video_frame_cap": 0,
	&"audio_master": 100,
	&"audio_music": 100,
	&"audio_sfx": 100,
	&"audio_ambience": 100,
	&"access_screen_shake": 100,
	&"access_hitstop": true,
	&"access_colourblind_telegraphs": false,
	&"access_hold_to_confirm": false,
	&"access_reduce_flashing": false,
}

const AUDIO_BUSES: Dictionary = {
	&"audio_master": &"Master",
	&"audio_music": &"Music",
	&"audio_sfx": &"SFX",
	&"audio_ambience": &"Ambience",
}

const WINDOW_MODES: Dictionary = {
	"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
	"borderless": DisplayServer.WINDOW_MODE_FULLSCREEN,
	"fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
}

const VSYNC_MODES: Dictionary = {
	"off": DisplayServer.VSYNC_DISABLED,
	"on": DisplayServer.VSYNC_ENABLED,
	"adaptive": DisplayServer.VSYNC_ADAPTIVE,
}

## Silence rather than an ever-smaller fraction of a decibel, so a slider at zero really is off.
const MUTE_DB: float = -80.0

static var _values: Dictionary = {}
static var _loaded: bool = false


static func get_value(key: StringName) -> Variant:
	_ensure_loaded()
	return _values.get(key, DEFAULTS.get(key))


static func set_value(key: StringName, value: Variant) -> void:
	_ensure_loaded()
	if not DEFAULTS.has(key) or _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	SaveManager.write_settings(_as_json())


static func reset(key: StringName) -> void:
	set_value(key, DEFAULTS.get(key))


static func reset_all() -> void:
	for key: StringName in DEFAULTS:
		reset(key)


static func apply_all() -> void:
	_ensure_loaded()
	for key: StringName in DEFAULTS:
		_apply(key)


## Hold on a keyboard and toggle on a pad is what each audience expects, so "auto" is a real
## answer rather than a missing one.
static func sprint_is_toggle(from_gamepad: bool) -> bool:
	var mode := str(get_value(&"gameplay_sprint_mode"))
	if mode == "auto":
		return from_gamepad
	return mode == "toggle"


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_values = DEFAULTS.duplicate()
	var stored := SaveManager.read_settings()
	for key: StringName in DEFAULTS:
		if stored.has(String(key)):
			_values[key] = _coerce(stored[String(key)], DEFAULTS[key])
	for key: StringName in DEFAULTS:
		_apply(key)


## JSON has one number type, so every int comes back as a float. Anything that cannot be read as
## the default's type is dropped rather than trusted — the file is hand-editable.
static func _coerce(stored: Variant, fallback: Variant) -> Variant:
	var numeric := typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT
	match typeof(fallback):
		TYPE_INT:
			return int(stored) if numeric else fallback
		TYPE_FLOAT:
			return float(stored) if numeric else fallback
		TYPE_BOOL:
			return bool(stored) if typeof(stored) == TYPE_BOOL else fallback
		TYPE_STRING:
			return str(stored) if typeof(stored) == TYPE_STRING else fallback
	return fallback


static func _as_json() -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in DEFAULTS:
		out[String(key)] = _values[key]
	return out


static func _apply(key: StringName) -> void:
	if AUDIO_BUSES.has(key):
		_apply_bus(AUDIO_BUSES[key], int(_values.get(key, DEFAULTS[key])))
		return
	match key:
		&"video_window_mode":
			_apply_window_mode()
		&"video_resolution":
			_apply_resolution()
		&"video_vsync":
			DisplayServer.window_set_vsync_mode(
				VSYNC_MODES.get(str(_values.get(key)), DisplayServer.VSYNC_ENABLED)
			)
		&"video_frame_cap":
			Engine.max_fps = maxi(int(_values.get(key, 0)), 0)


static func _apply_bus(bus: StringName, percent: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var linear := clampf(float(percent) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, MUTE_DB if linear <= 0.0 else linear_to_db(linear))


static func _apply_window_mode() -> void:
	var wanted := str(_values.get(&"video_window_mode"))
	DisplayServer.window_set_mode(
		WINDOW_MODES.get(wanted, DisplayServer.WINDOW_MODE_WINDOWED) as DisplayServer.WindowMode
	)
	# Borderless is plain fullscreen without a frame; exclusive keeps its own.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, wanted == "borderless")
	_apply_resolution()


## Only windowed mode owns its size — resizing an exclusive-fullscreen window fights the display.
static func _apply_resolution() -> void:
	if str(_values.get(&"video_window_mode")) != "windowed":
		return
	var parts := str(_values.get(&"video_resolution")).split("x")
	if parts.size() != 2:
		return
	DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
