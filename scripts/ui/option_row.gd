class_name OptionRow
extends Button
## One settings row: the name on the left, the control that changes it on the right. The whole row
## is a Button, so focus, hover and the click come from the engine — and left and right adjust the
## value rather than move the focus, because up and down are what walk the list.
##
## **A slider answers the mouse on its meter, and only there.** A toggle and a picker can take a
## click anywhere on the row because they have one next value; a slider has ten, so where you
## clicked is the whole of what you meant. Clicking the label would have to guess, and guessing at
## the master volume is the worst possible place to be wrong — so the label does nothing and the
## ten blocks do everything, drag included.
##
## It reads and writes `Settings` directly. There is no Apply button anywhere in this game, so a
## row that did not write on the spot would be a row that lies.

signal changed(setting: StringName, value: Variant)

enum Kind { SLIDER, TOGGLE, PICKER }

## Ten, because the design draws the meter as ten blocks rather than a bar with a thumb.
const SEGMENTS: int = 10
const SEGMENT_ON: Color = Color(1.0, 1.0, 1.0)
const SEGMENT_ON_FOCUSED: Color = Color(0.8275, 0.2275, 0.2275)
const SEGMENT_OFF: Color = Color(0.2275, 0.2275, 0.2353)
const SEGMENT_HEIGHT: float = 16.0
const KNOB_REST: float = 6.0
const KNOB_TRAVEL: float = 32.0
const KNOB_SLIDE: float = 0.12

@export var setting: StringName = &"":
	set = _set_setting
@export var label_key: String = "":
	set = _set_label_key
@export var kind: Kind = Kind.PICKER
## Picker only: the values as they are stored, and the keys that name them on screen. Same order,
## same length — the index into one is the index into the other.
@export var values: PackedStringArray = []
@export var value_keys: PackedStringArray = []
@export_group("Slider")
@export var minimum: float = 0.0
@export var maximum: float = 100.0
@export var step: float = 10.0
@export var suffix: String = ""

var _segments: Array[ColorRect] = []
var _knob_settled: bool = false

@onready var title: Label = $Row/Title
@onready var slider: HBoxContainer = $Row/Slider
@onready var slider_value: Label = $Row/Slider/Value
@onready var segment_box: HBoxContainer = $Row/Slider/Segments
@onready var toggle: HBoxContainer = $Row/Toggle
@onready var pill: Panel = $Row/Toggle/Pill
@onready var knob: Panel = $Row/Toggle/Pill/Knob
@onready var picker: HBoxContainer = $Row/Picker
@onready var picker_value: Label = $Row/Picker/Value


func _ready() -> void:
	_build_segments()
	slider.visible = kind == Kind.SLIDER
	toggle.visible = kind == Kind.TOGGLE
	picker.visible = kind == Kind.PICKER
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	mouse_entered.connect(grab_focus)
	pressed.connect(_on_pressed)
	_set_label_key(label_key)
	refresh()
	_on_focus_changed()


func _gui_input(event: InputEvent) -> void:
	if kind == Kind.SLIDER and _mouse_sets_the_meter(event):
		accept_event()
		return
	var direction := 0
	if event.is_action_pressed(&"ui_left", true):
		direction = -1
	elif event.is_action_pressed(&"ui_right", true):
		direction = 1
	if direction == 0:
		return
	accept_event()
	nudge(direction)


