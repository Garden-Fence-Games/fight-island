class_name Bird
extends Node3D
## One bird: on the sand until something comes near, then gone.
##
## Decoration, and nothing else. No collider, no navigation, no group, nothing combat can touch —
## a wave director that had to step around a seagull would be paying for scenery.
##
## **The flight is code, not a clip.** `bird_fly` is not on the model yet; when it is, it plays here
## and nothing else changes, because what moves the body is this script either way. A bird that
## waited for its animation would be a bird standing still in the sky.
##
## **Plain integers rather than an enum**, and that is not laziness. A `class_name` script cannot
## assign its own enum to a variable declared with that enum's bare name — GDScript resolves the
## value as `Bird.State` and the declaration as `State`, and refuses the two as different types. The
## same mismatch makes `bird.state == Bird.State.GROUNDED` a parse error from anywhere else. Three
## constants and two predicates cost nothing and cannot go wrong.
const GROUNDED: int = 0
const FLYING: int = 1
const LEAVING: int = 2

## Played while airborne, the day the model carries it. Missing is the ordinary case for now and
## costs nothing: the wings simply do not beat.
@export var fly_clip: StringName = &"bird_fly"
## How fast it climbs away once startled, and how fast it travels while doing it.
@export var flee_climb: float = 3.6
@export var flee_speed: float = 7.5
## A bird on the wing drifts rather than holds station — a fixed point in the sky reads as a prop.
@export var cruise_speed: float = 2.4
## Gone once it is this far above where it started. Freed rather than faded: nothing up there is
## worth a draw call.
@export var vanish_height: float = 22.0

var _state: int = GROUNDED
var _heading: Vector3 = Vector3.FORWARD
## The height it was put down at, which the bob oscillates around and the climb is measured from.
## NAN until it is first needed rather than read in `_ready`: whoever spawns the bird parents it
## before placing it, so at `_ready` it is still standing at the origin — and since the bob *writes*
## `position.y`, a zero recorded here dragged every ground bird down to sea level.
var _started_at: float = NAN
var _bob: float = 0.0


func _ready() -> void:
	_bob = randf() * TAU
	if _heading.is_equal_approx(Vector3.FORWARD):
		_heading = Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()
	if _state == FLYING:
		_play_flight()
	_face(_heading)


func is_grounded() -> bool:
	return _state == GROUNDED


func is_flying() -> bool:
	return _state == FLYING


## Sets the bird going before it enters the tree, so a flock can place it without a frame of it
## sitting in the wrong state.
func launch(on_the_ground: bool, heading: Vector3) -> void:
	_state = GROUNDED if on_the_ground else FLYING
	if not heading.is_zero_approx():
		_heading = heading.normalized()


## Something came too close. Everything from here is one way: it climbs, it leaves, it is freed.
func startle(away_from: Vector3) -> void:
	if _state == LEAVING:
		return
	_anchor()
	_state = LEAVING
	var escape := global_position - away_from
	escape.y = 0.0
	# A bird startled from directly overhead has nowhere to run, so it takes the way it was facing.
	_heading = escape.normalized() if not escape.is_zero_approx() else _heading
	_face(_heading)
	_play_flight()


func _process(delta: float) -> void:
	_anchor()
	if _state == GROUNDED:
		# Alive rather than placed: a couple of centimetres of breathing is the whole difference
		# between a bird and a rock shaped like one.
		_bob += delta * 1.7
		position.y = _started_at + sin(_bob) * 0.02
		return
	if _state == FLYING:
		_heading = _heading.rotated(Vector3.UP, delta * 0.35).normalized()
		global_position += _heading * cruise_speed * delta
		_face(_heading)
		return
	global_position += (_heading * flee_speed + Vector3.UP * flee_climb) * delta
	_face(_heading)
	if global_position.y - _started_at > vanish_height:
		queue_free()


## Takes the height it is standing at as its own, the first time anything asks.
func _anchor() -> void:
	if is_nan(_started_at):
		_started_at = global_position.y


## Flat: a bird that pitched towards its climb would need a clip to sell it, and it has none yet.
func _face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx():
		return
	rotation.y = atan2(-flat.x, -flat.z)


func _play_flight() -> void:
	for node: Node in find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player != null and player.has_animation(String(fly_clip)):
			player.play(String(fly_clip))
			return
