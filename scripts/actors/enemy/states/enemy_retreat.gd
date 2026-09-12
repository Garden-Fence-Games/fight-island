class_name EnemyRetreat
extends EnemyState
## Backing away, which is the whole of the thrower.
##
## He is what stops the player picking one corner and holding it: a body that will not be closed
## with has to be gone to. He never stops moving and he never commits, so the answer to him is
## either the gun or crossing the ground — and that is the choice the island is there to make
## interesting.
##
## He faces the player while he goes. A thrower walking backwards looking over his shoulder reads as
## retreating; one that turns and runs reads as fleeing, which is a different thing entirely and
## would make him look beaten rather than patient.

## How far past his retreat range he backs off before turning to fight again. Without the margin he
## sits exactly on the line, flipping between backing away and winding up every other frame.
const BREATHING_ROOM: float = 1.5


func enter(_message: Dictionary) -> void:
	# A body walking backwards is not committing to anything, and a held token would keep a second
	# thrower waiting for a turn that is not coming.
	enemy.release_token()


func physics_update(delta: float) -> void:
	if enemy.data == null or enemy.target == null:
		enemy.apply_motion(Vector3.ZERO, 0.0, delta)
		return
	enemy.apply_motion(-enemy.direction_to_target(), enemy.move_speed(), delta)
	enemy.face_target(delta)
	if enemy.distance_to_target() >= enemy.data.retreat_range + BREATHING_ROOM:
		transition_to(&"Chase")
