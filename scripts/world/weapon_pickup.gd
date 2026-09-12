class_name WeaponPickup
extends Area3D
## A weapon lying on the island, waiting to be walked over and taken.
##
## It carries a **weapon id**, not a `WeaponData`: what a pickup grants is a line in the run's bag,
## and the bag is what knows how to load a gun. A pickup that handed over a resource would be a
## second place that decides what "having the gun" means.
##
## The prompt is a `Label3D` on the thing itself rather than a line at the bottom of the screen.
## Two reasons: it points at what it is talking about, and a world-space label cannot collide with
## the tutorial's own prompt, which is the one part of the screen already spoken for.

## Where the prompt sits above the weapon, and how close the player has to be for it to appear. The
## radius is the collision shape's; this is only how far the label reads from.
const LABEL_HEIGHT: float = 1.3
## How high off the ground the weapon itself sits. What has to be in shot is the thing that reads
## as a weapon, not the air above it — `PickupDirector` asks the camera about this height, and
## `tools/verify_view.tscn` judges it at the same one.
const RESTING_HEIGHT: float = 0.3
## Turns per second, so the thing reads as an object to be taken rather than as scenery.
const SPIN: float = 1.2

@export var weapon_id: StringName = &""
## The localisation key of the line above it, with `{0}` for the glyph that takes it.
@export var prompt_key: String = "PICKUP_TAKE"

var _player_inside: bool = false

@onready var label: Label3D = get_node_or_null("Prompt") as Label3D


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.input_device_changed.connect(_on_input_device_changed)
	EventBus.bindings_changed.connect(_write_prompt)
	_show_prompt(false)
	_write_prompt()


func _process(delta: float) -> void:
	rotate_y(SPIN * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	take()


## Taking it is the bag's decision, and a bag that already has this weapon says no — which is what
## stops a pickup nobody removed from re-arming a gun the player has half emptied.
func take() -> void:
	if not GameState.loadout.find_weapon(weapon_id):
		return
	queue_free()


func _show_prompt(visible_now: bool) -> void:
	if label != null:
		label.visible = visible_now


func _write_prompt() -> void:
	if label == null:
		return
	label.text = tr(prompt_key).format([Devices.glyph("interact")])


func _on_input_device_changed(_device: int) -> void:
	_write_prompt()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = true
	_show_prompt(true)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = false
	_show_prompt(false)
