class_name Bird
extends Node3D
## One bird: hopping about on the sand until something comes near, then gone.
##
## Decoration, and nothing else. No collider, no navigation, no group, nothing combat can touch —
## a wave director that had to step around a seagull would be paying for scenery.
##
## **Two models, not one.** The rig is built for the air: at rest its wings lie spread flat, so a
## bird standing on it would stand there mid-glide. On the ground it is the perched model, wings
## folded; the moment it leaves, the rig takes over. Only the one on show is animated, so ten birds
## on the sand cost ten static meshes and not ten skeletons.
##
## **What moves the body is this script; the clips only move the wings.** A bird that waited for an
## animation to carry it would be a bird standing still in the sky, and a hop authored as a clip
## would have to be re-authored for every patch of ground it landed on.
##
## **Plain integers rather than an enum**, and that is not laziness. A `class_name` script cannot
## assign its own enum to a variable declared with that enum's bare name — GDScript resolves the
## value as `Bird.State` and the declaration as `State`, and refuses the two as different types. The
## same mismatch makes `bird.state == Bird.State.GROUNDED` a parse error from anywhere else. Three
## constants and two predicates cost nothing and cannot go wrong.
const GROUNDED: int = 0
const FLYING: int = 1
const LEAVING: int = 2
## How far a hopping bird may wander from where it was put down before it hops back towards it. The
## flock decides where birds are; a bird that hopped its way out of that decision would be making
## its own.
const HOME_RANGE: float = 0.6

## Wings beating, and wings held out. A startled bird only beats: it is trying to get away. One
## already up there alternates, because nothing flaps the whole way across the sky.
@export var fly_clip: StringName = &"bird_fly"
@export var glide_clip: StringName = &"bird_fly_idle"
## How much of a cruising bird's time is spent flapping rather than gliding.
@export_range(0.0, 1.0, 0.01) var flap_share: float = 1.0 / 3.0
## How many whole wingbeats one bout of flapping lasts. Counted in beats rather than seconds so a
## bout never cuts a stroke in half — a wing that stops mid-beat reads as a glitch, not as a glide.
@export var flap_beats: int = 2
## The crossfade between the two, in seconds.
@export var wing_blend: float = 0.25
## How fast it climbs away once startled, and how fast it travels while doing it.
@export var flee_climb: float = 3.6
@export var flee_speed: float = 7.5
## A bird on the wing drifts rather than holds station — a fixed point in the sky reads as a prop.
@export var cruise_speed: float = 2.4
## Gone once it is this far above where it started. Freed rather than faded: nothing up there is
## worth a draw call.
@export var vanish_height: float = 22.0
## Seconds between hops, drawn afresh after each one, so a beach of birds never hops in step.
@export var hop_every: Vector2 = Vector2(1.2, 3.5)
## One hop: how high, how far, how long. Small on purpose — this is a bird shifting its weight, not
## a bird going anywhere.
@export var hop_height: float = 0.08
@export var hop_length: float = 0.14
@export var hop_time: float = 0.22
## How often a hop also turns it, and by how much at most. Turning is what makes it look like it is
## looking about rather than walking a line.
@export_range(0.0, 1.0, 0.01) var hop_turn_chance: float = 0.4
@export var hop_turn_degrees: float = 70.0

var _state: int = GROUNDED
var _heading: Vector3 = Vector3.FORWARD
## The height it was put down at, which every hop lands back on and the climb is measured from.
## NAN until it is first needed rather than read in `_ready`: whoever spawns the bird parents it
## before placing it, so at `_ready` it is still standing at the origin — and since the hop *writes*
## the height, a zero recorded here dragged every ground bird down to sea level.
var _started_at: float = NAN
var _home: Vector3 = Vector3.ZERO
var _hop_wait: float = 0.0
var _hop_clock: float = -1.0
var _hop_from: Vector3 = Vector3.ZERO
var _hop_to: Vector3 = Vector3.ZERO
var _cruise_clock: float = 0.0
var _wings: AnimationPlayer = null

@onready var perched: Node3D = get_node_or_null("Perched") as Node3D
@onready var flight: Node3D = get_node_or_null("Flight") as Node3D
@onready var _voice: VoiceComponent = get_node_or_null(^"Voice") as VoiceComponent


func _ready() -> void:
	if flight != null:
		var players := flight.find_children("*", "AnimationPlayer", true, false)
		_wings = players[0] as AnimationPlayer if not players.is_empty() else null
	if _heading.is_equal_approx(Vector3.FORWARD):
		_heading = Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()
	_hop_wait = randf_range(0.0, hop_every.y)
	# A random point in the cycle, so a sky of birds does not flap in unison.
	_cruise_clock = randf() * _cruise_period()
	_show_wings(_state != GROUNDED)
	_face(_heading)


func _process(delta: float) -> void:
	_anchor()
	if _state == GROUNDED:
		_hop(delta)
		return
	if _state == FLYING:
		_heading = _heading.rotated(Vector3.UP, delta * 0.35).normalized()
		global_position += _heading * cruise_speed * delta
		_face(_heading)
		_cruise_clock += delta
		_beat(_cruising_clip())
		return
	global_position += (_heading * flee_speed + Vector3.UP * flee_climb) * delta
	_face(_heading)
	if global_position.y - _started_at > vanish_height:
		queue_free()


