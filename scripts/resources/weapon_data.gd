class_name WeaponData
extends Resource
## A weapon is its three attacks plus how it is carried. Tuning one never touches a script.

@export var id: StringName = &""
@export var display_name: String = ""
@export var attacks: Array[AttackData] = []
@export var is_ranged: bool = false

@export_group("Ranged")
@export var magazine: int = 0
@export var reload_time: float = 0.0


func attack_at(index: int) -> AttackData:
	if index < 0 or index >= attacks.size():
		return null
	return attacks[index]


func chain_length() -> int:
	return attacks.size()
