extends Node
## Bakes assets/models/char_player_stand_ins.tres — the attack clips the rig does not carry yet.
##
## The rig arrives one clip at a time, and it arrived with `idle_gun` and `walk_gun` but nothing
## for the three the gun's `.tres` files name. So the player picked the gun up, held it correctly,
## and then fired it without a single bone moving: `AnimationComponent` found no clip, fell back to
## the rest pose, and the rest pose on this rig is almost exactly the carry pose. Nothing was
## broken and nothing happened either, which is the hardest kind of gap to notice.
##
## **These are stand-ins and they are built to lose.** Every clip starts from the rig's own
## `idle_gun` pose and moves the shooting arm off it, so the body is the one the artist posed and
## only the recoil is this file's invention. `AnimationComponent` adds one only when the rig has no
## clip of that name, so the day a hand-authored `attack_gun_1` is exported the rig's wins and this
## one is never looked at again — no deletion, no coordination, no flag to remember to flip.
##
## The shape comes from the `AttackData` rather than from a number typed here: the gun comes up
## across the wind-up, the kick lands on the frame the ray is cast, and the arm is back at carry
## when the recovery ends. So an attack retuned in the inspector keeps its animation in step.
##
## Runs as a scene rather than with --script, unlike the other builders here: the guard takes its
## shape from `PlayerParry`, and a state script cannot even be compiled without the autoloads it
## talks to.
## Run: godot --headless --path . res://tools/build_clips.tscn

const RIG: String = "res://assets/models/char_player.glb"
const CARRY_CLIP: String = "idle_gun"
## What the guard is built on. The parry is not a weapon's clip — `AnimationComponent` looks for
## `parry_gun` first and falls straight back — so it stands on the empty-handed idle, and whatever
## is in the hand comes up with the hand.
const STANDING_CLIP: String = "idle"
const GUARD_CLIP: StringName = &"parry"
const OUTPUT: String = "res://assets/models/char_player_stand_ins.tres"

## The farmer, who has no attack clip at all: the telegraph froze him mid-stride and the blow that
## followed moved nothing. The lean that tells the player a blow is coming is `EnemyWindUp`'s and
## stays his — this only adds the arm, which is what says *which* farmer is swinging.
const FARMER_RIG: String = "res://assets/models/char_farmer.glb"
const FARMER_STANDING_CLIP: String = "idle"
const FARMER_OUTPUT: String = "res://assets/models/char_farmer_stand_ins.tres"
## Each archetype's attack, and how far its arm travels relative to the farmhand's straight punch.
## The reaper swings a scythe through a hundred and sixty degrees and the thrower brings an arm all
## the way over, so the same draw and the same swing at different depths is most of the difference.
const BLOWS: Dictionary[String, float] = {
	"res://data/attacks/farmhand_swing.tres": 1.0,
	"res://data/attacks/reaper_sweep.tres": 1.5,
	"res://data/attacks/thrower_stone.tres": 1.25,
}
## The clip a shot poses the body in. One, not three, and **it has no shooting arm in it.**
##
## The kick is physics now: `PlayerAttack` throws the arm at the ragdoll when the round leaves and
## the simulator eases it back. That only works if nothing else is writing those bones — an
## AnimationPlayer and a skeleton modifier both write bone poses and the clip wins, which was
## measured: the physical body swung five centimetres and the skin moved two millimetres. So the
## two joints the recoil runs through are **left out of the clip entirely**, and for the length of a
## shot the arm belongs to the physics and to nothing else.
##
## What the clip still owes is the pose underneath that — braced, gun out, legs where the artist put
## them — and that pose is the same for a tap, a double tap and a hand cannon.
const AIM_CLIP: StringName = &"aim_gun"
## How long the held pose is. Any length would do — every track has one key, so stretching it to a
## shot's duration is a no-op — and a second is what reads as a length in the inspector.
const HELD: float = 1.0

