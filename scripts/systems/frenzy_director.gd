class_name FrenzyDirector
extends Node
## Puts the rainbow bird on the island, and takes its power back when the wave ends.
##
## **One roll a wave, made at the bell**, and a landing some seconds later — see `FrenzyData`. A
## bird that is not taken by the end of the wave goes with it, and a power still running ends there
## too: the merchant is not a place to be invincible in, and the next wave starts from the same
## footing as every other.
##
## Placed the way a weapon is: **somewhere the player can see**, because a power-up that landed
## behind the camera is one the player never had.

const BIRD_SCENE: String = "res://scenes/world/rainbow_bird.tscn"
const DATA: String = "res://data/pickups/rainbow_bird.tres"
## Tries before settling for reachable ground out of shot.
const ATTEMPTS: int = 48
## The height the camera is asked about: the bird, not the sand under it.
const SEEN_AT: float = 0.3

@export var data: FrenzyData = null

## Seconds until this wave's bird lands, or negative when the wave has none owed.
var _lands_in: float = -1.0
var _bird: RainbowBird = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = GameState.run_seed + 6
	if data == null:
		data = load(DATA) as FrenzyData
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)


func _physics_process(delta: float) -> void:
	if _lands_in < 0.0:
		return
	_lands_in -= delta
	if _lands_in > 0.0:
		return
	# Nowhere to stand this frame keeps it owed, the promise every other director makes.
	_lands_in = 0.0
	if place() != null:
		_lands_in = -1.0


## The bird, landed near the player now. Public so the headless checks need not wait for a wave.
func place() -> RainbowBird:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or data == null:
		return null
	var where := _somewhere_visible(player)
	if where == Vector3.INF:
		return null
	take_away()
	_bird = (load(BIRD_SCENE) as PackedScene).instantiate() as RainbowBird
	_bird.data = data
	add_child(_bird)
	_bird.global_position = where
	return _bird


## The bird on the island, or null.
func bird() -> RainbowBird:
	return _bird if is_instance_valid(_bird) and not _bird.is_queued_for_deletion() else null


## Whether this wave still has a bird to land.
func owes_a_bird() -> bool:
	return _lands_in >= 0.0


## Takes back a bird nobody took.
func take_away() -> void:
	if bird() != null:
		_bird.queue_free()
	_bird = null


func _somewhere_visible(player: Node3D) -> Vector3:
	var world := player.get_world_3d()
	var camera := get_viewport().get_camera_3d()
	var fallback := Vector3.INF
	for _attempt: int in ATTEMPTS:
		var angle := _rng.randf_range(0.0, TAU)
		var reach := _rng.randf_range(data.nearest, data.furthest)
		var guess := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
		var standing := Ground.closest_point(world, guess)
		if not Ground.is_spawnable(world, guess, player.global_position):
			continue
		if fallback == Vector3.INF:
			fallback = standing
		if camera == null or camera.is_position_in_frustum(standing + Vector3.UP * SEEN_AT):
			return standing
	return fallback


func _on_wave_started(wave: int, _enemies: int) -> void:
	take_away()
	_lands_in = -1.0
	if data == null or not data.lands_on(wave, _rng.randf()):
		return
	_lands_in = _rng.randf_range(data.lands_between.x, data.lands_between.y)


## The wave is over, and so is everything the bird had to give.
func _on_wave_cleared(_wave: int, _reward: int) -> void:
	_lands_in = -1.0
	take_away()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var frenzy := player.get("frenzy") as FrenzyComponent if player != null else null
	if frenzy != null:
		frenzy.stop()
