extends Node
## What the island costs to draw, from the game's own camera, with the budget's crowd standing in
## it.
##
## Needs a window: the headless renderer is a dummy that draws nothing and reports nothing, so every
## figure here would be nought. This is the one measurement that cannot be a CI check, which is why
## the check beside it asserts the *shape* that makes culling possible instead.
##
## **The crowd is the point now.** `stress_enemies` answered the CPU side of #31 and answered it
## conclusively — a whole physics step is one to two and a half milliseconds at every size — but it
## runs headless, so it has never been able to say anything about the half of the budget that is
## drawing. Thirty bodies are placed in front of the camera here, and what comes out is a frame time
## against the 16.67 ms a 60 Hz frame has.
##
## **Two machines, one command.** The budget in `docs/architecture.md` names an Apple M-series and a
## GTX 1060, and no single person has both. The crowd size is an argument and every figure is
## printed on one line each, so the second machine runs the same line and the two runs are
## comparable rather than two stories.
## Run: godot --path . --resolution 1920x1080 res://tools/measure_draw.tscn -- 30

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## The budget from `docs/architecture.md`. Overridable from the command line so the shape past it
## can be asked for without editing a tool.
const CROWD: int = 30
## How long the island is left alone before anything is sampled. The scatter streams in and the
## navigation bakes, and a frame taken during either is a frame measuring the wrong thing.
const SETTLE: float = 2.0
## Long enough to see a worst frame rather than an average that hides one. At 60 Hz this is about
## four seconds of play.
const SAMPLES: int = 240
## Where the crowd is put: an arc in front of the player, between these two distances. In front
## because the camera is fixed and this is what it sees, and at this range because it is where a
## wave actually arrives — close enough to be drawn at size, far enough that thirty of them fit.
## Narrow rather than wide: the camera is fixed and looks down a corridor, so an arc that wraps
## round the player puts a third of the crowd off the sides of the frame — and thirty placed is not
## the claim the budget makes.
const ARC_DEGREES: float = 46.0
const NEAREST: float = 6.0
const FURTHEST: float = 15.0
## Frames a 60 Hz budget has, in milliseconds.
const BUDGET_MS: float = 1000.0 / 60.0


func _ready() -> void:
	# **Uncapped, and the measurement is worthless without it.** The first run of this tool reported
	# exactly 10.00 ms at every size, which is not a cost — it is the frame cap the player's settings
	# left on, measured very precisely. A budget asks what a frame costs, not what it was allowed to
	# take, so vsync and the cap come off and the render clock goes on before anything is built.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var arena := (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(arena)
	var director := arena.get_node_or_null("WaveDirector") as WaveDirector
	if director != null:
		director.halt()
		director.process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial := arena.get_node_or_null("Tutorial")
	if tutorial != null:
		tutorial.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(SETTLE).timeout

	var wanted := _wanted()
	var placed := _place(arena, director, wanted)
	await get_tree().create_timer(SETTLE).timeout
	await _measure(arena, placed)
	_count_the_scatter(arena)
	get_tree().quit(0)


## How many bodies, from `-- 30` on the command line. An argument rather than a constant because the
## question the second machine may need to ask is not always the budget's.
func _wanted() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.is_valid_int():
			return maxi(int(argument), 0)
	return CROWD


## **Harmless on purpose.** A crowd of thirty that swings kills the subject in about two seconds,
## and a frame time averaged over a death screen is not a frame time. They close, they circle and
## they are drawn exactly as they would be; what is missing from the figure is the swing itself and
## the impact it spawns, which are transient and are worth saying out loud rather than hiding.
func _place(arena: Node3D, director: WaveDirector, wanted: int) -> int:
	var data := load(FARMHAND) as EnemyData
	var player := arena.get_node_or_null("Player") as Node3D
	if data == null or player == null or director == null or wanted <= 0:
		return 0
	var facing := -player.global_transform.basis.z
	var placed := 0
	for index: int in wanted:
		var across := deg_to_rad(ARC_DEGREES) * (float(index) / maxf(float(wanted - 1), 1.0) - 0.5)
		var out := NEAREST + (FURTHEST - NEAREST) * float(index % 4) / 3.0
		var way := facing.rotated(Vector3.UP, across)
		var body := director.spawner.spawn_at(
			data, player.global_position + way * out, 1.0, 1.0, 1.0, 1.0, null, true
		)
		if body == null:
			break
		body.rouse()
		placed += 1
	return placed


