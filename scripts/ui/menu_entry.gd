class_name MenuEntry
extends Button
## One row of a menu: a caret, the label, and the glyph that fires it. The whole row is a Button so
## focus, hover, keyboard and click all come from the engine instead of three bespoke signals.
##
## The badge names an **action**, never a key. What it prints is whatever that action is bound to on
## the device in hand right now — so it follows a rebind, and it follows the player picking up a
## controller mid-menu. A literal would be wrong twice over, and silently.
##
## Every colour and box lives in `ui_theme.tres`; this script only says which variation applies.

@export var label_key: String = "":
	set = _set_label_key
## Empty hides the badge. That is how the title drops Options' glyph while a run is waiting: the pad
## has one Y and New run has taken it.
@export var action: String = "":
	set = _set_action
## For the one row a pad and a keyboard fire differently. Resume is `A` on a pad and `Esc` on a
## keyboard — not two names for one binding, two bindings that both mean *get me out of here*.
@export var gamepad_action: String = "":
	set = _set_gamepad_action

@onready var caret: Label = $Row/Caret
@onready var title: Label = $Row/Title
@onready var badge: PanelContainer = $Row/Badge
@onready var key: Label = $Row/Badge/Key


func _ready() -> void:
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	mouse_entered.connect(grab_focus)
	EventBus.input_device_changed.connect(_on_input_device_changed)
	EventBus.bindings_changed.connect(refresh_glyph)
	_set_label_key(label_key)
	refresh_glyph()
	_on_focus_changed()


## What the badge says, for whoever is holding whatever they are holding.
func refresh_glyph() -> void:
	if badge == null:
		return
	var glyph := Devices.glyph(_action_in_hand())
	badge.visible = not glyph.is_empty()
	key.text = glyph


func _action_in_hand() -> String:
	var on_pad := Devices.last_used() == InputBindings.Device.GAMEPAD
	if on_pad and not gamepad_action.is_empty():
		return gamepad_action
	return action


func _set_label_key(value: String) -> void:
	label_key = value
	if title != null:
		title.text = tr(value).to_upper()


func _set_action(value: String) -> void:
	action = value
	refresh_glyph()


func _set_gamepad_action(value: String) -> void:
	gamepad_action = value
	refresh_glyph()


func _on_input_device_changed(_device: int) -> void:
	refresh_glyph()


func _on_focus_changed() -> void:
	var active: bool = has_focus()
	caret.visible = active
	title.theme_type_variation = &"MenuTitleActive" if active else &"MenuTitle"
	badge.theme_type_variation = &"KeyBadgeActive" if active else &"KeyBadge"
	key.theme_type_variation = &"KeyLabelActive" if active else &"KeyLabel"
