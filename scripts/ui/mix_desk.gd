class_name MixDesk
extends CanvasLayer
## A fader per family, so the mix can be decided by ear instead of argued about in decibels.
##
## **Nothing a player is meant to see, and a release build never carries it** — the same rule the
## debug overlay lives by. F4 shows it, it starts hidden, and what it produces is not a setting: it
## is a set of numbers meant to be read off and written into `MixTable` as the new defaults.
##
## The faders are **trims over the written table**, not replacements for it. A sound is still baked
## to the level the table declares; the desk adds decibels at the moment it plays. That is what
## makes it usable while the game is running — the alternative is rebuilding every waveform on every
## drag of a slider — and it is why what comes out is an offset per family rather than a mix.

## How tall a fader is, and how wide its column. A desk is read by the shape of its faders, so they
## are worth the room.
const FADER_HEIGHT: int = 190
const COLUMN_WIDTH: int = 74
## Smallest move a fader makes. A quarter of a decibel is under what anyone can hear as a step and
## fine enough that the figure written down afterwards is not a rounded guess.
const FADER_STEP: float = 0.25
## How long a family's audition waits between one sound and the next, so a family with six of them
## is heard as six rather than as a chord.
const AUDITION_GAP: float = 0.42
## Where an auditioned voice is put, relative to the listener: a farmer's shout is a positional
## sound, and auditioning it flat would be auditioning something the game never plays.
const AUDITION_AT: Vector3 = Vector3(0.0, 0.0, -8.0)
## How far the desk keeps off the edge of the screen, and how much room the audition buttons take —
## the master strip holds the same space empty so the faders stay on one line.
const EDGE: int = 18
const BUTTON_ROW: int = 31
## How much of the screen the desk takes along the bottom. Enough for a full-length fader and the
## two figures under it, and no more: the rest is the fight being mixed.
const DESK_HEIGHT: int = 476

var _faders: Dictionary[StringName, VSlider] = {}
var _readouts: Dictionary[StringName, Label] = {}
var _master: VSlider = null
var _master_readout: Label = null
var _report: Label = null
var _auditioning: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	hide()
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"debug_mix_desk"):
		return
	visible = not visible
	if visible:
		_refresh()
	get_viewport().set_input_as_handled()


func _build() -> void:
	# A strip along the bottom rather than a full screen. The whole point is to mix **while the fight
	# is happening**, and a panel over the island is a panel you have to close to hear anything worth
	# judging. Everything above it stays visible and stays playable.
	var backing := ColorRect.new()
	backing.color = Color(0.05, 0.05, 0.07, 0.86)
	backing.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	backing.offset_top = -DESK_HEIGHT
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backing)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, EDGE)
	backing.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Mix desk — F4 hides it. Trims over the written table, in decibels."
	column.add_child(title)
	var strips := HBoxContainer.new()
	strips.add_theme_constant_override(&"separation", 6)
	strips.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(strips)
	for family: StringName in MixTable.FAMILIES:
		strips.add_child(_strip(family))
	strips.add_child(_master_strip())
	column.add_child(_buttons())
	_report = Label.new()
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_report)
	_refresh()


func _strip(family: StringName) -> Control:
	var strip := VBoxContainer.new()
	strip.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	strip.alignment = BoxContainer.ALIGNMENT_BEGIN
	var name_label := Label.new()
	name_label.text = String(family)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(name_label)
	var fader := VSlider.new()
	fader.min_value = -MixTable.FADER_RANGE
	fader.max_value = MixTable.FADER_RANGE
	fader.step = FADER_STEP
	fader.value = MixTable.of_family(family) - MixTable.master
	fader.custom_minimum_size = Vector2(0, FADER_HEIGHT)
	fader.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fader.value_changed.connect(_on_fader_moved.bind(family))
	strip.add_child(fader)
	_faders[family] = fader
	var readout := Label.new()
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(readout)
	_readouts[family] = readout
	var listen := Button.new()
	listen.text = "hear"
	# **Dead for the families that have nothing to play, and visibly dead.** `track` and `layer` are
	# the soundtrack: no sound is registered under either, so this button used to do nothing at all
	# and say nothing about it. Somebody moved the music fader eleven decibels down while listening
	# to silence, against a playlist that was still empty, and that is how the soundtrack shipped
	# under the menu click. A button that cannot be pressed is the smallest thing that stops it.
	listen.disabled = not _can_audition(family)
	listen.tooltip_text = "" if listen.disabled else "play this family"
	if listen.disabled:
		listen.tooltip_text = "nothing to audition — listen to what is already playing"
	listen.pressed.connect(_on_audition_pressed.bind(family))
	strip.add_child(listen)
	return strip


## Whether pressing `hear` would produce a sound. The voices are pooled rather than registered, so
## they are named; everything else has to have something under its family to play.
func _can_audition(family: StringName) -> bool:
	if family == &"farmer" or family == &"gull":
		return not AudioManager.voices_of(family).is_empty()
	return not MixTable.sounds_of(family).is_empty()


