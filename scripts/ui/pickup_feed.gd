class_name PickupFeed
extends VBoxContainer
## A running line of what the run has just gained: money off a body, a round scavenged, a weapon
## picked up, an upgrade bought.
##
## Everything a player earns arrives in the middle of the fight that earned it, and every other
## place that reports it is a thing in the corner of the eye — a chip that pulses, a counter that
## ticks, a number that has already floated away. This is the one place the corner can be *read*
## rather than glimpsed, a second or two after the fact.
##
## It listens on the bus and on `GameState` like the rest of the HUD and holds no reference to a
## player, so it survives a respawn and a restart.

## How many lines stand at once. The oldest leaves when one too many arrives — a feed with no
## ceiling is a wall of text laid over the fight it is reporting on.
const LINES: int = 6
## How long a line stands before it goes on its own, so a lull empties the corner instead of leaving
## the last six kills sitting there for the rest of the wave.
const LIFE: float = 5.0
const FADE: float = 0.6
## Two gains of one kind inside this window become one line. A wave pays per body, and six farmers
## going down in four seconds would otherwise be the entire feed.
const MERGE: float = 1.4
const MILLISECONDS: float = 1000.0

## The line still open to being added to, and what it is counting. Null once it has been let go of,
## which is what makes the next kill start a line of its own.
var _open: Label = null
var _open_kind: StringName = &""
var _open_total: int = 0
var _open_at: float = 0.0
var _lives: Dictionary[Label, Tween] = {}


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.rounds_scavenged.connect(_on_rounds_scavenged)
	EventBus.weapon_found.connect(_on_weapon_found)


## Only money arriving. A purchase is a line the merchant screen already spells out in full, and a
## feed that reported the spending too would be arguing with it.
func _on_money_changed(_balance: int, delta: int) -> void:
	if delta > 0:
		_count(&"money", delta)


func _on_rounds_scavenged(rounds: int, _body: Node3D) -> void:
	_count(&"rounds", rounds)


func _on_weapon_found(id: StringName) -> void:
	var weapon := Arsenal.find(id)
	if weapon != null:
		_announce(tr("HUD_FEED_FOUND") % tr(weapon.display_name))


func _on_upgrade_purchased(track: UpgradeTrack, _level: int) -> void:
	if track != null:
		_announce(tr("HUD_FEED_UPGRADE") % tr(track.display_name))


## A gain of a kind the open line is already counting is added to it rather than given a line of its
## own, and the line's clock starts again so a run of kills reads as one growing total.
func _count(kind: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var now := Time.get_ticks_msec() / MILLISECONDS
	if _still_open(kind, now):
		_open_total += amount
		_open.text = _worded(kind, _open_total)
		_open_at = now
		_start_the_clock(_open)
		return
	_open_kind = kind
	_open_total = amount
	_open_at = now
	_open = _line(_worded(kind, amount))


func _still_open(kind: StringName, now: float) -> bool:
	if _open == null or not is_instance_valid(_open):
		return false
	return kind == _open_kind and now - _open_at <= MERGE


## A one-off: a weapon or an upgrade is never counted, so it closes whatever line was open rather
## than letting the next kill land on top of a line that says "Gun found".
func _announce(text: String) -> void:
	_open = null
	_open_kind = &""
	_line(text)


func _worded(kind: StringName, amount: int) -> String:
	if kind == &"money":
		return "+$%s" % Economy.grouped(amount)
	return tr("HUD_ROUNDS") % amount


func _line(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"FeedLine"
	label.text = text
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_make_room()
	_start_the_clock(label)
	return label


## Removed before it is freed, because a queued node is still a child for the rest of the frame and
## a feed that counted them would let the seventh line stand while it waited.
func _make_room() -> void:
	while get_child_count() > LINES:
		var oldest := get_child(0) as Label
		_retire(oldest)


## Cut short rather than waited out, which is what a seventh line arriving does to the first.
func _retire(label: Label) -> void:
	var running: Tween = _lives.get(label)
	if running != null and running.is_valid():
		running.kill()
	_faded(label)


func _faded(label: Label) -> void:
	_lives.erase(label)
	if label == _open:
		_open = null
	remove_child(label)
	label.queue_free()


func _start_the_clock(label: Label) -> void:
	var running: Tween = _lives.get(label)
	if running != null and running.is_valid():
		running.kill()
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(LIFE)
	tween.tween_property(label, "modulate:a", 0.0, FADE)
	tween.tween_callback(_faded.bind(label))
	_lives[label] = tween
