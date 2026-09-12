extends Node
## A crowd, fighting, measured at several sizes in one process. The repeatable half of #31 — so the
## budget is re-measured rather than re-argued.
##
## Sizes rather than one size, because the question worth asking is not "how much" but "how does it
## grow": a rule that pits every body against every other only matters if the cost rises with the
## square of the crowd. All of them in the same process, because a machine with another Godot on it
## drifts between runs by far more than any of these differences are worth.
##
## It runs headless on purpose. The renderer there is a dummy, so nothing about drawing is measured
## and nothing about drawing should be read into these numbers; what it does measure is the CPU
## side, which is where the crowd rules live: the separation every body applies to every other, the
## hitbox that looks for what it is overlapping, the paths.
## Run: godot --headless --path . res://tools/stress_enemies.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## The budget from `docs/architecture.md` is thirty. The others are there to answer the question the
## budget cannot: whether the cost rises with the crowd or with the *square* of it. A rule that is
## every body against every other only matters if the second is true.
##
## **Sixty and a hundred and twenty are past the budget on purpose.** Stopping at forty was what
## made the growth unreadable: a whole physics step is mostly `move_and_slide` and the navigation
## agents, and a square term stays buried under those until it is bigger than them. Measuring only
## inside the budget answers "is it fast enough" and cannot answer "what shape is it", which is the
## question that decides whether the budget can ever be raised.
const CROWDS: Array[int] = [0, 10, 20, 30, 40, 60, 120]
## Close enough that every body is inside everyone else's separation radius for most of the run,
## which is the worst case and the only one worth measuring.
const HUDDLE: float = 6.0
const SETTLE_FRAMES: int = 60
const SAMPLE_FRAMES: int = 300
## Times the isolated separation pass is repeated before it is averaged. One pass over thirty bodies
## is tens of microseconds, which is below the resolution of a clock worth trusting.
const SEPARATION_PASSES: int = 120
## Frames thrown away after the isolated pass, so the one long frame it costs is never a sample.
const SPIKE_FRAMES: int = 10


func _ready() -> void:
	_run()


