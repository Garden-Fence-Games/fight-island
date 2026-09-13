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
	&"Dead": &"death",
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

## Appended to a state's clip name when the rig carries that variant. `walk` becomes `walk_gun` with
## a gun in hand, and the suffix falls away again the moment a variant is missing — so a weapon may
## have a walk cycle authored and no idle, and the idle simply stays the empty-handed one.
##
## **A suffix, not a weapon.** The component still does not know what a weapon is: whoever puts one
## in the hand sets this, the same way `WeaponVisualComponent` takes a flag rather than a
## `WeaponData`. It is also what lets a `_stick` set arrive with no code change at all.
var clip_suffix: StringName = &"":
	set = set_clip_suffix

var _current_clip: StringName = &""
var _current_speed: float = 1.0


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	if animation_player == null:
		animation_player = _find_animation_player(host)
	if state_machine == null:
		state_machine = _find_state_machine(host)
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
	var clip := _variant_of(clips.get(state_name, &""))
	if clip == &"" or animation_player == null or not animation_player.has_animation(String(clip)):
		_rest()
		clip_missing.emit(state_name, clip)
		return false
	var speed: float = clip_speeds.get(state_name, 1.0)
	# The speed is part of "which animation is playing": `Move` and `Sprint` share the walk cycle and
	# differ only by it, so a check for the clip alone would leave a sprinting player strolling.
	var same := clip == _current_clip and is_equal_approx(speed, _current_speed)
	if not same or not animation_player.is_playing():
		animation_player.play(String(clip), blend_time, speed)
		_current_clip = clip
		_current_speed = speed
	return true


## Plays a clip by name, from the start, optionally stretched to last `seconds`. A duration of zero
## leaves the clip at the speed it was authored at.
func play_clip(clip: StringName, seconds: float = 0.0) -> bool:
	if clip == &"" or animation_player == null or not animation_player.has_animation(String(clip)):
		_rest()
		clip_missing.emit(&"", clip)
		return false
	var speed := 1.0
	var length := animation_player.get_animation(String(clip)).length
	if seconds > 0.0 and length > 0.0:
		speed = length / seconds
	animation_player.play(String(clip), blend_time, speed)
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
func _on_state_machine_transitioned(state_name: StringName) -> void:
	var state := state_machine.current if state_machine != null else null
	if state != null and state.has_method("clip_name"):
		var named: StringName = state.call("clip_name")
		if named != &"":
			var seconds := 0.0
			if state.has_method("clip_duration"):
				seconds = float(state.call("clip_duration"))
			play_clip(named, seconds)
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
	if animation_player == null:
		return
	if animation_player.has_animation("RESET"):
		animation_player.play("RESET", blend_time)
	else:
		animation_player.stop()


## Depth-first: the importer buries the AnimationPlayer under the glTF scene root.
func _find_animation_player(root: Node) -> AnimationPlayer:
	for child: Node in root.get_children():
		var found := child as AnimationPlayer
		if found != null:
			return found
		var deeper := _find_animation_player(child)
		if deeper != null:
			return deeper
	return null


func _find_state_machine(root: Node) -> StateMachine:
	for child: Node in root.get_children():
		var found := child as StateMachine
		if found != null:
			return found
	return null
