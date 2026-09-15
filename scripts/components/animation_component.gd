class_name AnimationComponent
extends Node
## Plays the clip that matches the state, and knows nothing about whose skeleton it drives.
##
## It listens to a `StateMachine` rather than being driven by the states themselves. A state that
## had to remember to start its own clip is a state that will one day forget, and the bug that
## produces is a character frozen mid-stride with no error anywhere to explain it.
##
## **A state with no clip plays nothing rather than warning.** The rig arrives one animation at a
## time, so most of this map points at clips that do not exist yet, and that is the normal state of
## affairs for a while rather than a fault to report. It also matters for the build: the gate in CI
## fails on any `WARNING` line, so a component that complained once per transition would turn main
## red for the sin of having half a rig.

## Emitted instead of logging, so a caller who does care can react without the build caring.
signal clip_missing(state_name: StringName, clip: StringName)

## The states `pace` speeds up.
const LOCOMOTION: Array[StringName] = [&"Move", &"Sprint"]

## State node name to clip name. Explicit rather than a lowercase of the state, because `Move`
## plays `walk` and no rule bridges that pair. The clip names are the fixed ones listed in
## `docs/asset-pipeline.md`; the keys are the children of the `StateMachine`.
##
## Editable so a state can be pointed at a clip that already exists — `Sprint` at `walk` while the
## sprint cycle is not exported yet, for instance.
@export var clips: Dictionary[StringName, StringName] = {
	&"Idle": &"idle",
	&"Move": &"walk",
	&"Sprint": &"walk",
	&"Dodge": &"dodge_roll",
	&"Parry": &"parry",
	&"Hurt": &"hurt",
}
## How fast each state plays its clip. Absent means the speed it was authored at.
##
## `Sprint` is here because there is no sprint cycle yet and borrowing the walk one played faster
## reads as running for almost nothing. It stays a number rather than becoming a second clip entry
## so that authoring the real cycle is one line in `clips` and one deletion here — and so that the
## borrowed look never quietly becomes the intended one.
@export var clip_speeds: Dictionary[StringName, float] = {
	&"Sprint": 2.0,
}
## Crossfade between two clips. Long enough to hide the snap, short enough that a dodge still reads
## as instant.
@export var blend_time: float = 0.12
## Both are looked up under the owner when left null, so the component survives the rig being
## reimported under different node names.
@export var animation_player: AnimationPlayer = null
@export var state_machine: StateMachine = null
## Clips to fall back on for names the rig does not carry. A Resource export, so it resolves in a
## hand-written `.tscn` where a Node export would not — see ADR 0006.
##
## **The rig always wins.** A stand-in is added only when the AnimationPlayer has no animation of
## that name, so exporting a hand-authored `attack_gun_1` retires this file's version on the spot,
## with nothing to delete and no flag to remember. That is the whole contract, and it is why the
## library is built by `tools/build_clips.gd` out of the rig's own carry pose rather than authored
## anywhere a person would be tempted to keep improving it.
@export var stand_in_clips: AnimationLibrary = null
## Looked up under the owner and optional. While the physics has the body nothing here may touch the
## rig, and this is what that is asked of rather than each state remembering to say so.
##
## **The quiet version of this bug is the expensive one.** `EnemyStagger` handles it by naming no
## clip while it falls, which works on the farmer only because his rig carries no `RESET` — the
## component stops the player instead of posing it, and the bones stay where the simulator left
## them. The player's rig does carry a `RESET`, so the same arrangement would have snapped a dying
## man upright on the frame he was knocked down. One check here rather than a rule three states have
## to keep.
@export var ragdoll: RagdollComponent = null

## Appended to a state's clip name when the rig carries that variant. `walk` becomes `walk_gun` with
## a gun in hand, and the suffix falls away again the moment a variant is missing — so a weapon may
## have a walk cycle authored and no idle, and the idle simply stays the empty-handed one.
##
## **A suffix, not a weapon.** The component still does not know what a weapon is: whoever puts one
## in the hand sets this, the same way `WeaponVisualComponent` takes a flag rather than a
## `WeaponData`. It is also what lets a `_stick` set arrive with no code change at all.
var clip_suffix: StringName = &"":
	set = set_clip_suffix
