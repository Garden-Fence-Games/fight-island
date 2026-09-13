extends Node
## Headless proof of what `docs/tutorial.md` promises: **the opening lines run on a clock, never on
## a button, and wave 1 starts when they are over.**
##
## The failure this guards against is the one the old tutorial had — a lesson waiting for an input
## nobody made, and a run that never reached a wave. So the check never presses anything: it only
## lets time pass, and asks that everything moves on anyway.
##
## Whatever is on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_tutorial.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const SETTLE_FRAMES: int = 4
const STEPS: PackedStringArray = [
	"01_angry", "02_fight", "03_sprint", "04_survive", "05_weapon_switch"
]
const ORDER: Array[StringName] = [&"angry", &"fight", &"sprint", &"survive"]
## A tick of the clock, as a sixty-hertz frame.
const TICK: float = 1.0 / 60.0

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _director: TutorialDirector = null
var _waves: WaveDirector = null
var _kept_run: Dictionary = {}
var _kept_prompts: bool = true


func _ready() -> void:
	_run()


func _run() -> void:
	_keep_what_is_on_this_machine()
	_check_the_steps_are_data()
	await _open_a_fresh_arena()
	if _director == null:
		_report()
		return
	_check_the_island_waits_for_the_lines()
	_check_the_lines_run_on_the_clock()
	_check_wave_one_starts_after_the_last_line()
	await _check_only_a_title_run_shows_it()
	await _check_switching_the_prompts_off_starts_the_wave()
	await _check_the_first_weapon_teaches_the_switch()
	_close_the_arena()
	_put_back_what_was_on_this_machine()
	_report()


## The order, the wording and the timing live in `data/tutorial/`, so the failure this catches is a
## line whose copy was never written — a prompt that reads as its own key — or one with no time on
## screen, which the player would never see.
func _check_the_steps_are_data() -> void:
	for name: String in STEPS:
		var step := load("res://data/tutorial/%s.tres" % name) as TutorialStep
		if step == null:
			_fail("data/tutorial/%s.tres is not a TutorialStep" % name)
			continue
		if step.id.is_empty() or step.prompt_key.is_empty():
			_fail("%s is missing its id or its prompt key" % name)
		elif tr(step.prompt_key) == step.prompt_key:
			_fail("%s has no string for %s" % [step.id, step.prompt_key])
		if step.seconds <= 0.0:
			_fail("%s is on screen for no time at all" % step.id)


func _check_the_island_waits_for_the_lines() -> void:
	if not _director.is_running():
		_fail("a fresh run did not start the tutorial")
		return
	var ids: Array[StringName] = []
	for step: TutorialStep in _director.steps:
		ids.append(step.id)
	if ids != ORDER:
		_fail("the tutorial runs %s, expected %s" % [ids, ORDER])
	if _waves.is_running():
		_fail("wave 1 is running underneath the tutorial")
	if _waves.spawner != null and _waves.spawner.alive_count() > 0:
		_fail("something is standing on the island while the lines are up")
	if not _director.prompt.is_showing():
		_fail("the first line is not on screen")


## The whole point: nothing is pressed, and every line still gives way after its own time — not
## before, not never.
func _check_the_lines_run_on_the_clock() -> void:
	for index: int in ORDER.size():
		var step := _director.current_step()
		if step == null or step.id != ORDER[index]:
			_fail(
				"expected %s on screen, found %s" % [ORDER[index], step.id if step else &"nothing"]
			)
			return
		# A few frames short of its time, then frame by frame until it goes, so the next line starts
		# on a clean clock rather than on whatever this one overshot by.
		_let_time_pass(step.seconds - TICK * 4.0)
		if _director.current_step() != step:
			_fail("%s gave way before its %.1f seconds were up" % [step.id, step.seconds])
			return
		var frames := 0
		while _director.current_step() == step and frames < 12:
			_let_time_pass(TICK)
			frames += 1
		if _director.current_step() == step:
			_fail(
				(
					"%s is still up after its %.1f seconds, with nothing pressed"
					% [step.id, step.seconds]
				)
			)
			return


func _check_wave_one_starts_after_the_last_line() -> void:
	if _director.is_running():
		_fail("every line has run and the tutorial kept the island")
	if _director.prompt.is_showing():
		_fail("the last line stayed on screen into the wave")
	if not _waves.is_running() or _waves.wave != 1:
		_fail("wave 1 did not start when the lines were over (wave %d)" % _waves.wave)
	if not bool(Settings.get_value(&"gameplay_tutorial_prompts")):
		_fail("the tutorial switched the player's setting off, so the next new run skips it")