## The pirate, who is the other way round from the farmer: his rig carries a swing and nothing
## announces it. The clip is one movement across three states — he raises the club, holds it, brings
## it down, holds again, and lowers it — so the telegraph and the blow are **slices of it** rather
## than anything invented. `EnemyWindUp` stretches the first to the wind-up actually being fought
## and `EnemyAttack` plays the second over exactly the active window, which is what those two states
## do for every archetype.
const PIRATE_RIG: String = "res://assets/models/char_pirate.glb"
const PIRATE_OUTPUT: String = "res://assets/models/char_pirate_stand_ins.tres"
const PIRATE_BLOW: String = "res://data/attacks/pirate_club.tres"
const PIRATE_CLIP: String = "attack"
## Where the club stops going up and where it finishes coming down, as shares of that clip.
##
## **Measured, not guessed.** The shoulder's turn per twenty-fifth of the clip runs 3 15 28 42 56 53
## 45 32 11 4 0 0 0 2 10 23 44 53 55 51 36 27 18 10 1 0 0 — a lift, a still, a strike, a still — and
## these are the two floors between them. Splitting anywhere else puts the impact inside the
## telegraph or the telegraph inside the blow.
const PIRATE_DRAWN: float = 0.389
const PIRATE_LANDED: float = 0.694

## The bone the skinned gun hangs off, and the two joints above it. Named rather than discovered,
## because a rig that renamed them has changed enough that a stand-in built from guesses would be
## worse than none.
const SHOOTING_ARM: String = "mixamorig_RightArm"
const SHOOTING_FOREARM: String = "mixamorig_RightForeArm"
const BONE_PREFIX: String = "Armature/Skeleton3D:"

## The guard, on both arms at once: hands up and in, forearms across. Larger than the shot's
## numbers because this is a whole-body read at eleven metres rather than a flick of one wrist.
##
## `reach` is signed per side. A positive turn about local Z carries the right hand forward and the
## left hand backward — the axes mirror — so the left arm takes the negative of it and both hands
## end up in front of the same chest.
const GUARD_ARM_LIFT: float = -52.0
const GUARD_ARM_REACH: float = 36.0
const GUARD_FOREARM_LIFT: float = -58.0
const GUARD_FOREARM_REACH: float = 28.0
## How fast the hands come up. A guard that eases into place is a guard that is not up yet when the
## window it belongs to has already opened.
const GUARD_SNAP: float = 0.06

## The farmer's draw and his swing, in degrees on the shooting-side arm, before the archetype's
## depth is applied. The draw takes the arm up and back over the whole wind-up; the swing brings it
## down and through inside the active window, which is a tenth of a second and has to read.
##
## **The swing starts exactly where the draw ended.** They are built from the same numbers for that
## reason, and `verify_clips` asserts it: a blow that began from anywhere else would spend its one
## tenth of a second blending out of a pose the player had already been shown.
const DRAW_ARM_LIFT: float = -55.0
const DRAW_ARM_REACH: float = 28.0
const DRAW_FOREARM_LIFT: float = -85.0
const SWING_ARM_LIFT: float = -70.0
const SWING_ARM_REACH: float = -52.0
const SWING_FOREARM_LIFT: float = 0.0
## How much of the wind-up the arm spends still coming back. The rest is a held cock, so the last
## thing the player reads before the blow is a body that has stopped moving — which is the moment
## the lean has finished arriving too.
const DRAW_SHARE: float = 0.7


func _ready() -> void:
	_run()


func _run() -> void:
	var built := _player_stand_ins() and _farmer_stand_ins() and _pirate_stand_ins()
	get_tree().quit(0 if built else 1)


## What the player's rig is missing: three shots off the gun-carry pose and a guard off the
## empty-handed idle.
func _player_stand_ins() -> bool:
	var carry := _pose(RIG, CARRY_CLIP)
	var standing := _pose(RIG, STANDING_CLIP)
	if carry == null or standing == null:
		return false
	var library := AnimationLibrary.new()
	library.add_animation(AIM_CLIP, _aim_clip(carry))
	library.add_animation(GUARD_CLIP, _guard_clip(standing))
	return _save(library, OUTPUT)


