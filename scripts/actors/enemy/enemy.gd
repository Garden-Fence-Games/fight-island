class_name Enemy
extends CharacterBody3D
## A farmer. Which of the three he is comes from EnemyData and a material - not from a second
## scene to keep in sync.
##
## A body is leased and returned rather than created and freed: at thirty on screen, allocating and
## collecting shows up in the frame. Everything that differs between one life and the next lives in
## revive() — the wave's scaling included, which is why the shared EnemyData is never written to.

signal retired(enemy: Enemy)

const SEPARATION_RADIUS: float = 1.2
const SEPARATION_FORCE: float = 2.4
const TURN_SPEED_DEGREES: float = 360.0
## How long a route is walked before it is asked for again. Re-pathing every frame for thirty
## farmers is most of a frame spent on a query whose answer barely moves, and the player cannot get
## far in a quarter of a second.
const REPATH_INTERVAL: float = 0.25

@export var data: EnemyData = null

## Set by the pool before the body enters the tree. A hand-placed enemy wakes up fighting; a pooled
## one waits to be leased.
var pooled: bool = false
var target: Node3D = null
var poise_left: float = 0.0
## What this wave does to him. Held per body because EnemyData is one shared resource on disk, and
## scaling it in place would raise every farmer in the game and then save the result.
var damage_scale: float = 1.0
var speed_scale: float = 1.0
var windup_scale: float = 1.0

var _tokens: AttackTokens = null
var _gravity: float = 9.8
var _poise_window: float = 0.0
var _repath_clock: float = 0.0

@onready var health: HealthComponent = $Health
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var machine: StateMachine = $StateMachine
@onready var mesh: MeshInstance3D = $Body
@onready var agent: NavigationAgent3D = $Agent


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_tokens = get_tree().get_first_node_in_group(&"attack_tokens") as AttackTokens
	target = get_tree().get_first_node_in_group(&"player") as Node3D
	if hurtbox != null:
		hurtbox.hurt.connect(_on_hurt)
	if health != null:
		health.died.connect(_on_died)
	if pooled:
		sleep()
		return
	revive(global_position)


## Wakes a body up for one life. Everything a previous life could have left behind is reset here:
## a pooled enemy that comes back at three health, invisible, or still holding an attack token is
## the kind of bug that only appears in the fifth wave of a long run.
func revive(
	where: Vector3,
	health_boost: float = 1.0,
	damage: float = 1.0,
	speed: float = 1.0,
	windup: float = 1.0
) -> void:
	damage_scale = damage
	speed_scale = speed
	windup_scale = windup
	global_position = where
	velocity = Vector3.ZERO
	rotation.y = 0.0
	target = get_tree().get_first_node_in_group(&"player") as Node3D
	_poise_window = 0.0
	if data != null:
		poise_left = data.poise
		if health != null:
			health.set_max_health(data.health * health_boost, true)
		if mesh != null:
			_apply_tint()
	if hurtbox != null:
		hurtbox.monitorable = true
	if hitbox != null:
		hitbox.disarm()
	set_collision_layer_value(3, true)
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	add_to_group(&"enemies")
	if machine != null and machine.current != null:
		machine.current.transition_to(&"Idle")
	EventBus.enemy_spawned.emit(self)


## Out of the fight and out of the way, without announcing anything. Used for the pool's own
## pre-warm, where thirty-two spawn notifications would be thirty-two lies.
func sleep() -> void:
	release_token()
	remove_from_group(&"enemies")
	if hurtbox != null:
		hurtbox.monitorable = false
	if hitbox != null:
		hitbox.disarm()
	set_collision_layer_value(3, false)
	visible = false
	velocity = Vector3.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED


## Hands the body back to whoever is holding the lease.
func retire() -> void:
	sleep()
	retired.emit(self)


## The end of the death animation. A body nobody is pooling is a body that should stop existing.
func finish_dying() -> void:
	if pooled:
		retire()
		return
	queue_free()


func _process(delta: float) -> void:
	if _poise_window > 0.0:
		_poise_window = maxf(_poise_window - delta, 0.0)
		if is_zero_approx(_poise_window) and data != null:
			poise_left = data.poise


## The wave's numbers applied to the archetype's, so no state has to know a wave exists.
func move_speed() -> float:
	return (data.move_speed if data != null else 0.0) * speed_scale


func windup() -> float:
	if data == null or data.attack == null:
		return 0.0
	return data.attack.windup * windup_scale


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


## The way to walk to reach the target, around whatever stands in the way.
##
## Falls back to the straight line whenever there is no route to follow — no navigation mesh under
## the level, a target that has stepped off it, or the first frame after asking. An arena with no
## navigation mesh still plays exactly as it did before, which is what keeps the combat tests
## honest about combat.
func path_direction(delta: float) -> Vector3:
	if target == null:
		return Vector3.ZERO
	_repath_clock -= delta
	if _repath_clock <= 0.0:
		_repath_clock = REPATH_INTERVAL
		agent.target_position = target.global_position
	if agent.is_navigation_finished() or agent.get_current_navigation_path().is_empty():
		return direction_to_target()
	var step := agent.get_next_path_position() - global_position
	step.y = 0.0
	if step.is_zero_approx():
		return direction_to_target()
	return step.normalized()


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
	face(direction_to_target(), delta)


## A Node3D's forward is -Z, so the yaw that points it along `direction` is atan2(-x, -z).
func face(direction: Vector3, delta: float) -> void:
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
