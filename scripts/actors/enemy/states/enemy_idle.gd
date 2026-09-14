class_name EnemyIdle
extends EnemyState
## Standing where he was put, until the fight comes to him — or until he has been ignored long
## enough to come looking.
##
## A wave whose every body is closing from the moment it appears reads as one flat press. What makes
## it a fight is that some of it is still waiting — so the player can see a farmer before the farmer
## sees them, and distance carries information again.
##
## **But waiting for ever is not a fight either.** A body that nobody walks up to stands there for
## the whole wave, and a player who wants one has to go and get it: on a four-minute wave with a
## dozen bodies spread around them, that is most of the wave spent walking. So the waiting is a
## grace period rather than a state — long enough to be read, short enough that the island always
## comes to the player in the end.

## How long a body stands unnoticed before it notices anyway.
##
## Divided by the hour's rousing, which is the dial that already says how quickly the island turns
## on the player: in daylight it is this, after dark it is half of it. Night does not merely carry
## further, it also waits less — and that is the same sentence the design already makes about
## rousing, applied to the one thing it had not reached.
const PATIENCE: float = 10.0

var _ignored: float = 0.0


func enter(_message: Dictionary) -> void:
	_ignored = 0.0


func physics_update(delta: float) -> void:
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	# A runner waits for its own eyes and nothing else: no patience, and a crowd that noticed the
	# fight does not send it running — only the player coming close does, or a blow.
	if enemy.rank != null:
		if enemy.notices_target():
			enemy.rouse()
			transition_to(enemy.pursuit_state())
		return
	if enemy.roused:
		transition_to(&"Chase")
		return
	_ignored += delta
	if enemy.notices_target() or _ignored >= PATIENCE / maxf(GameState.rouse_scale(), 0.01):
		# Through rouse() rather than straight to Chase, so the farmers beside him come too.
		enemy.rouse()
		transition_to(&"Chase")