func is_grounded() -> bool:
	return _state == GROUNDED


func is_flying() -> bool:
	return _state == FLYING


## Sets the bird going before it enters the tree, so a flock can place it without a frame of it
## sitting in the wrong state.
func launch(on_the_ground: bool, heading: Vector3) -> void:
	_state = GROUNDED if on_the_ground else FLYING
	if not heading.is_zero_approx():
		_heading = heading.normalized()


## Something came too close. Everything from here is one way: it climbs, it leaves, it is freed.
func startle(away_from: Vector3) -> void:
	if _state == LEAVING:
		return
	_anchor()
	# Off the ground from wherever the hop had it, not from the top of a hop that will never land.
	_hop_clock = -1.0
	global_position.y = _started_at
	_state = LEAVING
	var escape := global_position - away_from
	escape.y = 0.0
	# A bird startled from directly overhead has nowhere to run, so it takes the way it was facing.
	_heading = escape.normalized() if not escape.is_zero_approx() else _heading
	_face(_heading)
	_show_wings(true)
	_beat(fly_clip)


## A cry, from where the bird is. Only from the ones on the sand and only now and then — a flock
## where every bird calls is not a shore, it is an alarm.
func cry() -> void:
	if _voice != null:
		_voice.speak()


## Takes the spot it is standing on as its own, the first time anything asks.
func _anchor() -> void:
	if is_nan(_started_at):
		_started_at = global_position.y
		_home = global_position


## Waiting, then one short arc: up and a step forward, landing back on the height it was put down
## at. A step is short enough that the ground under it has not moved, and `HOME_RANGE` keeps the
## steps from adding up.
func _hop(delta: float) -> void:
	if _hop_clock < 0.0:
		_hop_wait -= delta
		if _hop_wait > 0.0:
			return
		_take_off()
	_hop_clock += delta
	var through := clampf(_hop_clock / maxf(hop_time, 0.001), 0.0, 1.0)
	var at := _hop_from.lerp(_hop_to, through)
	# A parabola that is zero at both ends and `hop_height` in the middle.
	at.y = _started_at + 4.0 * hop_height * through * (1.0 - through)
	global_position = at
	if through >= 1.0:
		_hop_clock = -1.0
		_hop_wait = randf_range(hop_every.x, hop_every.y)


func _take_off() -> void:
	var from_home := global_position - _home
	from_home.y = 0.0
	if from_home.length() > HOME_RANGE:
		# Drifted too far: the next hop heads back.
		_heading = -from_home.normalized()
	elif randf() < hop_turn_chance:
		_heading = _heading.rotated(
			Vector3.UP, deg_to_rad(randf_range(-1.0, 1.0) * hop_turn_degrees)
		)
	_face(_heading)
	_hop_from = Vector3(global_position.x, _started_at, global_position.z)
	_hop_to = _hop_from + Vector3(_heading.x, 0.0, _heading.z).normalized() * hop_length
	_hop_clock = 0.0


## Flat: a bird that pitched towards its climb would need a clip to sell it.
##
## **The models' heads point along +Z** — the glTF exporter puts a model's front there, and Godot's
## forward is −Z. `bird.tscn` turns both model nodes half a circle so that this line can mean what
## it says. Without that turn a startled bird fled tail first.
func _face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx():
		return
	rotation.y = atan2(-flat.x, -flat.z)


## Which clip a cruising bird wants now: a bout of whole wingbeats, then twice as long gliding.
func _cruising_clip() -> StringName:
	var flapping := _flap_seconds()
	if flapping <= 0.0 or flap_share <= 0.0:
		return glide_clip
	var through := fposmod(_cruise_clock, _cruise_period())
	return fly_clip if through < flapping else glide_clip


func _flap_seconds() -> float:
	if _wings == null or not _wings.has_animation(String(fly_clip)):
		return 0.0
	return _wings.get_animation(String(fly_clip)).length * maxi(flap_beats, 1)


func _cruise_period() -> float:
	var flapping := _flap_seconds()
	if flapping <= 0.0 or flap_share <= 0.0:
		return 1.0
	return flapping / clampf(flap_share, 0.01, 1.0)


## Plays a wing clip if it is not the one already playing. Asking every frame is what lets the
## cruise decide from the clock instead of keeping a timer of its own that could drift from it.
func _beat(clip: StringName) -> void:
	if _wings == null or not _wings.has_animation(String(clip)):
		return
	if _wings.current_animation == String(clip) and _wings.is_playing():
		return
	_wings.play(String(clip), wing_blend)


## Which model is on show. The hidden rig is stopped rather than left running out of sight.
func _show_wings(in_the_air: bool) -> void:
	if perched != null:
		perched.visible = not in_the_air
	if flight != null:
		flight.visible = in_the_air
	if _wings != null and not in_the_air:
		_wings.stop()
