extends Node
## The fifteen waves, measured off the shipped resources rather than argued about.
##
## **What a wave costs the player is not what a wave sends.** `max_alive` decides how many bodies
## stand on the island; `AttackTokens` decides how many of them may swing, and it is two by day and
## three at night in every wave of the run. So the crowd is a fact about crowding, and the damage
## coming at the player is a fact about the pool — which does not grow.
##
## Every figure below is derived from `data/`: the wave config, the day cycle, the archetypes and
## their attacks, the upgrade tracks. Nothing is typed in twice. Change a `.tres` and the table
## moves with it, which is the only reason to have a tool rather than a paragraph.
##
## **What it does not model.** A body has to reach the player before it swings, it loses its turn
## when it is staggered, and the player dodges. So `contact` is the pressure with every token spent
## and nobody missing — a floor on survival, not a prediction of it. Read the *shape* across the
## fifteen, which is what a tuning pass moves; the absolute seconds are the worst case.
## Run: godot --headless --path . res://tools/measure_waves.tscn

const CONFIG: String = "res://data/waves/standard.tres"
const TRACKS: String = "res://data/upgrades/"
## The player's health before anything is bought — `scenes/actors/player.tscn`.
const BASE_HEALTH: float = 100.0
## What a wave pays over and above its reward: two per body, on the bodies a player actually fells.
const KILL_MONEY: int = 2
## The upgrade ladder from `Economy`, so the money column can say what it buys rather than what it
## totals. Written out because a run's affordability is the claim being checked.
const LADDER: Array[int] = [50, 80, 130, 205, 330]


func _ready() -> void:
	_run()


func _run() -> void:
	var config := load(CONFIG) as WaveConfig
	if config == null or config.cycle == null:
		printerr("no wave config")
		get_tree().quit(1)
		return
	var turn := config.cycle.wave_seconds()
	print("A wave is %.0f s. The melee pool is %s, the ranged pool is 1." % [turn, _pools(config)])
	print("")
	_table(config, turn)
	print("")
	_purse(config)
	get_tree().quit(0)


## The melee token pool, phase by phase, so the one number that caps incoming damage is on the page
## next to the columns it explains.
func _pools(config: WaveConfig) -> String:
	var sizes: PackedStringArray = []
	for phase: DayPhase in config.cycle.phases:
		if phase != null:
			sizes.append("%s %d" % [phase.id, int(phase.get("melee_tokens"))])
	return ", ".join(sizes)


## One phase of the turn by name, so the day column and the night column read the same figures the
## game reads rather than a copy of them.
func _phase(config: WaveConfig, id: StringName) -> DayPhase:
	for phase: DayPhase in config.cycle.phases:
		if phase != null and phase.id == id:
			return phase
	return null


func _table(config: WaveConfig, turn: float) -> void:
	print("wave  alive  standing    day dps  night dps   contact  roster  reachable")
	for wave: int in range(1, config.final_wave + 1):
		var alive := config.max_alive(wave)
		var standing := _standing_health(config, wave, alive)
		var by_day := _incoming(config, wave, _phase(config, &"day"))
		var by_night := _incoming(config, wave, _phase(config, &"night"))
		var health := BASE_HEALTH + _health_bought(wave)
		var contact := health / by_night if by_night > 0.0 else 0.0
		var reachable := _reachable(config, wave, turn)
		print(
			(
				"%4d  %5d  %8.0f  %9.1f  %9.1f  %6.1f s  %6d  %9d"
				% [
					wave,
					alive,
					standing,
					by_day,
					by_night,
					contact,
					config.enemy_count(wave),
					reachable
				]
			)
		)


## What stands on the island at once, in hit points: the wave's mix at its health multiplier.
func _standing_health(config: WaveConfig, wave: int, alive: int) -> float:
	var band := config.band_for(wave)
	if band == null:
		return 0.0
	var mean := 0.0
	for share: ArchetypeShare in band.shares:
		if share != null and share.enemy != null:
			mean += share.share * share.enemy.health
	return mean * float(alive) * config.health_multiplier(wave)


