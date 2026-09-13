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


func _ready() -> void:
	_run()


func _run() -> void:
	var carry := _pose(CARRY_CLIP)
	if carry == null:
		get_tree().quit(1)
		return
	var library := AnimationLibrary.new()
	for path: String in SHOTS:
		var attack := load(path) as AttackData
		if attack == null:
			printerr("clips: %s is not an AttackData" % path)
			get_tree().quit(1)
			return
		if attack.animation == &"":
			printerr("clips: %s names no animation" % path)
			get_tree().quit(1)
			return
		library.add_animation(attack.animation, _shot_clip(carry, attack, SHOTS[path]))
	var standing := _pose(STANDING_CLIP)
	if standing == null:
		get_tree().quit(1)
		return
	library.add_animation(GUARD_CLIP, _guard_clip(standing))
	if ResourceSaver.save(library, OUTPUT) != OK:
		printerr("clips: could not save " + OUTPUT)
		get_tree().quit(1)
		return
	print("clips baked — %d stand-ins in %s" % [library.get_animation_list().size(), OUTPUT])
	get_tree().quit(0)


## One of the rig's own clips, which every stand-in is built on top of. Null when the rig cannot be
## read or carries no such clip, because a stand-in invented from nothing would put the body in a
## pose nobody chose.
func _pose(named: String) -> Animation:
	var packed := load(RIG) as PackedScene
	if packed == null:
		printerr("clips: cannot load " + RIG)
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
		printerr("clips: the rig carries no %s to build on" % named)
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
