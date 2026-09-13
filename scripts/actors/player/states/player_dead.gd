class_name PlayerDead
extends PlayerState
## The run ends and the body goes down the way it was hit.
##
## **It is physics rather than a clip, and that is a decision rather than a stopgap.** The rig has
## no `death` and the farmers have had a ragdoll since they stopped sinking into the sand; giving
## the player the same one means a death that agrees with where they were standing, which way the
## blow came from and what they fell against. A clip could not do the last of those.
##
## Nothing here takes the body back. There is nothing to take it back for — `AnimationComponent`
## refuses to touch a rig the simulator is driving, so the body stays where it landed under the
## screen that says the run is over.

## How hard the last blow throws them. The farmers' figure, because it is the same physics and a
## player thrown appreciably harder or softer than the men around them would read as a different
## game rule rather than as the same one.
const KNOCKDOWN: KnockdownData = preload("res://data/combat/knockdown.tres")

var _laid: bool = false


func enter(_message: Dictionary) -> void:
	player.close_chain()
	if player.hitbox != null:
		player.hitbox.disarm()
	_laid = false
	if player.ragdoll != null and player.ragdoll.is_ready():
		# The fall has to be over before the summary covers it. `RunFlow` waits exactly this long
		# before it pauses the tree, and a tree paused mid-tumble leaves a body hanging in the air
		# behind the screen that says the run ended.
		player.ragdoll.knock(
			player.last_hit_from, player.last_hit_push * KNOCKDOWN.knock_speed, RunFlow.DELAY
		)


func physics_update(delta: float) -> void:
	player.halt(delta)
	if _laid or player.ragdoll == null or player.ragdoll.is_running():
		return
	_laid = true
	# The simulator is a modifier: its output reaches the skin but never the skeleton's own pose.
	# Without this the body is lying down only for as long as nothing asks the skeleton what it
	# looks like — and the first thing that does gets a man standing to attention.
	player.ragdoll.settle_pose()
