extends Node
## The current run, and nothing else: no gameplay logic and no node references. It holds the seed,
## the money, the wave the player is on and the tally the summary reads, and it keeps all of it by
## listening to the bus rather than by being told.

signal debug_overlay_toggled(visible: bool)
## The wallet changed, and by how much. On GameState rather than on the bus because the balance is
## state and the bus holds none — anything that wants to show money is already able to reach an
## autoload. `delta` is carried so a display can count up to the new figure rather than snap to it.
signal money_changed(balance: int, delta: int)
## A track went up a level. Carried rather than polled so the body that has to grow can listen and
## the merchant does not need to know a player exists.
signal upgrade_purchased(track: UpgradeTrack, level: int)

var run_seed: int = 0
var wave: int = 0
var run_in_progress: bool = false
## Carries between waves and is spent at the merchant. It only ever changes through `earn` and
## `spend`, so nothing can move it without the signal going out.
var money: int = 0
## What the run summary reads. Kept while the run happens, because half of these numbers leave no
## trace to reconstruct them from once the fight is over.
var stats: RunStats = RunStats.new()
## Track id to how many levels of it are owned. Levels rather than effects, so the body can always
## recompute from its own base instead of carrying a running total that drifts.
var upgrade_levels: Dictionary = {}

var debug_overlay_visible: bool = false

## The wave a purchase was last made in. One per wave is the whole economy: the interesting decision
## is what the player gives up, and it stops being one if they can buy everything.
var _bought_in_wave: int = -1
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


func _process(delta: float) -> void:
	if run_in_progress:
		stats.seconds += delta


func begin_run() -> void:
	_rng.randomize()
	run_seed = _rng.seed
	run_in_progress = true
	wave = 0
	money = 0
	stats = RunStats.new()
	upgrade_levels = {}
	_bought_in_wave = -1
	money_changed.emit(money, 0)


func end_run() -> void:
	run_in_progress = false
	stats.ended_on_wave = wave


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
	if track == null or _bought_in_wave == wave:
		return false
	if level_of(track) >= Economy.LEVEL_CAP:
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
	_bought_in_wave = wave
	upgrade_purchased.emit(track, level)
	return true


## Whether the merchant still has something to sell this wave.
func can_buy_anything() -> bool:
	return _bought_in_wave != wave


func toggle_debug_overlay() -> void:
	debug_overlay_visible = not debug_overlay_visible
	debug_overlay_toggled.emit(debug_overlay_visible)


func _on_wave_started(index: int, _enemies: int) -> void:
	wave = index
	stats.ended_on_wave = index


func _on_wave_cleared(_index: int, reward: int) -> void:
	stats.waves_cleared += 1
	earn(reward)


func _on_enemy_died(_enemy: Node3D, archetype: StringName, reward: int) -> void:
	stats.record_kill(archetype)
	earn(reward)


func _on_attack_landed(_target: Node3D, _damage: float, perfect: bool) -> void:
	if perfect:
		stats.perfect_hits += 1


func _on_parry_perfect() -> void:
	stats.perfect_parries += 1
