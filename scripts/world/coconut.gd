class_name Coconut
extends Area3D
## One coconut: out of a palm, into the sand, and gone again whether or not anyone came for it.
##
## **Walked over, not pressed.** The weapon pickups ask for `interact`, and that is right for them —
## taking a gun is a decision, and it happens between the fighting as often as during it. A coconut
## is the opposite: it exists to be grabbed in the middle of a crowd, and a button prompt in that
## moment is a window where the player is committed to something other than the fight. So contact is
## enough.
##
## **And only when it is worth something.** Walking over one at full health leaves it lying. The
## alternative is a player crossing the island for a coconut they cannot use and losing it by
## stepping on it, which is the kind of rule nobody reads as a rule — they read it as the game
## taking something away.
##
## It is takeable **only once it has landed.** In the air it is an object falling out of a tree, and
## a player who happened to be standing under the palm catching one at head height is not what "it
## fell from a palm" is meant to mean.

## Turns per second while it lies there — the same trick the weapon pickups use to keep a thing on
## the ground from reading as scenery, at a fraction of the speed because a coconut is not a prize.
const SPIN: float = 0.6
## How long it spends fading out at the end of its life, inside `lies_for` rather than after it. A
## coconut that vanished between frames reads as a bug; one that has visibly been going for a second
## reads as a chance that was missed.
const FADES_FOR: float = 1.2

var data: CoconutData = null
## The foot of the palm it came out of. Kept because it is the claim this whole thing makes — a
## coconut that fell from a tree — and a claim nothing can read is a claim nothing can check. With
## three hundred and eighty palms on the island, *some* palm is always a metre or two away; the only
## question worth asking is whether it is **this** one.
var fell_from: Vector3 = Vector3.ZERO

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _falling: float = 0.0
var _landed: bool = false
var _lying_for: float = 0.0

@onready var view: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D


func _ready() -> void:
	monitoring = false
	monitorable = false


## Which palm it leaves and where it lands. Called before it enters the tree so nothing is ever seen
## at the origin for a frame on its way to the palm it fell out of. The crown is worked out here
## rather than handed in, so where a coconut leaves a tree is decided in one place.
func drop_from(palm: Transform3D, sand: Vector3) -> void:
	fell_from = palm.origin
	_from = PalmGrove.crown_of(palm)
	_to = sand
	global_position = _from


func _physics_process(delta: float) -> void:
	if not _landed:
		_fall(delta)
		return
	_lying_for += delta
	if _lying_for >= _lies_for():
		queue_free()
		return
	_fade()
	if monitoring:
		_take_if_it_is_worth_taking()


func _process(delta: float) -> void:
	rotate_y(SPIN * delta)


## Accelerating rather than linear, because a coconut does not descend. The curve is the square of
## the elapsed share, which is what falling under gravity is, and it costs nothing to be right.
func _fall(delta: float) -> void:
	_falling += delta
	var over := _falls_for()
	var share := clampf(_falling / over, 0.0, 1.0)
	global_position = _from.lerp(_to, share * share)
	if share < 1.0:
		return
	_landed = true
	global_position = _to
	monitoring = true


## Taken only by a player who is hurt, and clamped so it can never overfill the bar. A coconut that
## could take somebody past their maximum would be a second, quieter version of the Health track.
func _take_if_it_is_worth_taking() -> void:
	for body: Node3D in get_overlapping_bodies():
		if not body.is_in_group(&"player"):
			continue
		var health := body.get("health") as HealthComponent
		if health == null or not health.is_alive():
			continue
		if health.current_health >= health.max_health:
			continue
		health.heal(_heals())
		queue_free()
		return


func _fade() -> void:
	if view == null:
		return
	var left := _lies_for() - _lying_for
	if left > FADES_FOR:
		return
	var material := view.get_surface_override_material(0)
	if material != null:
		material.albedo_color.a = clampf(left / FADES_FOR, 0.0, 1.0)


func _heals() -> float:
	return data.heals if data != null else 0.0


func _lies_for() -> float:
	return data.lies_for if data != null else 1.0


func _falls_for() -> float:
	return maxf(data.falls_for, 0.01) if data != null else 0.01
