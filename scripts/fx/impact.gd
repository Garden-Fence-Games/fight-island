class_name Impact
extends Node3D
## What a landed hit looks like. One burst of debris and a flare, sized by whether the timing was
## perfect.
##
## **A perfect hit has to be readable without a number** — the design turns damage numbers off by
## default precisely because the effect is meant to carry it. So the two differ in three ways at
## once: more debris, thrown further, and a flare that is brighter and lasts longer. Any one of
## them alone is a difference a player has to be told about; three is one they notice.
##
## `CPUParticles3D` rather than the GPU kind, deliberately. A burst is a dozen quads twice a second
## at most and the cost is nothing, while the GPU version cannot be asked what it did — it draws or
## it does not, and a headless check can only watch it fail to. This one can be measured.

signal spent

## How long the whole thing lasts. Longer than the hitstop it lands under, so the effect is still
## going when time comes back.
const LIFE: float = 0.45
const PERFECT_LIFE: float = 0.7
const DEBRIS: int = 8
const PERFECT_DEBRIS: int = 18
const SPEED: float = 3.0
const PERFECT_SPEED: float = 6.5
const FLARE: float = 0.35
const PERFECT_FLARE: float = 0.9
const NORMAL_COLOUR: Color = Color(1.0, 0.58, 0.3)
const PERFECT_COLOUR: Color = Color(1.0, 0.96, 0.7)
## What `access_reduce_flashing` leaves. The debris stays whole — it is motion, not flashing, and
## removing it would take the hit's readability with it. Only the flare is damped.
const DAMPED: float = 0.15
## How long the flare takes to swell and go. Short: it is the punctuation, not the sentence.
const FLARE_FADE: float = 0.18

@onready var debris: CPUParticles3D = $Debris
@onready var flare: MeshInstance3D = $Flare


func _ready() -> void:
	debris.emitting = false
	flare.visible = false


## Places the burst and starts it. `perfect` is the whole of the difference.
func play(where: Vector3, perfect: bool) -> void:
	global_position = where
	debris.amount = PERFECT_DEBRIS if perfect else DEBRIS
	debris.initial_velocity_min = (PERFECT_SPEED if perfect else SPEED) * 0.4
	debris.initial_velocity_max = PERFECT_SPEED if perfect else SPEED
	debris.lifetime = PERFECT_LIFE if perfect else LIFE
	debris.color = PERFECT_COLOUR if perfect else NORMAL_COLOUR
	debris.restart()
	_flare(perfect)
	var timer := get_tree().create_timer(debris.lifetime, true, false, true)
	timer.timeout.connect(_finish)


## The bright part, and the only part `access_reduce_flashing` touches.
func _flare(perfect: bool) -> void:
	var material := flare.material_override as StandardMaterial3D
	if material == null:
		return
	var size := PERFECT_FLARE if perfect else FLARE
	if bool(Settings.get_value(&"access_reduce_flashing")):
		size *= DAMPED
	flare.visible = size > 0.0
	flare.scale = Vector3.ONE * size
	material.albedo_color = PERFECT_COLOUR if perfect else NORMAL_COLOUR
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flare, "scale", Vector3.ONE * size * 2.2, FLARE_FADE)
	tween.tween_property(material, "albedo_color:a", 0.0, FLARE_FADE)


## Ends the burst now rather than when its timer runs out. For the headless check, which drives
## forty hits through a pool of eight and cannot sit through half a second each.
func finish_now() -> void:
	_finish()


func _finish() -> void:
	debris.emitting = false
	flare.visible = false
	spent.emit()
