class_name EnemyDead
extends EnemyState
## He goes down the way he was hit, and he stays there.
##
## **He used to sink.** Two metres into the sand over a second and a half, and then the body went
## back to the pool and the island forgot him. A wave is a fight you win by killing everybody in it,
## and the evidence disappearing was the game quietly declining to say so.
##
## Now the physics takes the body, it lands, and what it looks like when it lands is handed to
## `CorpseField` — which keeps the picture and nothing else, so the pool gets its body back on the
## same schedule it always did. The pile is the record of the run.
##
## A body with no rig to throw still has to die, so there is a fallback: it waits out the same
## ceiling standing where it fell and is retired without leaving anything behind. A capsule, a
## headless check on a prototype scene, and a farmer whose skeleton failed to resolve all take it.

## How long a dying tumble may run before the body is taken back whether it has settled or not. The
## living have a per-blow figure for this because how long a man stays down is the blow's business;
## a dead man is not getting up, so one figure is enough.
const LONGEST_FALL: float = 2.5

var _elapsed: float = 0.0
var _laid: bool = false


func enter(_message: Dictionary) -> void:
	# Out of the group the moment he dies rather than when the body finishes falling: a wave is
	# cleared when the last enemy dies, and the living should not steer around a corpse.
	enemy.remove_from_group(&"enemies")
	if enemy.hitbox != null:
		enemy.hitbox.disarm()
	if enemy.hurtbox != null:
		enemy.hurtbox.monitorable = false
	enemy.set_collision_layer_value(PhysicsLayers.INDEX_ENEMY_BODY, false)
	_elapsed = 0.0
	_laid = false
	if enemy.voice != null:
		enemy.voice.hush()
	if enemy.ragdoll != null and enemy.ragdoll.is_ready():
		# The blow's own throw, not `knock_speed` whole. That figure is metres per second **per point
		# of stagger**, so passing it bare threw every dead man as hard as a blow of stagger one —
		# harder than anything in the game but the charged shot, whatever had actually killed him.
		enemy.ragdoll.knock(
			enemy.last_hit_from, enemy.last_hit_push * Enemy.KNOCKDOWN.knock_speed, LONGEST_FALL
		)


func physics_update(delta: float) -> void:
	_elapsed += delta
	var falling := enemy.ragdoll != null and enemy.ragdoll.is_running()
	if falling and _elapsed < LONGEST_FALL:
		return
	if not _laid:
		_laid = true
		# The pose has to be pinned into the skeleton before anything is copied off it. The
		# simulator is a modifier: its output reaches the skin but never the skeleton's own pose,
		# so a corpse read straight off the bones came out standing to attention — measured at
		# 2.38 m tall against 1.49 m across, which is how a body that is not lying down reads.
		if enemy.ragdoll != null:
			enemy.ragdoll.settle_pose()
		_lay_him_down()
	enemy.finish_dying()


## The picture, handed over before the pool resets the body. Nothing happens when there is no field
## in the scene, which is what a prototype arena and most of the headless checks are.
func _lay_him_down() -> void:
	var field := enemy.get_tree().get_first_node_in_group(&"corpses") as CorpseField
	if field != null:
		field.lay(enemy)
	if enemy.ragdoll != null:
		enemy.ragdoll.stop()
