extends Node
## Headless proof that a wave is a turn of the day: it opens at daybreak, ends in the dark, the
## clock only goes forward, and night is meaner without being darker than a telegraph can be read.
##
## The table below is `docs/game-design.md` written out by hand. Reading the numbers off the
## resource being checked would make this file agree with whatever anybody puts there, which is not
## a test — it is a very expensive way of printing OK.
## Run: godot --headless --path . res://tools/verify_day_night.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const SKY: String = "res://scenes/world/island_sky.tscn"
const CONFIG: String = "res://data/waves/standard.tres"
## Four minutes, which is what "a wave" means now.
const WAVE_SECONDS: float = 90.0
## The rule from the spawn director, written out rather than read off it for the same reason.
const NEAREST_SPAWN: float = 12.0
## Sun plus ambient at night. A telegraph nobody can see is not difficulty either, and this is the
## floor under any future tuning pass that decides night should be darker.
const READABLE: float = 1.2
## Two farmers this far apart: further than a farmhand rouses by day, nearer than he rouses by
## night. One number that both halves of the check have to disagree about.
const APART: float = 11.0
## The whole wave squeezed into this, so the end-to-end check can sit through a night.
const A_QUICK_WAVE: float = 3.0
## Bodies arrive this often during it, and this many may stand at once. Both are pushed well past
## what the game uses: the check needs several farmers on each side of nightfall, and a wave that
## happened to send its last one at dusk would make it pass or fail by the frame.
const A_QUICK_ARRIVAL: float = 0.15
const A_CROWD: int = 20
const PATIENCE: float = 10.0

const TABLE: Array[Dictionary] = [
	{
		"id": &"dawn",
		"seconds": 10.0,
		"turning": 1.0,
		"hour": 7.0,
		"damage": 1.0,
		"windup": 1.0,
		"rouse": 1.0,
		"tokens": 2,
	},
	{
		"id": &"day",
		"seconds": 35.0,
		"turning": 0.25,
		"hour": 9.0,
		"damage": 1.0,
		"windup": 1.0,
		"rouse": 1.0,
		"tokens": 2,
	},
	{
		"id": &"dusk",
		"seconds": 10.0,
		"turning": 1.0,
		"hour": 18.0,
		"damage": 1.1,
		"windup": 0.95,
		"rouse": 1.4,
		"tokens": 2,
	},
	{
		"id": &"night",
		"seconds": 35.0,
		"turning": 0.25,
		"hour": 19.0,
		"damage": 1.25,
		"windup": 0.88,
		"rouse": 2.0,
		"tokens": 3,
	},
]

var _failures: PackedStringArray = []
var _config: WaveConfig = null
var _cycle: DayCycle = null
var _arena: Node3D = null
var _passed: Array = []
## What each body was handed when it walked on, against the phase that was in force at that moment.
var _arrivals: Array[Array] = []
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	# Running a wave writes a save. Whatever this machine already had goes back at the end: a check
	# that eats the developer's run is worse than no check.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	_config = load(CONFIG) as WaveConfig
	_cycle = _config.cycle if _config != null else null
	if _cycle == null:
		_fail("the wave table carries no day cycle")
		_report()
		return

	_check_the_phases_match_the_table()
	_check_a_wave_is_six_minutes()
	_check_the_turn_is_a_whole_day()
	_check_a_wave_opens_at_daybreak_and_ends_in_the_dark()
	_check_the_turn_only_ever_gets_meaner()
	_check_the_clock_only_goes_forward()
	_check_the_clock_lands_on_the_boundaries()
	_check_the_telegraph_floor_wins()
	_check_night_hits_harder()
	_check_night_can_still_be_seen()
	_check_a_dimmer_sun_casts_a_lighter_shadow()
	_check_nobody_notices_further_at_night()

	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	var director := _arena.get_node("WaveDirector") as WaveDirector
	director.halt()
	director.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame

	_check_a_sky_with_nobody_driving_it_opens_at_daybreak()
	_check_the_melee_pool_widens_at_night()
	_check_rousing_carries_further_at_night(director.spawner)
	await _check_the_sky_follows_the_clock()
	await _check_night_falls_inside_the_wave(director)
	_put_the_run_back()
	_report()


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _phase(id: StringName) -> DayPhase:
	for phase: DayPhase in _cycle.phases:
		if phase != null and phase.id == id:
			return phase
	return null


