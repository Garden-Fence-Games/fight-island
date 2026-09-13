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
## What a blow does to this body once it has landed — the push per point of `AttackData.stagger`,
## what breaking poise adds, and how long he may stay down. Preloaded rather than exported: these
## are the same figures for every attack and every archetype in the game, so there is nothing for a
## scene to choose and nothing for a pooled body to carry a stale copy of.
const KNOCKDOWN: KnockdownData = preload("res://data/combat/knockdown.tres")
## Where a stone leaves the hand and where it is aimed. Both at chest height, so a throw travels
## flat: an arc would be prettier and would also make the thing impossible to read at a glance.
##
## **The hand moved when the body did.** It was 1.1 m, which was a chest while a farmer was a 1.7 m
## capsule; the rig stands 2.21 m and 1.1 m is his waist. What it is aimed at did not move: that is
## the player's chest, and the player is still 1.8 m. `verify_sightlines` holds both figures against
## these, so a rig that ships at another height fails rather than throwing from the hip.
const THROW_HEIGHT: float = 1.44
const CHEST_HEIGHT: float = 1.0

@export var data: EnemyData = null

## Set by the pool before the body enters the tree. A hand-placed enemy wakes up fighting; a pooled
## one waits to be leased.
var pooled: bool = false
## Whether this farmer has noticed the fight. Until he has, he stands where he was put. It is one
## way for the life of the body and reset on revive: a farmer who loses interest because the player
## stepped back would make the edge of every crowd breathe in and out.
var roused: bool = false
var target: Node3D = null
var poise_left: float = 0.0
## What this wave does to him. Held per body because EnemyData is one shared resource on disk, and
## scaling it in place would raise every farmer in the game and then save the result.
var damage_scale: float = 1.0
var speed_scale: float = 1.0
var windup_scale: float = 1.0
## What this one rolled, or null for an ordinary farmer. Held rather than flattened into the
## multipliers because the money and the look need it too, and a body that is worth triple has to
## still know that when it dies.
var rank: EliteRank = null
## What the last swing to land on this body was worth, which is the one that matters: by the time
## the payout happens the swing is over. One rather than zero, so a body killed by anything that is
## not a player's attack — a headless check applying damage straight to the health — still pays.
var last_hit_worth: float = 1.0
## Which way the last blow was travelling. What sends a dying man the way he was hit rather than
## straight down, which is the difference between a body falling over and a body being killed.
var last_hit_from: Vector3 = Vector3.FORWARD
## He comes, he circles, and he never swings. The first two tutorial steps need something to hit
## that will not hit back — and a farmer standing still would teach the player that farmers do.
var passive: bool = false

## The stone this body has in the air, if any. The ranged token is held until it lands rather than
## until the throw finishes, because the design says at most one stone is in the air — and a throw
## whose recovery is shorter than its own stone's flight would otherwise let a second one go.
var _stone: Projectile = null
var _token_owed: bool = false

var _tokens: AttackTokens = null
var _gravity: float = 9.8
var _poise_window: float = 0.0
var _repath_clock: float = 0.0

