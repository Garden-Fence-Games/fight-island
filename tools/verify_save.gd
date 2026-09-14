extends Node
## Headless proof of the promise a save makes: the run that comes back is the run that left, and
## nothing a player can do to the file on disk can crash the game.
##
## The file is the one thing here the player owns and can edit, so every failure path is a check of
## its own — missing, truncated, not an object, and written by a build that does not exist yet. A
## save system that only works on files it wrote is not a save system.
##
## Whatever is on this machine is put back at the end. A check that eats the player's run is worse
## than no check.
## Run: godot --headless --path . res://tools/verify_save.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const SETTLE_FRAMES: int = 4
## Far enough ahead that no build will ever read it, which is the whole point of the refusal.
const FUTURE_VERSION: int = 9999
## How long the title screen is left up. Real time rather than frames, because the fault being
## checked for is a clock that counts seconds nobody spent playing.
const TITLE_IDLE: float = 0.3

var _failures: PackedStringArray = []
var _kept_run: String = ""
var _kept_progress: String = ""


func _ready() -> void:
	_run()


func _run() -> void:
	_keep_what_is_on_this_machine()
	_check_a_run_survives_a_round_trip()
	_check_a_missing_file_is_not_a_run()
	_check_a_corrupt_file_falls_back()
	_check_a_truncated_file_falls_back()
	_check_a_newer_build_is_refused()
	_check_settings_survive_the_version_stamp()
	_check_a_finished_run_is_not_resumable()
	_check_the_merchant_is_still_owed()
	await _check_an_interrupted_wave_is_fought_again()
	await _check_the_clock_stops_at_the_title()
	_put_back_what_was_on_this_machine()
	_report()


## The round trip is the whole feature: money, upgrades and the tally all have to come back, and
## the tally is the half that cannot be reconstructed from anything else.
func _check_a_run_survives_a_round_trip() -> void:
	GameState.begin_run()
	EventBus.wave_started.emit(4, 6)
	GameState.earn(500)
	var track := Upgrades.find(&"stamina")
	if not GameState.buy(track):
		_fail("the round trip could not set up a purchase")
		return
	GameState.stats.perfect_hits = 9
	GameState.stats.record_kill(&"farmhand")
	GameState.stats.record_kill(&"farmhand")
	GameState.save_run()

	var seed_before := GameState.run_seed
	var money_before := GameState.money
	var spent_before := GameState.stats.money_spent
	# Read the file before wiping, because starting a fresh run is also what overwrites it.
	var stored := SaveManager.read_run()
	GameState.begin_run()
	if not GameState.restore(stored):
		_fail("a run that was just written did not come back")
		return
	if GameState.run_seed != seed_before:
		_fail("the seed changed across the round trip, so the island would not")
	if GameState.wave != 4 or not GameState.wave_in_progress:
		_fail(
			(
				"the wave came back as %d, in progress %s"
				% [GameState.wave, GameState.wave_in_progress]
			)
		)
	if GameState.money != money_before:
		_fail("money came back as %d, expected %d" % [GameState.money, money_before])
	if GameState.level_of(track) != 1:
		_fail("a bought upgrade did not come back")
	if GameState.stats.perfect_hits != 9 or GameState.stats.kills_of(&"farmhand") != 2:
		_fail("the tally did not come back")
	if GameState.stats.money_spent != spent_before:
		_fail("what was spent did not come back, so the summary would understate it")
	# What was bought this wave comes back with it, or a resume would hand the allowance out again.
	var left := Economy.purchases_after(GameState.wave) - 1
	if GameState.purchases_left() != left:
		_fail(
			(
				"a resumed run has %d purchases left in a wave that already had one, expected %d"
				% [GameState.purchases_left(), left]
			)
		)


func _check_a_missing_file_is_not_a_run() -> void:
	SaveManager.clear_run()
	if SaveManager.has_run():
		_fail("a deleted run file still reads as a run")
	if GameState.load_run():
		_fail("a missing file loaded as a run")


func _check_a_corrupt_file_falls_back() -> void:
	SaveManager.write_json(SaveManager.RUN_PATH, {"wave": 3})
	# A dictionary with no seed is not half a run, it is not a run.
	if GameState.load_run():
		_fail("a run with no seed was accepted")
	if FileAccess.file_exists(SaveManager.RUN_PATH):
		_fail("an unreadable run file was left behind to fail again every launch")


func _check_a_truncated_file_falls_back() -> void:
	var file := FileAccess.open(SaveManager.RUN_PATH, FileAccess.WRITE)
	if file == null:
		_fail("could not write the truncated file this check needs")
		return
	file.store_string('{"seed": 12, "wave":')
	file.close()
	if not SaveManager.read_run().is_empty():
		_fail("a truncated file parsed as a run")
	if GameState.load_run():
		_fail("a truncated file loaded as a run")


func _check_a_newer_build_is_refused() -> void:
	SaveManager.write_json(SaveManager.RUN_PATH, {"version": FUTURE_VERSION, "seed": 7, "wave": 9})
	if not SaveManager.read_run().is_empty():
		_fail("a run from a newer build was read anyway")
	SaveManager.clear_run()


