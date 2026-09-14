extends Node
## The current run, and nothing else: no gameplay logic and no node references. It holds the seed,
## the money, the wave the player is on and the tally the summary reads, and it keeps all of it by
## listening to the bus rather than by being told.
##
## It is also what is written to disk. A run is forty minutes, which is far too long to lose to a
## closed laptop — so the same fields that drive the HUD are the ones that come back.

signal debug_overlay_toggled(visible: bool)
## The wallet changed, and by how much. On GameState rather than on the bus because the balance is
## state and the bus holds none — anything that wants to show money is already able to reach an
## autoload. `delta` is carried so a display can count up to the new figure rather than snap to it.
signal money_changed(balance: int, delta: int)
## The rules of the day have changed. Emitted only on a real change, so a listener can size a pool
## or swap a look without checking whether anything actually moved.
signal day_phase_changed(phase: DayPhase)
## A track went up a level. Carried rather than polled so the body that has to grow can listen and
## the merchant does not need to know a player exists.
signal upgrade_purchased(track: UpgradeTrack, level: int)

## The one thing in `progress.json` this build writes.
const BEST_WAVE_KEY: String = "best_wave"

var run_seed: int = 0
## The wave the player is on: being fought, or the one just cleared.
var wave: int = 0
## Whether that wave is still being fought. It is the difference between resuming *into* wave five
## and resuming *past* it, and getting it wrong silently skips a wave.
var wave_in_progress: bool = false
var run_in_progress: bool = false
## Whether a fight is actually on screen. Runtime only and never saved: `wave_in_progress` says the
## run is *mid-wave*, which stays true across a quit to the title, and the clock has to stop there.
var fighting: bool = false
## Whether the run about to load opens on the player waking up. Runtime only and never saved: set by
## a run started from the title and spent by `RunIntro` the moment it plays, so a resume, a retry
## and every headless check that begins a run go straight into the game.
var intro_owed: bool = false
## Whether the run about to load shows the tutorial lines after that opening. Set alongside
## `intro_owed` and spent by `TutorialDirector`, so every run begun from the title teaches it again.
var tutorial_owed: bool = false
## Carries between waves and is spent at the merchant. It only ever changes through `earn` and
## `spend`, so nothing can move it without the signal going out.
var money: int = 0
## What the run summary reads. Kept while the run happens, because half of these numbers leave no
## trace to reconstruct them from once the fight is over.
var stats: RunStats = RunStats.new()
## The turn of the day this run is on, and where in it the run has got to. The cycle is here rather
## than reached for through the wave director because the sky, the clock and the enemies all want
## it and none of them should have to find a director to ask.
var day_cycle: DayCycle = null
var day_phase: DayPhase = null
## Nought to twenty-four — what the clock face reads.
var hour: float = 0.0
## Seconds into the wave, which is the same fact the hour is but in the unit the cycle is written
## in. Both are kept because the face wants one and the sky wants the other, and deriving either
## from the other means every reader carrying the conversion.
var day_elapsed: float = 0.0
## Track id to how many levels of it are owned. Levels rather than effects, so the body can always
## recompute from its own base instead of carrying a running total that drifts.
var upgrade_levels: Dictionary = {}
## What is in the bag: the weapons found, the one in hand, and the rounds. Its own object for the
## same reason the tally is — it has rules, and this class is narrow on purpose.
var loadout: Loadout = Loadout.new()

var debug_overlay_visible: bool = false

## The wave purchases were last made in, and how many. The allowance is small on purpose — the
## interesting decision is what the player gives up, and it stops being one if they can buy
## everything — and it grows every few waves, see `Economy.purchases_after`.
var _bought_in_wave: int = -1
var _bought_this_wave: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Run time is fight time: a menu open over a paused game is not part of it.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	run_seed = _rng.seed
	EventBus.wave_started.connect(_on_wave_started)
	# Listened for rather than handed over: the wave director pays out and the enemies pay out, and
	# neither has any business knowing a wallet exists.
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.parry_perfect.connect(_on_parry_perfect)
	# Before anything can ask whether there is a run to continue.
	load_run()


## The clock measures fighting, not menus. Gated on `fighting` rather than on the wave because a run
## quit to the title mid-wave is still mid-wave — deliberately, so it resumes into that wave — and a
## run waiting on a title screen overnight would otherwise report a time nobody spent playing.
func _process(delta: float) -> void:
	if run_in_progress and fighting:
		stats.seconds += delta


