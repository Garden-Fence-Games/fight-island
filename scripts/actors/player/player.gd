class_name Player
extends CharacterBody3D
## The player body and the shared vocabulary its states use. It owns no behaviour of its own
## beyond movement helpers and the chain bookkeeping, which has to outlive any single attack.

const INPUT_BUFFER: float = 0.15
const TURN_SPEED_DEGREES: float = 720.0
## Slower than the farmhand's 3.4 m/s, which is deliberate: a walking player cannot break away from
## a farmer, so retreat costs stamina rather than being the default state.
const MOVE_SPEED: float = 3.2
const SPRINT_SPEED: float = 5.0
const SPRINT_DRAIN: float = 12.0
const SPRINT_MINIMUM: float = 10.0
## Ground covered between one footfall and the next. Measured in metres rather than counted on a
## timer, so a sprint's steps come faster than a walk's without either speed being told about the
## other — and so wading, which costs speed, slows the footsteps with it.
##
## **It is the walk cycle's own stride, and it has to stay that.** It was 0.95 m, which at 3.2 m/s
## is 202 footfalls a minute against a clip that puts down 118 — the ear heard a jog while the eye
## watched a walk. One walk cycle is `FOOTFALLS_PER_CYCLE` steps and covers `MOVE_SPEED × length`
## of ground, and this is that divided out. `verify_animation` holds the two together, so a
## reimported cycle of a different length fails rather than quietly running the sound fast again.
const STRIDE: float = 1.63
## What one loop of the walk clip puts on the ground. Left and right: it is a cycle, not a step.
const FOOTFALLS_PER_CYCLE: float = 2.0

## What is in hand. Set from the run state, not by the scene: a player who quits to the title and
## continues is holding what they were holding. The export is the fallback for a scene opened
## straight from the editor with no run behind it.
@export var weapon: WeaponData = null

## Where the last blow that landed was travelling, and how hard it throws. Only the fall reads
## them, which is why neither is reset anywhere: a run that never took a hit is a run that never
## died either. The push is in points of `AttackData.stagger`, the unit `KnockdownData.knock_speed`
## is a rate of — the player has no poise to break, so the blow's own figure is the whole of it.
var last_hit_from: Vector3 = Vector3.FORWARD
var last_hit_push: float = 0.0

## Index of the attack that just played, and the clock since its recovery began. A negative clock
## means no chain is open. Windows on attack N govern the press that produces attack N + 1.
var chain_index: int = -1

## Set by the upgrade component, read by whatever is about to swing. Multipliers rather than a
## rewritten AttackData, because the resource on disk is shared and scaling it in place would raise
## every fist in the game and then save the result.
var damage_multiplier: float = 1.0
var stamina_cost_multiplier: float = 1.0

var _body_materials: Array[StandardMaterial3D] = []
var _stride_walked: float = 0.0
var _chain_attack: AttackData = null
var _chain_clock: float = -1.0
var _lockout_clock: float = 0.0
var _press_age: float = INF
var _sprint_toggle: bool = false
var _sprint_latched: bool = false
var _gravity: float = 9.8

## The body itself, tipped by the sea as it goes under — see `PlayableArea`. Named apart from
## `visual`, which is the component that decides which weapon is in the hand.
@onready var rig: Node3D = get_node_or_null("Visual") as Node3D
@onready var health: HealthComponent = $Health
@onready var stamina: StaminaComponent = $Stamina
@onready var hitbox: Hitbox = $Hitbox
@onready var hitscan: Hitscan = get_node_or_null("Hitscan") as Hitscan
@onready
var visual: WeaponVisualComponent = get_node_or_null("WeaponVisual") as WeaponVisualComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var machine: StateMachine = $StateMachine
@onready var aim: AimComponent = $Aim
@onready var head_look: HeadLookComponent = get_node_or_null("HeadLook") as HeadLookComponent
@onready var animation: AnimationComponent = get_node_or_null("Animation") as AnimationComponent
@onready var ragdoll: RagdollComponent = get_node_or_null("Ragdoll") as RagdollComponent


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if hurtbox != null:
		hurtbox.hurt.connect(_on_hurt)
	if health != null:
		health.health_changed.connect(_on_health_changed)
		health.died.connect(_on_died)
	if stamina != null:
		stamina.stamina_changed.connect(_on_stamina_changed)
	if machine != null:
		machine.transitioned.connect(_on_state_transitioned)
	# The dust scales with how fast this body goes, so it is told the two speeds rather than reaching
	# in for them. They are this class's figures and stay here; the component stays ignorant of whose
	# dust it is kicking up.
	var dust := get_node_or_null(^"FootstepDust") as FootstepDustComponent
	if dust != null:
		dust.walking_speed = MOVE_SPEED
		dust.sprinting_speed = SPRINT_SPEED
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	_on_weapon_equipped(GameState.loadout.weapon())


