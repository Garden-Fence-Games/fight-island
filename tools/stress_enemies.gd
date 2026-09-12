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
const CROWDS: Array[int] = [0, 10, 20, 30, 40]
## Close enough that every body is inside everyone else's separation radius for most of the run,
## which is the worst case and the only one worth measuring.
const HUDDLE: float = 6.0
const SETTLE_FRAMES: int = 60
const SAMPLE_FRAMES: int = 300


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
		await _measure(placed)
	get_tree().quit(0)


func _measure(placed: int) -> void:
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
			"STRESS %d bodies | physics %.3f ms (worst %.3f) | process %.3f ms%s"
			% [placed, middle, worst, _median(idle), noisy]
		)
	)


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
