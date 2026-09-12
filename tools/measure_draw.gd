extends Node
## What the island actually costs to draw, from the game's own camera.
##
## Needs a window: the headless renderer is a dummy that draws nothing and reports nothing, so every
## figure here would be nought. This is the one measurement that cannot be a CI check, which is why
## the check beside it asserts the *shape* that makes culling possible instead.
## Run: godot --path . --resolution 1920x1080 res://tools/measure_draw.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const SETTLE: float = 2.0
const SAMPLES: int = 30


func _ready() -> void:
	var arena := (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(arena)
	var director := arena.get_node_or_null("WaveDirector")
	if director != null:
		(director as WaveDirector).halt()
		director.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(SETTLE).timeout

	var objects := 0.0
	var primitives := 0.0
	var calls := 0.0
	for _sample: int in SAMPLES:
		await get_tree().process_frame
		objects += float(_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		primitives += float(_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		calls += float(_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print(
		(
			"DRAW objects %.0f | primitives %.0f | draw calls %.0f"
			% [objects / SAMPLES, primitives / SAMPLES, calls / SAMPLES]
		)
	)
	_count_the_scatter(arena)
	get_tree().quit(0)


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