## A press or a drag on the meter, turned into a value. Returns whether it was one — anything
## landing outside the blocks is somebody clicking the row, not setting it, and is left alone.
func _mouse_sets_the_meter(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	var at := Vector2.ZERO
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		at = button.position
	elif motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		# Dragging past the ends is still dragging: once the press has landed on the meter the
		# pointer owns it, which is what makes running the volume to zero one movement.
		at = motion.position
	else:
		return false
	# In this row's own space, which is what a `_gui_input` position is in. `segment_box.position`
	# is relative to its container, and using it directly put the meter somewhere near the label —
	# so a click on the name of the setting ran the volume to zero.
	var meter := Rect2(segment_box.global_position - global_position, segment_box.size)
	if button != null and not meter.grow(SEGMENT_HEIGHT).has_point(at):
		return false
	_write_number(_value_under(at.x, meter))
	return true


## Where along the meter a point falls, snapped to the notches the blocks are drawn as. Clicking a
## block fills it: the third block is three tenths, which is what the picture says it is.
func _value_under(x: float, meter: Rect2) -> float:
	var across := clampf((x - meter.position.x) / maxf(meter.size.x, 0.001), 0.0, 1.0)
	var notches := maxf((maximum - minimum) / maxf(step, 0.001), 1.0)
	return clampf(minimum + roundf(across * notches) * step, minimum, maximum)


## Pulls the row back in line with what is actually stored. Called whenever the screen opens, so a
## reset-to-defaults elsewhere shows up here without anything having to tell this row about it.
func refresh() -> void:
	match kind:
		Kind.SLIDER:
			_draw_slider(_current_number())
		Kind.TOGGLE:
			_draw_toggle(bool(Settings.get_value(setting)))
			_knob_settled = true
		Kind.PICKER:
			_draw_picker(_current_index())


func _set_setting(value: StringName) -> void:
	setting = value
	if is_inside_tree():
		refresh()


func _set_label_key(value: String) -> void:
	label_key = value
	if title != null:
		title.text = tr(value).to_upper()


## One step in a direction: the next value, the other side of a toggle, or a notch of a slider.
## Public because left and right are not the only things that will ever ask for it.
func nudge(direction: int) -> void:
	match kind:
		Kind.SLIDER:
			var wanted := clampf(_current_number() + step * direction, minimum, maximum)
			# The stored type decides: a volume is a whole percent, a sensitivity is not.
			var whole: bool = typeof(Settings.DEFAULTS[setting]) == TYPE_INT
			_write(roundi(wanted) if whole else wanted)
		Kind.TOGGLE:
			_write(direction > 0)
		Kind.PICKER:
			_write(_typed(values[wrapi(_current_index() + direction, 0, values.size())]))
	refresh()


## A picker lists its values as text, but the file has to keep the type the setting was declared
## with — a frame cap saved as "120" is a frame cap that reads back wrong.
func _typed(value: String) -> Variant:
	match typeof(Settings.DEFAULTS[setting]):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return value == "true"
	return value


## A slider's value, written and redrawn, and only when it actually moved — a drag crosses the same
## notch many times and every crossing would otherwise be a settings write and a bus change.
func _write_number(value: float) -> void:
	if is_equal_approx(value, _current_number()):
		return
	_write(int(value) if typeof(Settings.get_value(setting)) == TYPE_INT else value)
	_draw_slider(value)


func _write(value: Variant) -> void:
	Settings.set_value(setting, value)
	changed.emit(setting, value)


func _current_number() -> float:
	return float(Settings.get_value(setting))


func _current_index() -> int:
	var index := values.find(str(Settings.get_value(setting)))
	return maxi(index, 0)


func _build_segments() -> void:
	for index: int in SEGMENTS:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(0.0, SEGMENT_HEIGHT)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment_box.add_child(block)
		_segments.append(block)


func _draw_slider(value: float) -> void:
	var span := maxf(maximum - minimum, 0.001)
	var filled := roundi((value - minimum) / span * SEGMENTS)
	var lit: Color = SEGMENT_ON_FOCUSED if has_focus() else SEGMENT_ON
	for index: int in _segments.size():
		_segments[index].color = lit if index < filled else SEGMENT_OFF
	slider_value.text = "%d%s" % [roundi(value), suffix]


func _draw_toggle(on: bool) -> void:
	pill.theme_type_variation = &"TogglePillOn" if on else &"TogglePill"
	var wanted := KNOB_REST + (KNOB_TRAVEL if on else 0.0)
	# The first draw is the screen opening, and a knob that slides on arrival reads as a change
	# the player did not make.
	if not _knob_settled:
		knob.position.x = wanted
		return
	create_tween().tween_property(knob, "position:x", wanted, KNOB_SLIDE)


func _draw_picker(index: int) -> void:
	if index < 0 or index >= value_keys.size():
		picker_value.text = ""
		return
	picker_value.text = tr(value_keys[index]).to_upper()


func _on_pressed() -> void:
	match kind:
		Kind.TOGGLE:
			_write(not bool(Settings.get_value(setting)))
			refresh()
		Kind.PICKER:
			nudge(1)


func _on_focus_changed() -> void:
	var active: bool = has_focus()
	title.theme_type_variation = &"RowLabelActive" if active else &"RowLabel"
	slider_value.theme_type_variation = &"RowLabelActive" if active else &"RowLabel"
	picker_value.theme_type_variation = &"RowLabelActive" if active else &"RowLabel"
	if kind == Kind.SLIDER:
		_draw_slider(_current_number())