## What the farmer's rig is missing: a draw and a blow for each archetype, both off his idle.
func _farmer_stand_ins() -> bool:
	var standing := _pose(FARMER_RIG, FARMER_STANDING_CLIP)
	if standing == null:
		return false
	var library := AnimationLibrary.new()
	for path: String in BLOWS:
		var attack := load(path) as AttackData
		if attack == null or attack.animation == &"" or attack.windup_animation == &"":
			printerr("clips: %s does not name both a wind-up and a blow" % path)
			return false
		library.add_animation(attack.windup_animation, _draw_clip(standing, attack, BLOWS[path]))
		library.add_animation(attack.animation, _swing_clip(standing, attack, BLOWS[path]))
	return _save(library, FARMER_OUTPUT)


## What the pirate's rig is missing: the two names his `AttackData` calls for, cut out of the swing
## he already has.
func _pirate_stand_ins() -> bool:
	var swinging := _pose(PIRATE_RIG, PIRATE_CLIP)
	var attack := load(PIRATE_BLOW) as AttackData
	if swinging == null:
		return false
	if attack == null or attack.animation == &"" or attack.windup_animation == &"":
		printerr("clips: %s does not name both a wind-up and a blow" % PIRATE_BLOW)
		return false
	var library := AnimationLibrary.new()
	library.add_animation(
		attack.windup_animation, _sliced(swinging, 0.0, PIRATE_DRAWN, attack.windup)
	)
	library.add_animation(
		attack.animation, _sliced(swinging, PIRATE_DRAWN, PIRATE_LANDED, attack.active)
	)
	return _save(library, PIRATE_OUTPUT)


func _save(library: AnimationLibrary, path: String) -> bool:
	if ResourceSaver.save(library, path) != OK:
		printerr("clips: could not save " + path)
		return false
	print("clips baked — %d stand-ins in %s" % [library.get_animation_list().size(), path])
	return true


## One of the rig's own clips, which every stand-in is built on top of. Null when the rig cannot be
## read or carries no such clip, because a stand-in invented from nothing would put the body in a
## pose nobody chose.
func _pose(rig_path: String, named: String) -> Animation:
	var packed := load(rig_path) as PackedScene
	if packed == null:
		printerr("clips: cannot load " + rig_path)
		return null
	var rig := packed.instantiate()
	var found: Animation = null
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player != null and player.has_animation(named):
			found = player.get_animation(named)
			break
	rig.free()
	if found == null:
		printerr("clips: %s carries no %s to build on" % [rig_path, named])
	return found


## The pose a shot is fired from: the carry pose **minus the arm that fires it**.
##
## Every track the carry pose holds is copied across at a single key, so the clip poses the whole
## body rather than leaving the legs wherever the last animation stopped them — every track except
## the shooting arm's and the shooting forearm's, which are the two the ragdoll is about to take.
## A bone nobody animates keeps the pose it was last given, so the arm is where `idle_gun` left it
## until the physics moves it, and where the physics left it until `idle_gun` comes back.
func _aim_clip(carry: Animation) -> Animation:
	var clip := Animation.new()
	clip.length = HELD
	clip.loop_mode = Animation.LOOP_NONE
	for track: int in carry.get_track_count():
		if _is_the_shooting_arm(carry.track_get_path(track)):
			continue
		_copy_pose_track(carry, track, clip)
	return clip


## Whether a track drives one of the two joints the recoil runs through. Matched on the tail of the
## path so a joint's position, rotation and scale are all caught — and only those two: the hand
## below them is not simulated and the gun hangs off it, so leaving the hand animated is what keeps
## the revolver in the fist while the arm is thrown.
func _is_the_shooting_arm(path: NodePath) -> bool:
	var named := String(path)
	return named.ends_with(SHOOTING_ARM) or named.ends_with(SHOOTING_FOREARM)


