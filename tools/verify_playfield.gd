extends Node
## Walks every square metre of the island the player can reach and asks the one question a fixed
## camera cannot be asked by eye: **is there anywhere the reaper's sweep has no answer?**
##
## The reaper's arc is 160° and it is aimed at the player, so he covers whichever way the player
## was most likely to go. A dodge is the answer — unless every direction a dodge could land in
## happens to fit inside one 160° window, in which case the arc covers all of them at once and
## there is nothing the player could have done. That is the corner this looks for.
##
## It reads the player's own space, not the navigation mesh. The mesh is baked for an agent a metre
## across and is pulled that far back from every obstacle; a player is half that and stands where
## the mesh does not go. Checking the mesh would pass a pocket the player can walk into.
##
## Run: godot --headless --path . res://tools/verify_playfield.tscn

const ISLAND: String = "res://scenes/world/island.tscn"
const REAPER_SWEEP: String = "res://data/attacks/reaper_sweep.tres"
## The reaper's arc, and the distance a dodge covers. Written out rather than read off the things
## that own them — a check that agrees with whatever it is checking is not a check — but the arc is
## compared against the shipped attack below, so a retune cannot leave this testing an arc the
## reaper no longer has.
const ARC_DEGREES: float = 160.0
const DODGE_DISTANCE: float = 3.2
## The player is 0.7 m across. Everything the island puts in the way is widened by this before a
## cell is called blocked, because a dodge that ends with a shoulder inside a post is not a dodge
## that landed.
const PLAYER_RADIUS: float = 0.35
## The still waterline and how deep `PlayableArea` lets anyone wade. Below the two together the sea
## pushes back, so that is the edge of the ground a dodge may land on.
const WATERLINE: float = -1.1
const WADE_DEPTH: float = 1.1
## How deep the navigation mesh follows the player in. **This is what makes the question the right
## question.** The fight happens where a reaper can stand, not everywhere a player can paddle: out
## past this the enemies do not come, and a body alone in the surf with the sea at its back is not
## in a corner, it is out of the fight. Walking the player's whole range instead flagged a sandbank
## a hundred metres out where nothing can ever swing at anybody.
const FIGHT_DEPTH: float = 0.5
## Half a metre, the same figure the navigation bake uses. Fine enough that a gap the player fits
## through is not rounded shut, coarse enough that the whole island is a hundred thousand cells
## rather than a million.
const CELL: float = 0.5
## One sample every metre. The question is about corners of the island, not about every cell of it,
## and a pocket a single metre across is not a pocket a body fits into in the first place.
const SAMPLE_STEP: int = 2
## Directions tried per sample, so a sector is ten degrees and the arc is a whole number of them.
const DIRECTIONS: int = 36

var _failures: PackedStringArray = []
var _side: int = 0
var _origin: float = 0.0
## Where a dodge may land, and where the fight can reach. The first is the wider of the two by a
## wading depth, which is the whole shape of the answer: the player's way out is larger than the
## ground the reaper had to stand on to threaten it.
var _open: PackedByteArray = []
var _fight: PackedByteArray = []


func _ready() -> void:
	var island := (load(ISLAND) as PackedScene).instantiate()
	add_child(island)
	await get_tree().physics_frame

	_check_the_arc_is_still_the_arc()
	if not _build_ground(island):
		_report()
		return
	_fight = _reach_from_the_spawn_pad(_fight)
	_check_no_corner_answers_a_sweep_with_nothing()
	_report()


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"playfield OK — every metre of ground the fight reaches leaves a dodge "
				+ "outside a %d° sweep" % int(ARC_DEGREES)
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


## The arc this is built around is the arc the reaper actually swings. Restating a balance figure is
## the house rule; restating one that has since moved is how a check goes quietly green on the wrong
## question.
func _check_the_arc_is_still_the_arc() -> void:
	var sweep := load(REAPER_SWEEP)
	if sweep == null:
		_failures.append("there is no reaper sweep to check the playfield against")
		return
	var arc: float = sweep.get("arc_degrees")
	if not is_equal_approx(arc, ARC_DEGREES):
		_failures.append(
			"the reaper sweeps %.0f°, this walks the island against %.0f°" % [arc, ARC_DEGREES]
		)


## The two grids: ground a dodge may land on, and ground the fight can reach. Both are the terrain
## above a depth, minus everything that blocks, widened by the body that has to fit.
func _build_ground(island: Node) -> bool:
	var collision := island.get_node_or_null("TerrainBody/Collision") as CollisionShape3D
	var terrain := collision.shape as HeightMapShape3D if collision != null else null
	if terrain == null:
		_failures.append("the island has no terrain to read heights off")
		return false

	var heights := terrain.map_data
	var map := terrain.map_width
	var half := float(map - 1) * 0.5
	_side = int(float(map - 1) / CELL) + 1
	_origin = -half
	_open.resize(_side * _side)
	_fight.resize(_side * _side)
	var wade_floor := WATERLINE - WADE_DEPTH
	var fight_floor := WATERLINE - FIGHT_DEPTH

	for row: int in _side:
		for column: int in _side:
			var x := _origin + float(column) * CELL
			var z := _origin + float(row) * CELL
			var near_x := clampi(int(round(x + half)), 0, map - 1)
			var near_z := clampi(int(round(z + half)), 0, map - 1)
			var height := heights[near_z * map + near_x]
			_open[row * _side + column] = 1 if height > wade_floor else 0
			_fight[row * _side + column] = 1 if height > fight_floor else 0

	for path: String in ["Props/PropColliders", "RockFormations", "Huts"]:
		var body := island.get_node_or_null(NodePath(path))
		if body == null:
			_failures.append("no colliders at " + path + " to keep the player out of")
			return false
		for node: Node in body.get_children():
			var shape := node as CollisionShape3D
			if shape != null:
				_stamp(shape)
	return true


