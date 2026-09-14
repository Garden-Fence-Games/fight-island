class_name EnemyFlee
extends EnemyState
## A runner, running: straight away from the player, slower than they walk, until it is caught — or
## until it reaches the sea deep enough to slip under and take its pay with it.
##
## **Away, not along a path.** The navigation mesh stops at the waterline, and the water is exactly
## where a runner is trying to get to, so it steers by the player's bearing rather than by a route.
## When something solid holds it — a boulder, a hut — it veers off to one side until it is moving
## again, rather than pressing into the rock for the rest of the wave.
##
## **Slipping under is not dying.** Nothing is thrown and nothing is paid: the body shrinks and
## sinks over `EliteRank.gone_over`, then goes back to the pool like a body sent home at the end of
## a wave.

## Below this share of its own speed, it counts as held by something.
const HELD_BELOW: float = 0.3
## How long it has to be held before it veers, and how far it veers, in radians.
const HELD_FOR: float = 0.35
const VEER: float = 1.1
## How far it sinks while it slips under, in metres.
const SINKS: float = 0.8
## The smallest share of its size it shrinks to before it is hidden.
const SMALLEST: float = 0.1

var _held: float = 0.0
var _veer: float = 0.0
var _going: float = -1.0


func enter(_message: Dictionary) -> void:
	_held = 0.0
	_veer = 0.0
	_going = -1.0


func physics_update(delta: float) -> void:
	var rank := enemy.rank
	if rank == null or enemy.target == null:
		enemy.apply_motion(Vector3.ZERO, 0.0, delta)
		return
	if _going >= 0.0:
		_slip_under(delta)
		return
	if Water.level - enemy.global_position.y >= rank.gone_at_depth:
		_begin_slipping_under()
		return
	var away := -enemy.direction_to_target()
	if away.is_zero_approx():
		away = -enemy.global_basis.z
	var heading := away.rotated(Vector3.UP, _veer)
	enemy.apply_motion(heading, enemy.move_speed(), delta)
	enemy.face(heading, delta)
	_notice_being_held(delta)


## Moving far slower than it is trying to means something solid is in the way. Veer, and keep the
## same side until it is free, so it walks round the rock instead of dithering at it.
func _notice_being_held(delta: float) -> void:
	var moving := Vector2(enemy.velocity.x, enemy.velocity.z).length()
	if moving >= enemy.move_speed() * HELD_BELOW:
		_held = 0.0
		_veer = move_toward(_veer, 0.0, delta)
		return
	_held += delta
	if _held < HELD_FOR:
		return
	_held = 0.0
	_veer = VEER if _veer >= 0.0 else -VEER


func _begin_slipping_under() -> void:
	_going = 0.0
	# Out of reach from here on: a blow landing on a body already going under would pay for a chase
	# the player lost.
	if enemy.hurtbox != null:
		enemy.hurtbox.set_deferred(&"monitorable", false)


func _slip_under(delta: float) -> void:
	_going += delta
	var share := clampf(_going / maxf(enemy.rank.gone_over, 0.01), 0.0, 1.0)
	enemy.velocity = Vector3.ZERO
	if enemy.visual != null:
		# Never to nothing: the ragdoll's bones hang off this node, and a scale of zero hands the
		# physics a transform it cannot invert. Small enough to be gone, then hidden.
		enemy.visual.scale = Vector3.ONE * enemy.rank.scale * maxf(1.0 - share, SMALLEST)
		enemy.visual.position.y = -SINKS * share
	if share < 1.0:
		return
	if enemy.visual != null:
		enemy.visual.position.y = 0.0
	enemy.retire()
