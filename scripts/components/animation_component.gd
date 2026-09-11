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
	&"Sprint": &"sprint",
	&"Dodge": &"dodge_roll",
	&"Parry": &"parry",
	&"Hurt": &"hurt",
	&"Dead": &"death",
}
## Crossfade between two clips. Long enough to hide the snap, short enough that a dodge still reads
## as instant.
@export var blend_time: float = 0.12
## Both are looked up under the owner when left null, so the component survives the rig being
## reimported under different node names.
@export var animation_player: AnimationPlayer = null
@export var state_machine: StateMachine = null

var _current_clip: StringName = &""


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


## The clip currently playing, or an empty name when the state has none. Readable from outside so
## the headless checks can assert on it without reaching into the AnimationPlayer.
func current_clip() -> StringName:
	return _current_clip


## True when the state had a clip and that clip exists on the rig.
func play_state(state_name: StringName) -> bool:
	var clip: StringName = clips.get(state_name, &"")
	if clip == &"" or animation_player == null or not animation_player.has_animation(String(clip)):
		_rest()
		clip_missing.emit(state_name, clip)
		return false
	if clip != _current_clip or not animation_player.is_playing():
		animation_player.play(String(clip), blend_time)
		_current_clip = clip
	return true


func _on_state_machine_transitioned(state_name: StringName) -> void:
	play_state(state_name)


## Back to the imported rest pose. Without it a state with no clip would hold whatever frame the
## previous one stopped on, which reads as a crash rather than as a missing animation.
func _rest() -> void:
	_current_clip = &""
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