## `with_intro` is the title's to pass: see `intro_owed` and `tutorial_owed`.
func begin_run(with_intro: bool = false) -> void:
	intro_owed = with_intro
	tutorial_owed = with_intro
	_rng.randomize()
	run_seed = _rng.seed
	run_in_progress = true
	wave = 0
	wave_in_progress = false
	money = 0
	hour = 0.0
	day_elapsed = 0.0
	set_day_phase(null)
	stats = RunStats.new()
	upgrade_levels = {}
	loadout = Loadout.new()
	_bought_in_wave = -1
	_bought_this_wave = 0
	money_changed.emit(money, 0)
	EventBus.weapon_equipped.emit(loadout.weapon())
	save_run()


func end_run() -> void:
	run_in_progress = false
	wave_in_progress = false
	stats.ended_on_wave = wave
	_record_best_wave()
	# A finished run is not a resumable one, whether it ended in a death or in a victory.
	discard_run()


func earn(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	stats.money_earned += amount
	money_changed.emit(money, amount)


## Whether the purchase went through. A merchant that has to check the balance itself is a merchant
## that can forget to, and then money goes negative somewhere nobody is looking.
func spend(amount: int) -> bool:
	if amount <= 0 or amount > money:
		return false
	money -= amount
	stats.money_spent += amount
	money_changed.emit(money, -amount)
	return true


func level_of(track: UpgradeTrack) -> int:
	return int(upgrade_levels.get(track.id, 0)) if track != null else 0


## What the next level of a track costs, or zero when there is no next level.
func price_of(track: UpgradeTrack) -> int:
	return Economy.upgrade_cost(level_of(track))


func can_buy(track: UpgradeTrack) -> bool:
	if track == null or purchases_left() <= 0:
		return false
	if level_of(track) >= Economy.LEVEL_CAP:
		return false
	# A track for a weapon that is not in the bag is not for sale. Fifteen per cent more damage on a
	# gun the player finds two waves from now is money spent on nothing they can use, and the card
	# said nothing about it — the merchant sells what you carry.
	if track.weapon != &"" and not loadout.owns(track.weapon):
		return false
	return money >= price_of(track)


## Whether the purchase went through. The money leaves, the level goes up and the signal goes out
## in that order, so nothing can see a level that has not been paid for.
func buy(track: UpgradeTrack) -> bool:
	if not can_buy(track):
		return false
	if not spend(price_of(track)):
		return false
	var level := level_of(track) + 1
	upgrade_levels[track.id] = level
	if _bought_in_wave != wave:
		_bought_in_wave = wave
		_bought_this_wave = 0
	_bought_this_wave += 1
	# The rounds land now rather than growing a per-wave grant, because there is no longer a
	# per-wave grant to grow. The merchant is one of the two ways ammunition enters a run.
	var handed := loadout.take(track.rounds)
	if handed > 0:
		EventBus.rounds_scavenged.emit(handed, null)
	upgrade_purchased.emit(track, level)
	save_run()
	return true


## Whether the merchant still has something to sell this wave.
func can_buy_anything() -> bool:
	return purchases_left() > 0


## How many more upgrades the merchant will sell after this wave. See `Economy.purchases_after`.
func purchases_left() -> int:
	var made := _bought_this_wave if _bought_in_wave == wave else 0
	return maxi(Economy.purchases_after(wave) - made, 0)


## The state a resumed run needs, and only that. The clock is in it, so a run picked up tomorrow
## still reports how long it took — saved at wave boundaries, so at worst it loses the wave that
## was interrupted.
func snapshot() -> Dictionary:
	var levels := {}
	for id: StringName in upgrade_levels:
		levels[String(id)] = int(upgrade_levels[id])
	return {
		# As text, because JSON has one number type and a 64-bit seed does not survive a double.
		# Losing its low bits would bring the run back on a different island.
		"seed": str(run_seed),
		"wave": wave,
		"wave_in_progress": wave_in_progress,
		"money": money,
		"bought_in_wave": _bought_in_wave,
		"bought_this_wave": _bought_this_wave,
		"upgrades": levels,
		"stats": stats.to_dict(),
		# Without this a resumed run hands the gun back unfound, which the player would read as
		# the save having eaten it.
		"loadout": loadout.to_dict(),
	}


## Whether the run came back. A file that is missing a field it cannot do without is refused whole
## rather than restored in halves: half a run reads as a bug in the game, not as a bad file.
func restore(data: Dictionary) -> bool:
	if not data.has("seed") or not data.has("wave"):
		return false
	var stored_seed: Variant = data["seed"]
	run_seed = stored_seed.to_int() if stored_seed is String else int(stored_seed)
	wave = maxi(int(data["wave"]), 0)
	wave_in_progress = bool(data.get("wave_in_progress", false))
	money = maxi(int(data.get("money", 0)), 0)
	_bought_in_wave = int(data.get("bought_in_wave", -1))
	# A save from when one purchase was the whole allowance has no count: that wave's one was spent.
	var made_default := 1 if _bought_in_wave >= 0 else 0
	_bought_this_wave = maxi(int(data.get("bought_this_wave", made_default)), 0)
	upgrade_levels = {}
	var levels: Variant = data.get("upgrades", {})
	if levels is Dictionary:
		for id: Variant in levels as Dictionary:
			# JSON has no StringName, and a String key would never answer `level_of`.
			upgrade_levels[StringName(id)] = int((levels as Dictionary)[id])
	var tally: Variant = data.get("stats", {})
	stats = RunStats.from_dict(tally as Dictionary if tally is Dictionary else {})
	var bag: Variant = data.get("loadout", {})
	loadout = Loadout.from_dict(bag as Dictionary if bag is Dictionary else {})
	run_in_progress = true
	money_changed.emit(money, 0)
	EventBus.weapon_equipped.emit(loadout.weapon())
	loadout.announce()
	return true


func save_run() -> void:
	if not run_in_progress:
		return
	SaveManager.write_run(snapshot())


## Whether a run was picked up. A file this build cannot read is deleted rather than left to fail
## the same way every launch — the player has already lost the run either way, and a title screen
## offering a Continue that does nothing is worse than one that does not offer it.
func load_run() -> bool:
	var data := SaveManager.read_run()
	if data.is_empty():
		return false
	if restore(data):
		return true
	push_warning("save: the stored run could not be read, starting fresh")
	discard_run()
	return false


func discard_run() -> void:
	SaveManager.clear_run()


func best_wave() -> int:
	return int(SaveManager.read_progress().get(BEST_WAVE_KEY, 0))


func set_day_phase(phase: DayPhase) -> void:
	if phase == day_phase:
		return
	day_phase = phase
	day_phase_changed.emit(phase)


## How far one farmer noticing the fight carries to the ones beside him, as the hour makes it.
## Null-handling lives here so no caller has to remember that a cycle is optional.
func rouse_scale() -> float:
	return day_phase.rouse_scale if day_phase != null else 1.0


func toggle_debug_overlay() -> void:
	debug_overlay_visible = not debug_overlay_visible
	debug_overlay_toggled.emit(debug_overlay_visible)


func _on_wave_started(index: int, _enemies: int) -> void:
	wave = index
	wave_in_progress = true
	stats.ended_on_wave = index
	save_run()


func _on_wave_cleared(_index: int, reward: int) -> void:
	wave_in_progress = false
	stats.waves_cleared += 1
	earn(reward)
	save_run()


## A kill is tallied here and paid on the sand. The money and the round a body is worth are thrown
## out of it by `LootDirector` and reach the purse and the pocket when they are walked over — rounds
## come off the bodies of the people who came to kill you, and from nowhere else but the merchant,
## so an empty pocket is a reason to close rather than to back away.
func _on_enemy_died(_enemy: Node3D, archetype: StringName, _reward: int) -> void:
	stats.record_kill(archetype)


func _on_attack_landed(_target: Node3D, _damage: float, perfect: bool, _attack: AttackData) -> void:
	if perfect:
		stats.perfect_hits += 1


func _on_parry_perfect() -> void:
	stats.perfect_parries += 1


## The only thing that outlives a run. It is written on the way out rather than as the waves pass,
## because nothing before the end of a run needs to read it.
func _record_best_wave() -> void:
	var progress := SaveManager.read_progress()
	var best := int(progress.get(BEST_WAVE_KEY, 0))
	if wave <= best:
		return
	progress[BEST_WAVE_KEY] = wave
	SaveManager.write_progress(progress)