@onready var health: HealthComponent = $Health
@onready var hitbox: Hitbox = $Hitbox
@onready var voice: VoiceComponent = get_node_or_null(^"Voice") as VoiceComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var machine: StateMachine = $StateMachine
@onready var visual: Node3D = $Visual
@onready var body_materials: BodyMaterialsComponent = $BodyMaterials
@onready var head_look: HeadLookComponent = get_node_or_null("HeadLook") as HeadLookComponent
@onready var animation: AnimationComponent = get_node_or_null("Animation") as AnimationComponent
@onready var ragdoll: RagdollComponent = get_node_or_null("Ragdoll") as RagdollComponent
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
	windup: float = 1.0,
	elite: EliteRank = null,
	harmless: bool = false
) -> void:
	# Assigned before anything reads it: the health below, the tint and the money all ask, and a
	# pooled body that kept a previous life's rank would come back an elite nobody rolled.
	rank = elite
	# A finisher's bonus belongs to the life it was earned in. Left behind, a recycled body would
	# pay a combo nobody threw the next time a jab knocked it over.
	last_hit_worth = 1.0
	last_hit_from = Vector3.FORWARD
	damage_scale = damage * (rank.damage_multiplier if rank != null else 1.0)
	speed_scale = speed
	windup_scale = windup
	passive = harmless
	global_position = where
	velocity = Vector3.ZERO
	rotation.y = 0.0
	target = get_tree().get_first_node_in_group(&"player") as Node3D
	_poise_window = 0.0
	roused = false
	if head_look != null:
		head_look.watching = null
		# A body that died on the ground went into the pool with its neck at rest; the next life
		# has to be able to look at somebody.
		head_look.resting = false
	# A body handed back mid-tumble comes out of the pool still tumbling, which is the kind of bug
	# that only shows up five waves in. Cheap to call when nothing is running, so it is called always.
	if ragdoll != null:
		ragdoll.stop()
	_stone = null
	_token_owed = false
	if data != null:
		poise_left = data.poise
		if health != null:
			var tougher := rank.health_multiplier if rank != null else 1.0
			health.set_max_health(data.health * health_boost * tougher, true)
		_apply_tint()
	if hurtbox != null:
		hurtbox.monitorable = true
	if hitbox != null:
		hitbox.disarm()
	set_collision_layer_value(PhysicsLayers.INDEX_ENEMY_BODY, true)
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
	set_collision_layer_value(PhysicsLayers.INDEX_ENEMY_BODY, false)
	# A flash still in flight would go on writing into the materials this body keeps, and finish in
	# whatever life it is leased for next.
	if body_materials != null:
		body_materials.stop_flash()
	visible = false
	velocity = Vector3.ZERO
	# Or the next man out of the pool finishes this one's sentence.
	if voice != null:
		voice.hush()
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


## Noticed the fight, and so has everyone standing near him.
##
## The recursion terminates on the guard rather than on a depth limit: a farmer who is already
## roused rouses nobody, so each body is visited once however the crowd is arranged.
func rouse() -> void:
	if roused:
		return
	roused = true
	# The one line he is guaranteed to say. Noticing you is the moment the fight becomes about him,
	# and it is also the moment he is furthest away — which is what gives the Doppler something to
	# do on the way in.
	if voice != null:
		voice.speak()
	# The head goes to the player the moment he is noticed, and stays there while the body walks
	# wherever the path takes it. Before that he looks where he is going, like anyone who has not
	# seen you yet.
	if head_look != null:
		head_look.watching = target
	if data == null or data.rouse_radius <= 0.0:
		return
	# The hour reaches the crowd here and nowhere else. Noticing is deliberately left alone: a
	# farmer arrives no closer than twelve metres and the thrower already notices at twelve, so a
	# night bonus on that would have every wave charging from the horizon again.
	var carries := data.rouse_radius * GameState.rouse_scale()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == null or other == self or other.roused or not other.is_alive():
			continue
		if global_position.distance_to(other.global_position) <= carries:
			other.rouse()


## What this body is worth to the wallet: what the archetype pays, what being an elite multiplies it
## by, and what the swing that finished it was worth. Private because the wallet learns it from the
## death on the bus, which is the only place it is ever asked.
func _money() -> int:
	if data == null:
		return 0
	var paid := data.money * (rank.money_multiplier if rank != null else 1)
	return roundi(float(paid) * last_hit_worth)


## Whether the player has come close enough to be noticed. Being hit does not go through here —
## a farmer struck from across the field has noticed, whatever his eyes say.
func notices_target() -> bool:
	if data == null or target == null:
		return false
	return distance_to_target() <= data.notice_radius


## Whether the player has come closer than this archetype will tolerate. Nought means he stands his
## ground, which is every archetype but the thrower.
func wants_room() -> bool:
	if data == null or data.retreat_range <= 0.0 or target == null:
		return false
	return distance_to_target() < data.retreat_range


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
func _separation() -> Vector3:
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
	var steered := (direction + _separation()).limit_length(1.0)
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


