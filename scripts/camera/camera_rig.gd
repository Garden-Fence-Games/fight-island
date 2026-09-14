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
## How close the wheel may come, and it is a **readability floor rather than a taste**. The ground
## that stays in shot on the blind bearing is very nearly half the arm: six metres showed 2.75 m of
## it, nine 4.25, eleven 5.25, seventeen 8.50. A pirate strikes from 2.0 m and covers 2.4 m more
## while he winds up, so under 4.4 m of visible ground his swing begins off-screen — which made the
## old floor of six a setting that quietly took the fight away from whoever chose it.
##
## Eleven is the first step of the wheel clear of that bound. `tools/verify_view.tscn` winds the
## wheel all the way in and re-measures, so a change to the pitch, the field of view or an
## archetype's reach fails here rather than in someone's hands.
const MIN_ZOOM: float = 11.0
## Room to pull further back when a crowd closes in. The cost of doing so is the ring above, and it
## is the player's to pay for a moment rather than the game's to pay for a whole run.
const MAX_ZOOM: float = 24.0
const ZOOM_STEP: float = 1.5
const ZOOM_SMOOTHING: float = 10.0
## How far the fiercest shake tips the eye, in degrees, at the full setting. Small on purpose: a
## fixed camera that lurches stops being fixed, and the whole argument for this angle is that a
## silhouette reads the same way every time.
##
## **A tip and not a shove.** The spring arm owns its child's *position* — it rewrites it every
## frame to hold the camera at the end of the arm — so a shake written there is a shake the arm
## undoes, and in the meantime it drags the camera back down the arm towards the player. It cost an
## afternoon: the first version passed every effect check and quietly broke the occlusion one,
## because the eye was no longer where anything thought it was. Rotation is left alone by the arm,
## and a kick is what a camera does anyway.
const SHAKE_REACH: float = 0.8
## How fast a knock dies away. Quick enough to be over before the next input matters.
const SHAKE_DECAY: float = 6.0
## The setting is a percentage, and nought means none — not a little.
const FULL_SHAKE: float = 100.0
const FOLLOW_SMOOTHING: float = 12.0
## Where a wind-up reads on a body — the chest, which is what the swing comes off and what the
## camera is already looking at. The feet are as likely to be behind the bottom edge of the frame as
## the body is to be off screen entirely.
const TELEGRAPH_HEIGHT: float = 1.1

## The one viewing direction of the entire game. Changing either re-frames every scene at once,
## which is why they live here and not on each arena.
@export var yaw_degrees: float = -45.0
@export var pitch_degrees: float = -50.0
@export var target: Node3D = null

var _wanted_zoom: float = 10.0
## How hard the camera is still shaking, nought to one, and the source of the jitter. Seeded from
## the run so two players who see the same fight see the same knock.
var _shake: float = 0.0
var _jolt := RandomNumberGenerator.new()

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var spring: SpringArm3D = $PitchPivot/Spring
@onready var camera: Camera3D = $PitchPivot/Spring/Camera


func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	rotation.y = deg_to_rad(yaw_degrees)
	pitch_pivot.rotation.x = deg_to_rad(pitch_degrees)
	spring.spring_length = DEFAULT_ZOOM
	_wanted_zoom = DEFAULT_ZOOM
	if target != null:
		global_position = target.global_position
	_jolt.seed = GameState.run_seed
	EventBus.shake_requested.connect(_on_shake_requested)
	PixelLook.attach(camera)


## How much knock is left, nought to one. Read by the headless check, which cannot see a camera
## move but can ask whether it was asked to.
func shake_left() -> float:
	return _shake


## Back to rest at once. For a check measuring one knock, which has to know the reading it takes
## came from the blow it just struck and not from the one before it.
func settle() -> void:
	_shake = 0.0


## Requests are scaled here rather than at the callers: a player who has turned shake off is not
## asking for less of it, and every emitter would otherwise have to remember that.
##
## **A telegraph outranks every knock.** The camera is fixed precisely so a wind-up can never end up
## hidden, and a screen that jumps while a farmer is committing gives that back — it steals the one
## frame the player needed, and there is no amount of feel worth that. So a request that arrives
## while something in shot is winding up is refused outright rather than softened: half a shake over
## a telegraph is still a shake over a telegraph.
func _on_shake_requested(strength: float) -> void:
	if _something_in_shot_is_winding_up():
		return
	var wanted := float(Settings.get_value(&"access_screen_shake")) / FULL_SHAKE
	_shake = maxf(_shake, strength * clampf(wanted, 0.0, 1.0))


## Only what is on screen. A farmer committing behind the player is a telegraph nobody could read
## anyway, and refusing every knock while anyone anywhere on the island winds up would mean refusing
## most of them.
func _something_in_shot_is_winding_up() -> bool:
	if camera == null:
		return false
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.machine == null:
			continue
		if not enemy.machine.current is EnemyWindUp:
			continue
		if camera.is_position_in_frustum(enemy.global_position + Vector3.UP * TELEGRAPH_HEIGHT):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_zoom_in"):
		_wanted_zoom = clampf(_wanted_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	if event.is_action_pressed(&"camera_zoom_out"):
		_wanted_zoom = clampf(_wanted_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)


func _process(delta: float) -> void:
	_follow(delta)
	_zoom(delta)
	_shudder(delta)


## The knock is put on the camera's own rotation, so it never moves what the rig is following and
## never argues with the spring arm about where the eye belongs.
func _shudder(delta: float) -> void:
	if _shake <= 0.0:
		if camera.rotation != Vector3.ZERO:
			camera.rotation = Vector3.ZERO
		return
	_shake = maxf(_shake - SHAKE_DECAY * delta * _shake, 0.0)
	if _shake < 0.001:
		_shake = 0.0
		camera.rotation = Vector3.ZERO
		return
	var reach := deg_to_rad(SHAKE_REACH * _shake)
	camera.rotation = Vector3(
		_jolt.randf_range(-reach, reach), _jolt.randf_range(-reach, reach), 0.0
	)


func _follow(delta: float) -> void:
	if target == null:
		return
	var weight := clampf(FOLLOW_SMOOTHING * delta, 0.0, 1.0)
	global_position = global_position.lerp(target.global_position, weight)


func _zoom(delta: float) -> void:
	var weight := clampf(ZOOM_SMOOTHING * delta, 0.0, 1.0)
	spring.spring_length = lerpf(spring.spring_length, _wanted_zoom, weight)
