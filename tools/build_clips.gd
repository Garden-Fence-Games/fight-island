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
## The attacks to build a stand-in for, and the weight of the kick each one throws. Relative to the
## single shot, which is one: the double tap puts two rounds down the same barrel at the same
## instant, and the charged shot is the reason the player rations the magazine.
##
## The spread is narrower than the damage is, and the rig is the reason rather than the fiction.
## This head is nearly as wide as the body: past about thirty degrees the revolver swings across
## the face instead of above it, and a charged shot scaled honestly off fifty-five damage did
## exactly that. Measured by rendering the peak frame of all three, which is the only way to find
## a ceiling that belongs to a mesh.
const SHOTS: Dictionary[String, float] = {
	"res://data/attacks/gun_single.tres": 1.0,
	"res://data/attacks/gun_double.tres": 1.3,
	"res://data/attacks/gun_charged.tres": 1.55,
}

## The stick's other two swings. The rig carries the backhand and only the backhand, so the return
## and the finisher are that same swing again over their own windows — stretched, not re-posed.
##
## **Stretched rather than re-posed because of the stick itself.** `attack_stick_1` keys `Stick` and
## `StickTrail` frame by frame; a stand-in built the way the gun's are, by turning two joints of a
## held pose, would swing an empty hand. Taking the clip's own keys takes the stick and its smear
## with them.
##
## **And it repeats rather than reverses.** The authored swing opens and closes on the grip — the
## arm is in the same place at both ends, measured at nought degrees — so playing it backwards
## travels the same arc and only moves where the fast part of it lands. That is a guess about the
## artist's timing, and a stand-in has no business making one.
##
## They are stand-ins on the same terms as the shots: the day Purple-Sigil exports a real
## `attack_stick_2` the rig's own wins and this file is never read for it again.
const SWINGS: Array[String] = [
	"res://data/attacks/stick_return.tres",
	"res://data/attacks/stick_overhead.tres",
]
## The swing the other two are made of.
const SWING_CLIP: String = "attack_stick_1"

## The bone the skinned gun hangs off, and the two joints above it. Named rather than discovered,
## because a rig that renamed them has changed enough that a stand-in built from guesses would be
## worse than none.
const SHOOTING_ARM: String = "mixamorig_RightArm"
const SHOOTING_FOREARM: String = "mixamorig_RightForeArm"
const BONE_PREFIX: String = "Armature/Skeleton3D:"

## Local rotations away from the carry pose, in degrees, added to whatever the artist posed rather
## than replacing it. Measured on this rig and not reasoned about: `idle_gun` already holds the gun
## out level, so a shot is not an arm coming up — it is a braced arm whose muzzle jumps. On
## `mixamorig_RightArm`, a positive turn about local X throws the muzzle upward and a positive turn
## about local Z pushes the whole arm forward.
##
## The brace is small on purpose. The wind-up on a tap shot is a tenth of a second, and anything
## larger than this reads as a second animation rather than as the arm stiffening.
const AIM_ARM_LIFT: float = -5.0
const AIM_ARM_REACH: float = 10.0
const AIM_FOREARM_LIFT: float = -3.0
## The kick, before the shot's weight is applied. Up and slightly back — a muzzle rising, not an arm
## thrown over a shoulder. At the charged shot's weight this is forty degrees, which is as far as a
## hand cannon should ever take an arm that has to be back on target within the recovery.
const KICK_ARM_LIFT: float = 20.0
const KICK_ARM_REACH: float = -7.0
const KICK_FOREARM_LIFT: float = 11.0

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

## How long the arm takes to come up. The wind-up is shorter than this for both tap shots, and then
## the raise simply takes the whole wind-up; the charged shot is the one that has time to aim and
## hold, which is what makes the hold read as a charge.
const RAISE_SECONDS: float = 0.18
## How long the muzzle is at the top of its kick, and how long it takes to come back down onto the
## target. Short and then slower, because a recoil snaps and a recovery does not.
const KICK_SECONDS: float = 0.05
const RECOVER_SECONDS: float = 0.14

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
	get_tree().quit(0 if _player_stand_ins() and _farmer_stand_ins() else 1)


