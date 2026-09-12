extends Node
## Headless proof of the three things a tuning record has to get right: the figures are that wave's
## own and not the run's running total, a purchase is filed under the wave that paid for it, and a
## recorder nobody armed leaves nothing behind.
##
## The last one is how a release build is covered here. What cannot be faked from a debug build is
## `OS.is_debug_build()` returning false, so what is proved instead is its whole consequence — an
## unarmed recorder writes no file, connects no signal and counts no second. `_ready` calling
## `start()` only in a debug build is then the one line standing between the two, and it is one line
## on purpose.
##
## Whatever telemetry is already on this machine goes back at the end.
## Run: godot --headless --path . res://tools/verify_telemetry.tscn

const RUN_SCENE: String = "res://scenes/main/main.tscn"
const TRACK: String = "res://data/upgrades/stamina.tres"
## Waves the fake run fights. Two, because one wave cannot tell a difference from a total.
const FIRST: int = 1
const SECOND: int = 2
const A_CROWD: int = 9
const ANOTHER_CROWD: int = 14
## Kills handed to the tally during each wave. Deliberately unequal: two waves that killed the same
## number would pass a recorder that wrote the same figure twice.
const FIRST_KILLS: int = 3
const SECOND_KILLS: int = 5
const A_LEVEL: int = 2
## Real seconds, not frames. A headless frame is worth almost no wall time, so a clock asserted on a
## frame count would pass against a clock that never ran.
const A_FIGHT: float = 0.4
const A_BREATHER: float = 0.3
## Wide enough for a loaded machine, narrower than the breather — which is what makes the bracket
## two-sided rather than a floor.
const CLOCK_SLACK: float = 0.15
const SETTLE_FRAMES: int = 4

var _failures: PackedStringArray = []
var _kept: String = ""
var _had_telemetry: bool = false


func _ready() -> void:
	_run()


func _run() -> void:
	_keep_what_is_on_this_machine()
	_check_a_recorder_nobody_armed_leaves_nothing_behind()
	_check_a_wave_is_a_row_with_every_column_named()
	_check_the_figures_are_that_waves_own()
	_check_a_purchase_is_filed_under_the_wave_that_paid_for_it()
	_check_a_death_is_recorded_where_it_happened()
	_check_a_wave_nobody_finished_is_still_a_row()
	_check_the_header_is_written_once_however_many_runs_arrive()
	await _check_the_clock_runs_with_the_fight_and_stops_with_it()
	await _check_the_run_scene_carries_a_recorder()
	_put_back_what_was_on_this_machine()
	_report()


func _keep_what_is_on_this_machine() -> void:
	_had_telemetry = FileAccess.file_exists(Telemetry.PATH)
	if not _had_telemetry:
		return
	var file := FileAccess.open(Telemetry.PATH, FileAccess.READ)
	if file == null:
		return
	_kept = file.get_as_text()
	file.close()


