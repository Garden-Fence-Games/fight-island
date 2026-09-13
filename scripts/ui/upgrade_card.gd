class_name UpgradeCard
extends Button
## One of the five cards. It shows the level owned, what the next level does in words, and what it
## costs — and it stays readable when it cannot be afforded, because seeing what you cannot buy is
## the whole tension the economy exists for.

const DIM: float = 0.4

var track: UpgradeTrack = null:
	set = _set_track

@onready var title: Label = $Rows/Head/Title
@onready var level: Label = $Rows/Head/Level/Value
@onready var level_badge: PanelContainer = $Rows/Head/Level
@onready var blurb: Label = $Rows/Blurb
@onready var price: Label = $Rows/Foot/Cost/Price
@onready var buy_hint: PanelContainer = $Rows/Foot/Buy


func _ready() -> void:
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	mouse_entered.connect(grab_focus)
	refresh()
	_on_focus_changed()


## Everything the card shows comes from the run state, so one call after a purchase puts all five
## back in line — the one that was bought and the four that just got more expensive to reach.
func refresh() -> void:
	if track == null or title == null:
		return
	var owned := GameState.level_of(track)
	var maxed: bool = owned >= Economy.LEVEL_CAP
	title.text = tr(track.display_name).to_upper()
	level.text = tr("MERCHANT_LEVEL") % owned
	blurb.text = tr("MERCHANT_MAXED") if maxed else tr(track.next_level_key)
	price.text = "—" if maxed else "$%d" % GameState.price_of(track)
	# Dimmed but never hidden: a card nobody can read is a card nobody can want.
	modulate.a = 1.0 if GameState.can_buy(track) or maxed else DIM
	_paint()


func _set_track(value: UpgradeTrack) -> void:
	track = value
	refresh()


func _on_focus_changed() -> void:
	_paint()


func _paint() -> void:
	var active: bool = has_focus()
	var affordable: bool = GameState.can_buy(track)
	title.theme_type_variation = &"CardTitleActive" if active else &"CardTitle"
	level_badge.theme_type_variation = &"CardLevelActive" if active else &"CardLevel"
	price.theme_type_variation = &"CardPrice" if affordable else &"CardPriceOut"
	buy_hint.visible = active and affordable
