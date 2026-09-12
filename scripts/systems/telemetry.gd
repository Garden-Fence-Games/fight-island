class_name Telemetry
extends Node
## One row per wave, appended to a CSV under `user://`, so fifteen waves can be tuned from what
## players did rather than from what the formulas promise.
##
## **Debug builds only, and not by a guard at the write.** In a release build `_ready` connects
## nothing and opens nothing, because the honest answer to "does this ship" is *there is no file*
## rather than *the file stays empty*. Local, no network, no prompt — see `docs/menus.md`.
##
## **It counts nothing of its own.** Every figure is the difference between two samples of
## `GameState.stats`, the tally the run summary already reads and the save file already carries. A
## second counter beside that one would be a second thing to get wrong, and the two would disagree
## quietly for a long time before anybody noticed which was lying.
##
## Written with `FileAccess`, and read back by nobody — not even to decide whether the header is
## owed. A file under `user://` is the player's to edit, and nothing here will ever hand one to the
## resource loader.

const PATH: String = "user://telemetry.csv"
## The header, and the order of every row. One list so a column cannot be added to the file without
## being named, or named without arriving.
const COLUMNS: PackedStringArray = [
	"run",
	"wave",
	"enemies",
	"seconds",
	"outcome",
	"kills",
	"perfect_hits",
	"perfect_parries",
	"earned",
	"spent",
	"bought",
	"level",
]
const CLEARED: StringName = &"cleared"
const DIED: StringName = &"died"
## A wave nobody finished: quit to the title, or the game closed mid-fight. Recorded rather than
## dropped, because a wave players walk out of is a finding and a missing row looks like nothing
## happened.
const ABANDONED: StringName = &"abandoned"

var _recording: bool = false
## The wave being written. Nought between the flush and the next `wave_started`, which is what stops
## a second flush from inventing a row.
var _wave: int = 0
var _enemies: int = 0
var _seconds: float = 0.0
## Only while the fight is on, so the merchant's pause and the director's gap between waves are not
## charged to either wave's clock.
var _fighting: bool = false
var _outcome: StringName = ABANDONED
var _bought: StringName = &""
var _level: int = 0
## What the tally read when this wave opened. Every figure in the row is measured from here.
var _opened_with: Dictionary[StringName, int] = {}


func _ready() -> void:
	set_process(false)
	if not OS.is_debug_build():
		return
	start()


func _process(delta: float) -> void:
	if _fighting:
		_seconds += delta


## The last wave leaves through here: a victory has no next wave to flush it, and a player who quits
## to the title is the only one who can say what that wave was worth.
func _exit_tree() -> void:
	_flush()


## Public and idempotent so the headless check can arm a recorder without an exported build, which
## is the one thing it cannot fake.
func start() -> void:
	if _recording:
		return
	_recording = true
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.player_died.connect(_on_player_died)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	set_process(true)


## The other half of `start()`, and what a release build amounts to: no listeners, no clock, and
## nothing written however many events arrive afterwards. Public because that is the one thing a
## debug build cannot fake — `OS.is_debug_build()` answering false — so the headless check proves
## its whole consequence instead, and `_ready` arming only in a debug build is the single line left
## between the two.
func stop() -> void:
	if not _recording:
		return
	_recording = false
	# An open row goes with it. Stopping means stopping, not finishing what was in hand.
	_wave = 0
	_fighting = false
	EventBus.wave_started.disconnect(_on_wave_started)
	EventBus.wave_cleared.disconnect(_on_wave_cleared)
	EventBus.player_died.disconnect(_on_player_died)
	GameState.upgrade_purchased.disconnect(_on_upgrade_purchased)
	set_process(false)


func recording() -> bool:
	return _recording


func _on_wave_started(wave: int, enemies: int) -> void:
	_flush()
	_wave = wave
	_enemies = enemies
	_seconds = 0.0
	_fighting = true
	_outcome = ABANDONED
	_bought = &""
	_level = 0
	_opened_with = _tally()


func _on_wave_cleared(wave: int, _reward: int) -> void:
	if wave != _wave:
		return
	_outcome = CLEARED
	_fighting = false


## Flushed at once rather than left for the next wave: there is no next wave, and the run is about
## to be ended and discarded under us.
func _on_player_died() -> void:
	_outcome = DIED
	_fighting = false
	_flush()


## The purchase belongs to the wave that paid for it, not to the one the player spends it in — the
## row is still open because the merchant opens before the next wave starts.
func _on_upgrade_purchased(track: UpgradeTrack, level: int) -> void:
	if track == null:
		return
	_bought = track.id
	_level = level


func _tally() -> Dictionary[StringName, int]:
	var stats := GameState.stats
	if stats == null:
		return {}
	return {
		&"kills": stats.total_kills(),
		&"perfect_hits": stats.perfect_hits,
		&"perfect_parries": stats.perfect_parries,
		&"earned": stats.money_earned,
		&"spent": stats.money_spent,
	}


func _since_the_wave_opened() -> Dictionary[StringName, int]:
	var gained: Dictionary[StringName, int] = {}
	var now := _tally()
	for figure: StringName in now:
		gained[figure] = now[figure] - _opened_with.get(figure, 0)
	return gained


## One guard, and the only one there is room for. `_wave` is set nowhere but in `_on_wave_started`,
## which cannot run unless the recorder is connected, and `stop()` clears it — so a recorder never
## armed, one stopped, and one whose row has already gone out are all the same state here.
func _flush() -> void:
	if _wave <= 0:
		return
	var gained := _since_the_wave_opened()
	_append(
		PackedStringArray(
			[
				str(GameState.run_seed),
				str(_wave),
				str(_enemies),
				"%.1f" % _seconds,
				String(_outcome),
				str(gained.get(&"kills", 0)),
				str(gained.get(&"perfect_hits", 0)),
				str(gained.get(&"perfect_parries", 0)),
				str(gained.get(&"earned", 0)),
				str(gained.get(&"spent", 0)),
				String(_bought),
				str(_level),
			]
		)
	)
	_wave = 0


func _append(row: PackedStringArray) -> void:
	# Asked of the directory rather than of the file's contents: whether the header is owed is a
	# question about existence, and reading a player's file to answer it would be reading it.
	var fresh := not FileAccess.file_exists(PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE if fresh else FileAccess.READ_WRITE)
	if file == null:
		push_warning("telemetry: cannot write %s (%d)" % [PATH, FileAccess.get_open_error()])
		return
	if fresh:
		file.store_csv_line(COLUMNS)
	else:
		file.seek_end()
	file.store_csv_line(row)
	file.close()