func _check_the_phases_match_the_table() -> void:
	if _cycle.phases.size() != TABLE.size():
		_fail("the cycle has %d phases, the table has %d" % [_cycle.phases.size(), TABLE.size()])
		return
	for index: int in TABLE.size():
		var row: Dictionary = TABLE[index]
		var phase: DayPhase = _cycle.phases[index]
		if phase == null or phase.id != row["id"]:
			_fail("phase %d should be %s" % [index, row["id"]])
			continue
		_same("%s lasts" % phase.id, phase.seconds, row["seconds"])
		# The share that turns is what makes the sky a slide rather than a flip, and a dusk that
		# went back to holding its look would read as the hard cut this cycle was fixed to stop.
		_same("%s turns over" % phase.id, phase.turning_share, row["turning"])
		_same("%s opens at" % phase.id, phase.starts_at_hour, row["hour"])
		_same("%s damage" % phase.id, phase.damage_scale, row["damage"])
		_same("%s telegraph" % phase.id, phase.windup_scale, row["windup"])
		_same("%s rousing" % phase.id, phase.rouse_scale, row["rouse"])
		_same("%s melee tokens" % phase.id, float(phase.melee_tokens), float(row["tokens"]))


func _check_a_wave_is_six_minutes() -> void:
	_same("a wave lasts", _cycle.wave_seconds(), WAVE_SECONDS)


## The phases have to tile a day exactly. A gap and the clock skips an hour; an overlap and the sky
## shows one phase while the rules run another.
func _check_the_turn_is_a_whole_day() -> void:
	var total := 0.0
	for phase: DayPhase in _cycle.phases:
		var span := _cycle.hours_of(phase)
		if span <= 0.0:
			_fail("%s covers no time at all" % phase.id)
		total += span
	_same("the phases together cover", total, DayCycle.HOURS_IN_A_DAY)


## The shape of the whole design in two assertions: a wave is a ramp the player can see coming.
func _check_a_wave_opens_at_daybreak_and_ends_in_the_dark() -> void:
	var opens := _cycle.phase_at(0.0)
	var closes := _cycle.phase_at(_cycle.wave_seconds() - 0.01)
	if opens == null or opens.id != &"dawn":
		_fail("a wave should open at daybreak, opens on %s" % [opens.id if opens else &"nothing"])
	if closes == null or closes.id != &"night":
		_fail("a wave should end in the dark, ends on %s" % [closes.id if closes else &"nothing"])


## **The turn only ever gets meaner.** Ordered across the table rather than pinned to named phases,
## so a phase inserted for its look alone has to sit where its rules already belong — a dawn that
## hits like dusk is a wave that opens on its own second half, and no single number in the table
## looks wrong on the way there.
func _check_the_turn_only_ever_gets_meaner() -> void:
	for index: int in range(1, _cycle.phases.size()):
		var earlier: DayPhase = _cycle.phases[index - 1]
		var later: DayPhase = _cycle.phases[index]
		var order := "%s then %s" % [earlier.id, later.id]
		_never_eases("%s: damage" % order, earlier.damage_scale, later.damage_scale)
		# The telegraph is the one that runs the other way: a shorter wind-up is a harder fight.
		_never_eases("%s: telegraph" % order, later.windup_scale, earlier.windup_scale)
		_never_eases("%s: rousing" % order, earlier.rouse_scale, later.rouse_scale)
		_never_eases(
			"%s: melee tokens" % order, float(earlier.melee_tokens), float(later.melee_tokens)
		)


func _never_eases(what: String, earlier: float, later: float) -> void:
	if later < earlier - 0.001:
		_fail("%s goes backwards, %.3f after %.3f" % [what, later, earlier])


