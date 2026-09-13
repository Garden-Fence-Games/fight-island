class_name EnemyWindUp
extends EnemyState
## The telegraph. It shortens as waves go on but never past its floor, because a wind-up nobody
## can read is noise, not difficulty.
##
## **He rears back.** The ring that used to fill on the ground is gone (#122), and the clip meant to
## replace it needs a rig the farmhand does not have yet — so the tell is the body itself: it tips
## backwards over the wind-up and snaps forward on the swing.
##
## That is not a placeholder for the clip so much as the same thing done with what exists. What the
## ring had to satisfy, this satisfies:
##
## - **A shape, not a colour.** It is geometry, so it survives greyscale, a colourblind player and a
##   camera twenty metres up — and it needs no accessibility switch to do it.
## - **The same tell for every archetype.** One lean, whoever is throwing it. A signal per farmer is
##   one more thing to learn in the half second there is to read it.
## - **Driven by the wind-up's own duration**, which is not a constant: the waves shorten it and the
##   hour shortens it again. The lean is a share of `enemy.windup()` rather than a clip playing at
##   its own rate, so the picture and the timing cannot drift apart. When the rig lands, the same
##   share hands straight to `AnimationComponent.play_clip(clip, seconds)`.
##
## Which leaves the sound as the other half of the telegraph rather than the whole of it. It is
## announced from here because this is the one place that knows a body has committed and where it is
## standing, and it is announced on the bus rather than played here because a state machine has no
## business knowing the game has audio in it.

## How far the body tips back, in degrees, at the moment the swing begins. Large on purpose: the top
## of the body sits 1.105 m above its own origin, so even this only swings the silhouette about half
## a metre — which against a body 0.7 m wide is the difference between "standing" and "loaded", and
## is what has to carry at twenty metres.
const LEAN_DEGREES: float = 35.0
## Which way a positive rotation tips the rig. **The visual is parented yawed 180°** — glTF faces
## +Z and a Node3D's forward is -Z — so turning it about its own X axis tips the top the opposite
## way round from the capsule this replaced. Rearing back is the negative of it, and this is the
## one place that difference is written down: `verify_vfx` reads the lean back through it.
const REARS_BACK: float = -1.0

var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	EventBus.telegraph_began.emit(enemy.global_position, enemy.data)


## Whatever ends the wind-up — the swing, a stagger, a death — stands the body back up. A farmer
## left leaning is the same lie the ring told when it outlived the commit it was drawn for.
func exit() -> void:
	if enemy.visual != null:
		enemy.visual.rotation.x = 0.0


## The telegraph's own clip, asked for by the animation component rather than looked up in its
## table: which one it is belongs to the archetype, and one state drives all three.
func clip_name() -> StringName:
	var attack := enemy.data.attack if enemy.data != null else null
	return attack.windup_animation if attack != null else &""


## As long as this wind-up actually lasts, which is not a constant — the waves shorten it and the
## hour shortens it again. The same share the lean is driven by, handed to the clip, so the body
## and the arm cannot tell the player two different things about how much time is left.
func clip_duration() -> float:
	return enemy.windup()


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	enemy.face_target(delta * 0.4)
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null:
		transition_to(&"Idle")
		return
	_lean(_elapsed / maxf(enemy.windup(), 0.001))
	if _elapsed >= enemy.windup():
		transition_to(&"Attack")


## Straight in, not eased. The whole use of the picture is telling the player *when*, so how far the
## body has tipped has to map to how much time is left — an ease would hold it upright and then rush
## it, which reads as a shorter wind-up than the one being fought.
##
## A Node3D's forward is -Z, so tipping the top towards +Z is tipping it backwards, away from
## whoever is about to be hit. Only the rotation is touched: the scale belongs to the elite rank and
## the position to the scene, and a tell that fought either would be a tell that broke them.
func _lean(through: float) -> void:
	if enemy.visual == null:
		return
	enemy.visual.rotation.x = REARS_BACK * deg_to_rad(LEAN_DEGREES) * clampf(through, 0.0, 1.0)
