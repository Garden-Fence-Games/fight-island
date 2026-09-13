class_name CoconutDirector
extends Node
## Drops coconuts out of the island's own palms while a wave is on.
##
## **It owns a supply, not a schedule.** What a wave is worth is `enemies × per_enemy`, decided when
## the wave starts and spent over the course of it — so a wave that presses harder supplies more
## without anything here knowing what wave 11 is supposed to feel like. The one thing it enforces on
## top of that is the ceiling, and the ceiling is the whole of the balance: see `CoconutData`.
##
## **It picks a tree, not a spot.** A weapon is placed where the player can see it, because a weapon
## the player never finds is a weapon they were never given. A coconut is the opposite — it came out
## of a specific palm and it lands at the foot of that palm, and if the player did not see it fall
## then it is a coconut lying under a tree, which is exactly what it should be. So the choice is
## which tree, and the answer is one near enough to be worth walking to.

const COCONUT_SCENE: String = "res://scenes/world/coconut.tscn"
const DATA: String = "res://data/pickups/coconut.tres"
## Trees tried before giving up on this attempt. The grove has three hundred and eighty in it, so
## failing this many times means the player is somewhere with no palms rather than unlucky.
const ATTEMPTS: int = 24
## The height the camera is asked about, which is where the coconut ends up rather than the foot of
## the tree. The two differ exactly at the bottom edge of the shot, which is the blind side — asking
## about the ground accepts a spot the coconut itself is not visible on.
const SEEN_AT: float = 0.25

@export var data: CoconutData = null

var _grove: Array[Transform3D] = []
var _owed: int = 0
var _wave: int = 1
var _waited: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = GameState.run_seed + 3
	if data == null:
		data = load(DATA) as CoconutData
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	# Read once. The scatter is baked into the scene and no palm ever moves, so asking the grove
	# again each time one is wanted would be re-reading ninety-nine buffers to learn nothing new.
	_grove = PalmGrove.every(get_parent())


func _physics_process(delta: float) -> void:
	if _owed <= 0 or data == null:
		return
	_waited += delta
	if _waited < data.every:
		return
	_waited = 0.0
	if lying_about() >= data.at_once(_wave):
		return
	if drop() != null:
		_owed -= 1


## One coconut out of a palm near the player, or null when there is no tree near enough. Public so
## the headless checks can drop one without waiting for a wave and a timer.
func drop() -> Coconut:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or data == null or _grove.is_empty():
		return null
	var found := _somewhere_a_coconut_can_be_seen(player)
	var palm: Transform3D = found[0]
	var sand: Vector3 = found[1]
	if palm == Transform3D.IDENTITY or sand == Vector3.INF:
		return null
	var coconut := (load(COCONUT_SCENE) as PackedScene).instantiate() as Coconut
	coconut.data = data
	# **Added before it is placed.** `global_position` on a node outside the tree does nothing and
	# says so — the engine prints `Condition "!is_inside_tree()" is true` and the write is dropped,
	# which left coconuts at the origin until something else moved them. Both happen inside one
	# frame, so nothing is ever drawn at the wrong place.
	add_child(coconut)
	coconut.drop_from(palm, sand)
	return coconut


## How many are on the island right now. Counted rather than tallied: a coconut removes itself when
## it is taken and when it rots, and a counter kept beside that would be a second truth that drifts.
func lying_about() -> int:
	var found := 0
	for child: Node in get_children():
		if child is Coconut and not child.is_queued_for_deletion():
			found += 1
	return found


## How many palms the island gave us, for a check that wants to know the grove was found at all.
func grove_size() -> int:
	return _grove.size()


