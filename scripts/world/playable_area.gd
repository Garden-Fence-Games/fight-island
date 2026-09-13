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
	_take_a_breath(delta)
	var limit := _water_level - wade_depth
	if _player.global_position.y >= limit:
		return
	var inward := global_position - _player.global_position
	inward.y = 0.0
	if inward.is_zero_approx():
		return
	var deeper := clampf((limit - _player.global_position.y) / wade_depth, 0.2, 1.5)
	_player.velocity.x = inward.normalized().x * push_speed * deeper
	_player.velocity.z = inward.normalized().z * push_speed * deeper
	_player.move_and_slide()


## The bar, while they are out there. Drained rather than damaged: see `HealthComponent.drain`.
##
## **There is no drowning clip and this does not fake one.** The body sinking is the terrain falling
## away under it, which is free and already true, and the read is the bar. When the clip lands, it
## plays where every other death animation does — this state ends the run through the same
## `died` signal and nothing here has to change.
func _take_a_breath(delta: float) -> void:
	if tide == null:
		return
	if _lungs == null:
		return
	var taken := tide.draining_at(_player.global_position.y, _water_level)
	if taken > 0.0:
		_lungs.drain(taken * delta)
