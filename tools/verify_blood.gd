extends Node
## Headless proof that a landed blow bleeds where it travelled, and that the island keeps it.
##
## Nothing here is drawn — the renderer is a dummy — so what is checked is every decision the
## drawing rests on: which way the stains were thrown, that they came down on the ground and not the
## sea, that the mask the ground's shader reads was actually painted, that it is still painted after
## the decals that showed it have been recycled, and that a fight builds nothing while it bleeds.
## Run: godot --headless --path . res://tools/verify_blood.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const GROUND_SHADER: String = "res://assets/shaders/terrain_blood.gdshader"
## Where the farmer is struck: the spawn pad, flat and dry, so every stain has ground to land on.
const STRUCK_AT: Vector3 = Vector3(0.0, 0.0, -3.0)
## A point well out to sea. The island's land ends at 88 m from the centre.
const OUT_AT_SEA: Vector3 = Vector3(0.0, 0.0, 130.0)
## Physics frames to let a leased body settle and the world be queryable.
const SETTLE_FRAMES: int = 8
## How far above or below the farmer's feet a stain may sit and still be on the ground he stands on.
## The pad is flat to a quarter of a metre; a stain further than this landed on something else.
const ON_THE_GROUND: float = 0.6
## How many blows the persistence check lands elsewhere — comfortably more than there are decals, so
## the first stain's decal has certainly been taken back.
const MORE_THAN_THE_DECALS: int = 80
## How far from a point the ground is read for blood. Written out: about two mask pixels, and well
## inside the pool at a victim's feet, which is 0.8 m across at its smallest.
const SOAK_REACH: float = 0.4

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _blood: BloodField = null


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	var tutorial := _arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	var director := _arena.get_node_or_null("WaveDirector") as WaveDirector
	_blood = get_tree().get_first_node_in_group(&"blood") as BloodField
	if director == null or _blood == null:
		_fail("the arena has no wave director or no blood field")
		_report()
		return
	director.halt()

	_check_the_ground_reads_the_mask()
	var farmer := director.spawner.spawn_at(load(FARMHAND) as EnemyData, STRUCK_AT)
	if farmer == null:
		_fail("the pool would not lease a farmer to strike")
		_report()
		return
	farmer.passive = true
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	await _check_a_blow_bleeds_the_way_it_travelled(farmer)
	_check_a_perfect_blow_spills_more(farmer)
	_check_the_island_keeps_what_the_decals_let_go(farmer)
	_check_the_sea_stays_clean()
	farmer.passive = false
	farmer.retire()
	_report()


## The ground has to be drawn by the shader that reads the mask, and holding the very mask the field
## paints. A terrain left on its old material would bleed decals and never keep a drop.
func _check_the_ground_reads_the_mask() -> void:
	var terrain := _arena.find_child("Terrain", true, false) as MeshInstance3D
	if terrain == null:
		_fail("the arena has no terrain to stain")
		return
	var material := terrain.material_override as ShaderMaterial
	if (
		material == null
		or material.shader == null
		or material.shader.resource_path != GROUND_SHADER
	):
		_fail("the ground is not drawn by %s, so nothing it soaks up is ever seen" % GROUND_SHADER)
		return
	if not (material.get_shader_parameter(&"blood_mask") is Texture2D):
		_fail("the ground's shader has no blood mask to read")


## The whole feature in one blow: a splash is thrown, stains come down on the ground around his
## feet, they lie **downstream** of where he was hit from, and the mask under him is soaked.
func _check_a_blow_bleeds_the_way_it_travelled(farmer: Enemy) -> void:
	var pool := get_tree().get_first_node_in_group(&"effects") as EffectPool
	var decals_before := _blood.decals_made()
	farmer.last_hit_from = Vector3.RIGHT
	var feet := farmer.global_position
	EventBus.attack_landed.emit(farmer, 10.0, false, null)
	await get_tree().process_frame
	var splashes := 0
	for node: Node in _arena.find_children("*", "BloodSplash", true, false):
		var splash := node as BloodSplash
		if splash != null and splash.visible and splash.drops.emitting:
			splashes += 1
	if splashes == 0:
		_fail("a blow landed and no blood was thrown")
	_blood.settle_now()
	var decals := _blood.showing_decals()
	if decals.is_empty():
		_fail("a blow landed and not one stain came down")
		return
	var downstream := 0.0
	for decal: Decal in decals:
		if absf(decal.global_position.y - feet.y) > ON_THE_GROUND:
			_fail(
				(
					"a stain came down %.2f m off the ground he was standing on"
					% (decal.global_position.y - feet.y)
				)
			)
		downstream += (decal.global_position - feet).dot(Vector3.RIGHT)
	if decals.size() > 1 and downstream <= 0.0:
		_fail("the blow travelled one way and the blood was thrown back the other")
	if _soaked_around(feet) <= 0.0:
		_fail("the ground under a man who was just struck is not soaked at all")
	if _blood.decals_made() != decals_before:
		_fail("a blow built %d decals" % (_blood.decals_made() - decals_before))
	if pool != null:
		# A splash built here would have been built mid-fight: the pool warms its batch on first ask.
		# Each is finished before the next blow, as `verify_vfx` does with impacts — a dozen blows in
		# one frame would be fourteen a second, and would measure the batch size rather than the pool.
		var made := pool.made_count()
		for _index: int in 12:
			_finish_the_splashes()
			EventBus.attack_landed.emit(farmer, 10.0, false, null)
		if pool.made_count() != made:
			_fail("a dozen blows built %d more effects" % (pool.made_count() - made))
		_finish_the_splashes()
		_blood.settle_now()


