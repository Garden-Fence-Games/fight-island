class_name ConfirmDialog
extends Control
## The only thing in the game that asks twice. Restart and Quit to title each throw away up to
## forty minutes; nothing else does, so nothing else confirms.
##
## `PROCESS_MODE_ALWAYS`, because it is opened from a menu that stopped the tree — a dialog that
## cannot process is a soft lock with a button on it.

signal resolved(confirmed: bool)

## Long enough to be a decision and short enough not to be a chore. Only used when the player has
## asked for hold-to-confirm in the accessibility options.
const HOLD_SECONDS: float = 0.75

var _held: float = 0.0
var _hold_required: bool = false
var _settled: bool = false

@onready var title: Label = $Center/Frame/Rows/Title
@onready var body: RichTextLabel = $Center/Frame/Rows/Body
@onready var confirm: Button = $Center/Frame/Rows/Buttons/Confirm
@onready var cancel: Button = $Center/Frame/Rows/Buttons/Cancel
@onready var fill: ColorRect = $Center/Frame/Rows/Buttons/Confirm/Fill


func _ready() -> void:
	confirm.pressed.connect(_on_confirm_pressed)
	cancel.pressed.connect(_resolve.bind(false))
	fill.visible = false
	set_process(false)
	UiSounds.arm(self)


func _process(delta: float) -> void:
	if not confirm.is_pressed():
		_held = 0.0
		fill.anchor_right = 0.0
		return
	_held += delta
	fill.anchor_right = clampf(_held / HOLD_SECONDS, 0.0, 1.0)
	if _held >= HOLD_SECONDS:
		_resolve(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_resolve(false)


## `danger` is the fragment of the body set in red — the part that says what is actually lost. It
## is passed separately because a translator must be free to move it inside the sentence.
func ask(title_key: String, body_key: String, danger_key: String, confirm_key: String) -> void:
	title.text = tr(title_key).to_upper()
	var danger := "[color=#d33a3a]%s[/color]" % tr(danger_key)
	body.text = tr(body_key) % danger
	confirm.text = tr(confirm_key).to_upper()
	cancel.text = tr("UI_CANCEL").to_upper()
	_hold_required = bool(Settings.get_value(&"access_hold_to_confirm"))
	fill.visible = _hold_required
	set_process(_hold_required)
	# Focus starts on cancel: the dangerous button should take a deliberate move to reach.
	cancel.grab_focus()


func _on_confirm_pressed() -> void:
	# In hold mode the release is what fires `pressed`, and a release is the opposite of a hold.
	if _hold_required:
		return
	_resolve(true)


func _resolve(confirmed: bool) -> void:
	if _settled:
		return
	_settled = true
	set_process(false)
	resolved.emit(confirmed)
	queue_free()
