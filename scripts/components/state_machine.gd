class_name StateMachine
extends Node
## Node-based on purpose: states are visible and re-orderable in the editor, and each can carry its
## own exported tuning.

signal transitioned(state_name: StringName)

@export var initial_state: StringName = &"Idle"

var current: State = null
var current_name: StringName = &""


func _ready() -> void:
	for child: Node in get_children():
		var state := child as State
		if state == null:
			continue
		state.machine = self
		state.transition_requested.connect(_on_transition_requested)
	var first := get_node_or_null(NodePath(String(initial_state))) as State
	if first == null:
		first = get_child(0) as State
	if first != null:
		_enter(first, {})


func _process(delta: float) -> void:
	if current != null:
		current.update(delta)


func _physics_process(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current != null:
		current.handle_input(event)


func _on_transition_requested(to: StringName, message: Dictionary) -> void:
	var next := get_node_or_null(NodePath(String(to))) as State
	if next == null:
		push_warning("No state named %s on %s" % [to, get_path()])
		return
	_enter(next, message)


## **A state may leave from inside its own `enter`**, and several do — a dodge with no stamina, a
## hurt with no stagger, a state that finds the thing it was entered for already gone. That
## re-enters this function while this call is still on the stack.
##
## So the announcement is guarded. Without it the nested call moved `current_name` out from under
## the outer one, which then announced the **inner** state a second time and the outer state never
## at all — so anything listening for what the body is doing heard a state it was already told about
## and missed one entirely.
func _enter(next: State, message: Dictionary) -> void:
	if current != null:
		current.exit()
	current = next
	current_name = next.name
	next.enter(message)
	if current != next:
		return
	transitioned.emit(current_name)