## **A tree and a landing spot together, judged where the coconut ends up.**
##
## Asking whether the *palm* is in frame is the wrong question by a metre and a half: the coconut
## lands anywhere inside `lands_within` of the foot and is then snapped to walkable ground, which
## moves it again. Judged at the palm, half the drops still landed outside the shot. So a pair is
## tried, the landing spot is what the camera is asked about, and the first pair that works wins.
##
## The fallback is deliberate and it is the last pair tried rather than nothing: a coconut behind
## the camera still beats no coconut at all.
func _somewhere_a_coconut_can_be_seen(player: Node3D) -> Array:
	var camera := get_viewport().get_camera_3d()
	var fallback: Array = [Transform3D.IDENTITY, Vector3.INF]
	for _attempt: int in ATTEMPTS:
		var palm := _a_palm_near(player)
		if palm == Transform3D.IDENTITY:
			return fallback
		var sand := _sand_under(palm, player)
		if sand == Vector3.INF:
			continue
		fallback = [palm, sand]
		if camera == null or camera.is_position_in_frustum(sand + Vector3.UP * SEEN_AT):
			return [palm, sand]
	return fallback


## A palm inside the band, chosen at random among the ones that qualify — the nearest palm to a
## player who has not moved is the same palm every time, and a supply that always arrives from one
## direction is a supply the player stops looking around for.
##
## **And one the camera can see, when there is one.** The first version picked any palm in range,
## on the reasoning that a coconut nobody watched fall is just a coconut lying under a tree. That
## was wrong in the way only a real frame shows: the camera is fixed and narrow, so **four of six**
## drops landed outside it — and at a ceiling of two on an early wave, the likeliest number of
## coconuts a player ever sees is none. The weapon pickups already had the right rule for the same
## reason; this is the same rule, with a fallback because a coconut behind the camera still beats no
## coconut at all.
##
## **Filtered rather than sampled.** The first version drew palms at random and gave up after a
## couple of dozen misses, which is a coin toss dressed as a search: `run_seed` is randomised every
## launch, so whether a wave supplied anything at all depended on which palms the draw happened to
## land on. Three hundred and eighty distance tests once every `every` seconds is not a cost worth
## being unreliable for, and this way "no coconut" means there is genuinely no tree in range.
func _a_palm_near(player: Node3D) -> Transform3D:
	var near := data.nearest * data.nearest
	var far := data.furthest * data.furthest
	var camera := get_viewport().get_camera_3d()
	var eligible: Array[Transform3D] = []
	var in_shot: Array[Transform3D] = []
	for palm: Transform3D in _grove:
		var away := palm.origin - player.global_position
		away.y = 0.0
		var span := away.length_squared()
		if span < near or span > far:
			continue
		eligible.append(palm)
		if camera != null and camera.is_position_in_frustum(palm.origin + Vector3.UP * SEEN_AT):
			in_shot.append(palm)
	var choices := in_shot if not in_shot.is_empty() else eligible
	if choices.is_empty():
		return Transform3D.IDENTITY
	return choices[_rng.randi_range(0, choices.size() - 1)]


## Ground at the foot of the tree it fell out of, and ground the player can actually walk to. The
## second half matters more than it looks: palms grow on sandbanks across bays as happily as
## anywhere, and a coconut on one of those is a promise the island cannot keep.
func _sand_under(palm: Transform3D, player: Node3D) -> Vector3:
	var world := player.get_world_3d()
	for _attempt: int in ATTEMPTS:
		var angle := _rng.randf_range(0.0, TAU)
		var out := _rng.randf_range(0.0, data.lands_within)
		var guess := palm.origin + Vector3(cos(angle), 0.0, sin(angle)) * out
		var standing := Ground.closest_point(world, guess)
		if Ground.is_spawnable(world, standing, player.global_position):
			return standing
	return Vector3.INF


## What the wave is worth, decided at the bell. The crowd is what the director was told, not what is
## alive now — a wave that the player is winning should not stop supplying because they are winning.
func _on_wave_started(wave: int, enemies: int) -> void:
	_wave = wave
	_waited = 0.0
	_owed = data.owed(enemies) if data != null else 0


## Whatever is left unspent dies with the wave. Otherwise a wave cleared early hands its unused
## supply to the next one, which is the quiet way a ceiling stops meaning anything.
func _on_wave_cleared(_wave_number: int, _reward: int) -> void:
	_owed = 0
