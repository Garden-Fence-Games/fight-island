class_name PlayerMove
extends PlayerState


func physics_update(delta: float) -> void:
	var direction := player.move_direction()
	player.apply_motion(direction, Player.MOVE_SPEED, delta)
	player.face(player.locomotion_facing(direction), delta)
	if try_common_transitions():
		return
	if direction.is_zero_approx():
		transition_to(&"Idle")
		return
	var can_sprint := player.stamina != null and player.stamina.has(Player.SPRINT_MINIMUM)
	if player.wants_sprint() and can_sprint:
		transition_to(&"Sprint")