## The wettest the ground is within `SOAK_REACH` of a point.
##
## **Not the one pixel under it.** The mask is eighteen centimetres a pixel and a stain is stamped
## where its droplets land, up to 0.3 m downstream and drawn with its pool left of centre — so the
## single pixel under his feet came out dry in 8% of 400 measured spills while the ground around it
## never once did. A check on that pixel failed one CI run in twelve for a body lying in blood.
func _soaked_around(where: Vector3) -> float:
	var wettest := 0.0
	var step := SOAK_REACH / 2.0
	for x: int in range(-2, 3):
		for z: int in range(-2, 3):
			wettest = maxf(wettest, _blood.soaked_at(where + Vector3(x * step, 0.0, z * step)))
	return wettest


func _finish_the_splashes() -> void:
	for node: Node in _arena.find_children("*", "BloodSplash", true, false):
		var splash := node as BloodSplash
		if splash != null and splash.visible:
			splash.finish_now()


## A perfect blow already differs three ways in `Impact`. It spills more stains too. Summed over a
## few blows, so one stain thrown off the edge of a rock cannot decide it.
func _check_a_perfect_blow_spills_more(farmer: Enemy) -> void:
	var feet := farmer.global_position
	var plain := 0
	var perfect := 0
	for _index: int in 6:
		plain += _blood.spill(feet, Vector3.RIGHT, false)
		perfect += _blood.spill(feet, Vector3.RIGHT, true)
	_blood.settle_now()
	if perfect <= plain:
		_fail("six perfect blows left %d stains and six plain ones %d" % [perfect, plain])


## The island's memory: strike one spot, then strike elsewhere until every decal has been taken back
## — and the first spot is still soaked, because the mask was never a decal.
func _check_the_island_keeps_what_the_decals_let_go(farmer: Enemy) -> void:
	var first := farmer.global_position + Vector3(-4.0, 0.0, 0.0)
	_blood.spill(first, Vector3.FORWARD, true)
	_blood.settle_now()
	var soaked := _soaked_around(first)
	if soaked <= 0.0:
		_fail("a spill on the pad left the mask dry")
		return
	var made := _blood.decals_made()
	for index: int in MORE_THAN_THE_DECALS:
		var elsewhere := farmer.global_position + Vector3(4.0, 0.0, float(index % 8) - 4.0)
		_blood.spill(elsewhere, Vector3.RIGHT, false)
		_blood.settle_now()
	if _blood.decals_made() != made:
		_fail("%d blows built %d decals" % [MORE_THAN_THE_DECALS, _blood.decals_made() - made])
	if _blood.stains_showing() > made:
		_fail("more stains are showing than there are decals")
	if _soaked_around(first) < soaked:
		_fail("the first stain faded out of the mask once its decal was taken back")


## The sea is not a canvas. A blow over the water leaves nothing behind.
func _check_the_sea_stays_clean() -> void:
	var landed := _blood.spill(OUT_AT_SEA, Vector3.FORWARD, true)
	_blood.settle_now()
	if landed > 0:
		_fail("blood spilled over the sea put down %d stains on the water" % landed)
	if _blood.soaked_at(OUT_AT_SEA) > 0.0:
		_fail("blood spilled over the sea soaked into it")


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"blood OK — the ground reads the mask, a blow bleeds the way it travelled and onto "
				+ "the ground, a perfect one spills more, the island keeps every stain after its "
				+ "decal is gone, a fight builds nothing, and the sea stays clean"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