## Sampled through a whole wave. A clock that runs backwards is the one thing a clock may never do,
## and rolling forward past midnight is what makes it possible to get wrong.
func _check_the_clock_only_goes_forward() -> void:
	var steps := 240
	var last := _cycle.hour_at(0.0)
	var travelled := 0.0
	for step: int in range(1, steps + 1):
		var hour := _cycle.hour_at(_cycle.wave_seconds() * float(step) / float(steps))
		var ahead := fposmod(hour - last, DayCycle.HOURS_IN_A_DAY)
		# More than half a day ahead is the same as being behind, the long way round.
		if ahead > DayCycle.HOURS_IN_A_DAY * 0.5:
			_fail("the clock goes backwards %.2f h into the wave" % hour)
			return
		travelled += ahead
		last = hour
	_same("a wave covers", travelled, DayCycle.HOURS_IN_A_DAY)


## Exact at the ends: each phase starts on its own hour. Anything else and the clock and the sky
## disagree about the moment night falls.
##
## Walked over the *table's* seconds against the *table's* hours, never the resource's. Asking the
## cycle when its own phases open is a question it cannot get wrong — `hour_at` reads the same two
## fields the answer would be compared against — so it would print OK for any pair of numbers.
func _check_the_clock_lands_on_the_boundaries() -> void:
	var opens := 0.0
	for row: Dictionary in TABLE:
		_same("%s arrives at" % row["id"], _cycle.hour_at(opens), row["hour"])
		opens += row["seconds"] as float


## Night shortens the telegraph before the floor, never after it. Clamping first and scaling second
## reads the same in a diff and puts a late wave below the point where a wind-up can be read.
func _check_the_telegraph_floor_wins() -> void:
	var night := _phase(&"night")
	for wave: int in range(1, 16):
		if _config.windup_multiplier(wave, night) < _config.windup_floor - 0.0001:
			_fail(
				(
					"a night telegraph at wave %d is %.3f, under the floor of %.2f"
					% [wave, _config.windup_multiplier(wave, night), _config.windup_floor]
				)
			)
			return
	# And it has to do something, or the floor would be "winning" over a dial nobody wired up.
	if _config.windup_multiplier(4, night) >= _config.windup_multiplier(4):
		_fail("night does not shorten the telegraph at wave 4")
	_same("wave 15 at night sits on the floor", _config.windup_multiplier(15, night), 0.75)


func _check_night_hits_harder() -> void:
	var night := _phase(&"night")
	_same("wave 5 at night hits for", _config.damage_multiplier(5, night), 1.4 * 1.25)
	_same("wave 5 by day hits for", _config.damage_multiplier(5), 1.4)


func _check_night_can_still_be_seen() -> void:
	var night := _phase(&"night")
	var light := night.sun_energy + night.ambient_energy
	if light < READABLE:
		_fail(
			(
				"night carries %.2f of light, and %.2f is the least it can be read by"
				% [light, READABLE]
			)
		)


## **A dimmer sun never casts a heavier shadow.** Ordered across the whole table rather than phase
## by phase, so a fourth phase added later is held to the same rule with nobody having to come
## back here.
##
## This is the one that rots quietly: the sun's energy and the shadow's weight are two numbers in
## two places, and tuning either alone is how a night render becomes a day render with the
## brightness pulled down — shadows darker than the light that threw them.
func _check_a_dimmer_sun_casts_a_lighter_shadow() -> void:
	# Typed explicitly: `duplicate()` hands back a bare Array, and the elements of one cannot be
	# inferred — which is a parse error, and a verify scene that will not parse hangs rather than
	# failing, because nothing ever reaches `_report()`.
	var phases: Array[DayPhase] = _cycle.phases.duplicate()
	phases.sort_custom(func(a: DayPhase, b: DayPhase) -> bool: return a.sun_energy < b.sun_energy)
	for index: int in range(1, phases.size()):
		var dimmer: DayPhase = phases[index - 1]
		var brighter: DayPhase = phases[index]
		if dimmer.shadow_opacity > brighter.shadow_opacity:
			_fail(
				(
					"%s is lit at %.2f and shadows at %.2f, against %s at %.2f lit and %.2f shadowed"
					% [
						dimmer.id,
						dimmer.sun_energy,
						dimmer.shadow_opacity,
						brighter.id,
						brighter.sun_energy,
						brighter.shadow_opacity
					]
				)
			)
		if dimmer.shadow_softness < brighter.shadow_softness:
			_fail(
				(
					"%s is dimmer than %s and draws a harder shadow edge — %.2f against %.2f"
					% [dimmer.id, brighter.id, dimmer.shadow_softness, brighter.shadow_softness]
				)
			)


