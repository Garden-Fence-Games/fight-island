class_name RunIntro
extends Node
## A new run opens on the player waking up, and the camera turning once round him before it becomes
## the camera the game is played from.
##
## **Only a run started from the title owes it** — `GameState.begin_run(true)`. A retry from the
## summary or a restart from the pause menu is the same player straight back into it, and a resumed
## run is a player who has already woken up. Nothing else sets the flag, so every headless check
## that begins a run gets the game without an opening.
##
## **It plays whole.** For its length the player has no body: the state machine is stopped, input
## reaches nothing, the head does not follow the aim, the waves and the tutorial wait, and the HUD
## is away. All of it comes back together when the camera has settled.
##
## **The turn ends where the game camera already is.** The last point of the orbit is the game
## camera's own position — same bearing, distance and height — so there is nothing to cut to; the
## short settle after the clip only absorbs whatever the rig moved while it waited. The camera still
## never turns during play: this is the one moment the island is seen from anywhere else.

signal finished

var intro: RunIntroData = preload("res://data/fx/run_intro.tres")

var _player: Player = null
var _rig: CameraRig = null
var _held: Array[Node] = []
var _hud: CanvasLayer = null
var _camera: Camera3D = null
var _clip_seconds: float = 0.0
var _elapsed: float = 0.0
var _released: bool = false


## Starts the opening in `main`, if the run owes one. Returns the intro, or null when there is none
## to play — no flag, or no arena to play it in.
static func open_if_owed(main: Node) -> RunIntro:
	if not GameState.intro_owed or main == null:
		return null
	GameState.intro_owed = false
	var arena := main.get_node_or_null(^"Arena")
	if arena == null or arena.get_node_or_null(^"Player") == null:
		return null
	var opening := RunIntro.new()
	opening.name = "RunIntro"
	main.add_child(opening)
	return opening


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var arena := get_parent().get_node(^"Arena")
	_player = arena.get_node(^"Player") as Player
	_rig = arena.get_node_or_null(^"CameraRig") as CameraRig
	_hud = get_parent().get_node_or_null(^"Hud") as CanvasLayer
	for waiting: NodePath in [^"WaveDirector", ^"TutorialDirector"]:
		var system := arena.get_node_or_null(waiting)
		if system != null:
			_held.append(system)
	_take_the_body()
	_clip_seconds = _play_the_clip()
	_camera = Camera3D.new()
	_camera.name = "IntroCamera"
	arena.add_child(_camera)
	PixelLook.attach(_camera)
	if _rig != null and _rig.camera != null:
		_camera.fov = _rig.camera.fov
	_camera.make_current()
	_frame(0.0)


func _process(delta: float) -> void:
	if _released:
		return
	_elapsed += delta
	if _elapsed < _clip_seconds:
		_frame(_elapsed / _clip_seconds)
		return
	var settling := clampf((_elapsed - _clip_seconds) / maxf(intro.settle_seconds, 0.001), 0.0, 1.0)
	if _rig != null and _rig.camera != null:
		var weight := smoothstep(0.0, 1.0, settling)
		_camera.global_transform = _orbit(1.0).interpolate_with(
			_rig.camera.global_transform, weight
		)
	if settling >= 1.0:
		_give_the_body_back()


func _take_the_body() -> void:
	_player.machine.process_mode = Node.PROCESS_MODE_DISABLED
	_player.set_process_unhandled_input(false)
	_player.velocity = Vector3.ZERO
	if _player.head_look != null:
		_player.head_look.resting = true
	if _rig != null:
		# The wheel waits too: a zoom turned during the opening would move the point it ends on.
		_rig.set_process_unhandled_input(false)
	for system: Node in _held:
		system.process_mode = Node.PROCESS_MODE_DISABLED
	if _hud != null:
		_hud.visible = false


## The clip, and how long it runs. Nought when the rig has no such clip, which ends the opening on
## its first frame rather than holding a player still for nothing.
func _play_the_clip() -> float:
	var component := _player.animation
	if component == null or component.animation_player == null:
		return 0.0
	if not component.animation_player.has_animation(intro.clip):
		return 0.0
	component.play_clip(intro.clip)
	return component.animation_player.get_animation(intro.clip).length


func _give_the_body_back() -> void:
	_released = true
	if _rig != null and _rig.camera != null:
		_rig.camera.make_current()
		_rig.set_process_unhandled_input(true)
	_camera.queue_free()
	_player.machine.process_mode = Node.PROCESS_MODE_INHERIT
	_player.set_process_unhandled_input(true)
	if _player.head_look != null:
		_player.head_look.resting = false
	if _player.animation != null:
		_player.animation.refresh()
	for system: Node in _held:
		system.process_mode = Node.PROCESS_MODE_INHERIT
	if _hud != null:
		_hud.visible = true
	finished.emit()
	queue_free()


func _frame(progress: float) -> void:
	_camera.global_transform = _orbit(progress)


## Where the camera is `progress` of the way round, nought to one. Ends on the game camera's own
## bearing, distance and height.
func _orbit(progress: float) -> Transform3D:
	var focus := _player.global_position + Vector3.UP * intro.look_height
	var offset := Vector3(0.0, 12.0, 12.0)
	if _rig != null and _rig.camera != null:
		offset = _rig.camera.global_position - focus
	var flat := Vector2(offset.x, offset.z)
	var eased := smoothstep(0.0, 1.0, progress)
	var bearing := flat.angle() - deg_to_rad(intro.turn_degrees) * (1.0 - eased)
	var reach := flat.length() * lerpf(intro.start_distance, 1.0, eased)
	var rise := offset.y * lerpf(intro.start_height, 1.0, eased)
	var eye := focus + Vector3(cos(bearing) * reach, rise, sin(bearing) * reach)
	var looking := Transform3D(Basis.IDENTITY, eye)
	# Toward the focus while turning, and toward wherever the game camera looks by the end of it, so
	# the last frame is the game camera's rotation and not a close one.
	var aimed := looking.looking_at(focus, Vector3.UP)
	if _rig != null and _rig.camera != null:
		aimed.basis = aimed.basis.slerp(_rig.camera.global_basis, smoothstep(0.7, 1.0, progress))
	return aimed
