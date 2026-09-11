class_name PlayerIdle
extends PlayerState


func physics_update(delta: float) -> void:
	player.halt(delta)
	if try_common_transitions():
		return
	if not player.move_direction().is_zero_approx():
		transition_to(&"Move")