func _master_strip() -> Control:
	var strip := VBoxContainer.new()
	strip.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	strip.alignment = BoxContainer.ALIGNMENT_BEGIN
	var name_label := Label.new()
	name_label.text = "MASTER"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(name_label)
	_master = VSlider.new()
	_master.min_value = -MixTable.FADER_RANGE
	_master.max_value = MixTable.FADER_RANGE
	_master.step = FADER_STEP
	_master.value = MixTable.master
	_master.custom_minimum_size = Vector2(0, FADER_HEIGHT)
	_master.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_master.value_changed.connect(_on_master_moved)
	strip.add_child(_master)
	_master_readout = Label.new()
	_master_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(_master_readout)
	# The master has nothing to audition, and a hole where every other strip has a button reads as a
	# strip that is missing one.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, BUTTON_ROW)
	strip.add_child(spacer)
	return strip


func _buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var flat := Button.new()
	flat.text = "Back to the written table"
	flat.pressed.connect(_on_flatten_pressed)
	row.add_child(flat)
	var write := Button.new()
	write.text = "Write the mix down"
	write.pressed.connect(_on_write_pressed)
	row.add_child(write)
	return row


## Every figure the desk currently stands at, as the table would be written if these were adopted —
## which is the only output of this whole screen that matters.
func _written_mix() -> String:
	var out := "MIX DESK — master %+.2f dB\n" % MixTable.master
	for family: StringName in MixTable.FAMILIES:
		out += (
			"%-11s fader %+6.2f   ->  %s %.2f\n"
			% [
				String(family),
				MixTable.of_family(family) - MixTable.master,
				_const_name(family),
				MixTable.level_of(family) - MixTable.HEADROOM_DB,
			]
		)
	return out


func _const_name(family: StringName) -> String:
	return String(family).to_upper() + "_LEVEL"


func _refresh() -> void:
	for family: StringName in _faders:
		_readouts[family].text = (
			"%+.1f\n%.1f" % [MixTable.of_family(family) - MixTable.master, _heard_level(family)]
		)
	_master_readout.text = "%+.1f" % MixTable.master


## What the family is worth at the ear. The same as its written level everywhere except the sea,
## which is a ring of sources: reading one stretch of coast off a fader would be reading a fraction
## of what the player hears.
func _heard_level(family: StringName) -> float:
	var level := MixTable.level_of(family)
	return level + SurfBed.FROM_THE_MIDDLE_DB if family == AudioManager.BED_SOUND else level


func _remix() -> void:
	_refresh()
	for node: Node in get_tree().get_nodes_in_group(&"remixable"):
		if node.has_method("remix"):
			node.call("remix")
	var sea := AudioManager.bed()
	if sea != null:
		sea.remix()


func _on_fader_moved(value: float, family: StringName) -> void:
	MixTable.faders[family] = value
	_remix()


func _on_master_moved(value: float) -> void:
	MixTable.master = value
	_remix()


func _on_flatten_pressed() -> void:
	MixTable.flatten()
	for family: StringName in _faders:
		_faders[family].set_value_no_signal(0.0)
	_master.set_value_no_signal(0.0)
	_remix()


func _on_write_pressed() -> void:
	var written := _written_mix()
	print(written)
	var file := FileAccess.open(MixTable.DESK_AT, FileAccess.WRITE)
	if file == null:
		_report.text = "could not write %s" % MixTable.DESK_AT
		return
	file.store_string(written)
	file.close()
	_report.text = written + "\nwritten to %s" % ProjectSettings.globalize_path(MixTable.DESK_AT)


## Plays a family so the fader has something to move against. The recordings are placed rather than
## flat, because a farmer is a positional sound and a flat audition of one is an audition of
## something the game never plays.
func _on_audition_pressed(family: StringName) -> void:
	if _auditioning:
		return
	_auditioning = true
	if family == &"farmer" or family == &"gull":
		await _audition_a_voice(family)
	else:
		for id: StringName in MixTable.sounds_of(family):
			AudioManager.play(id)
			await get_tree().create_timer(AUDITION_GAP).timeout
	_auditioning = false


func _audition_a_voice(family: StringName) -> void:
	var clips := AudioManager.voices_of(family)
	if clips.is_empty():
		return
	var voice := AudioStreamPlayer3D.new()
	voice.bus = &"SFX"
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.max_distance = AudioManager.REACH
	voice.unit_size = AudioManager.VOICE_UNIT
	voice.volume_db = linear_to_db(AudioManager.gain_of_voice(family))
	add_child(voice)
	var listener := get_viewport().get_camera_3d()
	voice.global_position = (
		listener.global_position + AUDITION_AT if listener != null else AUDITION_AT
	)
	voice.stream = clips[0]
	voice.play()
	await get_tree().create_timer(clips[0].get_length() + AUDITION_GAP).timeout
	voice.stop()
	voice.queue_free()
