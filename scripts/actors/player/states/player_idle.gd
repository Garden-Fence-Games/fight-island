class_name PlayerIdle
extends PlayerState
## Standing still is not standing frozen: a player who is aiming keeps turning to track what they
## are pointing at, which is the difference between waiting and covering.


func physics_update(delta: float) -> void:
	player.halt(delta)
	player.face(player.look_direction(Vector3.ZERO), delta)
	if try_common_transitions():
		return
	if not player.move_direction().is_zero_approx():
		transition_to(&"Move")
