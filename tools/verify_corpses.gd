extends Node
## Proof that a dead farmer lands, stays, and costs a picture rather than a body.
##
## Three things have to be true at once and each of them breaks the other two if it is done wrong.
## He must **stay** — the pile is the record of the run. He must **not be an enemy any more** — the
## pool is thirty-two bodies and a fifteen-wave run kills several hundred. And he must **not sink**,
## which is what he used to do and what made the first two moot.
## Run: godot --headless --path . res://tools/verify_corpses.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const KILLING_BLOW: String = "res://data/attacks/fist_uppercut.tres"
## Long enough for a tumble to finish and the body to be handed over. The fall has its own ceiling
## of 2.5 s; this is that plus room.
const FALLS_WITHIN: float = 4.0
## How far below the ground a corpse may be found before it is sinking rather than lying. A body
## half in the sand reads as a bug, which is what the sink used to be dressed up as.
const NO_DEEPER: float = 0.35
## More bodies than the field will hold, so the ceiling has to do something.
const PAST_THE_CEILING: int = 6

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _field: CorpseField = null
var _director: SpawnDirector = null
var _leased_while_alive: int = -1


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
	await get_tree().physics_frame

	await _check_a_dead_farmer_is_laid_down_and_the_body_comes_back()
	await _check_he_is_not_buried()
	await _check_he_is_lying_down()
	await _check_the_pile_has_a_ceiling()
	_check_a_new_run_starts_on_a_clean_island()
	_report()


## The whole shape of it: one body dies, one corpse appears, and the **enemy** goes back to the pool
## so the next wave has something to lease.
func _check_a_dead_farmer_is_laid_down_and_the_body_comes_back() -> void:
	_field.clear_field()
	var pool := _director.pool
	var spare := pool.idle_count()
	var farmer := await _kill_one(Vector3(0.0, 0.0, -6.0), true)
	if farmer == null:
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
	if pool.made_count() > EnemyPool.SIZE:
		_fail(
			"the pool grew to %d bodies, which means it could not reclaim one" % pool.made_count()
		)


## He used to sink two metres and disappear. The ragdoll lands on the world layer, so what is
## checked is that nothing put him back under it afterwards.
func _check_he_is_not_buried() -> void:
	_field.clear_field()
	var at := Vector3(4.0, 0.0, -5.0)
	var farmer := await _kill_one(at)
	if farmer == null:
		return
	var corpse := _newest()
	if corpse == null:
		_fail("nothing was laid down to look at")
		return
	# The lowest **vertex**, not the origin. A rig's origin is between its feet and a body lying
	# down has its geometry elsewhere, so measuring the origin says nothing about whether a shoulder
	# is buried — which is exactly what "he sinks a little" looks like.
	var box := _box_of(corpse)
	if box.size == Vector3.ZERO:
		_fail("the corpse has no mesh, so there is nothing to be above the sand")
		return
	var ground := Ground.closest_point(_arena.get_world_3d(), box.get_center())
	if ground == Vector3.INF:
		_fail("there is no ground under the corpse to measure against")
		return
	var under := ground.y - box.position.y
	if under > NO_DEEPER:
		_fail(
			"the corpse's lowest point is %.2f m under the sand — he is sinking, not lying" % under
		)


## **Lying, not standing.** Measured rather than looked at: from a camera seventeen metres up and
## tipped fifty degrees, a body on its back and a body on its feet are genuinely hard to tell apart
## in a screenshot, and I read three of them wrong before measuring.
##
## A farmer stands 2.2 m and is 0.7 m across. Flat on the sand he is the other way round, so the
## test is simply that he is wider than he is tall — which no standing pose can satisfy and every
## fallen one does.
func _check_he_is_lying_down() -> void:
	_field.clear_field()
	var farmer := await _kill_one(Vector3(-3.0, 0.0, -6.0))
	if farmer == null:
		return
	var corpse := _newest()
	if corpse == null:
		_fail("nothing was laid down to measure")
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


## What the corpse actually occupies, in world metres. Taken off the baked mesh rather than a
## collision shape, because a corpse has no collision at all.
func _box_of(corpse: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for node: Node in _everything_under(corpse):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var here := mesh.global_transform * mesh.mesh.get_aabb()
		box = here if not found else box.merge(here)
		found = true
	return box if found else AABB()


func _everything_under(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found.append_array(_everything_under(child))
	return found


## The pile is bounded, and the oldest is what goes. A run of fifteen waves kills several hundred,
## and a skinned mesh is not free even when nothing moves it.
func _check_the_pile_has_a_ceiling() -> void:
	_field.clear_field()
	var ceiling := _field.most
	_field.most = 3
	for index: int in PAST_THE_CEILING:
		var farmer := await _kill_one(Vector3(float(index) * 2.0 - 5.0, 0.0, -7.0))
		if farmer == null:
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


## Stands a farmer up, kills him with a real blow through the hurtbox, and waits for him to land.
func _kill_one(where: Vector3, count_the_pool: bool = false) -> Enemy:
	var data := load(FARMHAND) as EnemyData
	var farmer := _director.spawn_at(data, where, 1.0, 1.0, 1.0, 1.0, null, true)
	if farmer == null or farmer.hurtbox == null:
		_fail("no farmer could be stood up")
		return null
	if count_the_pool:
		_leased_while_alive = _director.pool.idle_count()
	await get_tree().physics_frame
	var blow := HitInfo.new(load(KILLING_BLOW) as AttackData, null, false, 99.0)
	farmer.hurtbox.take_hit(blow)
	var waited := 0.0
	while waited < FALLS_WITHIN and farmer.is_inside_tree() and farmer.visible:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	return farmer


func _newest() -> Node3D:
	var children := _field.get_children()
	return children[children.size() - 1] as Node3D if not children.is_empty() else null


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"corpses OK — a dead farmer lands, stays out of the sand, hands his body back to "
				+ "the pool, and the pile has a ceiling"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("corpses FAILED — %s" % failure)
	get_tree().quit(1)
