class_name Enemy
extends CharacterBody3D
## A farmer. Which of the three he is comes from EnemyData and a material - not from a second
## scene to keep in sync.

const SEPARATION_RADIUS: float = 1.2
const SEPARATION_FORCE: float = 2.4
const TURN_SPEED_DEGREES: float = 360.0

@export var data: EnemyData = null

var target: Node3D = null
var poise_left: float = 0.0

var _tokens: AttackTokens = null
var _gravity: float = 9.8
var _poise_window: float = 0.0

@onready var health: HealthComponent = $Health
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var machine: StateMachine = $StateMachine
@onready var mesh: MeshInstance3D = $Body


func _ready() -> void:
	add_to_group(&"enemies")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_tokens = get_tree().get_first_node_in_group(&"attack_tokens") as AttackTokens
	target = get_tree().get_first_node_in_group(&"player") as Node3D
	if data != null:
		poise_left = data.poise
		if health != null:
			health.set_max_health(data.health, true)
		if mesh != null:
			_apply_tint()
	if hurtbox != null:
		hurtbox.hurt.connect(_on_hurt)
	if health != null:
		health.died.connect(_on_died)
	EventBus.enemy_spawned.emit(self)


func _process(delta: float) -> void:
	if _poise_window > 0.0:
		_poise_window = maxf(_poise_window - delta, 0.0)
		if is_zero_approx(_poise_window) and data != null:
			poise_left = data.poise


func distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)


func direction_to_target() -> Vector3:
	if target == null:
		return Vector3.ZERO
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	return to_target.normalized()


## Steering that keeps bodies from stacking. Cheap, and worth far more than it costs.
func separation() -> Vector3:
	var push := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == self:
			continue
		var offset := global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > SEPARATION_RADIUS or is_zero_approx(distance):
			continue
		push += offset.normalized() * (1.0 - distance / SEPARATION_RADIUS)
	return push * SEPARATION_FORCE


func apply_motion(direction: Vector3, speed: float, delta: float) -> void:
	var steered := (direction + separation()).limit_length(1.0)
	# Enemies pay the same toll as the player, so backing into the shallows is a real choice
	# rather than a free escape.
	var wading := Water.drag_at(global_position.y, PlayableArea.WADE_DEPTH)
	velocity.x = steered.x * speed * wading
	velocity.z = steered.z * speed * wading
	velocity.y -= _gravity * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()


func face_target(delta: float) -> void:
	var direction := direction_to_target()
	if direction.is_zero_approx():
		return
	var wanted := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, wanted, deg_to_rad(TURN_SPEED_DEGREES) * delta)


func claim_token() -> bool:
	if _tokens == null:
		return true
	return _tokens.claim(self, data != null and data.is_ranged)


func release_token() -> void:
	if _tokens == null:
		return
	_tokens.release(self, data != null and data.is_ranged)


func stagger(duration: float) -> void:
	if machine == null or not is_alive():
		return
	release_token()
	machine.current.transition_to(&"Stagger", {"duration": duration})


func is_alive() -> bool:
	return health == null or health.is_alive()


func _apply_tint() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = data.tint
	mesh.material_override = material


func _on_hurt(info: HitInfo) -> void:
	if not is_alive():
		return
	_poise_window = 2.0
	poise_left -= info.poise_damage
	if poise_left <= 0.0 and data != null:
		poise_left = data.poise
		stagger(maxf(info.stagger, 0.4))


func _on_died() -> void:
	release_token()
	EventBus.enemy_died.emit(self, data.money if data != null else 0)
	if machine != null:
		machine.current.transition_to(&"Dead")
