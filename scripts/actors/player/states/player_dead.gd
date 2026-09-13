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
##
## **Except in the sea.** A player who dies out of their depth has nothing to fall against and no
## blow to be thrown by, so the ragdoll has nothing true to say: they struggle instead, the
## `drowning` loop, and sink while they do — the loop keeps turning until the body has gone all the
## way under, and `RunFlow` waits for that before the summary comes up. Out of depth is the tide's
## own rule, the depth at which the water starts taking the bar, so "drowned" means exactly what the
## bar already said.

## How hard the last blow throws them. The farmers' figure, because it is the same physics and a
## player thrown appreciably harder or softer than the men around them would read as a different
## game rule rather than as the same one.
const KNOCKDOWN: KnockdownData = preload("res://data/combat/knockdown.tres")
const TIDE: TideData = preload("res://data/combat/tide.tres")
const DROWNING_CLIP: StringName = &"drowning"
## The model, which is what sinks. The body stays where the physics has it: the camera follows the
## body, and a capsule pushed through the sea floor is a problem for nobody but the collision.
const MODEL: NodePath = ^"Visual"

var _laid: bool = false
var _drowned: bool = false
var _sunk: float = 0.0
var _model: Node3D = null


func enter(_message: Dictionary) -> void:
	player.close_chain()
	if player.hitbox != null:
		player.hitbox.disarm()
	_laid = false
	_sunk = 0.0
	# Decided here, before the machine announces the state, because `clip_name` is asked right after.
	_drowned = is_out_of_depth(player.global_position.y)
	if _drowned:
		_model = player.get_node_or_null(MODEL) as Node3D
		# The head is thrown back in the clip; one still following the aim would undo it.
		if player.head_look != null:
			player.head_look.resting = true
		return
	if player.ragdoll != null and player.ragdoll.is_ready():
		# The fall has to be over before the summary covers it. `RunFlow` waits exactly this long
		# before it pauses the tree, and a tree paused mid-tumble leaves a body hanging in the air
		# behind the screen that says the run ended.
		player.ragdoll.knock(
			player.last_hit_from, player.last_hit_push * KNOCKDOWN.knock_speed, RunFlow.DELAY
		)


func physics_update(delta: float) -> void:
	player.halt(delta)
	if _drowned:
		_sink(delta)
		return
	if _laid or player.ragdoll == null or player.ragdoll.is_running():
		return
	_laid = true
	# The simulator is a modifier: its output reaches the skin but never the skeleton's own pose.
	# Without this the body is lying down only for as long as nothing asks the skeleton what it
	# looks like — and the first thing that does gets a man standing to attention.
	player.ragdoll.settle_pose()


## The drowning loop when the sea took them, and nothing otherwise — the ragdoll has the body.
func clip_name() -> StringName:
	return DROWNING_CLIP if _drowned else &""


## Whether a drowned body is still on its way under. `RunFlow` holds the summary back until it is
## not.
func is_sinking() -> bool:
	return _drowned and _sunk < TIDE.sink_depth


## How far under a drowned body has gone, in metres.
func sunk() -> float:
	return _sunk


## Whether a body standing at `height` is where the water takes the bar. Static so the check can ask
## it without a player.
static func is_out_of_depth(height: float) -> bool:
	return TIDE != null and TIDE.draining_at(height, Water.level) > 0.0


func _sink(delta: float) -> void:
	if _model == null or not is_sinking():
		return
	var step := minf(TIDE.sink_speed * delta, TIDE.sink_depth - _sunk)
	_sunk += step
	_model.position.y -= step
	if is_sinking():
		return
	# All the way under: the struggle is over, and nothing is left to see of it.
	_model.visible = false
	if player.animation != null and player.animation.animation_player != null:
		player.animation.animation_player.stop()