## The guard, and the reason it is worth building rather than waiting for.
##
## Without a `parry` clip the player who presses the defensive button goes to the rest pose for
## nearly half a second — arms at the sides, the body limp, in the one moment the game asks the most
## of them. That is worse than no animation.
##
## **The shape is the state's own windows, not a guess at them.** The hands snap up in a twentieth
## of a second and stay up for exactly as long as the parry can still do something, which is
## `PlayerParry.LATE_END`; they come down across the recovery, which is the window where a mashed
## parry is punished. So what the body is doing is what the rules are doing, and retuning one
## retunes the other.
func _guard_clip(standing: Animation) -> Animation:
	var clip := Animation.new()
	clip.length = PlayerParry.RECOVERY_END
	clip.loop_mode = Animation.LOOP_NONE
	for track: int in standing.get_track_count():
		_copy_pose_track(standing, track, clip)
	var held := PackedFloat32Array(
		[0.0, GUARD_SNAP, PlayerParry.LATE_END, PlayerParry.RECOVERY_END]
	)
	for side: float in [1.0, -1.0]:
		var arm := "mixamorig_RightArm" if side > 0.0 else "mixamorig_LeftArm"
		var forearm := "mixamorig_RightForeArm" if side > 0.0 else "mixamorig_LeftForeArm"
		_key_guard(clip, arm, held, _turn(GUARD_ARM_LIFT, GUARD_ARM_REACH * side))
		_key_guard(clip, forearm, held, _turn(GUARD_FOREARM_LIFT, GUARD_FOREARM_REACH * side))
	return clip


## Up, held, down. The first and last keys are the pose the clip was built on, so the guard leaves
## the body exactly where it found it.
func _key_guard(clip: Animation, bone: String, times: PackedFloat32Array, up: Quaternion) -> void:
	var track := _joint_track(clip, bone)
	if track < 0:
		return
	var standing: Quaternion = clip.rotation_track_interpolate(track, 0.0)
	clip.track_remove_key(track, 0)
	clip.rotation_track_insert_key(track, times[0], standing)
	clip.rotation_track_insert_key(track, times[1], standing * up)
	clip.rotation_track_insert_key(track, times[2], standing * up)
	clip.rotation_track_insert_key(track, times[3], standing)


## The rotation track for one bone, or -1 with a reason. A stand-in built on a pose that does not
## turn the joint it needs would silently animate nothing at all.
func _joint_track(clip: Animation, bone: String) -> int:
	var track := clip.find_track(NodePath(BONE_PREFIX + bone), Animation.TYPE_ROTATION_3D)
	if track < 0:
		printerr("clips: the pose being built on does not turn %s" % bone)
	return track


## The telegraph: the arm comes up and back over most of the wind-up, then holds cocked.
##
## Its length is nominal. The wind-up is not a constant — the waves shorten it and the hour shortens
## it again — so `EnemyWindUp` hands the real duration to `play_clip`, which stretches this to fit.
## Building it at the tuned figure only means the stretch is one at the wave it was tuned for.
func _draw_clip(standing: Animation, attack: AttackData, depth: float) -> Animation:
	var clip := Animation.new()
	clip.length = attack.windup
	clip.loop_mode = Animation.LOOP_NONE
	for track: int in standing.get_track_count():
		_copy_pose_track(standing, track, clip)
	var drawn := clip.length * DRAW_SHARE
	for pair: Array in _swinging_arm(depth, true):
		_key_path(clip, pair[0] as String, [0.0, drawn, clip.length], [null, pair[1], pair[1]])
	return clip


## The blow, from the cocked pose straight through. It starts on the last frame of the draw so the
## two read as one movement, and it lasts exactly the active window.
func _swing_clip(standing: Animation, attack: AttackData, depth: float) -> Animation:
	var clip := Animation.new()
	clip.length = maxf(attack.active, 0.001)
	clip.loop_mode = Animation.LOOP_NONE
	for track: int in standing.get_track_count():
		_copy_pose_track(standing, track, clip)
	var cocked := _swinging_arm(depth, true)
	var through := _swinging_arm(depth, false)
	for index: int in cocked.size():
		_key_path(
			clip,
			cocked[index][0] as String,
			[0.0, clip.length],
			[cocked[index][1], through[index][1]]
		)
	return clip


## The three joints a farmer swings with and how far each turns, either drawn back or followed
## through. Returned as pairs so the draw and the blow cannot be given different joints, which is
## the way the two would come apart.
func _swinging_arm(depth: float, drawn: bool) -> Array:
	var lift := DRAW_ARM_LIFT if drawn else SWING_ARM_LIFT
	var reach := DRAW_ARM_REACH if drawn else SWING_ARM_REACH
	var forearm := DRAW_FOREARM_LIFT if drawn else SWING_FOREARM_LIFT
	# Depth reaches the upper arm and the shoulder, never the elbow. How far a blow travels is how
	# far the arm comes round; multiplying the elbow as well would bend it past where an elbow goes
	# and the reaper would swing on a broken arm.
	return [
		["mixamorig_RightArm", _turn(lift * depth, reach * depth)],
		["mixamorig_RightForeArm", _turn(forearm, 0.0)],
		["mixamorig_RightShoulder", _turn(lift * depth * 0.2, 0.0)],
	]


