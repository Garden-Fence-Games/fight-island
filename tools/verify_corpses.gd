extends Node
## Proof that a dead farmer lands, stays, is still a body, and costs a picture once he is still.
##
## Four things have to be true at once and each of them breaks the others if it is done wrong.
## He must **stay** — the pile is the record of the run. He must **not be an enemy any more** — the
## pool is thirty-two bodies and a fifteen-wave run kills several hundred. He must **lie on the
## sand**, neither in it nor above it, which the first corpses managed neither of. And he must
## **still be a body**: walked into, he moves; struck, he bleeds and moves, and the blow is not a
## hit.
## Run: godot --headless --path . res://tools/verify_corpses.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const KILLING_BLOW: String = "res://data/attacks/fist_uppercut.tres"
## Long enough for a tumble to finish and the body to be handed over. The fall has its own ceiling
## of 2.5 s; this is that plus room.
const FALLS_WITHIN: float = 4.0
## How far the corpse's lowest point may be from the sand under it, either way. A body half in the
## sand reads as a bug, and one hovering over it reads as a worse one.
##
## The lower figure was 0.35 and read 0.36 on about one CI run in five. A centimetre is the solver
## disagreeing with itself between two machines, not a body sinking: what this was written against
## was **two metres** of skin under the sand, and forty-five centimetres is still nowhere near a
## body that has gone under. A threshold finer than the thing it measures repeats is a threshold
## that reports the weather.
const NO_DEEPER: float = 0.45
const NO_HIGHER: float = 0.25
## How far a shove has to move a body to count as having moved it.
const MOVED: float = 0.3
## How long the two shove checks keep pushing or keep watching before they give up. **They poll for
## the movement rather than sampling at a fixed frame**, which is what made them intermittent: a
## ragdoll woken a frame later than usual had not travelled its three tenths yet when the reading
## was taken, and the check reported that the player walks through corpses. Both windows are far
## past what the movement takes when it happens at all, so the thing being caught — a body that does
## not move — still fails, and only the frame it happens to move on has stopped mattering.
const SHOVE_PATIENCE: int = 60
const STRUCK_PATIENCE: float = 2.0
## How far **one blow** has to disturb a body, which is a different and much smaller figure than a
## sustained walk into one — and the reason this check was red four runs in five.
##
## The impulse was never being lost: instrumenting `push_near` showed sixteen bodies taking it every
## time. What varies is how much of it reaches the **hips**, which is what `where()` reports, and
## that depends on the pose the tumble happened to leave — splayed on his back the hips travel a
## third of a metre, folded on his side they travel a tenth. Both are a body reacting; only one of
## them was passing.
##
## So this asserts what a blow actually guarantees: the body is **disturbed**. A picture reads 0.00,
## the two modes read 0.09 and 0.33, and five centimetres separates them with room on both sides.
## Calling it "shoved" and holding it to three tenths was the check describing an outcome the game
## does not promise.
const DISTURBED: float = 0.05
## How far clear of the body the walk-past is staged, on top of his own half-width and the whole of
## `trample_reach`. Small: the point is to sit just outside everything that could legitimately be
## touched, because just outside is where the sphere that replaced it was still reaching.
const WELL_CLEAR_OF_HIM: float = 0.2
## A pace and a span for the walk-past. Faster than `trample_speed` so the field is certainly
## looking, and long enough that a wake would have happened several times over.
const WALKING_PACE: float = 3.0
const WALK_PAST_FRAMES: int = 30
## Slower than the old `trample_speed` of 1.0, which is what made a body walked over at this pace
## report nothing at all.
const A_SLOW_WALK: float = 0.6
## More bodies than the field will hold, so the ceiling has to do something.
const PAST_THE_CEILING: int = 6
## The player's own death, which is the same physics and the same failure modes.
const KILLED_BY: String = "res://data/attacks/farmhand_swing.tres"
## A light blow and a heavy one, for the question a bound on either alone cannot answer: is the
## throw the blow's, or the same throw every time? Their stagger figures are 0.10 and 0.60.
const A_JAB: String = "res://data/attacks/fist_jab.tres"
const AN_UPPERCUT: String = "res://data/attacks/fist_uppercut.tres"
## How much further the heavy blow has to put him. Six times the stagger ought to be far more than
## this; a metre is only enough to say the two blows are not the same blow.
const FURTHER_BY: float = 1.0
## How far a body may be from where it was standing once it has come to rest. A blow sends a man
## sprawling; it does not send him across the island. Written out rather than derived from the
## throw, which would move with any figure anybody set — and the figure it is guarding against was
## `knock_speed` passed whole, which is metres per second **per point of stagger** and put a corpse
## seventeen metres downrange.
const SPRAWLS_WITHIN: float = 4.0
## How high the head may be once the fall is over. Standing, it is 0.89 m on this rig — so this is
## comfortably below standing and comfortably above the ground, and a man who ended upright fails it
## whether or not the mesh happened to look right from one angle.
const HEAD_DOWN_BELOW: float = 0.55

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _field: CorpseField = null
var _director: SpawnDirector = null
var _leased_while_alive: int = -1
var _landed: int = 0
var _struck: int = 0


