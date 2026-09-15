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
## **It glows, and that is not decoration.** A coconut is a fourteen-centimetre sphere of brown, on
## sand, under brown palm trunks, between ten and twenty metres from a fixed camera, through a
## pixel-art filter that quantises the frame to fat pixels. Measured on a real frame it was not
## findable — the thing worked perfectly and no player would ever have known it existed. So it
## carries its own light — **on the coconut, not around it**. An emissive body with a lit rim, and a
## small lamp that spills onto the sand it is lying on, both breathing together. A billboard behind
## it was the first attempt and it read as exactly what it was: a square.
##
## It is takeable **only once it has landed.** In the air it is an object falling out of a tree, and
## a player who happened to be standing under the palm catching one at head height is not what "it
## fell from a palm" is meant to mean.

## Turns per second while it lies there — the same trick the weapon pickups use to keep a thing on
## the ground from reading as scenery, at a fraction of the speed because a coconut is not a prize.
const SPIN: float = 0.6
## How fast the halo breathes, in cycles a second, and how far either side of its own size it goes.
## Slow and shallow: a pulse fast enough to read as an alarm competes with a wind-up, and nothing in
## this game is allowed to do that.
const PULSE_HZ: float = 0.8
const PULSE_DEPTH: float = 0.16
## What the light and the body sit at when the breath is at rest. Kept here rather than read off the
## scene, so the pulse has something to return to that a later edit of the material cannot drift.
const LAMP_ENERGY: float = 2.4
const GLOW_ENERGY: float = 0.55
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
## Where it will come to rest. Public because **where it ends up is the only position worth asking
## about**: for its first second it is at the crown of the palm, five metres up, and a check that
## read `global_position` there was judging the framing of the tree's canopy.
var lands_at: Vector3 = Vector3.ZERO

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _falling: float = 0.0
var _landed: bool = false
var _lying_for: float = 0.0
var _pulsing: float = 0.0
## How much of the glow is left as the coconut rots away. Kept rather than written straight onto the
## light: the pulse writes the same property from `_process`, the physics step runs first, and the
## last writer of a frame is the one the eye gets — so a fade that set the light directly was
## overwritten before anything was drawn and the light never dimmed at all.
var _dimming: float = 1.0

@onready var view: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var lamp: OmniLight3D = get_node_or_null("Glow") as OmniLight3D


func _ready() -> void:
	monitoring = false
	monitorable = false


## Which palm it leaves and where it lands. Called **once it is in the tree**, because a global
## position written before that is discarded by the engine. The crown is worked out here rather than
## handed in, so where a coconut leaves a tree is decided in one place.
func drop_from(palm: Transform3D, sand: Vector3) -> void:
	fell_from = palm.origin
	lands_at = sand
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
	_breathe(delta)


## The light, swelling and settling. Brightness rather than size: a thing that changes size reads as
## coming closer, and this one is lying still in the sand.
func _breathe(delta: float) -> void:
	_pulsing = fposmod(_pulsing + delta * PULSE_HZ, 1.0)
	var swell := 1.0 + sin(_pulsing * TAU) * PULSE_DEPTH
	if lamp != null:
		lamp.light_energy = LAMP_ENERGY * swell * _dimming
	var material := view.get_surface_override_material(0) if view != null else null
	if material != null:
		material.emission_energy_multiplier = GLOW_ENERGY * swell * _dimming


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
		var given := health.heal(_heals())
		# Announced rather than shown here: the feed at the bottom of the screen already words every
		# other thing the player picks up, and a coconut that reported itself its own way would be a
		# second voice saying the same kind of sentence.
		EventBus.coconut_taken.emit(given)
		queue_free()
		return


## Both the body and its light go together at the end. A halo that outlived the thing it was
## pointing at would be a light over nothing, which reads as a bug rather than as a chance missed.
func _fade() -> void:
	var left := _lies_for() - _lying_for
	if left > FADES_FOR:
		return
	var share := clampf(left / FADES_FOR, 0.0, 1.0)
	if view != null:
		var material := view.get_surface_override_material(0)
		if material != null:
			material.albedo_color.a = share
	# Handed to the pulse rather than written here — see `_dimming`.
	_dimming = share


func _heals() -> float:
	return data.heals if data != null else 0.0


func _lies_for() -> float:
	return data.lies_for if data != null else 1.0


func _falls_for() -> float:
	return maxf(data.falls_for, 0.01) if data != null else 0.01
