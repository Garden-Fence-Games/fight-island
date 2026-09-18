class_name EnemyStagger
extends EnemyState
## Knocked off his feet, and back on them.
##
## Two phases, and the animation follows them by name. **While the physics has the body the state
## names no clip at all** — a simulator and an AnimationPlayer both write bone poses, and the one
## that is not driving has no business fighting the one that is. Once the body settles, a get-up
## takes over.
##
## **Which get-up is the way he fell.** On his back he sits up and stands; on his front he rolls
## over first. The ragdoll is asked which before it lets go of the skeleton, and the body is turned
## so the clip's head lies where the ragdoll's head does — both clips start with the head along the
## body's own +Z, so that one yaw puts the first frame on top of the last thing the player saw.
##
## **Getting up takes as long as the clip.** `KnockdownData.rise_time` was the stand-in for a clip
## that did not exist, and it said so; now it only answers for a rig that carries neither.
##
## **Most hits never get here at all.** Only a blow that broke his poise sends him down; everything
## else is rocked where he stands, which is this state with no tumble in it. A hit that finds no rig
## to throw takes the same path, so a capsule, a headless check and a farmer whose skeleton failed
## to resolve all still work.

enum Phase { FALLING, RISING }

const GET_UP_BACK: StringName = &"get_up_back"
const GET_UP_FRONT: StringName = &"get_up_front"

var _phase: Phase = Phase.RISING
var _remaining: float = 0.0
var _clip: StringName = &""
## Where the hurtbox sits on a standing man, and how far above his feet its shape is centred. Both
## are read from the scene rather than written down here, so a rig whose chest moves takes its hit
## volume with it.
var _hurtbox_home := Vector3.ZERO
var _hurtbox_lift: float = 0.0


func enter(message: Dictionary) -> void:
	if enemy.hitbox != null:
		enemy.hitbox.disarm()
	_clip = &""
	_remaining = float(message.get("duration", 0.5))
	var push: float = float(message.get("push", 0.0)) * Enemy.KNOCKDOWN.knock_speed
	var from: Vector3 = message.get("from", Vector3.ZERO)
	var sprawling: bool = bool(message.get("sprawling", false))
	if not sprawling or push <= 0.0 or enemy.ragdoll == null or not enemy.ragdoll.is_ready():
		# Rocked where he stands. A get-up here would lie a standing man down to stand him up again.
		_phase = Phase.RISING
		return
	_phase = Phase.FALLING
	_remember_the_hurtbox()
	_rest_the_neck(true)
	if not enemy.ragdoll.came_to_rest.is_connected(_on_came_to_rest):
		enemy.ragdoll.came_to_rest.connect(_on_came_to_rest)
	enemy.ragdoll.knock(from, push, _remaining * Enemy.KNOCKDOWN.fall_ceiling)


## Whatever takes him out of here — a killing blow, a wave cleared, a body returned to the pool —
## has to hand the skeleton back, or it comes out of the pool still tumbling.
func exit() -> void:
	# Whatever takes him out of here — a kill, a wave cleared, a body pooled — must not leave the hit
	# volume parked somewhere in the world.
	_put_the_hurtbox_back()
	# A dead man's neck stays at rest: he is still falling, and a corpse turning its head to follow
	# the player is the one thing worse than a living man doing it lying down. `revive` wakes it.
	_rest_the_neck(not enemy.is_alive())
	# **A body on its way to `Dead` keeps its tumble.** Stopping here snapped a dying farmer upright
	# in the frame before the corpse was taken, so every one of them ended up standing in the pile.
	# The dead state owns the fall from that point and stops it when it lays him down.
	if enemy.ragdoll != null and enemy.ragdoll.is_running() and enemy.is_alive():
		enemy.ragdoll.stop()
	if enemy.ragdoll != null and enemy.ragdoll.came_to_rest.is_connected(_on_came_to_rest):
		enemy.ragdoll.came_to_rest.disconnect(_on_came_to_rest)