## The hour is not allowed near this one. A farmer arrives no closer than twelve metres and notices
## at nine: scale it, and every night is back to a charge from the horizon.
func _check_nobody_notices_further_at_night() -> void:
	for path: String in ["farmhand", "reaper", "pirate"]:
		var data := load("res://data/enemies/%s.tres" % path) as EnemyData
		if data == null:
			_fail("there is no %s to check" % path)
			continue
		if data.notice_radius > NEAREST_SPAWN:
			_fail(
				(
					"a %s notices at %.1f m and spawns no closer than %.1f — he arrives awake"
					% [path, data.notice_radius, NEAREST_SPAWN]
				)
			)


func _check_the_melee_pool_widens_at_night() -> void:
	var tokens := _arena.get_node("AttackTokens") as AttackTokens
	if tokens == null:
		_fail("the arena has no attack tokens")
		return
	GameState.set_day_phase(_phase(&"night"))
	_same("the melee pool at night", float(tokens.melee_tokens), 3.0)
	GameState.set_day_phase(_phase(&"day"))
	_same("the melee pool by day", float(tokens.melee_tokens), 2.0)


## The dial that changes the shape of a night rather than its numbers, proved on two bodies too far
## apart to wake each other in daylight.
func _check_rousing_carries_further_at_night(spawner: SpawnDirector) -> void:
	var data := load("res://data/enemies/farmhand.tres") as EnemyData
	if spawner == null or data == null:
		_fail("nowhere to put two farmers")
		return
	for night: bool in [false, true]:
		GameState.set_day_phase(_phase(&"night" if night else &"day"))
		var shouts := spawner.spawn_at(data, Vector3.ZERO)
		var hears := spawner.spawn_at(data, Vector3(APART, 0.0, 0.0))
		if shouts == null or hears == null:
			_fail("the pool would not lease two farmers")
			return
		shouts.rouse()
		if hears.roused != night:
			_fail(
				(
					"a shout carried %.0f m %s — it should %s"
					% [APART, "at night" if night else "in daylight", "carry" if night else "not"]
				)
			)
		shouts.retire()
		hears.retire()


## The title screen shows the same island under the same sky scene, with no wave director behind it.
## Without this it would come up at whatever hour the run the player just lost had reached.
func _check_a_sky_with_nobody_driving_it_opens_at_daybreak() -> void:
	GameState.day_elapsed = _cycle.wave_seconds() * 0.9
	var lone := (load(SKY) as PackedScene).instantiate()
	add_child(lone)
	var opens := _cycle.phase_at(GameState.day_elapsed)
	if opens == null or opens.id != &"dawn":
		_fail("a sky with nobody driving it opens on %s" % [opens.id if opens else &"nothing"])
	lone.queue_free()


## The sky reads the clock, not the wave: set the hour and the sun has to be the right sun.
func _check_the_sky_follows_the_clock() -> void:
	var sky := _arena.get_node("Sky") as DayNight
	if sky == null or sky.sun == null:
		_fail("the arena has no sky")
		return
	var opens := 0.0
	for phase: DayPhase in _cycle.phases:
		# **At the instant it opens**, which is the only moment a phase is purely itself. A quarter
		# of the way in used to be safe, back when every phase held its look for three quarters of
		# its span; dawn and dusk now turn from their first instant, because they exist to be the
		# turn, so anywhere past the opening is already part way into the next look.
		GameState.day_elapsed = opens
		opens += phase.seconds
		await get_tree().process_frame
		_same("the sun at %s" % phase.id, sky.sun.light_energy, phase.sun_energy)
		# Painted from the phase rather than left on the node, or a moon would throw noon's shadow.
		_same("the shadow at %s" % phase.id, sky.sun.shadow_opacity, phase.shadow_opacity)
		_same("the shadow edge at %s" % phase.id, sky.sun.shadow_blur, phase.shadow_softness)