func _put_back_what_was_on_this_machine() -> void:
	if not _had_telemetry:
		_erase()
		return
	var file := FileAccess.open(Telemetry.PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(_kept)
	file.close()


## The release build's whole consequence. Every event a run can raise, raised at a recorder that was
## never armed — and nothing on disk afterwards.
func _check_a_recorder_nobody_armed_leaves_nothing_behind() -> void:
	_erase()
	var quiet := Telemetry.new()
	add_child(quiet)
	# Stopped rather than never started, because `_ready` arms in any debug build and this one is a
	# debug build. What is left afterwards is exactly the state a release build boots into.
	quiet.stop()
	_fight(FIRST, A_CROWD, FIRST_KILLS)
	EventBus.wave_cleared.emit(FIRST, 50)
	EventBus.player_died.emit()
	quiet.free()
	if FileAccess.file_exists(Telemetry.PATH):
		_fail("a recorder nobody armed wrote %s anyway" % Telemetry.PATH)
	if not _rows().is_empty():
		_fail("a recorder nobody armed left rows behind")


func _check_a_wave_is_a_row_with_every_column_named() -> void:
	var rows := _one_wave_cleared()
	if rows.size() != 2:
		_fail("a cleared wave should be a header and one row, got %d lines" % rows.size())
		return
	if rows[0] != Telemetry.COLUMNS:
		_fail("the header reads %s" % [rows[0]])
	if rows[1].size() != Telemetry.COLUMNS.size():
		_fail(
			(
				"a row carries %d values against %d columns"
				% [rows[1].size(), Telemetry.COLUMNS.size()]
			)
		)
		return
	_same("the wave", _value(rows[1], "wave"), str(FIRST))
	_same("the crowd", _value(rows[1], "enemies"), str(A_CROWD))
	_same("the outcome", _value(rows[1], "outcome"), String(Telemetry.CLEARED))
	_same("the kills", _value(rows[1], "kills"), str(FIRST_KILLS))


## **The one that rots quietly.** `GameState.stats` is a running total for the whole run, so a
## recorder that writes it straight out gives every wave the sum of the ones before it — and wave
## one, the only wave where the two agree, is the wave every check tends to look at.
func _check_the_figures_are_that_waves_own() -> void:
	var rows := _two_waves_cleared()
	if rows.size() != 3:
		_fail("two waves should be a header and two rows, got %d lines" % rows.size())
		return
	_same("wave one's kills", _value(rows[1], "kills"), str(FIRST_KILLS))
	_same("wave two's kills", _value(rows[2], "kills"), str(SECOND_KILLS))


func _check_a_purchase_is_filed_under_the_wave_that_paid_for_it() -> void:
	var track := load(TRACK) as UpgradeTrack
	if track == null:
		_fail("there is no %s to buy" % TRACK)
		return
	var rows := _two_waves_cleared(track)
	if rows.size() != 3:
		_fail("a purchase should not change the row count, got %d lines" % rows.size())
		return
	_same("what wave one bought", _value(rows[1], "bought"), String(track.id))
	_same("the level it reached", _value(rows[1], "level"), str(A_LEVEL))
	# The row the player *spends* it in owes nothing: one purchase per wave is the whole economy,
	# and a track credited twice would read as one bought every wave.
	_same("what wave two bought", _value(rows[2], "bought"), "")


func _check_a_death_is_recorded_where_it_happened() -> void:
	_erase()
	var recorder := _armed()
	_fight(SECOND, A_CROWD, FIRST_KILLS)
	EventBus.player_died.emit()
	recorder.free()
	var rows := _rows()
	if rows.size() != 2:
		_fail("a death should close its wave, got %d lines" % rows.size())
		return
	_same("the wave it happened on", _value(rows[1], "wave"), str(SECOND))
	_same("the outcome", _value(rows[1], "outcome"), String(Telemetry.DIED))


## A player who quits mid-fight is the only one who can say what that wave was worth, so the row is
## written on the way out rather than dropped. A wave people leave is a finding.
func _check_a_wave_nobody_finished_is_still_a_row() -> void:
	_erase()
	var recorder := _armed()
	_fight(FIRST, A_CROWD, FIRST_KILLS)
	recorder.free()
	var rows := _rows()
	if rows.size() != 2:
		_fail("a wave walked out of should still be a row, got %d lines" % rows.size())
		return
	_same("the outcome", _value(rows[1], "outcome"), String(Telemetry.ABANDONED))


func _check_the_header_is_written_once_however_many_runs_arrive() -> void:
	_erase()
	for _run_number: int in 3:
		var recorder := _armed()
		_fight(FIRST, A_CROWD, FIRST_KILLS)
		EventBus.wave_cleared.emit(FIRST, 50)
		recorder.free()
	var rows := _rows()
	if rows.size() != 4:
		_fail("three runs should be a header and three rows, got %d lines" % rows.size())
		return
	for index: int in range(1, rows.size()):
		if rows[index] == Telemetry.COLUMNS:
			_fail("the header was written again at line %d" % index)


## The one figure the recorder measures itself rather than sampling, so it is the one that can be
## wrong on its own. Two claims in one bracket: the clock runs while the fight does, and it stops
## when the wave is cleared. A clock left running charges the merchant's pause and the gap between
## waves to whichever wave happened to still be open.
func _check_the_clock_runs_with_the_fight_and_stops_with_it() -> void:
	_erase()
	var recorder := _armed()
	_fight(FIRST, A_CROWD, FIRST_KILLS)
	await _wait(A_FIGHT)
	EventBus.wave_cleared.emit(FIRST, 50)
	await _wait(A_BREATHER)
	recorder.free()
	var rows := _rows()
	if rows.size() != 2:
		_fail("a timed wave should be a header and one row, got %d lines" % rows.size())
		return
	var written := float(_value(rows[1], "seconds"))
	if absf(written - A_FIGHT) > CLOCK_SLACK:
		_fail(
			(
				"a %.1f s fight and a %.1f s breather after it were written as %.1f s"
				% [A_FIGHT, A_BREATHER, written]
			)
		)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The wiring, which is the half the hand-raised events above cannot reach: a recorder that exists
## and is never in the scene the run plays in records nothing at all.
func _check_the_run_scene_carries_a_recorder() -> void:
	_erase()
	# Set rather than ended: `GameState.end_run()` discards the run file and stamps progress, and
	# this machine's own run is not this check's to spend. Without it the run flow would decide a
	# merchant is owed and pause the tree under us.
	GameState.run_in_progress = false
	var run := (load(RUN_SCENE) as PackedScene).instantiate()
	add_child(run)
	await get_tree().process_frame
	var recorder := run.get_node_or_null("Telemetry") as Telemetry
	if recorder == null:
		_fail("%s carries no recorder" % RUN_SCENE)
	elif not recorder.recording():
		_fail("the recorder in %s was not armed by a debug build" % RUN_SCENE)
	run.queue_free()
	await get_tree().process_frame


## A recorder listening, with nothing of the scene tree it will not use.
func _armed() -> Telemetry:
	var recorder := Telemetry.new()
	add_child(recorder)
	recorder.start()
	return recorder


## A wave opening, and a tally moving under it the way a fight would move it.
func _fight(wave: int, crowd: int, kills: int) -> void:
	EventBus.wave_started.emit(wave, crowd)
	for _kill: int in kills:
		GameState.stats.record_kill(&"farmhand")


func _one_wave_cleared() -> Array[PackedStringArray]:
	_erase()
	var recorder := _armed()
	_fight(FIRST, A_CROWD, FIRST_KILLS)
	EventBus.wave_cleared.emit(FIRST, 50)
	recorder.free()
	return _rows()


func _two_waves_cleared(bought: UpgradeTrack = null) -> Array[PackedStringArray]:
	_erase()
	var recorder := _armed()
	_fight(FIRST, A_CROWD, FIRST_KILLS)
	EventBus.wave_cleared.emit(FIRST, 50)
	if bought != null:
		GameState.upgrade_purchased.emit(bought, A_LEVEL)
	_fight(SECOND, ANOTHER_CROWD, SECOND_KILLS)
	EventBus.wave_cleared.emit(SECOND, 62)
	recorder.free()
	return _rows()


func _rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	if not FileAccess.file_exists(Telemetry.PATH):
		return rows
	var file := FileAccess.open(Telemetry.PATH, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line := file.get_csv_line()
		# A trailing newline reads back as one empty field, which is not a row.
		if line.size() > 1:
			rows.append(line)
	file.close()
	return rows


func _value(row: PackedStringArray, column: String) -> String:
	var at := Array(Telemetry.COLUMNS).find(column)
	if at < 0 or at >= row.size():
		return ""
	return row[at]


func _erase() -> void:
	SaveManager.erase(Telemetry.PATH)


func _same(what: String, got: String, wanted: String) -> void:
	if got != wanted:
		_fail("%s reads %s, should be %s" % [what, got, wanted])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"telemetry OK — a wave is one row of its own figures, a purchase belongs to the "
				+ "wave that paid for it, and a recorder nobody armed leaves nothing behind"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("telemetry FAILED — %s" % failure)
	get_tree().quit(1)
