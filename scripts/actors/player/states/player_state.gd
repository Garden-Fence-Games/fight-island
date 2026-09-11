class_name PlayerState
extends State
## Shared vocabulary for the player's states: the body, and the transitions every ground state
## offers so none of them has to remember the whole list.

const DODGE_COST: float = 22.0
const PARRY_COST: float = 10.0

var player: Player = null


func _ready() -> void:
	player = owner as Player


## The interrupts a grounded, non-committed state always accepts, in priority order.
func try_common_transitions() -> bool:
	if player.stamina != null and Input.is_action_just_pressed(&"dodge"):
		if player.stamina.try_spend(DODGE_COST):
			transition_to(&"Dodge")
			return true
	if player.stamina != null and Input.is_action_just_pressed(&"parry"):
		if player.stamina.try_spend(PARRY_COST):
			transition_to(&"Parry")
			return true
	var queued := player.take_attack_input()
	if not queued.is_empty():
		transition_to(&"Attack", queued)
		return true
	return false
