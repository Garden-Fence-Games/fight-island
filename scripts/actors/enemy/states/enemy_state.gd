class_name EnemyState
extends State

var enemy: Enemy = null


func _ready() -> void:
	enemy = owner as Enemy
