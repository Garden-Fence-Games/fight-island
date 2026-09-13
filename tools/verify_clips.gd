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
const FARMER_RIG: String = "res://assets/models/char_farmer.glb"
## The heading the inventory lives under, and the shape of a row in it.
const INVENTORY_HEADING: String = "## Clips the rigs do not carry yet"
const INVENTORY_CELLS: int = 3
## The clips the stand-in library exists to lend. Written out rather than read from the library,
## which would make this check agree with whatever the library happens to hold.
const LENT: Array[String] = ["attack_gun_1", "attack_gun_2", "attack_gun_3", "parry"]
const FARMER_LENT: Array[String] = [
	"windup_punch", "attack_punch", "windup_sweep", "attack_scythe", "windup_throw", "attack_throw"
]
## The farmer's attacks, and the joint a blow is read off. A draw and the blow that follows it are
## one movement split across two states, so the blow has to begin on the pose the draw ended on —
## and a blow is shorter than the crossfade into it, which is what makes that a requirement rather
## than a nicety.
const BLOWS: Array[String] = [
	"res://data/attacks/farmhand_swing.tres",
	"res://data/attacks/reaper_sweep.tres",
	"res://data/attacks/thrower_stone.tres",
]
const SWINGING_JOINT: String = "Armature/Skeleton3D:mixamorig_RightArm"
## How far apart the draw's last pose and the blow's first may be, in degrees. A tenth is a rounding
## difference; a degree is somebody having edited one of the two.
const SAME_POSE_DEGREES: float = 0.5
## The wind-up scale the telegraph is driven at while it is being watched. Deliberately not one: at
## one, a clip built at the tuned length plays at speed one whether or not anything stretched it,
## and a duration that had stopped being asked for would look exactly like one that had not.
const A_SHORTER_NIGHT: float = 0.5
## How far the playing speed may sit from the stretch the wind-up asked for.
const SAME_SPEED: float = 0.02
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
	await _check_every_blow_starts_where_its_draw_ended()
	await _check_the_farmer_actually_plays_them()
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
	_check_one_rig_lends_nothing_of_its_own(RIG, LENT)
	_check_one_rig_lends_nothing_of_its_own(FARMER_RIG, FARMER_LENT)


## Read off the file rather than out of the cache, and that is not fussiness. `AnimationComponent`
## lends by adding to the AnimationPlayer's own library, which belongs to the imported rig and is
## shared by every instance of it — so once one farmer has walked past, the cached rig answers yes
## to clips that are not in the `.glb` at all. Asking the file is the only way this check keeps
## meaning what it says.
func _check_one_rig_lends_nothing_of_its_own(rig_path: String, lent: Array[String]) -> void:
	var packed := (
		ResourceLoader.load(rig_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		as PackedScene
	)
	if packed == null:
		_fail("cannot load " + rig_path)
		return
	var rig := packed.instantiate()
	var raw: AnimationPlayer = null
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false):
		raw = node as AnimationPlayer
	if raw == null:
		_fail("the rig carries no AnimationPlayer")
		rig.free()
		return
	for clip: String in lent:
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


