class_name MerchantScreen
extends Control
## Five cards between waves, and a few purchases — one early in the run, one more every few waves
## (`Economy.purchases_after`). It is not a shop: there is no grid, no cart and no confirmation —
## the interesting decision is what the player gives up, and asking them whether they are sure would
## turn a choice into a chore. It stays open until the allowance is spent or the player leaves.
##
## Leaving without buying is done by pressing back, and the game does not ask about that either.

signal closed

const CARD_SCENE: String = "res://scenes/ui/upgrade_card.tscn"

var _cards: Array[UpgradeCard] = []

@onready var heading: Label = $Content/Column/Head/Title
@onready var purse: Label = $Content/Column/Head/Purse/Row/Value
@onready var cards: HBoxContainer = $Content/Column/Cards


func _ready() -> void:
	_write_heading()
	for track: UpgradeTrack in Upgrades.all():
		var card := (load(CARD_SCENE) as PackedScene).instantiate() as UpgradeCard
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.track = track
		card.pressed.connect(_on_card_pressed.bind(card))
		cards.add_child(card)
		_cards.append(card)
	GameState.money_changed.connect(_on_money_changed)
	_on_money_changed(GameState.money, 0)
	_focus_best()
	UiSounds.arm(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _on_card_pressed(card: UpgradeCard) -> void:
	if not GameState.buy(card.track):
		return
	for other: UpgradeCard in _cards:
		other.refresh()
	# The wave's allowance spent, there is nothing left to stay for; until then the shop stays open.
	if not GameState.can_buy_anything():
		close()
		return
	_write_heading()
	_focus_best()


## The title, and how many purchases are left when there is more than one to make.
func _write_heading() -> void:
	var title := tr("MERCHANT_TITLE")
	var left := GameState.purchases_left()
	if left > 1:
		title = "%s · %s" % [title, tr("MERCHANT_LEFT") % left]
	heading.text = title.to_upper()


func _on_money_changed(balance: int, _delta: int) -> void:
	purse.text = "$%s" % Economy.grouped(balance)
	for card: UpgradeCard in _cards:
		card.refresh()


## Focus lands on something the player can actually buy, and falls back to the first card when
## nothing is affordable — a screen that opens with nothing highlighted is a screen that looks
## broken on a pad.
func _focus_best() -> void:
	for card: UpgradeCard in _cards:
		if GameState.can_buy(card.track):
			card.grab_focus()
			return
	if not _cards.is_empty():
		_cards[0].grab_focus()
