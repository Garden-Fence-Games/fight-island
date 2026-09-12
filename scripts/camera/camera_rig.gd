class_name CameraRig
extends Node3D
## A fixed angle that follows the player, framed the way an isometric RPG is: the yaw and the pitch
## never change, so the world is only ever seen from one direction.
##
## The spring arm is deliberately inert — its collision mask is zero. Letting it dodge geometry is
## what produced sudden zoom jumps the moment the island had trees: the arm collapsed against
## whatever stood behind the player and sprang back out when it cleared. A fixed camera has to be
## *fixed*, so stone that gets in the way goes pale instead — see `OcclusionFader`. Palms are left
## alone: the body reads clearly through a crown of fronds, and thinning several hundred trees in
## and out as someone walks looks stranger than the trees did.
##
## The constraint buys more than it costs. Every silhouette reads the same way every time, the
## island only has to be composed for one viewpoint, and a telegraph can never end up hidden behind
## geometry because the player happened to have turned the camera. Zoom stays, because it costs
## nothing and helps when a crowd closes in.

## Where the camera sits before anybody touches the wheel. It lives here with the yaw and the pitch
## rather than on each arena's spring arm, because it is the same decision: how the game is framed.
##
## Seventeen is where the trade stops paying. Further back is a more legible crowd, and it is also
## more of the ring a body can arrive on sitting inside the shot — and a spawn point in shot is
## refused, because a farmer fading into existence in frame tells the player the world is a spawner
## rather than a place. Measured on the island: ten metres puts 6% of that ring on screen, thirteen
## 14%, seventeen 25%, twenty-four 49%. Past twenty the arrivals start coming only from behind.
const DEFAULT_ZOOM: float = 17.0
const MIN_ZOOM: float = 6.0
## Room to pull further back when a crowd closes in. The cost of doing so is the ring above, and it
## is the player's to pay for a moment rather than the game's to pay for a whole run.
const MAX_ZOOM: float = 24.0
const ZOOM_STEP: float = 1.5
const ZOOM_SMOOTHING: float = 10.0
const FOLLOW_SMOOTHING: float = 12.0

## The one viewing direction of the entire game. Changing either re-frames every scene at once,
## which is why they live here and not on each arena.
@export var yaw_degrees: float = -45.0
@export var pitch_degrees: float = -50.0
@export var target: Node3D = null

var _wanted_zoom: float = 10.0

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var spring: SpringArm3D = $PitchPivot/Spring


func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	rotation.y = deg_to_rad(yaw_degrees)
	pitch_pivot.rotation.x = deg_to_rad(pitch_degrees)
	spring.spring_length = DEFAULT_ZOOM
	_wanted_zoom = DEFAULT_ZOOM
	if target != null:
		global_position = target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_zoom_in"):
		_wanted_zoom = clampf(_wanted_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	if event.is_action_pressed(&"camera_zoom_out"):
		_wanted_zoom = clampf(_wanted_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)


func _process(delta: float) -> void:
	_follow(delta)
	_zoom(delta)


## The ground direction the player reads as "up the screen". Movement stays camera-relative even
## though the camera never turns, so W always means away from the viewer.
func screen_forward() -> Vector3:
	return Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z).normalized()


func _follow(delta: float) -> void:
	if target == null:
		return
	var weight := clampf(FOLLOW_SMOOTHING * delta, 0.0, 1.0)
	global_position = global_position.lerp(target.global_position, weight)


func _zoom(delta: float) -> void:
	var weight := clampf(ZOOM_SMOOTHING * delta, 0.0, 1.0)
	spring.spring_length = lerpf(spring.spring_length, _wanted_zoom, weight)
