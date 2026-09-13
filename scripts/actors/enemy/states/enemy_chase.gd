class_name EnemyChase
extends EnemyState
## Closing the distance, around the island rather than through it.
##
## He faces where he is walking rather than where the player is. A body that strides sideways past a
## rock while staring over its shoulder is the clearest tell there is that a thing is being steered
## rather than moving; the facing that matters is the one he takes in WindUp.


func physics_update(delta: float) -> void:
	if enemy.data == null or enemy.target == null:
		enemy.apply_motion(Vector3.ZERO, 0.0, delta)
		return
	# On the way over, on his own clock. `VoiceComponent` is what decides he has been quiet long
	# enough; this only says he is walking towards you, which is the state the sound is about.
	if enemy.voice != null:
		enemy.voice.speak()
	var direction := enemy.path_direction(delta)
	enemy.apply_motion(direction, enemy.move_speed(), delta)
	enemy.face(direction, delta)
	if enemy.distance_to_target() > enemy.data.attack_range:
		return
	transition_to(&"WindUp" if enemy.claim_token() else &"Strafe")
