class_name WeaponRack
extends HBoxContainer
## What is in hand, what else is in the bag, and what is not in it yet.
##
## The three weapons are the run's whole progression — the stick in wave 2, the gun in wave 4 — and
## until now the screen said nothing about any of it. A player could carry three weapons and have no
## way to know it but to press the key and watch their hands.
##
## **The slots are built from `Arsenal`, not listed here.** The order is the order it cycles in, so
## the row and the key that walks along it can never disagree, and a fourth weapon is a `.tres`
## rather than an edit to a scene.
##
## Three states, and the dimming is the whole of the language: **in hand** is lit and wears the
## active chip; **carried** is legible but dim; **not found yet** is dimmer still and says the wave
## it turns up in rather than its key. A locked slot is shown rather than hidden for the reason the
## merchant shows a locked card — a player who cannot see the gun coming has no reason to want it.
##
## Like the rest of the HUD it listens on the bus and holds no reference to the player, so it
## survives a respawn, a restart, and a run that has not started yet.

## What a weapon in the bag but not in the hand is worth on screen: readable at a glance, never
## mistakable for the one being swung.
const CARRIED: float = 0.62
## And what one nobody has found is worth. Low enough to read as absent, high enough to read at all.
const LOCKED: float = 0.3
## The key that walks along the row, shown once at the end rather than on every slot. It is the one
## control that exists on both devices: a pad has no number keys, so without this a pad player sees
## a row of weapons and nothing that says how to reach them.
const CYCLE: String = "weapon_next"

var _badges: Dictionary[StringName, Label] = {}
var _names: Dictionary[StringName, Label] = {}
var _chips: Dictionary[StringName, PanelContainer] = {}
var _cycle: Label = null


func _ready() -> void:
	_build()
	# A fresh run and a resumed one both announce what is in hand — `GameState.begin_run` equips —
	# so there is no separate signal for "the bag was rebuilt" to listen for.
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	EventBus.weapon_found.connect(_on_weapon_found)
	EventBus.input_device_changed.connect(_on_input_device_changed)
	EventBus.bindings_changed.connect(refresh)
	refresh()


## Everything the row shows comes from the bag, so one call after any of it puts all three back in
## line — the one just equipped and the two that stopped being.
func refresh() -> void:
	var bag := GameState.loadout
	for weapon: WeaponData in Arsenal.all():
		if not _chips.has(weapon.id):
			continue
		var chip: PanelContainer = _chips[weapon.id]
		var owned := bag.owns(weapon.id)
		var in_hand := owned and bag.equipped == weapon.id
		chip.theme_type_variation = &"BindChipActive" if in_hand else &"BindChip"
		chip.modulate.a = 1.0 if in_hand else (CARRIED if owned else LOCKED)
		_names[weapon.id].text = tr(weapon.display_name).to_upper()
		_badges[weapon.id].text = _badge_for(weapon, owned)
		_badges[weapon.id].visible = not _badges[weapon.id].text.is_empty()
	if _cycle != null:
		_cycle.text = Devices.glyph(CYCLE)
		_cycle.get_parent().visible = not _cycle.text.is_empty()


## The key that reaches this weapon, or the wave it arrives in for one nobody has yet. A device with
## no direct key for it — a pad, which cycles instead — gets no badge rather than an empty chip.
func _badge_for(weapon: WeaponData, owned: bool) -> String:
	if not owned:
		return tr("HUD_WEAPON_WAVE") % weapon.found_at_wave
	var key := Devices.glyph("weapon_%s" % weapon.id)
	return "" if key == InputBindings.UNBOUND else key


func _build() -> void:
	for weapon: WeaponData in Arsenal.all():
		var chip := PanelContainer.new()
		# Named after the weapon, so the headless check can ask for a slot by the id it is about
		# rather than by a position in the row.
		chip.name = String(weapon.id)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 8)
		var badge := Label.new()
		badge.theme_type_variation = &"BindKey"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Label.new()
		name_label.theme_type_variation = &"Caption"
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		row.add_child(name_label)
		chip.add_child(row)
		add_child(chip)
		_chips[weapon.id] = chip
		_badges[weapon.id] = badge
		_names[weapon.id] = name_label
	_build_the_cycle_key()


func _build_the_cycle_key() -> void:
	var chip := PanelContainer.new()
	chip.name = "Cycle"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.theme_type_variation = &"BindChip"
	_cycle = Label.new()
	_cycle.theme_type_variation = &"BindKey"
	_cycle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_cycle)
	add_child(chip)


func _on_weapon_equipped(_weapon: WeaponData) -> void:
	refresh()


func _on_weapon_found(_id: StringName) -> void:
	refresh()


func _on_input_device_changed(_device: int) -> void:
	refresh()
