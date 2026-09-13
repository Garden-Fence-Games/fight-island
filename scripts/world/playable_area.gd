class_name PlayableArea
extends Node3D
## Keeps the player on the island by the waterline rather than by a radius.
##
## The island is not round, so a circle would either fence off half the beach or let the player
## swim away on the other side. Depth is the honest boundary: walk down the sand, wade in to the
## shins, and the sea pushes back. Nothing is ever blocked, so the edge of the world is felt as
## the shape of the place.
##
## **And the boundary has a price now.** The push alone was a wall the player bounced off: it wins
## against a walk before the water is over a head, so nobody could ever reach anything. Past the
## wading limit the bar comes down, faster the deeper they are, and a player who keeps walking out
## against the sea drowns. Every point of it is reversible — stop pushing and the sea carries them
## back in — so the only way to die out there is to insist for five seconds while watching it
## happen. See `TideData` for the figures.

## How deep anyone may wade before the sea pushes back, measured from the water plane.
const WADE_DEPTH: float = 1.1

@export var wade_depth: float = WADE_DEPTH
@export var push_speed: float = 5.0
## What the water costs to stand in. Preloaded rather than exported: there is one sea.
@export var tide: TideData = preload("res://data/combat/tide.tres")

var _water_level: float = -1.1
var _player: CharacterBody3D = null
## Found once beside the player, never per frame: a path lookup in a body that runs sixty times a
## second is a silent dependency on a scene's shape, and the day it returns null it does so sixty
## times a second in the middle of a fight.
var _lungs: HealthComponent = null
## How long the player has been walking out against the push, without a break. See
## `TideData.forcing_multiplier`.
var _forcing_seconds: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if _player != null:
		_lungs = _player.get_node_or_null(^"Health") as HealthComponent
	var water := get_parent().get_node_or_null(^"Water") as Node3D
	if water != null:
		_water_level = water.position.y
	Water.level = _water_level


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# A drowned player stays where the sea took them, struggling; carried back to the sand under the
	# summary, the last thing seen would be a dead man gliding up the beach.
	if _player.has_method("is_alive") and not bool(_player.call("is_alive")):
		return
	var limit := _water_level - wade_depth
	var inward := global_position - _player.global_position
	inward.y = 0.0
	_forcing_seconds = (_forcing_seconds + delta) if _is_forcing(limit, inward) else 0.0
	_take_a_breath(delta)
	if _player.global_position.y >= limit:
		return
	if inward.is_zero_approx():
		return
	var deeper := clampf((limit - _player.global_position.y) / wade_depth, 0.2, 1.5)
	_player.velocity.x = inward.normalized().x * push_speed * deeper
	_player.velocity.z = inward.normalized().z * push_speed * deeper
	_player.move_and_slide()


## The bar, while they are out there. Drained rather than damaged: see `HealthComponent.drain`.
##
## The body sinking is the terrain falling away under it, which is free and already true, and the
## read is the bar. The death itself is `PlayerDead`'s: the run ends through the same `died` signal
## as any other, and a player who dies out of depth plays the `drowning` loop there.
func _take_a_breath(delta: float) -> void:
	if tide == null:
		return
	if _lungs == null:
		return
	var taken := tide.draining_at(_player.global_position.y, _water_level)
	if taken > 0.0:
		_lungs.drain(taken * tide.forcing_multiplier(_forcing_seconds) * delta)


## How long the current push out to sea has lasted, for the headless check.
func forcing_seconds() -> float:
	return _forcing_seconds


## Walking out against the push: in the water the sea shoves back from, and heading out to sea
## rather than along the shore or back in.
func _is_forcing(limit: float, inward: Vector3) -> bool:
	if tide == null or _player.global_position.y >= limit or inward.is_zero_approx():
		return false
	if not _player.has_method("move_direction"):
		return false
	var heading := _player.call("move_direction") as Vector3
	heading.y = 0.0
	if heading.is_zero_approx():
		return false
	return heading.normalized().dot(-inward.normalized()) >= tide.forcing_alignment
