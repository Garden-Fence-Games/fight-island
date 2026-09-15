class_name Enemy
extends CharacterBody3D
## A farmer, or a pirate. Which archetype he is comes from EnemyData and a material; the three
## farmers share one rig and one scene, and only a body wearing a different model needs a scene of
## its own — an inherited one that overrides the rig, the data and nothing else.
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
## The rigs are modelled facing the camera and a body's forward is -Z, so every one of them is
## turned about. One figure rather than a transform per scene: a rig that disagrees is a pipeline
## fault to fix at the export, not a number to override here.
const FACING: float = PI

@export var data: EnemyData = null
## The rig this body wears. Instanced here rather than saved into the scene, because a scene that
## inherits another cannot swap a child that is already an instance — and a second archetype with a
## model of its own is exactly what inheritance is for. Everything under it is found at runtime
## anyway: the ragdoll builds its bones, the head-look builds its modifier, the animation component
## looks up the player. The rig was already replaceable; this is what makes it choosable.
@export var body: PackedScene = null

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
## What this one rolled, or null for an ordinary farmer. Non-null makes it a runner: it never
## fights, runs from the player instead of towards them, and pays what the rank says when it dies.
var rank: EliteRank = null
## What the last swing to land on this body was worth, which is the one that matters: by the time
## the payout happens the swing is over. One rather than zero, so a body killed by anything that is
## not a player's attack — a headless check applying damage straight to the health — still pays.
var last_hit_worth: float = 1.0
## Which way the last blow was travelling. What sends a dying man the way he was hit rather than
## straight down, which is the difference between a body falling over and a body being killed.
var last_hit_from: Vector3 = Vector3.FORWARD
## How hard the last blow that landed throws him, in points of `AttackData.stagger` with the poise
## multiplier already in it. Kept for the same reason the direction is: by the time he is dying, the
## swing that did it is gone. Without it the fall took `knock_speed` whole — the figure that means
## *per point of stagger* — and a farmer killed by a jab was thrown as hard as one killed by the
## heaviest blow in the game.
var last_hit_push: float = 0.0
## He comes, he circles, and he never swings. The first two tutorial steps need something to hit
## that will not hit back — and a farmer standing still would teach the player that farmers do.
var passive: bool = false

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


## The rig goes on before any component wakes up: children are readied before their parent, and
## every one of them looks for a skeleton the moment it is. Guarded because a pooled body enters
## the tree twice — once into the pool, once onto the island — and the second one would dress it
## again.
func _enter_tree() -> void:
	if body == null or has_node(^"Visual"):
		return
	var rig := body.instantiate() as Node3D
	if rig == null:
		push_error("%s was given a body that is not a Node3D." % name)
		return
	rig.name = "Visual"
	rig.rotate_y(FACING)
	add_child(rig)


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
	last_hit_push = 0.0
	damage_scale = damage
	speed_scale = speed
	windup_scale = windup
	# A runner never swings: refused the token, it can never reach WindUp.
	passive = harmless or rank != null
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
	# that only shows up five waves in. Cheap to call when nothing is running, so it is called
	# always.
	if ragdoll != null:
		ragdoll.stop()
	if data != null:
		poise_left = data.poise
		if health != null:
			health.set_max_health(data.health * health_boost, true)
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


## The wave's numbers applied to the archetype's, so no state has to know a wave exists. A runner
## runs at its rank's own speed, which the waves do not touch.
func move_speed() -> float:
	if rank != null:
		return rank.runs_at
	return (data.move_speed if data != null else 0.0) * speed_scale


## Where this body goes once it has noticed the player: at them, or — for a runner — away.
func pursuit_state() -> StringName:
	return &"Flee" if rank != null else &"Chase"


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
	# farmer arrives no closer than twelve metres and notices at nine, so a night bonus on that
	# would have every wave charging from the horizon again.
	var carries := data.rouse_radius * GameState.rouse_scale()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		# A runner is not roused by the crowd: it runs from the player's approach, not from the
		# noise.
		if other == null or other == self or other.roused or not other.is_alive() or other.rank:
			continue
		if global_position.distance_to(other.global_position) <= carries:
			other.rouse()


## What this body is worth to the wallet: what the archetype pays and what the swing that finished
## it was worth — or, for a runner, exactly the coins its rank says, since the chase is the price.
## Private because the wallet learns it from the death on the bus, the only place it is ever asked.
func _money() -> int:
	if data == null:
		return 0
	if rank != null:
		return rank.coins
	return roundi(float(data.money) * last_hit_worth)


## Whether the player has come close enough to be noticed. Being hit does not go through here —
## a farmer struck from across the field has noticed, whatever his eyes say. A runner notices from
## closer than anyone, so it can be walked up on.
func notices_target() -> bool:
	if data == null or target == null:
		return false
	var within := rank.notices_within if rank != null else data.notice_radius
	return distance_to_target() <= within


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
##
## Every body against every other, and it stays that way: the spatial grid that would flatten it has
## now been written and measured three times and thrown away three times, because at the budget of
## thirty it is the same figure. See *The crowd's cost* in `docs/architecture.md`.
##
## `tools/stress_enemies.gd` times this one rather than a copy of it, and reaches in to do it. A
## measurement taken on a copy measures whatever the copy still does — which is how a rule and the
## tool watching its cost drift apart without either of them being wrong.
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


## The one gate every path into WindUp goes through, which is why refusing here is all it takes to
## make a body harmless. He keeps closing and keeps circling, so he still reads as a threat.
func claim_token() -> bool:
	if passive:
		return false
	if _tokens == null:
		return true
	return _tokens.claim(self)


func release_token() -> void:
	if _tokens == null:
		return
	_tokens.release(self)


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
	_poise_window = KNOCKDOWN.poise_window
	poise_left -= info.poise_damage
	var broke := poise_left <= 0.0 and data != null
	if broke:
		poise_left = data.poise
	# **Every hit throws him**, and every hit therefore opens the next one — that is what makes a
	# combo a combo rather than three swings at a man who is already walking away. Poise no longer
	# decides *whether* he reacts, only how hard: a blow that breaks it sends him sprawling, one
	# that does not rocks him where he stands and leaves him open all the same.
	var push := info.stagger * (KNOCKDOWN.broken_poise_push if broke else 1.0)
	last_hit_push = push
	stagger(maxf(info.stagger, 0.4), info.direction, push)


func _on_died() -> void:
	release_token()
	EventBus.enemy_died.emit(self, data.id if data != null else &"", _money())
	if machine != null:
		machine.current.transition_to(&"Dead")