## End to end, on a wave squeezed into a couple of seconds: the rules change while the player is
## standing in the fight, and the wave ends when its night does rather than when the roster runs
## out. Six real minutes is not something a check can sit through, so the proportions are kept and
## the numbers are not — what is asserted is the rule.
func _check_night_falls_inside_the_wave(director: WaveDirector) -> void:
	director.process_mode = Node.PROCESS_MODE_INHERIT
	director.config = _shortened(_config, A_QUICK_WAVE)
	director.spawn_interval = A_QUICK_ARRIVAL
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	GameState.set_day_phase(null)
	director.start_wave(1)
	var seen: Array[StringName] = []
	var waited := 0.0
	while _passed.is_empty() and waited < PATIENCE:
		await get_tree().process_frame
		waited += get_process_delta_time()
		var now := GameState.day_phase as DayPhase
		if now != null and not seen.has(now.id):
			seen.append(now.id)
	if _passed.is_empty():
		_fail("a wave should end when its night does, %.0f s passed" % PATIENCE)
		return
	if not seen.has(&"day") or not seen.has(&"night"):
		_fail("a wave should run from day into night, ran through %s" % [seen])
	_check_every_body_carried_the_light_it_arrived_in(director.config)


## The claim that night hits harder, asserted on bodies rather than on a formula. A director that
## read the phase once at the top of the wave would send night farmers with daylight damage, and
## every other check here would still pass.
func _check_every_body_carried_the_light_it_arrived_in(config: WaveConfig) -> void:
	if _arrivals.is_empty():
		_fail("nobody arrived during the wave")
		return
	var lights: Array[StringName] = []
	for arrival: Array in _arrivals:
		var phase: DayPhase = arrival[0]
		var carried: float = arrival[1]
		var due := config.damage_multiplier(1, phase)
		var name: StringName = phase.id if phase != null else &"nothing"
		if not lights.has(name):
			lights.append(name)
		if absf(carried - due) > 0.001:
			_fail(
				"a farmer who walked on at %s hits for %.3f, should be %.3f" % [name, carried, due]
			)
	if not lights.has(&"day") or not lights.has(&"night"):
		_fail("bodies should arrive in both lights, arrived in %s" % [lights])


func _on_enemy_spawned(enemy: Node3D) -> void:
	var body := enemy as Enemy
	if body != null:
		_arrivals.append([GameState.day_phase, body.damage_scale])


func _shortened(config: WaveConfig, seconds: float) -> WaveConfig:
	var quick := config.duplicate() as WaveConfig
	quick.base_alive = A_CROWD
	quick.most_alive = A_CROWD
	var whole := config.cycle.wave_seconds()
	var cycle := DayCycle.new()
	var phases: Array[DayPhase] = []
	for phase: DayPhase in config.cycle.phases:
		var brief := phase.duplicate() as DayPhase
		brief.seconds = seconds * phase.seconds / whole
		phases.append(brief)
	cycle.phases = phases
	quick.cycle = cycle
	return quick


func _on_wave_cleared(wave: int, _reward: int) -> void:
	_passed.append(wave)


func _same(what: String, got: float, wanted: float) -> void:
	if absf(got - wanted) > 0.001:
		_fail("%s %.3f, the table says %.3f" % [what, got, wanted])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"day/night OK — a wave is a turn of the day, the clock only goes forward, "
				+ "the shadows follow the sun that throws them, "
				+ "and night is meaner without being darker than it can be read"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("day/night FAILED — %s" % failure)
	get_tree().quit(1)
