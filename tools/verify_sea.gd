extends Node
## Walks the player out to sea and holds the three promises `docs/game-design.md` makes about it:
## the descent is felt before anything is lost, the sea takes health at the depth named in
## `data/world/sea.tres` and not before, and drowning ends the run through the same door every other
## death uses.
##
## The player is **placed** rather than walked. Where the sea floor happens to fall away is the
## island's business and it is rebuilt from a seed; what has to hold whatever the island looks like
## is the rule, so the rule is what this stands in front of.
##
## Whatever is on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_sea.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const STEP: float = 1.0 / 60.0
## Long enough to drown a full health bar several times over, so a check that never dies fails by
## saying so rather than by hanging.
const PATIENCE: int = 900
## Far enough out that there is nothing under the body at all — **past the terrain mesh, not merely
## past the island**. The land stops at 44 m and the mesh goes on to 66, where the sea floor is
## shallow enough to stand a body on: at sixty metres the shove was being measured against a
## collider rather than against itself, and read as the sea pushing the player *out*.
##
## The rule is what is on trial here and the rule is depth, so the check stands where no ground can
## have an opinion about it.
const OUT_TO_SEA: float = 200.0

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _area: PlayableArea = null
var _player: Player = null
var _sea: SeaData = null
var _deaths: int = 0
var _warnings: Array[float] = []


func _ready() -> void:
	_run()


func _run() -> void:
	await _open_the_arena()
	if _area == null:
		_report()
		return
	_check_the_beach_costs_nothing()
	_check_the_warning_comes_first()
	_check_the_depth_is_the_one_in_data()
	_check_the_body_goes_under()
	_check_the_sea_pushes_back()
	_check_drowning_ends_the_run()
	_report()


## Ankle-deep is the beach. Nothing is warned about, nothing is taken, and the body stands straight.
func _check_the_beach_costs_nothing() -> void:
	_stand_at(_sea.wade_depth * 0.5)
	var before := _player.health.current_health
	_area._physics_process(STEP)
	if _area.sinking() > 0.0:
		_fail("wading to the shins is already being called sinking")
	if _player.health.current_health < before:
		_fail("the beach took health")
	if _player.rig != null and not is_zero_approx(_player.rig.rotation.x):
		_fail("the body lists while standing in the shallows")


## The whole of the feature, as one assertion: **the descent is legible before anything is lost.**
## The share is on the bus and rising for the entire depth between the wading limit and the one that
## drowns, and not a point of health is gone in any of it.
func _check_the_warning_comes_first() -> void:
	_warnings.clear()
	var before := _player.health.current_health
	var depth := _sea.wade_depth
	while depth < _sea.drowns_at:
		depth += (_sea.drowns_at - _sea.wade_depth) * 0.2
		_stand_at(minf(depth, _sea.drowns_at))
		_area._physics_process(STEP)
	if _warnings.size() < 3:
		_fail("the sea said nothing on the way down — %d warnings" % _warnings.size())
	if not _warnings.is_empty() and _warnings[_warnings.size() - 1] <= _warnings[0]:
		_fail("the warning did not climb as the water did")
	if _player.health.current_health < before:
		_fail("health was taken before the water was over the head")


## The one number this is all measured from, checked at both sides of itself rather than taken on
## trust: a check that reads the depth out of the same resource the rule reads it from would pass
## for any figure at all, including one that drowns a player standing on the beach.
func _check_the_depth_is_the_one_in_data() -> void:
	_stand_at(_sea.drowns_at - 0.05)
	var above := _player.health.current_health
	_area._physics_process(STEP)
	if _player.health.current_health < above:
		_fail("the sea took health a hand's breadth above the depth it says it drowns at")
	_stand_at(_sea.drowns_at + _sea.drowns_over)
	var under := _player.health.current_health
	_area._physics_process(STEP)
	var taken := under - _player.health.current_health
	var owed := _sea.drains * STEP
	if not is_equal_approx(taken, owed):
		_fail(
			"a second at full depth costs %.1f, and the sea says %.1f" % [taken / STEP, _sea.drains]
		)