## The settings file that shipped carries no version stamp at all. Refusing it would reset every
## player's options on the update that added the stamp, which is the worst possible way to find out.
func _check_settings_survive_the_version_stamp() -> void:
	var kept := SaveManager.read_json(SaveManager.SETTINGS_PATH)
	SaveManager.write_json(SaveManager.SETTINGS_PATH, {"audio_master": 42})
	var stamped := SaveManager.read_settings()
	if int(stamped.get("audio_master", -1)) != 42:
		_fail("an unstamped settings file was thrown away instead of migrated")
	SaveManager.write_settings({"audio_master": 42})
	if (
		int(SaveManager.read_json(SaveManager.SETTINGS_PATH).get("version", 0))
		!= SaveManager.VERSION
	):
		_fail("a written settings file carries no version, so the next build cannot tell")
	SaveManager.write_json(SaveManager.SETTINGS_PATH, kept)


func _check_a_finished_run_is_not_resumable() -> void:
	GameState.begin_run()
	EventBus.wave_started.emit(2, 4)
	if not SaveManager.has_run():
		_fail("a run in progress was not on disk")
	GameState.end_run()
	if SaveManager.has_run():
		_fail("a finished run can still be continued")
	if GameState.best_wave() < 2:
		_fail("the wave reached was not recorded in progress.json")


## Quitting while the merchant is up must not cost the player that wave's one purchase.
func _check_the_merchant_is_still_owed() -> void:
	var flow := RunFlow.new()
	GameState.begin_run()
	EventBus.wave_started.emit(3, 5)
	GameState.earn(500)
	if flow.merchant_is_owed():
		_fail("the merchant was owed in the middle of a wave")
	EventBus.wave_cleared.emit(3, 0)
	if not flow.merchant_is_owed():
		_fail("a run resumed between two waves lost its merchant")
	if not GameState.buy(Upgrades.find(&"health")):
		_fail("the owed merchant could not be spent")
	if flow.merchant_is_owed():
		_fail("the merchant was owed again after the wave's purchase was made")
	flow.free()


## The off-by-one that this issue exists to kill: a player who quits halfway through wave five
## comes back to wave five, not to wave six.
func _check_an_interrupted_wave_is_fought_again() -> void:
	GameState.begin_run()
	EventBus.wave_started.emit(5, 8)
	var interrupted := await _wave_the_director_opens()
	if interrupted != 5:
		_fail("a wave quit halfway through reopened as wave %d, expected 5" % interrupted)

	EventBus.wave_cleared.emit(5, 0)
	var handed_over := await _wave_the_director_opens()
	if handed_over != 6:
		_fail("a cleared wave handed over to wave %d, expected 6" % handed_over)


## The other half of the same fact. Quitting to the title keeps the run *and* keeps the wave — that
## is what makes it resume into that wave rather than past it — so the clock cannot be gated on
## either of them, and a laptop left open on the menu used to add hours to the run summary.
func _check_the_clock_stops_at_the_title() -> void:
	GameState.begin_run()
	var arena := (load(ARENA) as PackedScene).instantiate()
	add_child(arena)
	await get_tree().process_frame
	var director := arena.get_node("WaveDirector") as WaveDirector
	if director == null:
		_fail("the arena has no wave director to fight a wave with")
		return
	director.start_wave(5)
	var before_a_frame := GameState.stats.seconds
	await get_tree().process_frame
	await get_tree().process_frame
	if GameState.stats.seconds <= before_a_frame:
		_fail("the run clock did not count while a wave was being fought")

	# What a quit to the title does: the island goes, the run stays, and the wave stays with it.
	arena.queue_free()
	await get_tree().process_frame
	if not GameState.run_in_progress or not GameState.wave_in_progress:
		_fail("quitting mid-wave dropped the wave, so the run would resume past it")
	var at_the_title := GameState.stats.seconds
	await get_tree().create_timer(TITLE_IDLE, true, false, true).timeout
	if GameState.stats.seconds > at_the_title:
		_fail(
			(
				"the clock ran on the title screen for %.2f s of a %.2f s wait"
				% [GameState.stats.seconds - at_the_title, TITLE_IDLE]
			)
		)
	GameState.end_run()


## What `start_wave` would be called with, read off a director that has just woken up in a fresh
## arena — which is exactly what a resumed run does.
func _wave_the_director_opens() -> int:
	var arena := (load(ARENA) as PackedScene).instantiate()
	add_child(arena)
	await get_tree().process_frame
	var director := arena.get_node("WaveDirector") as WaveDirector
	var opens := director.wave + 1 if director != null else -1
	if director != null:
		director.halt()
	arena.queue_free()
	await get_tree().process_frame
	return opens


func _keep_what_is_on_this_machine() -> void:
	_kept_run = _read_text(SaveManager.RUN_PATH)
	_kept_progress = _read_text(SaveManager.PROGRESS_PATH)


func _put_back_what_was_on_this_machine() -> void:
	_write_text(SaveManager.RUN_PATH, _kept_run)
	_write_text(SaveManager.PROGRESS_PATH, _kept_progress)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> void:
	if text.is_empty():
		SaveManager.erase(path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print("save OK — the run comes back, and no file on disk can crash it")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
