class_name State
extends Node
## One state of a StateMachine. Ask the machine to move on with transition_to().

signal transition_requested(to: StringName, message: Dictionary)

var machine: StateMachine = null


func enter(_message: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func transition_to(to: StringName, message: Dictionary = {}) -> void:
	transition_requested.emit(to, message)
