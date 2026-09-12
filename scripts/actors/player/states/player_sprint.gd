class_name PlayerSprint
extends PlayerState


func physics_update(delta: float) -> void:
	var direction := player.move_direction()
	player.apply_motion(direction, Player.SPRINT_SPEED, delta)
	player.face(player.locomotion_facing(direction), delta)
	if player.stamina != null:
		player.stamina.drain(Player.SPRINT_DRAIN, delta)
	if try_common_transitions():
		return
	var out_of_breath := player.stamina != null and not player.stamina.has(0.1)
	if direction.is_zero_approx() or not player.wants_sprint() or out_of_breath:
		player.release_sprint()
		transition_to(&"Move")
