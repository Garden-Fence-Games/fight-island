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
const LENT: Array[String] = ["attack_gun_1", "attack_gun_2", "attack_gun_3", "parry"]
## What each stand-in is as long as, and the thing it took its length from. A stand-in is built to
## the rules rather than to a number typed beside them, and this is what holds that promise after
## somebody retunes the rules and forgets to run `tools/build_clips.tscn` — the clip would go on
## playing a shape that belonged to the old windows, and nothing else in the project would notice.
const TIMED_BY: Dictionary[String, String] = {
	"attack_gun_1": "res://data/attacks/gun_single.tres",
	"attack_gun_2": "res://data/attacks/gun_double.tres",
	"attack_gun_3": "res://data/attacks/gun_charged.tres",
}
## A frame at sixty, which is finer than any window in the game is tuned to.
const SAME_LENGTH: float = 0.016
## The joint the guard is read off, and how far up it still has to be when the parry stops working.
## The length check alone would pass a clip that had the hands on the way down through the whole
## window that matters, which is the promise the guard is actually making.
const GUARD_JOINT: String = "Armature/Skeleton3D:mixamorig_RightArm"
const STILL_UP: float = 0.95
## How close to the standing pose the clip has to end. Two degrees is inside what a blend hides.
const BACK_DOWN_DEGREES: float = 2.0
const SAMPLES: int = 90
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
	await _check_the_stand_ins_still_fit_the_rules()
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


## A stand-in whose length has come away from the rule it was built to. The clip is generated, so
## the two can only agree while somebody rebakes — and the check is here rather than in the builder
## because the builder is the thing that would not have been run.
func _check_the_stand_ins_still_fit_the_rules() -> void:
	var actor := (load(PLAYER) as PackedScene).instantiate()
	add_child(actor)
	await get_tree().physics_frame
	var anim := actor.get_node_or_null("Animation") as AnimationComponent
	if anim != null and anim.animation_player != null:
		for clip: String in TIMED_BY:
			var attack := load(TIMED_BY[clip]) as AttackData
			if attack != null:
				_same_length(anim.animation_player, clip, attack.total_duration(), TIMED_BY[clip])
		_same_length(
			anim.animation_player, "parry", PlayerParry.RECOVERY_END, "PlayerParry.RECOVERY_END"
		)
		_check_the_guard_is_up_while_the_parry_works(anim.animation_player)
	actor.queue_free()


## The guard's promise, which is not about its length: **the hands are up for as long as pressing
## the button can still do something, and down by the time the state ends.** A clip that merely
## lasted the right number of seconds could have the hands falling through the entire window that
## negates a hit, and the player would be reading a body that was lying to them.
func _check_the_guard_is_up_while_the_parry_works(player: AnimationPlayer) -> void:
	if not player.has_animation("parry"):
		return
	var clip := player.get_animation("parry")
	var track := clip.find_track(NodePath(GUARD_JOINT), Animation.TYPE_ROTATION_3D)
	if track < 0:
		_fail("the guard does not turn %s, so there is no guard to read" % GUARD_JOINT)
		return
	var standing: Quaternion = clip.rotation_track_interpolate(track, 0.0)
	var peak := 0.0
	for step: int in SAMPLES + 1:
		var at := clip.length * float(step) / float(SAMPLES)
		peak = maxf(peak, _apart(standing, clip.rotation_track_interpolate(track, at)))
	if peak <= BACK_DOWN_DEGREES:
		_fail("the guard never leaves the standing pose — there is nothing to see")
		return
	var late: float = _apart(standing, clip.rotation_track_interpolate(track, PlayerParry.LATE_END))
	if late < peak * STILL_UP:
		_fail(
			(
				(
					"the guard is %.0f%% of the way down by PlayerParry.LATE_END — the hands fall "
					% ((1.0 - late / peak) * 100.0)
				)
				+ "while the parry still works. Rebake with tools/build_clips.tscn"
			)
		)
	var ended: float = _apart(
		standing, clip.rotation_track_interpolate(track, PlayerParry.RECOVERY_END)
	)
	if ended > BACK_DOWN_DEGREES:
		_fail("the guard is still %.0f degrees up when the parry state ends" % ended)


## The angle between two turns, in degrees.
func _apart(from: Quaternion, to: Quaternion) -> float:
	var between := from.inverse() * to
	return rad_to_deg(2.0 * acos(clampf(absf(between.w), -1.0, 1.0)))


func _same_length(player: AnimationPlayer, clip: String, wanted: float, source: String) -> void:
	if not player.has_animation(clip):
		return
	var got := player.get_animation(clip).length
	if absf(got - wanted) > SAME_LENGTH:
		_fail(
			(
				"%s lasts %.3fs and %s says %.3fs — rebake with tools/build_clips.tscn"
				% [clip, got, source, wanted]
			)
		)


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