## What the locomotion clips are sped up by, on top of `clip_speeds`, so feet that cover the ground
## twice as fast are seen to. Only walking and sprinting: an attack or a roll keeps its own timing.
var pace: float = 1.0:
	set = set_pace

var _current_clip: StringName = &""
var _current_speed: float = 1.0


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	if animation_player == null:
		animation_player = Descend.first(host, AnimationPlayer) as AnimationPlayer
	if state_machine == null:
		state_machine = Descend.first(host, StateMachine) as StateMachine
	if ragdoll == null:
		ragdoll = Descend.first(host, RagdollComponent) as RagdollComponent
	if ragdoll != null:
		ragdoll.took_the_body.connect(_let_go_of_the_rig)
	_lend_the_missing_clips()
	if state_machine == null:
		return
	state_machine.transitioned.connect(_on_state_machine_transitioned)
	# The machine enters its first state inside its own _ready, which may already have run.
	if state_machine.current_name != &"":
		play_state(state_machine.current_name)


## Puts a weapon's locomotion set in force, and re-evaluates the state already running so the change
## is visible now. Picking a gun up while walking has to change the stride there and then — waiting
## for the next transition would leave the player carrying a rifle with their arms swinging free
## until they happened to stop.
##
## A state that named its own clip is deliberately left alone: an attack mid-swing belongs to the
## weapon that threw it, and restarting it here would cancel a hit that is already in the air.
func set_clip_suffix(suffix: StringName) -> void:
	if suffix == clip_suffix:
		return
	clip_suffix = suffix
	if state_machine == null or state_machine.current_name == &"":
		return
	var state := state_machine.current
	if state != null and state.has_method("clip_name") and state.call("clip_name") != &"":
		return
	play_state(state_machine.current_name)


func set_pace(value: float) -> void:
	if is_equal_approx(value, pace):
		return
	pace = value
	if state_machine != null and LOCOMOTION.has(state_machine.current_name):
		play_state(state_machine.current_name)


## Hands the rig whichever stand-ins it has no clip of its own for.
##
## Into the AnimationPlayer's own library rather than added beside it as a second one: a library
## added under a name answers to `gun/attack_gun_1`, and every clip in this project is named by the
## contract in `docs/asset-pipeline.md` without a prefix. The library belongs to the imported rig
## and is shared by every instance of it, which is why this is written to be true a second time —
## the next player to ask finds the clips already there and lends nothing.
func _lend_the_missing_clips() -> void:
	if stand_in_clips == null or animation_player == null:
		return
	var mine := animation_player.get_animation_library(&"")
	if mine == null:
		return
	for clip: StringName in stand_in_clips.get_animation_list():
		if mine.has_animation(clip):
			continue
		mine.add_animation(clip, stand_in_clips.get_animation(clip))


## The clip currently playing, or an empty name when the state has none. Readable from outside so
## the headless checks can assert on it without reaching into the AnimationPlayer.
func current_clip() -> StringName:
	return _current_clip


## True when the state had a clip and that clip exists on the rig.
##
## Locomotion clips are held rather than restarted: re-entering `Move` while already walking must
## not snap the stride back to its first frame. A clip a state names for itself goes through
## `play_clip` instead, which always restarts — a second jab has to look like a second jab.
func play_state(state_name: StringName) -> bool:
	if _physics_has_the_body():
		return false
	var clip := _variant_of(clips.get(state_name, &""))
	if clip == &"" or animation_player == null or not animation_player.has_animation(String(clip)):
		_rest()
		clip_missing.emit(state_name, clip)
		return false
	var speed: float = clip_speeds.get(state_name, 1.0)
	if LOCOMOTION.has(state_name):
		speed *= pace
	# The speed is part of "which animation is playing": `Move` and `Sprint` share the walk cycle and
	# differ only by it, so a check for the clip alone would leave a sprinting player strolling.
	var same := clip == _current_clip and is_equal_approx(speed, _current_speed)
	if not same or not animation_player.is_playing():
		animation_player.play(String(clip), blend_time, speed)
		_current_clip = clip
		_current_speed = speed
	return true