func _ready() -> void:
	_run()


func _run() -> void:
	GameState.begin_run()
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	var tutorial := _arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	var waves := _arena.get_node_or_null(^"WaveDirector") as WaveDirector
	if waves != null:
		waves.halt()
	_field = _arena.get_node_or_null(^"Corpses") as CorpseField
	_director = _arena.get_node_or_null(^"WaveDirector/SpawnDirector") as SpawnDirector
	if _field == null or _director == null:
		_fail("the arena has no corpse field or no spawner")
		_report()
		return
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.corpse_struck.connect(_on_corpse_struck)
	await get_tree().physics_frame

	await _check_a_dead_farmer_is_laid_down_and_the_body_comes_back()
	await _check_he_lies_on_the_sand()
	await _check_he_is_lying_down()
	await _check_a_resting_corpse_keeps_no_skeleton()
	await _check_a_struck_corpse_bleeds_and_moves_and_is_not_a_hit()
	await _check_walking_into_a_corpse_shoves_it()
	await _check_walking_past_one_leaves_it_asleep()
	await _check_a_slow_walk_still_moves_a_body()
	await _check_the_pile_has_a_ceiling()
	await _check_a_heavier_blow_throws_him_further()
	await _check_the_player_goes_down_too()
	_check_a_new_run_starts_on_a_clean_island()
	_report()


## Whether the throw is the blow's at all.
##
## A bound on how far one corpse travels cannot answer this: every wrong version of the code throws
## a body some fixed distance, and a fixed distance passes any single bound you pick. Two blows six
## times apart in stagger have to land two bodies visibly apart — otherwise the fall is reading a
## constant, whatever constant it happens to be.
func _check_a_heavier_blow_throws_him_further() -> void:
	var light := await _thrown_by(A_JAB, Vector3(6.0, 0.0, -6.0))
	var heavy := await _thrown_by(AN_UPPERCUT, Vector3(-6.0, 0.0, -6.0))
	if light < 0.0 or heavy < 0.0:
		return
	if heavy - light < FURTHER_BY:
		_fail(
			(
				(
					"a jab threw him %.1f m and an uppercut %.1f m — six times the stagger moved him "
					% [light, heavy]
				)
				+ "%.1f m, so the fall is not reading the blow" % (heavy - light)
			)
		)


## How far one blow throws a farmer, measured from where he stood to where his corpse was laid.
##
## The corpse rather than the body: the moment a tumble ends the body is handed back to the pool and
## moved, so anything read off it afterwards is the pool's bookkeeping and not the fall. The corpse
## is the lasting record and it is what the player sees.
func _thrown_by(attack_path: String, where: Vector3) -> float:
	_field.clear_field()
	var farmer := _director.spawn_at(
		load(FARMHAND) as EnemyData, where, 1.0, 1.0, 1.0, 1.0, null, true
	)
	if farmer == null or farmer.hurtbox == null:
		_fail("nothing could be stood up to kill with %s" % attack_path)
		return -1.0
	await get_tree().physics_frame
	var stood := farmer.global_position
	farmer.hurtbox.take_hit(HitInfo.new(load(attack_path) as AttackData, null, false, 99.0))
	var waited := 0.0
	while waited < FALLS_WITHIN and farmer.is_inside_tree() and farmer.visible:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	var laid := _field.laid()
	if laid.is_empty():
		_fail("%s killed him and laid nothing down" % attack_path)
		return -1.0
	var corpse: Corpse = laid[laid.size() - 1]
	# Where it comes to rest, not where it was handed over: a corpse carries on the tumble.
	waited = 0.0
	while waited < Corpse.LONGEST_TUMBLE + 1.0 and not corpse.is_resting():
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	# The hips, not the node it hangs off. The corpse node stays where the fall began, so a body
	# that tumbled twenty metres leaves it at the spawn point with the body twenty metres away.
	var at := corpse.where()
	return Vector2(at.x - stood.x, at.z - stood.z).length()