## Damage per second with every token spent. The melee pool is the phase's, and it is always full:
## a wave of this size never runs short of bodies willing to commit.
##
## **The ranged pool is one token and it is only worth what the odds of a thrower say.** One alive
## is enough to spend it and a second adds nothing, so what is paid is the chance that at least one
## of the standing crowd is a thrower — which is what makes a share of six per cent a different
## thing from a share of eighteen, rather than the same token either way.
func _incoming(config: WaveConfig, wave: int, phase: DayPhase) -> float:
	var band := config.band_for(wave)
	if band == null or phase == null:
		return 0.0
	var melee := 0.0
	var melee_share := 0.0
	var ranged := 0.0
	var ranged_share := 0.0
	for share: ArchetypeShare in band.shares:
		if share == null or share.enemy == null or share.enemy.attack == null:
			continue
		var rate := _rate(share.enemy, config, wave, phase)
		if share.enemy.is_ranged:
			ranged += share.share * rate
			ranged_share += share.share
		else:
			melee += share.share * rate
			melee_share += share.share
	var tokens := int(phase.get("melee_tokens"))
	var out := 0.0
	if melee_share > 0.0:
		out += melee / melee_share * float(tokens)
	if ranged_share > 0.0:
		var none := pow(1.0 - ranged_share, float(config.max_alive(wave)))
		out += ranged / ranged_share * (1.0 - none)
	return out * config.damage_multiplier(wave, phase)


## One body's damage per second of its own attack cycle, with the telegraph the wave and the hour
## have shortened. The multipliers are applied by the caller, once.
func _rate(enemy: EnemyData, config: WaveConfig, wave: int, phase: DayPhase) -> float:
	var attack := enemy.attack
	var cycle := (
		attack.windup * config.windup_multiplier(wave, phase) + attack.active + attack.recovery
	)
	return attack.damage / cycle if cycle > 0.0 else 0.0


## How much of the roster can physically arrive. A body only enters when one dies once the island
## is full, so the budget is spent at the rate the player kills — and `enemy_count` past that is a
## number nobody will ever meet.
func _reachable(config: WaveConfig, wave: int, turn: float) -> int:
	var band := config.band_for(wave)
	if band == null:
		return 0
	var mean := 0.0
	for share: ArchetypeShare in band.shares:
		if share != null and share.enemy != null:
			mean += share.share * share.enemy.health
	var body := mean * config.health_multiplier(wave)
	var felled := int(floorf(_player_damage_per_second(wave) * turn / body)) if body > 0.0 else 0
	return mini(config.enemy_count(wave), config.max_alive(wave) + felled)


## What the player puts out, on the weapon a run of this length would be swinging, at the level the
## money below affords. The stick: found in wave 2, thirty damage on the overhead, and a three-hit
## chain that averages out near half of it a second.
func _player_damage_per_second(wave: int) -> float:
	var stick := load(TRACKS + "stick.tres") as UpgradeTrack
	var levels := float(mini((wave - 1) / 3, 5))
	var grown := 1.0 + (stick.damage if stick != null else 0.15) * levels
	return 16.0 * grown


## Health bought by this wave, on the same assumption the damage column makes: a level every three
## waves, spread across the tracks, so health takes a third of them.
func _health_bought(wave: int) -> float:
	var health := load(TRACKS + "health.tres") as UpgradeTrack
	var per := health.max_health if health != null else 20.0
	return per * floorf(float((wave - 1) / 3) / 3.0)


## What the run pays, against what the ladder costs. The claim in `docs/game-design.md` is two full
## tracks and change out of five; this is where it is either true or is not.
func _purse(config: WaveConfig) -> void:
	var earned := 0
	var turn := config.cycle.wave_seconds()
	for wave: int in range(1, config.final_wave + 1):
		earned += config.reward_for(wave, false)
		earned += _reachable(config, wave, turn) * KILL_MONEY
	var track := 0
	for cost: int in LADDER:
		track += cost
	print(
		(
			"A run with no flawless bonus earns %d. One track maxed costs %d — %.1f tracks of five."
			% [earned, track, float(earned) / float(track)]
		)
	)