## Plays a clip by name, from the start, optionally stretched to last `seconds`. A duration of zero
## leaves the clip at the speed it was authored at. A negative `blend` takes the component's own.
func play_clip(clip: StringName, seconds: float = 0.0, blend: float = -1.0) -> bool:
	if _physics_has_the_body():
		return false
	if clip == &"" or animation_player == null or not animation_player.has_animation(String(clip)):
		_rest()
		clip_missing.emit(&"", clip)
		return false
	var speed := 1.0
	var length := animation_player.get_animation(String(clip)).length
	if seconds > 0.0 and length > 0.0:
		speed = length / seconds
	animation_player.play(String(clip), blend if blend >= 0.0 else blend_time, speed)
	_current_clip = clip
	_current_speed = speed
	return true


## A state may name its own clip, and one that does wins over the table. `Attack` is the reason:
## one state drives all nine attacks and which is running is data, so no table could answer for it.
## Everything else stays declarative, and a state that says nothing still cannot forget to animate.
##
## Asks the current state again what it wants played. For a state whose answer changes partway
## through — a knockdown that stops being a tumble and becomes a man standing up — without it
## needing a second state to say so.
func refresh() -> void:
	if state_machine != null and state_machine.current_name != &"":
		_on_state_machine_transitioned(state_machine.current_name)


## Asked here rather than pushed by the state, because `StateMachine` runs `enter` *before* it emits
## — a state that started its own clip would have it stopped again one line later.
##
## A state may also say how fast to fade in, through `clip_blend()`. The get-up is why: the ragdoll
## hands the skeleton back in its *standing* rest pose, so the usual crossfade would stand a man up
## for a tenth of a second between lying on the ground and lying on the ground.
func _on_state_machine_transitioned(state_name: StringName) -> void:
	var state := state_machine.current if state_machine != null else null
	if state != null and state.has_method("clip_name"):
		var named: StringName = state.call("clip_name")
		if named != &"":
			var seconds := 0.0
			if state.has_method("clip_duration"):
				seconds = float(state.call("clip_duration"))
			var blend := -1.0
			if state.has_method("clip_blend"):
				blend = float(state.call("clip_blend"))
			play_clip(named, seconds, blend)
			return
	play_state(state_name)


## The weapon's version of a clip when the rig has one, and the plain clip otherwise. The fallback
## is the whole point: a rig with `walk_gun` and no `idle_gun` gets an armed walk and a plain idle
## rather than a state with nothing to play, which is how this rig arrives — one clip at a time.
func _variant_of(clip: StringName) -> StringName:
	if clip == &"" or clip_suffix == &"" or animation_player == null:
		return clip
	var variant := StringName(String(clip) + String(clip_suffix))
	return variant if animation_player.has_animation(String(variant)) else clip


## Back to the imported rest pose. Without it a state with no clip would hold whatever frame the
## previous one stopped on, which reads as a crash rather than as a missing animation.
func _rest() -> void:
	_current_clip = &""
	_current_speed = 1.0
	if animation_player == null or _physics_has_the_body():
		return
	if animation_player.has_animation("RESET"):
		animation_player.play("RESET", blend_time)
	else:
		animation_player.stop()


## Whether the simulator is driving the skeleton. Both write bone poses, and the one that writes
## second wins — so an animation started during a tumble is not a small glitch, it is the tumble
## cancelled.
func _physics_has_the_body() -> bool:
	return ragdoll != null and ragdoll.is_running()


## Stops, rather than resting. `_rest()` plays the rig's `RESET`, and a body posed to its bind pose
## on the frame it was knocked down is a body that never fell. Stopping leaves the bones wherever
## they were and lets the simulator have them.
func _let_go_of_the_rig() -> void:
	_current_clip = &""
	_current_speed = 1.0
	if animation_player != null:
		animation_player.stop()