func _process(delta: float) -> void:
	_press_age += delta
	if _lockout_clock > 0.0:
		_lockout_clock = maxf(_lockout_clock - delta, 0.0)
		if is_zero_approx(_lockout_clock):
			EventBus.chain_ready.emit()
	if _chain_clock >= 0.0:
		_chain_clock += delta
		if _chain_attack == null or _chain_clock > _chain_attack.chain_window.y:
			close_chain()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		press_attack()
	if event.is_action_pressed(&"sprint"):
		_on_sprint_pressed(InputBindings.device_of(event) == InputBindings.Device.GAMEPAD)
	if event.is_action_pressed(&"reload"):
		_begin_reload()
	_read_weapon_input(event)


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


## Where the body should be pointing: at what the player is aiming when they are aiming, and along
## their movement otherwise. Aiming returns ZERO when it is idle, so a pad player who never touches
## the right stick gets exactly the facing the game had before it existed.
func look_direction(movement: Vector3) -> Vector3:
	var aimed := aim.direction() if aim != null else Vector3.ZERO
	return aimed if not aimed.is_zero_approx() else movement


## Where the body should point while it is only walking or standing: along its own movement, never
## at the aim. The head carries the aim now, and a body that turned to the cursor while travelling
## somewhere else would play a forward stride sideways — the moonwalk that having one `walk` clip
## and a free-turning body produces.
##
## **Standing still is the exception.** The neck stops at its limit, so an aim further round than
## that would leave the player looking over one shoulder with no way to ever face it. The body then
## turns just far enough to bring the aim back inside the head's reach, and not one degree further.
## Attacks and dodges do not come through here: a swing commits to the aim itself, in full.
func locomotion_facing(movement: Vector3) -> Vector3:
	if not movement.is_zero_approx():
		return movement
	var aimed := aim.direction() if aim != null else Vector3.ZERO
	if aimed.is_zero_approx() or head_look == null:
		return Vector3.ZERO
	var wanted := atan2(-aimed.x, -aimed.z)
	var offset := angle_difference(rotation.y, wanted)
	var limit := deg_to_rad(head_look.limit_degrees)
	if absf(offset) <= limit:
		return Vector3.ZERO
	var target := wanted - signf(offset) * limit
	return Vector3(-sin(target), 0.0, -cos(target))


## Every material the body is drawn with, as copies this body owns. Whatever wants to tint the whole
## silhouette — the drained colour while a chain is spent — goes through here.
##
## **Copies, not the originals.** The rig's materials come out of the imported glTF and are
## shared by every instance of it, so tinting one in place would drain the merchant and all three
## farmers the day they use the same rig. A surface override is private to this mesh instance.
##
## Tinting `albedo_color` rather than replacing the material with `material_override`: albedo is
## multiplied with the texture, so the character stays himself and merely goes the colour asked for.
## An override would flatten a textured rig to a single block of paint.
##
## Built on first use, because the visual is an instanced scene and its meshes are not in the tree
## when the player's own `_ready` runs.
func body_materials() -> Array[StandardMaterial3D]:
	if not _body_materials.is_empty():
		return _body_materials
	for mesh: MeshInstance3D in _mesh_instances(self):
		for surface: int in mesh.get_surface_override_material_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var copy := source.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(surface, copy)
			_body_materials.append(copy)
	return _body_materials


func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null:
			found.append(mesh)
		found.append_array(_mesh_instances(child))
	return found


## `on_foot` is what separates walking from every other way the body covers ground. A roll travels
## too and it is not two steps, and an attack calls `halt` and travels none — so the two states that
## actually walk say so, and nothing else has to know footfalls exist.
func apply_motion(direction: Vector3, speed: float, delta: float, on_foot: bool = false) -> void:
	var wading := Water.drag_at(global_position.y, PlayableArea.SEA.wade_depth)
	velocity.x = direction.x * speed * wading
	velocity.z = direction.z * speed * wading
	velocity.y -= _gravity * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	if on_foot:
		_carry_the_stride(delta)


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


