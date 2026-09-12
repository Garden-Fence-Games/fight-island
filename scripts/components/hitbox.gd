class_name Hitbox
extends Area3D
## The active half: monitoring, never monitorable, and disabled at rest. In M1 the owning state
## arms it for the active frames; from the art phase an animation call-method track does it
## instead, through the same two methods.

signal landed(target: Node3D, info: HitInfo)

## How far past the attack's reach a body still counts as hit. Reach is measured centre to centre
## and a body is not a point, so without this a farmer standing with his shoulder inside the swing
## is missed. Half a body, which is what the player is wide.
const BODY_ALLOWANCE: float = 0.4
## Closer than this, direction stops meaning anything — the angle between two bodies overlapping
## each other is noise, and someone standing on top of you is inside any swing there is.
const POINT_BLANK: float = 0.5

var attack: AttackData = null
var source: Node3D = null
var perfect: bool = false
## What the wave does to this attack. On the hitbox rather than on the AttackData because the data
## is one shared resource: scaling it would scale it for everyone, permanently.
var damage_scale: float = 1.0
## What the stick upgrade does to the swing — the reach and the arc together, because the track
## buys both. Not an argument to `arm` because only the player ever moves it, and a parameter on
## every call site to say "unchanged" is noise.
var reach_scale: float = 1.0

var _already_hit: Array[int] = []

@onready var shape: CollisionShape3D = $Shape


func _ready() -> void:
	monitoring = true
	monitorable = false
	if shape != null:
		shape.disabled = true


func arm(
	from_attack: AttackData, from_source: Node3D, was_perfect: bool, scale_damage: float = 1.0
) -> void:
	attack = from_attack
	source = from_source
	perfect = was_perfect
	damage_scale = scale_damage
	_already_hit.clear()
	if shape == null:
		return
	_fit_to(from_attack)
	shape.disabled = false


## The broad phase, and only that: a box around the attacker big enough to hold every point the
## swing could reach. `_within_the_swing` cuts it down to the reach and the arc.
##
## It used to be the shape itself — a rectangle from the attacker's nose out to its reach — and it
## was wrong at both ends. Its corners reached half again the weapon's length, and because it ran
## from `z = 0` backwards it also **clipped the arc short of its own angle**: nothing beyond about
## sixty degrees could ever be inside it, so a 160° sweep was never 160°. Whichever way that box was
## sized, the number in `arc_degrees` was not the number the player felt.
func _fit_to(from_attack: AttackData) -> void:
	var box := shape.shape as BoxShape3D
	if box == null:
		return
	var span := maxf(from_attack.reach * reach_scale + BODY_ALLOWANCE, 0.2)
	box.size = Vector3(span * 2.0, 1.2, span * 2.0)
	shape.position = Vector3(0.0, 1.0, 0.0)


func disarm() -> void:
	if shape != null:
		shape.disabled = true
	_already_hit.clear()


## Whether a contact is really inside the swing, rather than merely inside the box that approximates
## it.
##
## The box cannot be the whole answer, and the reaper is the proof. A 160° arc on a 2.8 m weapon
## becomes a rectangle 5.5 m wide whose corners reach 3.9 m — nearly half again the weapon's own
## length, and in exactly the direction the character is built around. Confirming against the reach
## and the angle themselves is what makes `arc_degrees` mean what it says for every weapon in the
## game rather than only for the narrow ones, where a box happens to be close enough.
##
## Not entered into `_already_hit`, so a body the swing misses this frame can still be caught later
## in the same swing as it moves across the arc.
func _within_the_swing(hurtbox: Hurtbox) -> bool:
	if attack == null or source == null:
		return true
	var offset := hurtbox.global_position - source.global_position
	offset.y = 0.0
	var apart := offset.length()
	if apart > attack.reach * reach_scale + BODY_ALLOWANCE:
		return false
	if apart <= POINT_BLANK:
		return true
	var forward := -source.global_transform.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return true
	var away := rad_to_deg(forward.normalized().angle_to(offset / apart))
	return away <= minf(attack.arc_degrees * reach_scale, 360.0) * 0.5


func _physics_process(_delta: float) -> void:
	if shape == null or shape.disabled or attack == null:
		return
	for area: Area3D in get_overlapping_areas():
		_try_hit(area)


func _try_hit(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null:
		return
	var id := hurtbox.get_instance_id()
	if _already_hit.has(id):
		return
	if not _within_the_swing(hurtbox):
		return
	_already_hit.append(id)
	var info := HitInfo.new(attack, source, perfect, damage_scale)
	if hurtbox.take_hit(info):
		landed.emit(hurtbox.owner, info)
