class_name PlayableArea
extends Node3D
## Keeps the player on the island by the waterline rather than by a radius.
##
## The island is not round, so a circle would either fence off half the beach or let the player
## swim away on the other side. Depth is the honest boundary: walk down the sand, wade in to the
## shins, and the sea pushes back. Nothing is ever blocked, so the edge of the world is felt as
## the shape of the place.

## How deep anyone may wade before the sea pushes back, measured from the water plane.
const WADE_DEPTH: float = 1.1

@export var wade_depth: float = WADE_DEPTH
@export var push_speed: float = 5.0

var _water_level: float = -1.1
var _player: CharacterBody3D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	var water := get_parent().get_node_or_null(^"Water") as Node3D
	if water != null:
		_water_level = water.position.y
	Water.level = _water_level


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
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