## Pays for a finished chain: nothing may attack again until the clock runs out. Announced on the
## bus rather than shown here, because what the body does about it is presentation and combat has
## no business knowing.
func spend_chain(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_lockout_clock = seconds
	EventBus.chain_spent.emit(seconds)


func chain_locked() -> bool:
	return _lockout_clock > 0.0


func lockout_left() -> float:
	return _lockout_clock


func close_chain() -> void:
	_chain_attack = null
	_chain_clock = -1.0
	chain_index = -1


func buffered_attack_press() -> bool:
	return _press_age <= INPUT_BUFFER


func consume_press() -> void:
	_press_age = INF


## True while the player is asking to sprint. A keyboard holds and a pad toggles, because that is
## what each audience expects — and the setting lets either of them say otherwise. The latch lives
## on the body rather than in the sprint state, because it has to survive that state ending.
func wants_sprint() -> bool:
	if _sprint_toggle:
		return _sprint_latched
	return Input.is_action_pressed(&"sprint")


## Drops the latch, whatever ended the sprint — a stop, an empty bar, or an attack.
func release_sprint() -> void:
	_sprint_latched = false


## The attack a fresh press should produce right now, or an empty dictionary for none. Reading it
## consumes the press, so only a state about to act on it should ask.
##
## A press during the lockout leaves without consuming anything: the wait refuses this attack, it
## does not eat the player's input, so a press a hair early still lands the moment the weapon is
## ready again — the same promise the input buffer makes everywhere else.
func take_attack_input() -> Dictionary:
	if not buffered_attack_press() or weapon == null or chain_locked():
		return {}
	if _chain_clock < 0.0 or _chain_attack == null:
		consume_press()
		return {"index": 0, "perfect": false}
	return _continue_chain()


## The attack that follows the one just played, if the press landed inside its window.
func _continue_chain() -> Dictionary:
	var next := chain_index + 1
	if _chain_attack.is_finisher() or next >= weapon.chain_length():
		return {}
	var window := _chain_attack.chain_window
	if _chain_clock < window.x or _chain_clock > window.y:
		return {}
	var perfect_window := _chain_attack.perfect_window
	var perfect := _chain_clock >= perfect_window.x and _chain_clock <= perfect_window.y
	consume_press()
	return {"index": next, "perfect": perfect}


func is_alive() -> bool:
	return health == null or health.is_alive()


## Counts the ground just covered and puts a foot down each `STRIDE` of it.
##
## Read off `velocity` after the slide rather than off the direction that was asked for, so a player
## leaning into a boulder makes no sound. No ground covered, nothing heard — which is also what
## makes the footfalls slow down in the shallows without anybody telling them the water is there.
func _carry_the_stride(delta: float) -> void:
	_stride_walked += Vector2(velocity.x, velocity.z).length() * delta
	if _stride_walked < STRIDE:
		return
	_stride_walked = 0.0
	EventBus.footstep_taken.emit(
		Water.drag_at(global_position.y, PlayableArea.SEA.wade_depth) < 1.0
	)


func _on_sprint_pressed(from_gamepad: bool) -> void:
	_sprint_toggle = Settings.sprint_is_toggle(from_gamepad)
	if _sprint_toggle:
		_sprint_latched = not _sprint_latched


func _on_hurt(info: HitInfo) -> void:
	if not is_alive():
		return
	if machine != null:
		var parry := machine.current as PlayerParry
		if parry != null:
			parry.resolve(info)
			return
	if health != null and health.is_invulnerable():
		# Rolling through a swing rather than merely rolling. Announced here because this is the one
		# place that knows the blow arrived and was refused.
		if machine != null and machine.current is PlayerDodge:
			EventBus.dodge_evaded.emit()
		return
	# Taking a hit is the loudest thing that happens to the player and the only one they did not
	# choose, so it spends from the same budget every blow they land does — see `Emphasis`. Here
	# rather than in `Hurt`, because a blow with no stagger still arrived.
	# Kept for the fall. A body has to go down the way it was hit, and by the time the health
	# component has decided this was the last one the blow that threw it is gone.
	last_hit_from = info.direction
	last_hit_push = info.stagger
	Emphasis.spend(Emphasis.for_hurt())
	if machine != null and info.stagger > 0.0:
		machine.current.transition_to(&"Hurt", {"stagger": info.stagger})


## Three direct keys and a wheel. The wheel only ever offers what has been found, so a player who
## has not picked the gun up cannot cycle onto an empty hand.
##
## Switching is **free and instant**: no animation, no penalty, no cooldown. The interesting
## decision is which weapon suits the moment, not whether the player can afford to find out.
func _read_weapon_input(event: InputEvent) -> void:
	var bag := GameState.loadout
	for carried: WeaponData in Arsenal.all():
		if event.is_action_pressed(StringName("weapon_%s" % carried.id)):
			bag.equip(carried.id)
			return
	if event.is_action_pressed(&"weapon_next"):
		bag.equip(Arsenal.next_owned(bag.equipped, bag.found, 1))
	elif event.is_action_pressed(&"weapon_prev"):
		bag.equip(Arsenal.next_owned(bag.equipped, bag.found, -1))


## Nothing happens on a weapon that does not reload or a magazine already full, and that includes
## not leaving whatever state the player is in.
func _begin_reload() -> void:
	if machine == null or not GameState.loadout.can_reload(GameState.magazine_bonus()):
		return
	if machine.current is PlayerDead or machine.current is PlayerAttack:
		return
	machine.current.transition_to(&"Reload")


## The only thing a swap costs is the chain, which cannot be carried to a different weapon because
## its windows belonged to the old one.
func _on_weapon_equipped(equipped: WeaponData) -> void:
	if equipped != null:
		weapon = equipped
	close_chain()
	if visual != null:
		visual.armed = weapon != null and weapon.is_ranged
	# The clips were authored with the gun modelled into the rig, so how the body is carried is part
	# of which weapon is in hand — read off the weapon rather than off `is_ranged`, because a second
	# melee weapon with its own cycles is a `.tres` value and not another branch here.
	if animation != null:
		animation.clip_suffix = weapon.clip_suffix if weapon != null else &""


func _on_state_transitioned(state: StringName) -> void:
	EventBus.player_state_changed.emit(state)


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_damaged.emit(current, maximum)


func _on_stamina_changed(current: float, maximum: float) -> void:
	EventBus.stamina_changed.emit(current, maximum)


func _on_died() -> void:
	EventBus.player_died.emit()
	if machine != null:
		machine.current.transition_to(&"Dead")
