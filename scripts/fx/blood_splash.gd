class_name BloodSplash
extends Node3D
## The blood in the air: droplets thrown the way the blow travelled, for half a second.
##
## **Drops, not cubes.** Each particle is a thin capsule aligned to its own velocity, so it reads as
## a streak while it is fast and shortens into a drop as gravity slows it — which is the whole
## difference between liquid and debris, and needs no texture at all.
##
## Leased from `EffectPool` like `Impact`, and for the same reason: a burst built in the middle of a
## fight is a burst paid for in the frame the player is meant to feel. `CPUParticles3D` for the same
## reason as `Impact` too — a headless check can ask it what it did.
##
## Where the droplets land is not read off the particles. `BloodField` places the stains off the
## same direction and the same `splash_life`, so the picture and the stains are one decision.

signal spent

@onready var drops: CPUParticles3D = $Drops


func _ready() -> void:
	drops.emitting = false


## Throws the droplets from `where` along `direction`. `perfect` spills more, and faster.
func play(where: Vector3, direction: Vector3, perfect: bool, blood: BloodData) -> void:
	global_position = where
	var flat := Vector3(direction.x, 0.0, direction.z)
	flat = flat.normalized() if not flat.is_zero_approx() else Vector3.FORWARD
	# Up as well as out: a blow lifts the spray before gravity takes it.
	drops.direction = (flat + Vector3.UP * 0.55).normalized()
	drops.amount = blood.perfect_droplets if perfect else blood.droplets
	# Not `scale`, which is the node's own and would be shadowed.
	var faster := blood.perfect_speed_scale if perfect else 1.0
	drops.initial_velocity_min = blood.splash_speed.x * faster
	drops.initial_velocity_max = blood.splash_speed.y * faster
	drops.lifetime = blood.splash_life
	drops.color = blood.colour
	drops.restart()
	var timer := get_tree().create_timer(blood.splash_life, true, false, true)
	timer.timeout.connect(_finish)


## Ends the splash now rather than when its timer runs out, for a check that cannot wait.
func finish_now() -> void:
	_finish()


func _finish() -> void:
	drops.emitting = false
	spent.emit()
