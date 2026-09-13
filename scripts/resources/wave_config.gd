class_name WaveConfig
extends Resource
## Every coefficient a wave is made of, in one place and tunable without opening a script.
##
## The formulas in `docs/game-design.md` are these fields, not a copy of them: the table in the
## document and the numbers below are checked against each other by `tools/verify_waves.tscn`, so
## the two cannot drift apart while nobody is looking.

@export_group("Size")
## The roster is a budget the island draws on to stay populated for a whole four-minute wave, not a
## queue to be emptied — `max_alive` is what the player actually faces at once. It is generous on
## purpose: a wave that runs out of farmers halfway through its night is a wave that stops.
@export var base_count: int = 12
@export var count_per_wave: float = 6.0
@export var base_alive: int = 4
@export var alive_per_wave: float = 0.8
@export var fewest_alive: int = 4
@export var most_alive: int = 12

@export_group("Scaling")
@export var health_per_wave: float = 0.18
@export var damage_per_wave: float = 0.10
@export var speed_per_wave: float = 0.03
@export var speed_ceiling: float = 1.35
## The telegraph shortens with the waves and stops at its floor. A wind-up nobody can read is
## noise, not difficulty — which is why this is a floor and not a curve that keeps going.
@export var windup_per_wave: float = 0.02
@export var windup_floor: float = 0.75

@export_group("Elites")
## What an elite is worth. Null and none ever roll, which is what lets a tutorial wave or a
## headless check run the same director with the feature switched off.
@export var elite: EliteRank = null
@export var elite_first_wave: int = 4
@export var elite_base_chance: float = 0.10
@export var elite_chance_per_wave: float = 0.05
@export var elite_chance_ceiling: float = 0.40

## Clearing this wave is the victory. It lives here with the rest of the wave's figures rather than
## in the screen that announces it, so there is one place that knows how long a run is.
@export var final_wave: int = 15

@export_group("Reward")
@export var base_reward: int = 50
@export var reward_per_wave: int = 12
@export var flawless_bonus: float = 0.30

@export_group("Composition")
@export var bands: Array[WaveBand] = []
## The turn of the day, which is also how long a wave lasts. It lives here because a wave *is* a
## turn of the day: asking how long one takes and asking when night falls are the same question.
@export var cycle: DayCycle = null


func enemy_count(wave: int) -> int:
	return base_count + int(floorf(float(wave) * count_per_wave))


func max_alive(wave: int) -> int:
	var wanted := base_alive + int(floorf(float(wave) * alive_per_wave))
	return clampi(wanted, fewest_alive, most_alive)


func health_multiplier(wave: int) -> float:
	return 1.0 + health_per_wave * float(wave - 1)


## The phase is optional so the wave curve can still be read on its own — which is what the design
## document tabulates and what the headless check compares against.
func damage_multiplier(wave: int, phase: DayPhase = null) -> float:
	var grown := 1.0 + damage_per_wave * float(wave - 1)
	return grown * (phase.damage_scale if phase != null else 1.0)


func speed_multiplier(wave: int) -> float:
	return minf(1.0 + speed_per_wave * float(wave - 1), speed_ceiling)


## Night shortens the telegraph before the floor is applied and never after it. The floor is the
## point past which a wind-up stops being readable, and an unreadable telegraph is not difficulty
## whatever time it is — so night bites in the early waves and the floor wins in the late ones.
func windup_multiplier(wave: int, phase: DayPhase = null) -> float:
	var shortened := 1.0 - windup_per_wave * float(wave - 1)
	if phase != null:
		shortened *= phase.windup_scale
	return maxf(shortened, windup_floor)


func elite_chance(wave: int) -> float:
	if wave < elite_first_wave:
		return 0.0
	var grown := elite_base_chance + elite_chance_per_wave * float(wave - elite_first_wave)
	return minf(grown, elite_chance_ceiling)


## Rounded to whole money: a wallet with a decimal point in it is a wallet nobody can read.
func reward_for(wave: int, flawless: bool) -> int:
	var money := float(base_reward + reward_per_wave * (wave - 1))
	if flawless:
		money *= 1.0 + flawless_bonus
	return int(roundf(money))


## The mix in force at this wave — the last band that has started.
func band_for(wave: int) -> WaveBand:
	var found: WaveBand = null
	for band: WaveBand in bands:
		if band != null and band.first_wave <= wave:
			if found == null or band.first_wave >= found.first_wave:
				found = band
	return found