## No clip, so the tell is the body. It tips with the depth, and it lets go the moment the ragdoll
## has the body instead.
func _check_the_body_goes_under() -> void:
	if _player.rig == null:
		_fail("the player has no rig for the sea to tip")
		return
	_stand_at(_sea.drowns_at)
	_area._physics_process(STEP)
	var listed := _player.rig.rotation.x
	if listed <= 0.0:
		_fail("the body stands straight with the water over its head")
	if not is_equal_approx(rad_to_deg(listed), _sea.lists_by):
		_fail(
			(
				"the body lists %.1f° at full depth, and the sea says %.1f°"
				% [rad_to_deg(listed), _sea.lists_by]
			)
		)


## The boundary is still a boundary: what has changed is that it can be pushed against, not that it
## has been removed.
func _check_the_sea_pushes_back() -> void:
	_stand_at(_sea.drowns_at)
	var before := Vector2(_player.global_position.x, _player.global_position.z).length()
	for _frame: int in 10:
		_hold_at(_sea.drowns_at)
		_area._physics_process(STEP)
	var after := Vector2(_player.global_position.x, _player.global_position.z).length()
	if after >= before:
		_fail("the sea did not carry the player back in — %.2f m out, then %.2f" % [before, after])


## A drowning is a death, and it leaves by the door every other death leaves by.
func _check_drowning_ends_the_run() -> void:
	_player.health.minimum_health = 0.0
	var frames := 0
	while _player.is_alive() and frames < PATIENCE:
		_hold_at(_sea.drowns_at + _sea.drowns_over)
		_area._physics_process(STEP)
		frames += 1
	if _player.is_alive():
		_fail("the sea never drowned anybody, in %.1f seconds of being under" % (PATIENCE * STEP))
		return
	if _deaths != 1:
		_fail("drowning announced %d deaths on the bus, and a death is announced once" % _deaths)
	if _player.machine != null and _player.machine.current_name != &"Dead":
		_fail("the drowned player is in %s rather than Dead" % _player.machine.current_name)
	_area._physics_process(STEP)
	if _player.rig != null and not is_zero_approx(_player.rig.rotation.x):
		_fail("the sea is still tipping a body the ragdoll has taken over")


## Out to sea, at a depth below the waterline. Placed rather than walked: see the docstring.
func _stand_at(depth: float) -> void:
	_player.global_position = Vector3(OUT_TO_SEA, Water.level - depth, 0.0)


## The same depth, holding whatever the sea has done to the body sideways. Which is the point of the
## shove, so it is the one thing a check about the shove must not undo.
func _hold_at(depth: float) -> void:
	_player.global_position.y = Water.level - depth


func _open_the_arena() -> void:
	GameState.begin_run()
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	await get_tree().physics_frame
	var island := _arena.get_node_or_null("Island")
	_area = island.get_node_or_null("PlayableArea") as PlayableArea if island != null else null
	_player = _arena.get_node_or_null("Player") as Player
	if _area == null or _player == null:
		_fail("the arena is missing its playable area or its player")
		return
	_sea = PlayableArea.SEA
	# A lesson that protects the player from ever reaching nought would hide the death this is here
	# to see, and the wave director would go on sending farmers into the measurement.
	var tutorial := _arena.get_node_or_null("TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	var waves := _arena.get_node_or_null("WaveDirector") as WaveDirector
	if waves != null:
		waves.halt()
		waves.process_mode = Node.PROCESS_MODE_DISABLED
	# The states move the body every frame and this check is about where the *sea* puts it, so the
	# body is held still and placed by hand. The **state machine** is what is silenced and not the
	# player: disabling a CharacterBody3D takes it out of the physics space, and `move_and_slide`
	# then has no space to slide in. Signals arrive either way, which is how the death still reaches
	# the machine.
	if _player.machine != null:
		_player.machine.process_mode = Node.PROCESS_MODE_DISABLED
	_area.process_mode = Node.PROCESS_MODE_DISABLED
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_sinking.connect(_on_player_sinking)


func _on_player_died() -> void:
	_deaths += 1


func _on_player_sinking(share: float) -> void:
	_warnings.append(share)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			"sea OK — the descent warns, the depth in data is the depth that drowns, and it ends the run"
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
