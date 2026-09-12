class_name MenuEntry
extends Button
## One row of a menu: a caret, the label, and the glyph that fires it. The whole row is a Button so
## focus, hover, keyboard and click all come from the engine instead of three bespoke signals.
##
## Every colour and box lives in `ui_theme.tres`; this script only says which variation applies.

@export var label_key: String = "":
	set = _set_label_key
@export var key_hint: String = "":
	set = _set_key_hint

@onready var caret: Label = $Row/Caret
@onready var title: Label = $Row/Title
@onready var badge: PanelContainer = $Row/Badge
@onready var key: Label = $Row/Badge/Key


func _ready() -> void:
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	mouse_entered.connect(grab_focus)
	_set_label_key(label_key)
	_set_key_hint(key_hint)
	_on_focus_changed()


func _set_label_key(value: String) -> void:
	label_key = value
	if title != null:
		title.text = tr(value).to_upper()


func _set_key_hint(value: String) -> void:
	key_hint = value
	if badge == null:
		return
	badge.visible = not value.is_empty()
	key.text = value


func _on_focus_changed() -> void:
	var active: bool = has_focus()
	caret.visible = active
	title.theme_type_variation = &"MenuTitleActive" if active else &"MenuTitle"
	badge.theme_type_variation = &"KeyBadgeActive" if active else &"KeyBadge"
	key.theme_type_variation = &"KeyLabelActive" if active else &"KeyLabel"