## Sends a stone on its way, and keeps the ranged token until it is spent.
func throw_at(target_position: Vector3) -> void:
	if data == null or data.attack == null or data.projectile == null:
		return
	var stone := data.projectile.instantiate() as Projectile
	if stone == null:
		push_error("%s throws something that is not a projectile" % name)
		return
	# Into the tree beside the thrower, not under it: a stone parented to a body that dies mid-flight
	# would be freed in the air.
	get_parent().add_child(stone)
	var from := global_position + Vector3.UP * THROW_HEIGHT
	stone.global_position = from
	var toward := target_position + Vector3.UP * CHEST_HEIGHT - from
	stone.launch(data.attack, self, toward, damage_scale)
	stone.spent.connect(_on_stone_spent)
	_stone = stone


## The one gate every path into WindUp goes through, which is why refusing here is all it takes to
## make a body harmless. He keeps closing and keeps circling, so he still reads as a threat.
func claim_token() -> bool:
	if passive:
		return false
	if _tokens == null:
		return true
	return _tokens.claim(self, data != null and data.is_ranged)


func release_token() -> void:
	if _tokens == null:
		return
	if _stone != null and is_instance_valid(_stone):
		# Owed, not released. Letting go here would put a second stone in the air while the first is
		# still travelling, which is the one thing the ranged pool of 1 exists to prevent.
		_token_owed = true
		return
	_token_owed = false
	_tokens.release(self, data != null and data.is_ranged)


func _on_stone_spent() -> void:
	_stone = null
	if _token_owed:
		_token_owed = false
		release_token()


## The push is the attack's own stagger figure and the direction is the way the blow travelled.
## Both are passed rather than looked up: by the time the body reacts, the swing is over.
func stagger(duration: float, from: Vector3 = Vector3.ZERO, push: float = 0.0) -> void:
	if machine == null or not is_alive():
		return
	release_token()
	machine.current.transition_to(&"Stagger", {"duration": duration, "from": from, "push": push})


func is_alive() -> bool:
	return health == null or health.is_alive()


## The archetype's colour, and the elite's glow over the top of it. The visual is scaled here and
## the body is not: an elite reads bigger without its swing quietly gaining reach.
func _apply_tint() -> void:
	if body_materials == null or visual == null:
		return
	# Multiplied over the rig's own painted colours rather than replacing them. White is the farmer
	# as he was painted; the two archetypes that have no texture of their own yet are still told
	# apart by a wash, which is what their tint was for when all three were capsules.
	body_materials.tint(data.tint)
	body_materials.glow(
		rank.glow if rank != null else Color.BLACK, rank.glow_energy if rank != null else 0.0
	)
	visual.scale = Vector3.ONE * (rank.scale if rank != null else 1.0)
	# A wave cleared mid-wind-up retires the body through `sleep()` with no state ever exiting, so
	# the tell is standing here or the next life starts leaning into a swing nobody threw.
	visual.rotation.x = 0.0


func _on_hurt(info: HitInfo) -> void:
	if not is_alive():
		return
	# Recorded here rather than on death because the hurtbox reports the contact before the health
	# is spent, so this is the last moment the killing blow is still identifiable.
	last_hit_worth = info.money_multiplier
	# And which way it was going, for the tumble. Read here for the same reason the money is: the
	# hurtbox reports the contact before the health is spent, so this is the last moment the killing
	# blow is still identifiable.
	last_hit_from = info.direction
	rouse()
	_poise_window = 2.0
	poise_left -= info.poise_damage
	var broke := poise_left <= 0.0 and data != null
	if broke:
		poise_left = data.poise
	# **Every hit throws him**, and every hit therefore opens the next one — that is what makes a
	# combo a combo rather than three swings at a man who is already walking away. Poise no longer
	# decides *whether* he reacts, only how hard: a blow that breaks it sends him sprawling, one
	# that does not rocks him where he stands and leaves him open all the same.
	var push := info.stagger * (KNOCKDOWN.broken_poise_push if broke else 1.0)
	stagger(maxf(info.stagger, 0.4), info.direction, push)


func _on_died() -> void:
	release_token()
	EventBus.enemy_died.emit(self, data.id if data != null else &"", _money())
	if machine != null:
		machine.current.transition_to(&"Dead")