func _measure(arena: Node3D, placed: int) -> void:
	var viewport := get_viewport().get_viewport_rid()
	var frames: Array[float] = []
	var gpu := 0.0
	var render := 0.0
	var physics := 0.0
	var last := Time.get_ticks_usec()
	for _sample: int in SAMPLES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		render += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		# Seconds, whatever the constant name suggests.
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var middle := _median(frames)
	print(
		(
			"DRAW %d bodies, %d in shot | frame %.2f ms median, %.2f worst → %.0f fps"
			% [placed, _in_shot(arena), middle, _worst(frames), 1000.0 / maxf(middle, 0.001)]
		)
	)
	print(
		(
			"DRAW gpu %s | render cpu %.2f ms | physics %.2f ms"
			% [
				_gpu_time(gpu / float(SAMPLES)),
				render / float(SAMPLES),
				physics / float(SAMPLES),
			]
		)
	)
	_report_the_frame_counts()
	_report_the_budget(middle)


## **A zero here is an absence, not a result**, and printing it as `0.00 ms` reads as a free frame.
## Godot's Metal backend returns no timestamps, so on an Apple machine the GPU half of this budget
## has to be read off the frame time; a Vulkan machine — which the GTX 1060 is — reports it.
func _gpu_time(measured: float) -> String:
	if measured <= 0.0:
		return "not reported by this backend"
	return "%.2f ms" % measured


func _report_the_frame_counts() -> void:
	print(
		(
			"DRAW objects %d | primitives %d | draw calls %d"
			% [
				_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			]
		)
	)


## The one line somebody reads. A budget nobody states is a measurement that gets argued about
## afterwards; stated, the run either met it or it did not.
func _report_the_budget(middle: float) -> void:
	var verdict := "PASS" if middle <= BUDGET_MS else "OVER"
	print(
		(
			"DRAW budget %.2f ms at 60 fps — %s by %.2f ms"
			% [BUDGET_MS, verdict, absf(BUDGET_MS - middle)]
		)
	)


## How many of them the camera can actually see, because "thirty enemies on screen" is the budget
## and thirty enemies placed is not the same claim.
func _in_shot(arena: Node3D) -> int:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0
	var seen := 0
	for node: Node in arena.get_tree().get_nodes_in_group(&"enemies"):
		var body := node as Node3D
		if body != null and camera.is_position_in_frustum(body.global_position):
			seen += 1
	return seen


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _worst(values: Array[float]) -> float:
	var worst := 0.0
	for value: float in values:
		worst = maxf(worst, value)
	return worst


func _count_the_scatter(arena: Node3D) -> void:
	var props := arena.get_node_or_null("Island/Props")
	if props == null:
		return
	for node: Node in props.get_children():
		print("SCATTER %s -> %s" % [node.name, _describe(node)])


func _describe(node: Node) -> String:
	var multi := node as MultiMeshInstance3D
	if multi != null:
		var size := multi.get_aabb().size
		return (
			"1 batch, %d instances, %.0f x %.0f m"
			% [multi.multimesh.instance_count, size.x, size.z]
		)
	var batches := 0
	var instances := 0
	var widest := 0.0
	for child: Node in node.get_children():
		var chunk := child as MultiMeshInstance3D
		if chunk == null:
			continue
		batches += 1
		instances += chunk.multimesh.instance_count
		widest = maxf(widest, chunk.get_aabb().size.x)
	return "%d batches, %d instances, widest %.0f m" % [batches, instances, widest]


func _info(what: RenderingServer.RenderingInfo) -> int:
	return RenderingServer.get_rendering_info(what)