## One collider, closed out of the open ground. The cylinder is grown by the body's radius and the
## box by the same on each side — conservative at a box's corners, which is the safe direction: a
## check that called a pocket walkable would be worse than one that called a corner blocked.
func _stamp(collision: CollisionShape3D) -> void:
	var at := collision.transform.origin
	var cylinder := collision.shape as CylinderShape3D
	var box := collision.shape as BoxShape3D
	var reach := 0.0
	if cylinder != null:
		reach = cylinder.radius + PLAYER_RADIUS
	elif box != null:
		reach = Vector2(box.size.x, box.size.z).length() * 0.5 + PLAYER_RADIUS
	else:
		return

	var basis := collision.transform.basis
	var low := _cell_of(at.x - reach, at.z - reach)
	var high := _cell_of(at.x + reach, at.z + reach)
	for row: int in range(low.y, high.y + 1):
		for column: int in range(low.x, high.x + 1):
			if row < 0 or column < 0 or row >= _side or column >= _side:
				continue
			var point := Vector3(_origin + float(column) * CELL, at.y, _origin + float(row) * CELL)
			if _inside(point - at, basis, cylinder, box):
				_open[row * _side + column] = 0
				_fight[row * _side + column] = 0


func _inside(offset: Vector3, basis: Basis, cylinder: CylinderShape3D, box: BoxShape3D) -> bool:
	if cylinder != null:
		return Vector2(offset.x, offset.z).length() < cylinder.radius + PLAYER_RADIUS
	var local := basis.inverse() * offset
	return (
		absf(local.x) < box.size.x * 0.5 + PLAYER_RADIUS
		and absf(local.z) < box.size.z * 0.5 + PLAYER_RADIUS
	)


## Everything nothing can walk to is nobody's problem. A sandbar across a channel is open ground
## and would read as the tightest corner on the island; no fight ever happens on it.
func _reach_from_the_spawn_pad(ground: PackedByteArray) -> PackedByteArray:
	var reached := PackedByteArray()
	reached.resize(ground.size())
	var start := _cell_of(0.0, 0.0)
	var queue: Array[int] = [start.y * _side + start.x]
	reached[queue[0]] = 1
	var head := 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var row := index / _side
		var column := index % _side
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_row := row + step.y
			var next_column := column + step.x
			if next_row < 0 or next_column < 0 or next_row >= _side or next_column >= _side:
				continue
			var next := next_row * _side + next_column
			if reached[next] == 1 or ground[next] == 0:
				continue
			reached[next] = 1
			queue.append(next)
	return reached


## The walk. A sample fails when every direction a dodge could land in fits inside one arc — which
## is the same as saying the directions that are *closed* leave a gap of at least 360° minus the
## arc, because the reaper picks where to point.
func _check_no_corner_answers_a_sweep_with_nothing() -> void:
	var covered := int(round(ARC_DEGREES / 360.0 * float(DIRECTIONS)))
	var tightest := DIRECTIONS + 1
	var worst := Vector2.ZERO
	var walked := 0

	for row: int in range(0, _side, SAMPLE_STEP):
		for column: int in range(0, _side, SAMPLE_STEP):
			if _fight[row * _side + column] == 0:
				continue
			walked += 1
			var here := Vector2(_origin + float(column) * CELL, _origin + float(row) * CELL)
			var landings := _landings(here)
			var span := _span(landings)
			if span < tightest:
				tightest = span
				worst = here

	if walked == 0:
		_failures.append("no ground the fight can reach is connected to the spawn pad")
		return
	if tightest <= covered:
		_failures.append(
			(
				"a dodge from %.0f, %.0f lands in %d of %d directions, all inside a %d° sweep"
				% [worst.x, worst.y, tightest, DIRECTIONS, int(ARC_DEGREES)]
			)
		)
		return
	print(
		(
			(
				"walked %d m² of ground the fight reaches; the tightest corner is at %.0f, %.0f and "
				% [walked, worst.x, worst.y]
			)
			+ "still leaves %d° of dodge" % int(round(float(tightest) / float(DIRECTIONS) * 360.0))
		)
	)


## Which of the directions around a point a dodge can actually land in.
func _landings(here: Vector2) -> PackedByteArray:
	var landings := PackedByteArray()
	landings.resize(DIRECTIONS)
	for step: int in DIRECTIONS:
		var angle := TAU * float(step) / float(DIRECTIONS)
		var to := here + Vector2(cos(angle), sin(angle)) * DODGE_DISTANCE
		var cell := _cell_of(to.x, to.y)
		var inside := cell.x >= 0 and cell.y >= 0 and cell.x < _side and cell.y < _side
		landings[step] = 1 if inside and _open[cell.y * _side + cell.x] == 1 else 0
	return landings


## The narrowest window of directions that holds every landing there is. A sweep only has no answer
## when that window fits inside the arc, so this is the number the check turns on.
func _span(landings: PackedByteArray) -> int:
	var total := 0
	for step: int in DIRECTIONS:
		total += landings[step]
	if total == 0:
		return 0
	if total == DIRECTIONS:
		return DIRECTIONS

	# The tightest window is the complement of the widest run of directions with nothing in them.
	var widest := 0
	var run := 0
	for step: int in DIRECTIONS * 2:
		if landings[step % DIRECTIONS] == 1:
			run = 0
			continue
		run += 1
		widest = maxi(widest, mini(run, DIRECTIONS))
	return DIRECTIONS - widest


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(round((x - _origin) / CELL)), int(round((z - _origin) / CELL)))
