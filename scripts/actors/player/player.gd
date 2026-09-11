class_name Player
extends CharacterBody3D
## The player body and the shared vocabulary its states use. It owns no behaviour of its own
## beyond movement helpers and the chain bookkeeping, which has to outlive any single attack.

const INPUT_BUFFER: float = 0.15
const TURN_SPEED_DEGREES: float = 720.0
const MOVE_SPEED: float = 4.2
const SPRINT_SPEED: float = 6.6
const SPRINT_DRAIN: float = 12.0
const SPRINT_MINIMUM: float = 10.0

@export var weapon: WeaponData = null

## Index of the attack that just played, and the clock since its recovery began. A negative clock
## means no chain is open. Windows on attack N govern the press that produces attack N + 1.
var chain_index: int = -1

var _chain_attack: AttackData = null
var _chain_clock: float = -1.0
var _press_age: float = INF
var _gravity: float = 9.8

@onready var health: HealthComponent = $Health
@onready var stamina: StaminaComponent = $Stamina
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var machine: StateMachine = $StateMachine
@onready var mesh: MeshInstance3D = $Body


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if hurtbox != null:
		hurtbox.hurt.connect(_on_hurt)
	if health != null:
		health.health_changed.connect(_on_health_changed)
		health.died.connect(_on_died)
	if stamina != null:
		stamina.stamina_changed.connect(_on_stamina_changed)


func _process(delta: float) -> void:
	_press_age += delta
	if _chain_clock >= 0.0:
		_chain_clock += delta
		if _chain_attack == null or _chain_clock > _chain_attack.chain_window.y:
			close_chain()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		press_attack()


## The one way a press enters the buffer, so a headless check can drive the chain like a player.
func press_attack() -> void:
	_press_age = 0.0


## Ground movement direction in world space, relative to wherever the camera is looking.
func move_direction() -> Vector3:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if input.is_zero_approx():
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var basis := camera.global_transform.basis if camera != null else global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	return (right * input.x - forward * input.y).limit_length(1.0)


func apply_motion(direction: Vector3, speed: float, delta: float) -> void:
	var wading := Water.drag_at(global_position.y, PlayableArea.WADE_DEPTH)
	velocity.x = direction.x * speed * wading
	velocity.z = direction.z * speed * wading
	velocity.y -= _gravity * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()


func halt(delta: float) -> void:
	apply_motion(Vector3.ZERO, 0.0, delta)


## A Node3D's forward is -Z, so the yaw that points it along `direction` is atan2(-x, -z).
func face(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var target := atan2(-direction.x, -direction.z)
	var step := deg_to_rad(TURN_SPEED_DEGREES) * delta
	rotation.y = rotate_toward(rotation.y, target, step)


func snap_to_face(direction: Vector3) -> void:
	if direction.is_zero_approx():
		return
	rotation.y = atan2(-direction.x, -direction.z)


## Opens the window that lets the next attack exist. Called when an attack enters its recovery.
func open_chain(from_attack: AttackData, index: int) -> void:
	_chain_attack = from_attack
	chain_index = index
	_chain_clock = 0.0


func close_chain() -> void:
	_chain_attack = null
	_chain_clock = -1.0
	chain_index = -1


func buffered_attack_press() -> bool:
	return _press_age <= INPUT_BUFFER


func consume_press() -> void:
	_press_age = INF


## The attack a fresh press should produce right now, or an empty dictionary for none. Reading it
## consumes the press, so only a state about to act on it should ask.
func take_attack_input() -> Dictionary:
	if not buffered_attack_press() or weapon == null:
		return {}
	if _chain_clock < 0.0 or _chain_attack == null:
		consume_press()
		return {"index": 0, "perfect": false}
	if _chain_attack.is_finisher():
		return {}
	var window := _chain_attack.chain_window
	if _chain_clock < window.x or _chain_clock > window.y:
		return {}
	var next := chain_index + 1
	if next >= weapon.chain_length():
		return {}
	var perfect_window := _chain_attack.perfect_window
	var perfect := _chain_clock >= perfect_window.x and _chain_clock <= perfect_window.y
	consume_press()
	return {"index": next, "perfect": perfect}


func is_alive() -> bool:
	return health == null or health.is_alive()


func _on_hurt(info: HitInfo) -> void:
	if not is_alive():
		return
	if machine != null:
		var parry := machine.current as PlayerParry
		if parry != null:
			parry.resolve(info)
			return
	if health != null and health.is_invulnerable():
		return
	if machine != null and info.stagger > 0.0:
		machine.current.transition_to(&"Hurt", {"stagger": info.stagger})


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_damaged.emit(current, maximum)


func _on_stamina_changed(current: float, maximum: float) -> void:
	EventBus.stamina_changed.emit(current, maximum)


func _on_died() -> void:
	EventBus.player_died.emit()
	if machine != null:
		machine.current.transition_to(&"Dead")