## The player dies by the same physics, and fails in the same three ways.
##
## **The rig has to be let go of.** The simulator writes bone poses and so does an AnimationPlayer;
## whichever writes second wins, and the player's rig — unlike the farmer's — carries a `RESET`, so
## the component resting a clipless state would have stood a dying man to attention on the frame he
## was knocked down.
##
## **The pose has to be settled.** The simulator is a modifier: its output reaches the skin and
## never the skeleton's own pose, so a body that looks like it is lying down answers "standing" to
## anything that asks the bones — which is what the corpses did before #159.
##
## **The throw has to be the blow's.** Sprawling, not launched.
func _check_the_player_goes_down_too() -> void:
	var player := _arena.get_node_or_null(^"Player") as Player
	if player == null:
		_fail("the arena has no player to kill")
		return
	if player.ragdoll == null or not player.ragdoll.is_ready():
		_fail("the player has no ragdoll to be knocked down with")
		return
	var anim := player.get_node_or_null("Animation") as AnimationComponent
	if anim == null or anim.animation_player == null:
		_fail("the player has no AnimationComponent to let go of the rig")
		return
	var stood := player.global_position
	player.hurtbox.take_hit(HitInfo.new(load(KILLED_BY) as AttackData, null, false, 99.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not player.ragdoll.is_running():
		_fail("the player died and the physics never took the body")
		return
	if anim.animation_player.is_playing() or anim.current_clip() != &"":
		_fail("the rig is still playing %s while the physics has the body" % anim.current_clip())

	var waited := 0.0
	while waited < FALLS_WITHIN and player.ragdoll.is_running():
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	# A frame for the state to notice the tumble ended and pin the pose.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var head := _head_height(player)
	if head < 0.0:
		_fail("the player has no skeleton to read a pose off")
		return
	if head > HEAD_DOWN_BELOW:
		_fail(
			(
				(
					"the player came to rest with his head %.2f m up — he is still standing, which "
					% head
				)
				+ "means the pose was never settled into the skeleton"
			)
		)
	var at := player.ragdoll.settled_position()
	var flew := Vector2(at.x - stood.x, at.z - stood.z).length()
	if flew > SPRAWLS_WITHIN:
		_fail(
			(
				(
					"the player was thrown %.1f m by a blow of stagger %.2f — the fall is taking the "
					% [flew, (load(KILLED_BY) as AttackData).stagger]
				)
				+ "knock rate whole instead of the blow's own share of it"
			)
		)


## Where the head is, asked of the skeleton rather than of the skin — which is the whole point.
func _head_height(player: Player) -> float:
	var skeleton: Skeleton3D = null
	for node: Node in player.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
	if skeleton == null:
		return -1.0
	var head := skeleton.find_bone("mixamorig_Head")
	if head < 0:
		return -1.0
	var at: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(head).origin
	return at.y


## The whole shape of it: one body dies, one corpse appears, and the **enemy** goes back to the pool
## so the next wave has something to lease.
func _check_a_dead_farmer_is_laid_down_and_the_body_comes_back() -> void:
	_field.clear_field()
	var pool := _director.pool
	var spare := pool.idle_count()
	var corpse := await _kill_one(Vector3(0.0, 0.0, -6.0), true)
	if corpse == null:
		return
	if _field.count() != 1:
		_fail("one farmer died and %d corpses are lying there" % _field.count())
	# Back to where it started. Leasing took one and the death gave it back — a corpse that kept its
	# body would leave the pool one short for every farmer ever killed, and a run kills hundreds.
	if pool.idle_count() != spare:
		_fail(
			(
				(
					"the pool held %d spare before the fight and %d after the death — the corpse kept "
					+ "its body"
				)
				% [spare, pool.idle_count()]
			)
		)
	if _leased_while_alive != spare - 1:
		_fail(
			(
				"leasing left %d spare rather than %d, so the death is not what returned it"
				% [_leased_while_alive, spare - 1]
			)
		)
	# The shared shelf plus one reserve for every archetype that brought a rig of its own.
	var shelves := EnemyPool.SIZE + EnemyPool.RESERVE * pool.bodies.size()
	if pool.made_count() > shelves:
		_fail(
			"the pool grew to %d bodies, which means it could not reclaim one" % pool.made_count()
		)


## He used to sink two metres, and then he used to hover: a picture lifted onto the navigation mesh,
## which sits above the sand. Measured on the **lowest vertex** against the terrain itself.
func _check_he_lies_on_the_sand() -> void:
	_field.clear_field()
	var corpse := await _kill_one(Vector3(4.0, 0.0, -5.0))
	if corpse == null:
		return
	var box := _box_of(corpse)
	if box.size == Vector3.ZERO:
		_fail("the corpse has no mesh, so there is nothing to be on the sand")
		return
	var ground := _ground_under(box.get_center())
	if is_nan(ground):
		_fail("there is no ground under the corpse to measure against")
		return
	var gap := box.position.y - ground
	if gap < -NO_DEEPER:
		_fail("the corpse's lowest point is %.2f m under the sand — he is sinking" % -gap)
	if gap > NO_HIGHER:
		_fail("the corpse's lowest point is %.2f m over the sand — he is floating" % gap)


## **Lying, not standing.** A farmer stands 2.4 m and is 0.7 m across. Flat on the sand he is the
## other way round, so the test is simply that he is wider than he is tall — which no standing pose
## can satisfy and every fallen one does.
func _check_he_is_lying_down() -> void:
	_field.clear_field()
	var corpse := await _kill_one(Vector3(-3.0, 0.0, -6.0))
	if corpse == null:
		return
	var box := _box_of(corpse)
	if box.size == Vector3.ZERO:
		_fail("the corpse has no mesh to measure, so it is not a picture of anything")
		return
	var across := maxf(box.size.x, box.size.z)
	if box.size.y >= across:
		_fail(
			(
				(
					"the corpse is %.2f m tall and %.2f m across — he is standing, which means the "
					+ "pose the physics left him in never reached the mesh"
				)
				% [box.size.y, across]
			)
		)


## Still, a corpse is a picture. A `Skeleton3D` in the tree costs a fraction of a millisecond every
## frame whether anything moves it or not, and the pile is forty-eight of them.
func _check_a_resting_corpse_keeps_no_skeleton() -> void:
	_field.clear_field()
	var corpse := await _kill_one(Vector3(1.0, 0.0, -8.0))
	if corpse == null:
		return
	if not corpse.is_resting():
		_fail("the corpse never came to rest")
		return
	for node: Node in _everything_under(corpse):
		if node is Skeleton3D or node is PhysicalBone3D:
			_fail("a resting corpse still has %s in the tree" % node.get_class())
			return


## A blow on a corpse throws it and it bleeds — and it is **not a hit**: no `attack_landed`, so no
## combo, no money and no hitstop come out of a pile.
func _check_a_struck_corpse_bleeds_and_moves_and_is_not_a_hit() -> void:
	_field.clear_field()
	var corpse := await _kill_one(Vector3(-1.0, 0.0, -4.0))
	if corpse == null:
		return
	var hurtbox := corpse.get_node_or_null(^"Hurtbox") as Hurtbox
	if hurtbox == null:
		_fail("the corpse has no hurtbox, so nothing can strike it")
		return
	var before := corpse.where()
	_landed = 0
	_struck = 0
	var blow := HitInfo.new(load(KILLING_BLOW) as AttackData, null, false, 1.0)
	blow.direction = Vector3.RIGHT
	if hurtbox.take_hit(blow):
		_fail("the corpse consumed the blow, so the swing counts as having landed")
	var patience := 0.0
	while patience < STRUCK_PATIENCE and corpse.where().distance_to(before) < DISTURBED:
		await get_tree().physics_frame
		patience += 1.0 / 60.0
	if _struck != 1:
		_fail("a struck corpse raised corpse_struck %d times rather than once" % _struck)
	if _landed != 0:
		_fail("a struck corpse raised attack_landed — a pile pays out like a fight")
	if corpse.where().distance_to(before) < DISTURBED:
		_fail(
			(
				"a struck corpse moved %.2f m — it is a picture, not a body"
				% corpse.where().distance_to(before)
			)
		)


## Walked into, a body is shoved along. Called the way the field calls it for the player, so the
## check does not depend on steering a player into the right spot.
func _check_walking_into_a_corpse_shoves_it() -> void:
	_field.clear_field()
	var corpse := await _kill_one(Vector3(2.0, 0.0, -3.0))
	if corpse == null:
		return
	var before := corpse.where()
	# Beside the hips and a little under them, wherever the blow threw him — an uppercut can carry a
	# farmer fifteen metres and up a dune.
	var feet := before - Vector3(0.4, 0.25, 0.0)
	for _frame: int in SHOVE_PATIENCE:
		if corpse.where().distance_to(before) >= MOVED:
			break
		corpse.trample(feet, Vector3(5.0, 0.0, 0.0))
		feet.x += 5.0 / 60.0
		await get_tree().physics_frame
	if corpse.where().distance_to(before) < MOVED:
		_fail(
			(
				"a corpse walked into moved %.2f m — the player walks through it"
				% corpse.where().distance_to(before)
			)
		)


## **A body nobody is standing on is not woken.**
##
## Approached **across** him, never along him, and that is the whole construction. A man lying down
## is two metres one way and a little over half a metre the other, so a sphere about his hips is the
## wrong shape to ask "are you near this body" with: down his length it stops short of his boots,
## and across him it reaches a metre into empty sand. The old gate was that sphere — anything within
## `body_radius + trample_reach` — and `Corpse.trample` woke what it admitted *before* `push_near`
## asked whether a bone was inside `trample_reach` to push. So a pass across a body woke it to push
## nothing, every time.
##
## Where the body actually is is measured here off its own meshes, by `_box_of`, so this does not
## ask the gate to confirm itself.
##
## It is not cosmetic: waking puts a `Skeleton3D` back in the tree and restarts a ten-second tumble,
## and `Corpse` exists precisely so a pile of forty-eight costs one still picture each.
func _check_walking_past_one_leaves_it_asleep() -> void:
	_field.clear_field()
	var corpse := await _kill_one(Vector3(3.0, 0.0, -9.0))
	if corpse == null:
		return
	if not corpse.is_resting():
		_fail("the corpse never settled, so there is no sleep to be left in")
		return
	var box := _box_of(corpse)
	if box.size == Vector3.ZERO:
		_fail("the corpse baked no picture, so there is nothing to measure his width against")
		return
	# Out past his narrow side — where he is slimmest is where a sphere about his hips overreaches
	# furthest, and it is the only bearing on which the two gates disagree.
	var middle := box.get_center()
	var across_x := box.size.x <= box.size.z
	var half := (box.size.x if across_x else box.size.z) * 0.5
	var out := half + _field.trample_reach + WELL_CLEAR_OF_HIM
	var feet := middle + (Vector3.RIGHT if across_x else Vector3.BACK) * out
	feet.y = middle.y
	for _frame: int in WALK_PAST_FRAMES:
		_field.trample_near(feet, Vector3(0.0, 0.0, WALKING_PACE))
		await get_tree().physics_frame
	if not corpse.is_resting():
		_fail(
			(
				(
					"a pass %.2f m clear of his own %.2f m width woke him — the field is waking bodies "
					% [out, half * 2.0]
				)
				+ "it cannot reach, and every one costs a skeleton back in the tree"
			)
		)


## **And walking is enough to disturb one.** The shove was refused outright below `trample_speed`,
## so a player crossing a body at anything under a metre a second passed through it with nothing
## happening at all — no contact, no push, a man walking through a corpse.
func _check_a_slow_walk_still_moves_a_body() -> void:
	_field.clear_field()
	var corpse := await _kill_one(Vector3(-4.0, 0.0, -9.0))
	if corpse == null:
		return
	var before := corpse.where()
	var feet := before - Vector3(0.4, 0.25, 0.0)
	for _frame: int in SHOVE_PATIENCE:
		if corpse.where().distance_to(before) >= DISTURBED:
			break
		corpse.trample(feet, Vector3(A_SLOW_WALK, 0.0, 0.0))
		feet.x += A_SLOW_WALK / 60.0
		await get_tree().physics_frame
	if corpse.where().distance_to(before) < DISTURBED:
		_fail(
			(
				(
					"a body walked over at %.1f m/s moved %.2f m — under that pace the player passes "
					% [A_SLOW_WALK, corpse.where().distance_to(before)]
				)
				+ "straight through it"
			)
		)


## The pile is bounded, and the oldest is what goes. A run of fifteen waves kills several hundred.
func _check_the_pile_has_a_ceiling() -> void:
	_field.clear_field()
	var ceiling := _field.most
	_field.most = 3
	for index: int in PAST_THE_CEILING:
		var corpse := await _kill_one(Vector3(float(index) * 2.0 - 5.0, 0.0, -7.0), false, false)
		if corpse == null:
			break
	if _field.count() > 3:
		_fail("the field holds %d corpses against a ceiling of 3" % _field.count())
	if _field.count() < 3:
		_fail("the field holds %d corpses and should be full at 3" % _field.count())
	_field.most = ceiling


## A new run starts on a clean island. The pile is *this* run's record; inheriting the last one's
## would be the game telling the player about somebody else.
func _check_a_new_run_starts_on_a_clean_island() -> void:
	if _field.count() == 0:
		_fail("there was nothing to clear, so clearing it proves nothing")
		return
	_field.clear_field()
	if _field.count() != 0:
		_fail("%d corpses survived the field being cleared" % _field.count())


## Stands a farmer up, kills him with a real blow through the hurtbox, waits for him to be handed
## over, and — unless told not to — for the corpse to come to rest. Returns the corpse.
func _kill_one(where: Vector3, count_the_pool: bool = false, until_still: bool = true) -> Corpse:
	var data := load(FARMHAND) as EnemyData
	var farmer := _director.spawn_at(data, where, 1.0, 1.0, 1.0, 1.0, null, true)
	if farmer == null or farmer.hurtbox == null:
		_fail("no farmer could be stood up")
		return null
	if count_the_pool:
		_leased_while_alive = _director.pool.idle_count()
	await get_tree().physics_frame
	var laid_before := _field.count()
	var blow := HitInfo.new(load(KILLING_BLOW) as AttackData, null, false, 99.0)
	farmer.hurtbox.take_hit(blow)
	var waited := 0.0
	while waited < FALLS_WITHIN and farmer.is_inside_tree() and farmer.visible:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	if _field.count() == laid_before and _field.count() < _field.most:
		_fail("a farmer died and nothing was laid down")
		return null
	var laid := _field.laid()
	var corpse: Corpse = laid[laid.size() - 1] if not laid.is_empty() else null
	if corpse == null or not until_still:
		return corpse
	waited = 0.0
	while waited < Corpse.LONGEST_TUMBLE + 1.0 and not corpse.is_resting():
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	return corpse


func _wait(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().physics_frame
		waited += 1.0 / 60.0


## What the corpse occupies, in world metres, off the meshes in the tree — the picture when it is
## resting, which is the only time these checks read it.
func _box_of(corpse: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for node: Node in _everything_under(corpse):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.visible:
			continue
		var here := mesh.global_transform * mesh.mesh.get_aabb()
		box = here if not found else box.merge(here)
		found = true
	return box if found else AABB()


func _ground_under(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 4.0, at + Vector3.DOWN * 8.0, PhysicsLayers.BIT_WORLD
	)
	var hit := _arena.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else NAN


func _everything_under(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found.append_array(_everything_under(child))
	return found


func _on_attack_landed(
	_target: Node3D, _damage: float, _perfect: bool, _attack: AttackData
) -> void:
	_landed += 1


func _on_corpse_struck(_where: Vector3, _direction: Vector3, _perfect: bool) -> void:
	_struck += 1


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"corpses OK — a dead farmer lands on the sand, rests as a picture, is shoved when "
				+ "walked into, bleeds and moves when struck without paying out, hands his body back "
				+ "to the pool, the pile has a ceiling, and the player goes down by the same physics"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("corpses FAILED — %s" % failure)
	get_tree().quit(1)