func _run() -> void:
	var arena := (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(arena)
	var director := arena.get_node_or_null("WaveDirector") as WaveDirector
	director.halt()
	director.process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial := arena.get_node_or_null("Tutorial")
	if tutorial != null:
		tutorial.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().physics_frame

	var data := load(FARMHAND) as EnemyData
	var player := arena.get_node("Player") as Node3D
	var placed := 0
	var separations: Array[float] = []
	var counts: Array[int] = []
	# Every size is measured in the same process, one after another, because a machine with another
	# Godot on it drifts between runs by more than any of these differences are worth.
	for wanted: int in CROWDS:
		while placed < wanted:
			var angle := TAU * float(placed) / float(CROWDS[CROWDS.size() - 1])
			var where := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * HUDDLE
			var body := director.spawner.spawn_at(data, where)
			if body == null:
				break
			# Awake, so they close on the player and pile into each other. An idle crowd measures
			# the cost of standing still, which nobody is worried about.
			body.rouse()
			placed += 1
		for _frame: int in SETTLE_FRAMES:
			await get_tree().physics_frame
		separations.append(await _measure(placed))
		counts.append(placed)
	_report_the_shape(counts, separations)
	get_tree().quit(0)


## The one conclusion the per-size rows cannot be read off safely.
##
## Adjacent steps are too noisy to argue from — each pass shares its frame with a crowd that is
## genuinely fighting, so a single step wanders by half again either way. The span from the
## smallest crowd that has real work to do up to the largest is not: if the cost per body is flat
## the whole thing is linear, and if it climbs with the crowd the rule is the square one it looks
## like. Printed as cost per body for exactly that reason.
func _report_the_shape(counts: Array[int], separations: Array[float]) -> void:
	print("STRESS ---------------------------------------------")
	var line := "STRESS separation per body:"
	for index: int in counts.size():
		if counts[index] <= 0:
			continue
		line += " %d→%.1fµs" % [counts[index], separations[index] * 1000.0 / float(counts[index])]
	print(line)
	print(
		(
			"STRESS a flat figure above is linear; one that climbs with the crowd is the square "
			+ "term, and it is the whole of what #31 asked about"
		)
	)


func _measure(placed: int) -> float:
	var separation := await _separation_alone()
	var physics: Array[float] = []
	var idle: Array[float] = []
	for _frame: int in SAMPLE_FRAMES:
		await get_tree().physics_frame
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		idle.append(Performance.get_monitor(Performance.TIME_PROCESS))
	var middle := _median(physics)
	var worst := _worst(physics)
	# A machine with a second Godot on it throws frames many times the others, and a run taken on
	# one is not a result. Said out loud rather than left for the reader to spot, because the whole
	# point of this scene is to stop a perf claim being made from noise.
	var noisy := " — BUSY MACHINE, do not compare this run" if worst > middle * 3.0 else ""
	print(
		(
			"STRESS %d bodies | physics %.3f ms (worst %.3f) | process %.3f ms | separation %.3f ms%s"
			% [placed, middle, worst, _median(idle), separation, noisy]
		)
	)
	return separation


## The separation pass on its own, away from the physics server and the navigation agents that
## dominate a whole step.
##
## **The whole-step figure cannot answer the question in the docstring above, and reading the shape
## off it was how this tool's own conclusion came out wrong.** At forty bodies the square term is a
## fraction of a millisecond under two or three of `move_and_slide`, so the total looks flat and the
## rule looks innocent. Isolated and taken past the budget, the same pass doubles at almost exactly
## four times per doubling — which is the definition of the thing it was supposed to be checked for.
##
## **One pass per frame, and in its own phase.** Two hundred of them inside a single frame is a
## single frame six hundred and seventy-eight milliseconds long at a hundred and twenty bodies —
## which is this tool's own busy-machine warning going off at every size, correctly, about itself.
## Moving it out of the sampled window was not enough, because the frame it ran in was the sample.
## So each pass gets a frame of its own, no frame carries more than the one pass the game would
## have done anyway, and the phase is kept clear of the window the whole-step figure is read from.
##
## The arithmetic is copied from `Enemy._separation` rather than called, because that method is
## private and because a measurement that reaches inside a body to time it breaks when the body is
## tidied. If the two ever drift, the growth is still the growth: the shape is what is measured.
func _separation_alone() -> float:
	var bodies: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var body := node as Node3D
		if body != null:
			bodies.append(body)
	if bodies.is_empty():
		return 0.0
	var spent := 0
	for _pass: int in SEPARATION_PASSES:
		await get_tree().physics_frame
		var opened := Time.get_ticks_usec()
		for body: Node3D in bodies:
			_push_on(body, bodies)
		spent += Time.get_ticks_usec() - opened
	# A breath before the whole-step samples begin, so the last pass is never one of them.
	for _frame: int in SPIKE_FRAMES:
		await get_tree().physics_frame
	return float(spent) / float(SEPARATION_PASSES) / 1000.0


static func _push_on(body: Node3D, bodies: Array[Node3D]) -> Vector3:
	var push := Vector3.ZERO
	for other: Node3D in bodies:
		if other == body:
			continue
		var offset := body.global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > Enemy.SEPARATION_RADIUS or is_zero_approx(distance):
			continue
		push += offset.normalized() * (1.0 - distance / Enemy.SEPARATION_RADIUS)
	return push * Enemy.SEPARATION_FORCE


## The middle sample, in milliseconds, and never the mean. A machine with a second Godot on it
## throws frames that are eight times the others, and one of those moves an average enough to argue
## from — which is exactly how a perf change gets claimed in the wrong direction.
func _median(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2] * 1000.0


## Printed beside it, so a run taken on a busy machine says so rather than looking like a result.
func _worst(samples: Array[float]) -> float:
	var most := 0.0
	for sample: float in samples:
		most = maxf(most, sample)
	return most * 1000.0