## Keys one bone against the pose the clip was built on. A null turn means "the pose itself", which
## is how a clip starts and ends where the body already was.
func _key_path(clip: Animation, bone: String, times: Array, turns: Array) -> void:
	var track := _joint_track(clip, bone)
	if track < 0:
		return
	var standing: Quaternion = clip.rotation_track_interpolate(track, 0.0)
	clip.track_remove_key(track, 0)
	for index: int in times.size():
		var turn: Variant = turns[index]
		var pose: Quaternion = standing if turn == null else standing * (turn as Quaternion)
		clip.rotation_track_insert_key(track, times[index] as float, pose)


## A stretch of one of the rig's own clips, over a window of its own.
##
## Both ends are sampled rather than snapped to the nearest key, so the slice opens and closes
## exactly on the pose the source held at that instant — which is what makes the telegraph hand the
## blow a body it is already standing in, with no crossfade to spend a two-tenths strike on.
func _sliced(source: Animation, opens: float, closes: float, seconds: float) -> Animation:
	var clip := Animation.new()
	clip.length = seconds
	clip.loop_mode = Animation.LOOP_NONE
	var span := maxf(source.length, 0.001)
	var from := opens * span
	var to := closes * span
	var width := maxf(to - from, 0.001)
	for track: int in source.get_track_count():
		var kind := source.track_get_type(track)
		var made := clip.add_track(kind)
		clip.track_set_path(made, source.track_get_path(track))
		_insert(clip, made, kind, 0.0, _sampled(source, track, kind, from))
		for key: int in source.track_get_key_count(track):
			var when := source.track_get_key_time(track, key)
			if when <= from or when >= to:
				continue
			var value: Variant = source.track_get_key_value(track, key)
			_insert(clip, made, kind, (when - from) / width * seconds, value)
		_insert(clip, made, kind, seconds, _sampled(source, track, kind, to))
	return clip


func _sampled(source: Animation, track: int, kind: int, when: float) -> Variant:
	if kind == Animation.TYPE_POSITION_3D:
		return source.position_track_interpolate(track, when)
	if kind == Animation.TYPE_ROTATION_3D:
		return source.rotation_track_interpolate(track, when)
	if kind == Animation.TYPE_SCALE_3D:
		return source.scale_track_interpolate(track, when)
	return null


func _insert(clip: Animation, track: int, kind: int, when: float, value: Variant) -> void:
	match kind:
		Animation.TYPE_POSITION_3D:
			clip.position_track_insert_key(track, when, value as Vector3)
		Animation.TYPE_ROTATION_3D:
			clip.rotation_track_insert_key(track, when, value as Quaternion)
		Animation.TYPE_SCALE_3D:
			clip.scale_track_insert_key(track, when, value as Vector3)


func _copy_pose_track(carry: Animation, track: int, clip: Animation) -> void:
	var kind := carry.track_get_type(track)
	var made := clip.add_track(kind)
	clip.track_set_path(made, carry.track_get_path(track))
	match kind:
		Animation.TYPE_POSITION_3D:
			clip.position_track_insert_key(made, 0.0, carry.position_track_interpolate(track, 0.0))
		Animation.TYPE_ROTATION_3D:
			clip.rotation_track_insert_key(made, 0.0, carry.rotation_track_interpolate(track, 0.0))
		Animation.TYPE_SCALE_3D:
			clip.scale_track_insert_key(made, 0.0, carry.scale_track_interpolate(track, 0.0))


## A turn away from the carry pose, composed from the two axes it was measured on rather than from
## Euler angles, whose order would be one more thing to be wrong about.
func _turn(lift_degrees: float, reach_degrees: float) -> Quaternion:
	var lift := Quaternion(Vector3.RIGHT, deg_to_rad(lift_degrees))
	var reach := Quaternion(Vector3.BACK, deg_to_rad(reach_degrees))
	return lift * reach