## What the player's rig is missing: three shots off the gun-carry pose and a guard off the
## empty-handed idle.
func _player_stand_ins() -> bool:
	var carry := _pose(RIG, CARRY_CLIP)
	var standing := _pose(RIG, STANDING_CLIP)
	if carry == null or standing == null:
		return false
	var swinging := _pose(RIG, SWING_CLIP)
	if swinging == null:
		return false
	var library := AnimationLibrary.new()
	for path: String in SHOTS:
		var attack := load(path) as AttackData
		if attack == null or attack.animation == &"":
			printerr("clips: %s is not an AttackData that names an animation" % path)
			return false
		library.add_animation(attack.animation, _shot_clip(carry, attack, SHOTS[path]))
	for path: String in SWINGS:
		var attack := load(path) as AttackData
		if attack == null or attack.animation == &"":
			printerr("clips: %s is not an AttackData that names an animation" % path)
			return false
		library.add_animation(attack.animation, _retimed(swinging, attack.total_duration()))
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


## One shot, as long as the attack itself.
##
## Every track the carry pose holds is copied across at a single key, so the clip poses the whole
## body rather than leaving the legs wherever the last animation stopped them. Then the two joints
## that fire the gun get the keys that make it a shot.
func _shot_clip(carry: Animation, attack: AttackData, weight: float) -> Animation:
	var clip := Animation.new()
	clip.length = attack.total_duration()
	clip.loop_mode = Animation.LOOP_NONE
	for track: int in carry.get_track_count():
		_copy_pose_track(carry, track, clip)
	_key_joint(
		clip,
		SHOOTING_ARM,
		attack,
		weight,
		AIM_ARM_LIFT,
		AIM_ARM_REACH,
		KICK_ARM_LIFT,
		KICK_ARM_REACH
	)
	_key_joint(
		clip, SHOOTING_FOREARM, attack, weight, AIM_FOREARM_LIFT, 0.0, KICK_FOREARM_LIFT, 0.0
	)
	return clip


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


## One of the rig's own clips over a different window.
##
## Every key is kept, at its own share of the clip rather than at its own second, so the swing that
## was authored over half a second reads the same over the finisher's one-and-a-quarter — and the
## stick and its trail, which the source clip keys frame by frame, come along with the arm.
func _retimed(source: Animation, seconds: float) -> Animation:
	var clip := Animation.new()
	clip.length = seconds
	clip.loop_mode = Animation.LOOP_NONE
	var span := maxf(source.length, 0.001)
	for track: int in source.get_track_count():
		var kind := source.track_get_type(track)
		var made := clip.add_track(kind)
		clip.track_set_path(made, source.track_get_path(track))
		for key: int in source.track_get_key_count(track):
			var share := clampf(source.track_get_key_time(track, key) / span, 0.0, 1.0)
			_insert(clip, made, kind, share * seconds, source.track_get_key_value(track, key))
	return clip


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


## Replaces one bone's single carry key with the five that make a shot: still at carry, up on aim,
## held there until the ray is cast, kicked, and back down again before the recovery ends.
func _key_joint(
	clip: Animation,
	bone: String,
	attack: AttackData,
	weight: float,
	aim_lift: float,
	aim_reach: float,
	kick_lift: float,
	kick_reach: float
) -> void:
	var track := _joint_track(clip, bone)
	if track < 0:
		return
	var carry: Quaternion = clip.rotation_track_interpolate(track, 0.0)
	var aim := carry * _turn(aim_lift, aim_reach)
	var kick := carry * _turn(aim_lift + kick_lift * weight, aim_reach + kick_reach * weight)
	clip.track_remove_key(track, 0)

	var fired := attack.windup
	var raised := minf(RAISE_SECONDS, fired)
	clip.rotation_track_insert_key(track, 0.0, carry)
	clip.rotation_track_insert_key(track, raised, aim)
	if fired > raised:
		clip.rotation_track_insert_key(track, fired, aim)
	clip.rotation_track_insert_key(track, fired + KICK_SECONDS, kick)
	clip.rotation_track_insert_key(track, fired + KICK_SECONDS + RECOVER_SECONDS, aim)
	clip.rotation_track_insert_key(track, clip.length, carry)


## A turn away from the carry pose, composed from the two axes it was measured on rather than from
## Euler angles, whose order would be one more thing to be wrong about.
func _turn(lift_degrees: float, reach_degrees: float) -> Quaternion:
	var lift := Quaternion(Vector3.RIGHT, deg_to_rad(lift_degrees))
	var reach := Quaternion(Vector3.BACK, deg_to_rad(reach_degrees))
	return lift * reach
