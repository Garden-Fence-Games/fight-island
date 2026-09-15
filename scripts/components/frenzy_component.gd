class_name FrenzyComponent
extends Node
## The rainbow bird's power, on the body that took it: a clock, the shield, the overwhelming punch
## and the colours. Whatever else changes for the owner — the speed, the weapon in hand — the owner
## does itself when `started` and `ended` say so; this knows its siblings only by the actor scene's
## own naming contract, the way `Hurtbox` knows `Health`.
##
## **Not stackable.** `start` refuses while it is running, so a second bird is left lying rather
## than spent for nothing.

signal started(data: FrenzyData)
signal ended

const SHADER: String = "res://assets/shaders/rainbow.gdshader"
## How long the colours take to come on and go off. Short: the power is on the moment the bird is
## taken, and the body should say so straight away.
const FADE: float = 0.25
## Blinks a second while it is running down.
const WARNING_HZ: float = 4.0

var data: FrenzyData = null

var _left: float = 0.0
var _overlay: ShaderMaterial = null
var _fading: Tween = null

@onready var health: HealthComponent = get_node_or_null(^"../Health") as HealthComponent
@onready var hitbox: Hitbox = get_node_or_null(^"../Hitbox") as Hitbox
@onready var animation: AnimationComponent = get_node_or_null(^"../Animation") as AnimationComponent
@onready var visual: Node3D = get_node_or_null(^"../Visual") as Node3D


func _process(delta: float) -> void:
	if not is_active():
		return
	_left = maxf(_left - delta, 0.0)
	if is_zero_approx(_left):
		stop()
		return
	_warn()


func is_active() -> bool:
	return data != null


func time_left() -> float:
	return _left


## Whether it took. Refused while one is already running, and for a body with nothing to shield.
func start(with: FrenzyData) -> bool:
	if with == null or is_active() or health == null or not health.is_alive():
		return false
	data = with
	_left = with.lasts
	health.shielded = true
	if hitbox != null:
		hitbox.overwhelm = with.launches_like
	if animation != null:
		animation.pace = with.speed_multiplier
	_show_colours(true)
	started.emit(with)
	return true


## Ends it now, whatever is left: the clock ran out, or the wave did.
func stop() -> void:
	if not is_active():
		return
	data = null
	_left = 0.0
	if health != null:
		health.shielded = false
	if hitbox != null:
		hitbox.overwhelm = null
	if animation != null:
		animation.pace = 1.0
	_show_colours(false)
	ended.emit()


## The colours as a `material_overlay` on every mesh of the body, built on first use because the rig
## is an instanced scene. One material shared by the whole body, so one uniform fades all of it.
func overlay() -> ShaderMaterial:
	if _overlay != null:
		return _overlay
	_overlay = ShaderMaterial.new()
	_overlay.shader = load(SHADER) as Shader
	_overlay.set_shader_parameter(&"strength", 0.0)
	return _overlay


func _show_colours(on: bool) -> void:
	var material := overlay()
	material.set_shader_parameter(&"glitter", 0.0 if _reduce_flashing() else 1.0)
	if on:
		_dress(material)
	if _fading != null and _fading.is_valid():
		_fading.kill()
	if not is_inside_tree():
		material.set_shader_parameter(&"strength", 1.0 if on else 0.0)
		if not on:
			_dress(null)
		return
	_fading = create_tween()
	_fading.tween_method(_set_strength, _strength(), 1.0 if on else 0.0, FADE)
	if not on:
		_fading.tween_callback(_dress.bind(null))


func _dress(material: ShaderMaterial) -> void:
	if visual == null:
		return
	for mesh: MeshInstance3D in Descend.meshes(visual):
		mesh.material_overlay = material


## The last seconds blink rather than simply ending. With flashing reduced, they dim instead.
func _warn() -> void:
	if data == null or _left > data.warns_for:
		return
	if _fading != null and _fading.is_running():
		return
	var wave := 0.5 + 0.5 * cos((data.warns_for - _left) * TAU * WARNING_HZ)
	if _reduce_flashing():
		wave = _left / maxf(data.warns_for, 0.01)
	_set_strength(lerpf(0.25, 1.0, wave))


func _set_strength(value: float) -> void:
	overlay().set_shader_parameter(&"strength", value)


func _strength() -> float:
	return float(overlay().get_shader_parameter(&"strength"))


func _reduce_flashing() -> bool:
	return bool(Settings.get_value(&"access_reduce_flashing"))