## Every run begun from the title teaches it again — the bug this replaced was a tutorial that ran
## once per machine. A retry or a restart does not: it is the same player straight back in.
func _check_only_a_title_run_shows_it() -> void:
	_close_the_arena()
	await _open_a_fresh_arena(false)
	if _director != null and (_director.is_running() or _director.prompt.is_showing()):
		_fail("a retry showed the tutorial, and only a run from the title should")
	_close_the_arena()
	await _open_a_fresh_arena()
	if _director != null and not _director.is_running():
		_fail("a second run from the title did not show the tutorial again")
	if GameState.tutorial_owed:
		_fail("the tutorial started and the run still owes one, so a reload would show it twice")


## Switched off mid-way is asking to skip it, and the run has to carry on rather than sit empty.
func _check_switching_the_prompts_off_starts_the_wave() -> void:
	_close_the_arena()
	Settings.set_value(&"gameplay_tutorial_prompts", true)
	await _open_a_fresh_arena()
	if _director == null or not _director.is_running():
		_fail("a fresh run with the prompts on did not start the tutorial")
		return
	Settings.set_value(&"gameplay_tutorial_prompts", false)
	_let_time_pass(TICK)
	if _director.is_running():
		_fail("the prompts were switched off and the tutorial kept the island anyway")
	if not _waves.is_running() or _waves.wave != 1:
		_fail("switching the prompts off left the island with no wave")


## The first weapon picked up shows how to switch, once, with the button of the device in hand — and
## a pickup during the opening lines waits for them rather than cutting one off.
func _check_the_first_weapon_teaches_the_switch() -> void:
	_close_the_arena()
	Settings.set_value(&"gameplay_tutorial_prompts", true)
	await _open_a_fresh_arena()
	if _director == null or _director.on_first_weapon == null:
		_fail("the tutorial has no line for the first weapon")
		return
	var line := _director.on_first_weapon
	var switch_text := tr(line.prompt_key).format([Devices.glyph("weapon_next")])
	# Picked up while the opening lines are still up: the opening keeps the screen.
	EventBus.weapon_found.emit(&"stick")
	if _director.is_showing_weapon_line():
		_fail("a weapon found during the opening cut an opening line off")
	var total := 0.0
	for step: TutorialStep in _director.steps:
		total += step.seconds
	_let_time_pass(total + TICK * 12.0)
	if _director.is_running():
		_fail("the opening did not finish in the time its lines add up to")
	if not _director.is_showing_weapon_line() or _director.prompt.text() != switch_text:
		_fail(
			(
				"after the opening the switch line is not up — the prompt reads '%s', expected '%s'"
				% [_director.prompt.text(), switch_text]
			)
		)
	_let_time_pass(line.seconds + TICK * 4.0)
	if _director.is_showing_weapon_line():
		_fail("the switch line is still up after its %.1f seconds" % line.seconds)
	EventBus.weapon_found.emit(&"gun")
	if _director.is_showing_weapon_line():
		_fail("a second weapon showed the switch line again")
	# After the opening, the line comes up the moment the weapon does.
	_close_the_arena()
	await _open_a_fresh_arena()
	_let_time_pass(total + TICK * 12.0)
	EventBus.weapon_found.emit(&"gun")
	if not _director.is_showing_weapon_line():
		_fail("a weapon found after the opening did not show the switch line")
	# And a retry does not teach it.
	_close_the_arena()
	await _open_a_fresh_arena(false)
	EventBus.weapon_found.emit(&"gun")
	if _director != null and _director.is_showing_weapon_line():
		_fail("a retry showed the switch line, and only a run from the title should")


## Driven by hand rather than by frames, so the check takes no real time and cannot race the clock.
func _let_time_pass(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		_director._process(minf(TICK, left))
		left -= TICK


## `from_title` is the run the title begins, which owes the opening and the tutorial. The opening
## itself belongs to `Main`, which this check never builds, so its flag is dropped here.
func _open_a_fresh_arena(from_title: bool = true) -> void:
	GameState.begin_run(from_title)
	GameState.intro_owed = false
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	await get_tree().physics_frame
	_director = _arena.get_node_or_null("TutorialDirector") as TutorialDirector
	_waves = _arena.get_node_or_null("WaveDirector") as WaveDirector
	if _director == null or _waves == null:
		_fail("the arena is missing its tutorial or its wave director")
		_director = null
		return
	# The clock is this check's to turn.
	_director.process_mode = Node.PROCESS_MODE_DISABLED


func _close_the_arena() -> void:
	if _arena == null:
		return
	remove_child(_arena)
	_arena.free()
	_arena = null
	_director = null
	_waves = null


func _keep_what_is_on_this_machine() -> void:
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	_kept_prompts = bool(Settings.get_value(&"gameplay_tutorial_prompts"))
	Settings.set_value(&"gameplay_tutorial_prompts", true)


func _put_back_what_was_on_this_machine() -> void:
	Settings.set_value(&"gameplay_tutorial_prompts", _kept_prompts)
	if _kept_run.is_empty():
		SaveManager.erase(SaveManager.RUN_PATH)
	else:
		SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print("tutorial OK — the lines run on the clock, and wave 1 starts when they are over")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
