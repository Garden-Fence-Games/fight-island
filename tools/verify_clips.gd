extends Node
## Headless proof that every clip the game asks a rig for either exists or is on a written list of
## the ones that do not exist yet.
##
## `AnimationComponent` plays nothing rather than warning when a clip is missing, and that is the
## right behaviour — the rigs arrive one clip at a time and a build that went red for half a rig
## would be a build nobody could ship. But silence is only safe while somebody knows what the
## silence covers, and nobody did: the gun's three attacks were named in `data/attacks`, absent
## from the rig, and fired without a bone moving for as long as the gun has existed. Nothing in the
## project could have told you.
##
## So the inventory in `docs/asset-pipeline.md` is the thing this check holds. A clip may be
## missing, but it may not be missing *quietly* — and a clip that arrives has to leave the list,
## which is what stops the list from becoming a page nobody has read since it was written.
## Runs as a scene rather than with --script, because the actors talk to the autoloads.
## Run: godot --headless --path . res://tools/verify_clips.tscn

const PLAYER: String = "res://scenes/actors/player.tscn"
const ENEMY: String = "res://scenes/actors/enemy.tscn"
const PIPELINE: String = "res://docs/asset-pipeline.md"
const ENEMY_DATA: String = "res://data/enemies"
const RIG: String = "res://assets/models/char_player.glb"
## The heading the inventory lives under, and the shape of a row in it.
const INVENTORY_HEADING: String = "## Clips the rigs do not carry yet"
const INVENTORY_CELLS: int = 3
## The clips the stand-in library exists to lend. Written out rather than read from the library,
## which would make this check agree with whatever the library happens to hold.
const LENT: Array[String] = ["attack_gun_1", "attack_gun_2", "attack_gun_3"]
## Fewer clips asked about than this means the walk over the actors found nothing and reported a
## tidy pass over an empty list.
const ASKED_AT_LEAST: int = 15

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	var documented := _documented_gaps()
	var asked: Array[String] = []
	var missing: Array[String] = []
	for pair: Array in [[PLAYER, _player_attacks()], [ENEMY, _enemy_attacks()]]:
		await _ask_one_actor(pair[0] as String, pair[1] as Array, asked, missing)

	if asked.size() < ASKED_AT_LEAST:
		_fail(
			(
				"only %d clips were asked for, which is fewer than the %d this project has"
				% [asked.size(), ASKED_AT_LEAST]
			)
		)
	_check_the_stand_ins_are_lent_and_not_the_rigs()
	_check_the_gaps_are_written_down(missing, documented)
	_check_the_list_has_nothing_stale(missing, documented)
	_report()


## One actor's clips: what its states name, and what its attacks name. Both, because a state with
## no clip and an attack with no clip fail the same way and neither one warns.
func _ask_one_actor(
	path: String, attacks: Array, asked: Array[String], missing: Array[String]
) -> void:
	var actor := (load(path) as PackedScene).instantiate()
	add_child(actor)
	await get_tree().physics_frame
	var anim := actor.get_node_or_null("Animation") as AnimationComponent
	if anim == null or anim.animation_player == null:
		_fail("%s carries no AnimationComponent with a rig under it" % path)
		actor.queue_free()
		return
	var wanted: Array[String] = []
	for clip: StringName in anim.clips.values():
		if clip != &"" and not wanted.has(String(clip)):
			wanted.append(String(clip))
	for clip: StringName in attacks:
		if clip != &"" and not wanted.has(String(clip)):
			wanted.append(String(clip))
	for clip: String in wanted:
		if not asked.has(clip):
			asked.append(clip)
		if not anim.animation_player.has_animation(clip) and not missing.has(clip):
			missing.append(clip)
	actor.queue_free()


func _player_attacks() -> Array:
	var named: Array = []
	for id: String in Arsenal.ORDER:
		var weapon := Arsenal.find(StringName(id))
		if weapon == null:
			_fail("the arsenal has no weapon called %s" % id)
			continue
		for index: int in weapon.chain_length():
			var attack := weapon.attack_at(index)
			if attack != null:
				named.append(attack.animation)
	return named


func _enemy_attacks() -> Array:
	var named: Array = []
	var directory := DirAccess.open(ENEMY_DATA)
	if directory == null:
		_fail("cannot read " + ENEMY_DATA)
		return named
	for name: String in directory.get_files():
		var data := load("%s/%s" % [ENEMY_DATA, name.trim_suffix(".remap")]) as EnemyData
		if data != null and data.attack != null:
			named.append(data.attack.animation)
	return named


## The contract the stand-ins are written to: the rig does not carry them, and the player does.
## Asserted from both ends, because a library that stopped being lent and a rig that grew the clips
## of its own look identical from the game's side and mean opposite things.
func _check_the_stand_ins_are_lent_and_not_the_rigs() -> void:
	var packed := load(RIG) as PackedScene
	if packed == null:
		_fail("cannot load " + RIG)
		return
	var rig := packed.instantiate()
	var raw: AnimationPlayer = null
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false):
		raw = node as AnimationPlayer
	if raw == null:
		_fail("the rig carries no AnimationPlayer")
		rig.free()
		return
	for clip: String in LENT:
		if raw.has_animation(clip):
			_fail(
				(
					(
						"the rig now carries %s of its own — delete it from the stand-in list in "
						% clip
					)
					+ "tools/build_clips.gd, and the check that guards it here"
				)
			)
	rig.free()


func _check_the_gaps_are_written_down(missing: Array[String], documented: Array[String]) -> void:
	for clip: String in missing:
		if not documented.has(clip):
			_fail(
				(
					"%s is asked for and no rig carries it, and it is not in the list under " % clip
					+ "'%s' in docs/asset-pipeline.md" % INVENTORY_HEADING
				)
			)


## A clip that has arrived has to leave the list. Without this the inventory only ever grows, and
## an inventory that is never wrong about anything is one nobody trusts enough to read.
func _check_the_list_has_nothing_stale(missing: Array[String], documented: Array[String]) -> void:
	for clip: String in documented:
		if not missing.has(clip):
			_fail(
				(
					"%s is listed as not authored yet, and it plays — take the row out of " % clip
					+ "docs/asset-pipeline.md"
				)
			)


## The clip names in the inventory table. The first cell of each row, stripped of its backticks.
func _documented_gaps() -> Array[String]:
	var file := FileAccess.open(PIPELINE, FileAccess.READ)
	if file == null:
		_fail("cannot read " + PIPELINE)
		return []
	var listed: Array[String] = []
	var inside := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("#"):
			inside = line == INVENTORY_HEADING
			continue
		if not inside or not line.begins_with("|"):
			continue
		var cells := line.split("|")
		if cells.size() != INVENTORY_CELLS + 2:
			continue
		var clip := cells[1].strip_edges().replace("`", "")
		if clip == "" or clip == "Clip" or clip.begins_with("---"):
			continue
		listed.append(clip)
	if listed.is_empty():
		_fail(
			(
				"the inventory under '%s' has no rows — the parser and the document disagree"
				% INVENTORY_HEADING
			)
		)
	return listed


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("clips OK — every clip asked for either plays or is written down as missing")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("clips: " + failure)
	get_tree().quit(1)