func physics_update(delta: float) -> void:
	if _phase == Phase.FALLING:
		# The body node is not what is moving — the bones are. Holding it still keeps the collider
		# and the navigation agent out of the way until the tumble picks a place to stop.
		enemy.apply_motion(Vector3.ZERO, 0.0, delta)
		# The hurtbox is a child of that pinned node, so it has to be carried by hand or the man is
		# hittable where he was standing and not where he is lying.
		_carry_the_hurtbox()
		return
	_remaining -= delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	if _remaining <= 0.0:
		transition_to(enemy.pursuit_state())


## Nothing while the physics drives, then the get-up for the way he landed.
func clip_name() -> StringName:
	return &"" if _phase == Phase.FALLING else _clip


## Straight onto the first frame. The ragdoll hands the skeleton back standing, so any crossfade
## would be a man springing upright and dropping flat again before he gets up.
func clip_blend() -> float:
	return 0.0


## The tumble is over. The body node catches up with where the hips actually ended, because that is
## where the player last saw him — leaving it where he was hit would teleport him back.
##
## Everything the ragdoll knows is read **before** `stop()`, which resets the bones to a standing
## man.
func _on_came_to_rest() -> void:
	if _phase != Phase.FALLING:
		return
	var landed := enemy.ragdoll.settled_position()
	var face_up := enemy.ragdoll.lies_face_up()
	var heading := enemy.ragdoll.settled_heading()
	enemy.ragdoll.stop()
	enemy.global_position = Vector3(landed.x, enemy.global_position.y, landed.z)
	# The body has caught up, so the hurtbox goes back to being an ordinary child of it.
	_put_the_hurtbox_back()
	# Both clips lie with the head along the body's +Z, and a yaw θ sends +Z to (sin θ, 0, cos θ).
	if not heading.is_zero_approx():
		enemy.rotation.y = atan2(heading.x, heading.z)
	_clip = GET_UP_BACK if face_up else GET_UP_FRONT
	_phase = Phase.RISING
	_remaining = _rise_time(_clip)
	# Re-asked rather than assumed: the state is the same, but what it wants played has changed.
	if enemy.animation != null:
		enemy.animation.refresh()


## The neck stops watching the player for as long as he is down, and picks it back up on his feet.
func _rest_the_neck(down: bool) -> void:
	if enemy.head_look != null:
		enemy.head_look.resting = down


## The clip's own length when the rig carries it, and the resource's stand-in when it does not.
func _rise_time(clip: StringName) -> float:
	var player := enemy.animation.animation_player if enemy.animation != null else null
	if player != null and player.has_animation(String(clip)):
		return player.get_animation(String(clip)).length
	return Enemy.KNOCKDOWN.rise_time


## The hurtbox's own transform, before the tumble starts moving it about.
func _remember_the_hurtbox() -> void:
	if enemy.hurtbox == null:
		return
	_hurtbox_home = enemy.hurtbox.position
	var shape := enemy.hurtbox.get_node_or_null(^"Shape") as Node3D
	_hurtbox_lift = shape.position.y if shape != null else 0.0


## Onto the hips, every physics frame the ragdoll is driving.
##
## The hips rather than the chest because a man on the ground has no chest height to speak of, and
## the hips are the bone the ragdoll reports for everything else — where he landed, which way he
## faces. Lowered by the shape's own offset so the capsule ends up **centred** on them rather than
## standing on them.
func _carry_the_hurtbox() -> void:
	if enemy.hurtbox == null or enemy.ragdoll == null or not enemy.ragdoll.is_running():
		return
	var hips := enemy.ragdoll.settled_position()
	enemy.hurtbox.global_position = Vector3(hips.x, hips.y - _hurtbox_lift, hips.z)


func _put_the_hurtbox_back() -> void:
	if enemy.hurtbox != null:
		enemy.hurtbox.position = _hurtbox_home
