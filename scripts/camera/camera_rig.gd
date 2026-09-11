class_name CameraRig
extends Node3D
## Framed like an isometric RPG, played like an action game: the yaw is free and wraps, the pitch
## is clamped so the ground never leaves the frame, and the arm gives way to anything solid.
##
## Mouse look is read here rather than through the InputMap because Godot has no
## InputEventMouseMotion action. Both halves feed one vector, so sensitivity applies once.

const MIN_PITCH_DEGREES: float = -65.0
const MAX_PITCH_DEGREES: float = -15.0
const MIN_ZOOM: float = 6.0
const MAX_ZOOM: float = 16.0
const ZOOM_STEP: float = 1.5
const ZOOM_SMOOTHING: float = 10.0
const FOLLOW_SMOOTHING: float = 12.0
const STICK_DEGREES_PER_SECOND: float = 180.0

## Degrees per 100 pixels, so the feel does not change with resolution.
@export var mouse_sensitivity: float = 22.0
@export var stick_sensitivity: float = 1.0
@export var invert_y: bool = false
@export var target: Node3D = null

var _look: Vector2 = Vector2.ZERO
var _wanted_zoom: float = 10.0

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var spring: SpringArm3D = $PitchPivot/Spring


func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	_wanted_zoom = spring.spring_length if spring != null else 10.0
	if pitch_pivot != null:
		pitch_pivot.rotation.x = deg_to_rad(-50.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look += motion.relative * (mouse_sensitivity / 100.0)
	if event.is_action_pressed(&"camera_zoom_in"):
		_wanted_zoom = clampf(_wanted_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	if event.is_action_pressed(&"camera_zoom_out"):
		_wanted_zoom = clampf(_wanted_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	if event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click := event as InputEventMouseButton
	if click != null and click.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_follow(delta)
	_turn(delta)
	_zoom(delta)


func recenter() -> void:
	if target == null:
		return
	rotation.y = target.rotation.y


func _follow(delta: float) -> void:
	if target == null:
		return
	var weight := clampf(FOLLOW_SMOOTHING * delta, 0.0, 1.0)
	global_position = global_position.lerp(target.global_position, weight)


func _turn(delta: float) -> void:
	var stick := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	var stick_degrees := stick * STICK_DEGREES_PER_SECOND * stick_sensitivity * delta
	var degrees := _look + stick_degrees
	_look = Vector2.ZERO
	if Input.is_action_just_pressed(&"camera_recenter"):
		recenter()
		return
	# Yaw wraps on purpose: it is never clamped, so the player can keep turning the same way.
	rotation.y = wrapf(rotation.y - deg_to_rad(degrees.x), -PI, PI)
	if pitch_pivot == null:
		return
	var pitch_change := deg_to_rad(degrees.y) * (1.0 if invert_y else -1.0)
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x + pitch_change,
		deg_to_rad(MIN_PITCH_DEGREES),
		deg_to_rad(MAX_PITCH_DEGREES)
	)


func _zoom(delta: float) -> void:
	if spring == null:
		return
	var weight := clampf(ZOOM_SMOOTHING * delta, 0.0, 1.0)
	spring.spring_length = lerpf(spring.spring_length, _wanted_zoom, weight)