## The wiring, which is a different question from whether the clips exist. Both are read off the
## component rather than off the states, because what matters is the clip that ends up playing:
## a `clip_name` that answered with the wrong field, or a `clip_duration` that stopped asking the
## body how long its own telegraph is, would leave the clips on disk and the farmer still moving
## like nothing had been added.
##
## Watched at half the tuned wind-up on purpose. The waves shorten the telegraph and the hour
## shortens it again, so the clip has to stretch to the wind-up actually being fought — and at the
## tuned length that promise is invisible, because the right answer and no answer are both speed
## one.
func _check_the_farmer_actually_plays_them() -> void:
	var enemy := (load(ENEMY) as PackedScene).instantiate() as Enemy
	add_child(enemy)
	await get_tree().physics_frame
	var anim := enemy.get_node_or_null("Animation") as AnimationComponent
	if anim == null or enemy.machine == null:
		_fail("the enemy carries no AnimationComponent and no StateMachine")
		enemy.queue_free()
		return
	for path: String in BLOWS:
		var attack := load(path) as AttackData
		var data := _archetype_using(attack)
		if data == null:
			_fail("no enemy in %s attacks with %s" % [ENEMY_DATA, path])
			continue
		enemy.data = data
		enemy.revive(Vector3.ZERO, 1.0, 1.0, 1.0, A_SHORTER_NIGHT)
		await get_tree().physics_frame

		enemy.machine.current.transition_to(&"WindUp")
		await get_tree().physics_frame
		if anim.current_clip() != attack.windup_animation:
			_fail(
				(
					"%s winds up playing %s, expected %s"
					% [data.id, anim.current_clip(), attack.windup_animation]
				)
			)
		var wanted := attack.windup / maxf(enemy.windup(), 0.001)
		var speed := anim.animation_player.get_playing_speed()
		if absf(speed - wanted) > SAME_SPEED:
			_fail(
				(
					"%s plays its telegraph at %.2f and the wind-up it is fighting asks for %.2f"
					% [data.id, speed, wanted]
				)
			)

		enemy.machine.current.transition_to(&"Attack")
		await get_tree().physics_frame
		if anim.current_clip() != attack.animation:
			_fail(
				(
					"%s strikes playing %s, expected %s"
					% [data.id, anim.current_clip(), attack.animation]
				)
			)
		enemy.machine.current.transition_to(&"Idle")
		await get_tree().physics_frame
	enemy.queue_free()


## The archetype whose attack this is. Found rather than named here, so an archetype pointed at a
## different attack is a change this check follows instead of one it contradicts.
func _archetype_using(attack: AttackData) -> EnemyData:
	var directory := DirAccess.open(ENEMY_DATA)
	if directory == null or attack == null:
		return null
	for name: String in directory.get_files():
		var data := load("%s/%s" % [ENEMY_DATA, name.trim_suffix(".remap")]) as EnemyData
		if data != null and data.attack == attack:
			return data
	return null


## One movement, two states. `EnemyWindUp` draws the arm back and `EnemyAttack` throws it, and the
## handover is a crossfade the blow is shorter than — so if the two poses are not the same pose, the
## strike is spent getting to its own first frame and the player sees nothing land.
func _check_every_blow_starts_where_its_draw_ended() -> void:
	var actor := (load(ENEMY) as PackedScene).instantiate()
	add_child(actor)
	await get_tree().physics_frame
	var anim := actor.get_node_or_null("Animation") as AnimationComponent
	if anim != null and anim.animation_player != null:
		for path: String in BLOWS:
			var attack := load(path) as AttackData
			if attack == null:
				_fail("%s is not an AttackData" % path)
				continue
			_check_one_pair(anim.animation_player, attack, path)
	actor.queue_free()


func _check_one_pair(player: AnimationPlayer, attack: AttackData, path: String) -> void:
	if attack.windup_animation == &"":
		_fail("%s names a blow and no wind-up to lead into it" % path)
		return
	if not player.has_animation(String(attack.windup_animation)):
		return
	if not player.has_animation(String(attack.animation)):
		return
	var draw := player.get_animation(String(attack.windup_animation))
	var blow := player.get_animation(String(attack.animation))
	var drawn := draw.find_track(NodePath(SWINGING_JOINT), Animation.TYPE_ROTATION_3D)
	var thrown := blow.find_track(NodePath(SWINGING_JOINT), Animation.TYPE_ROTATION_3D)
	if drawn < 0 or thrown < 0:
		_fail(
			(
				"%s or %s does not turn %s"
				% [attack.windup_animation, attack.animation, SWINGING_JOINT]
			)
		)
		return
	var cocked: Quaternion = draw.rotation_track_interpolate(drawn, draw.length)
	var opens: Quaternion = blow.rotation_track_interpolate(thrown, 0.0)
	var apart := _apart(cocked, opens)
	if apart > SAME_POSE_DEGREES:
		_fail(
			(
				(
					"%s ends %.1f degrees away from where %s starts — the blow would spend itself "
					% [attack.windup_animation, apart, attack.animation]
				)
				+ "blending. Rebake with tools/build_clips.tscn"
			)
		)
	var lands: Quaternion = blow.rotation_track_interpolate(thrown, blow.length)
	if _apart(opens, lands) <= SAME_POSE_DEGREES:
		_fail("%s never moves the arm — the blow lands on nothing" % attack.animation)
	_same_length(player, String(attack.animation), attack.active, path + " active window")


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
