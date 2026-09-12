class_name OcclusionFader
extends Node
## Fades the stone that comes between the camera and the player, rather than moving the camera.
##
## The camera is fixed on purpose — see `CameraRig` — so the answer to occlusion has to be the other
## one. What it fades is found by group, so this knows nothing about the shape of the island's tree.
##
## **Only the six authored formations.** The palms are not faded: the body reads clearly through a
## crown of fronds, and thinning a tree out looks stranger than the tree did. What can hide the
## player outright is five metres of rock.
##
## **The detector is geometry, not physics.** A ray on the occluder layer is the obvious
## implementation and it would be the wrong one: a boulder's collider is a box seven tenths its
## size, sunk in the ground, and what hides the player is the silhouette. So each occluder is a
## sphere around what actually blocks the view, tested against the segment from the eye to the
## player's chest.

## Where on the body the line is drawn to. The feet are under the ground and the head is the first
## thing to clear an obstacle, so neither is what "hidden" means.
const CHEST: float = 1.1
## How far a blocked occluder fades. Not to nothing: an enemy behind the rock still has to be
## readable, and a hole where a boulder was is more distracting than a pale boulder.
const MOST_FADED: float = 0.72
## Fades per second. Fast enough not to trail behind a sprint, slow enough not to flicker when the
## line clips an edge.
const FADE_SPEED: float = 5.0
## A boulder is its own bounding sphere, shrunk: the corners of its box are empty air, and fading
## stone the player can already see past reads as a glitch.
const SNUGNESS: float = 0.62

var _player: Node3D = null
var _stones: Array[MeshInstance3D] = []
var _centres: PackedVector3Array = []
var _radii: PackedFloat32Array = []
var _fades: PackedFloat32Array = []


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	for node: Node in get_tree().get_nodes_in_group(&"occluder"):
		var stone := node as MeshInstance3D
		if stone != null:
			_take(stone)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _player == null:
		return
	var eye := camera.global_position
	var chest := _player.global_position + Vector3.UP * CHEST
	# Nothing further from the player than the camera is can be between them.
	var reach := eye.distance_to(chest)
	for index: int in _stones.size():
		var wanted := 0.0
		if _centres[index].distance_to(chest) <= reach + _radii[index]:
			wanted = MOST_FADED if _blocks(_centres[index], _radii[index], eye, chest) else 0.0
		if is_equal_approx(_fades[index], wanted):
			continue
		_fades[index] = move_toward(_fades[index], wanted, FADE_SPEED * delta)
		_paint(_stones[index], _fades[index])


static func _blocks(centre: Vector3, radius: float, eye: Vector3, chest: Vector3) -> bool:
	return Geometry3D.get_closest_point_to_segment(centre, eye, chest).distance_to(centre) < radius


## Per surface on the node, because the six formations share one mesh: a material hung there would
## fade all of them the moment one stood in the way.
static func _paint(stone: MeshInstance3D, faded: float) -> void:
	for surface: int in stone.get_surface_override_material_count():
		var material := stone.get_surface_override_material(surface) as ShaderMaterial
		if material != null:
			material.set_shader_parameter("faded", faded)


func _take(stone: MeshInstance3D) -> void:
	var box := stone.get_aabb()
	_stones.append(stone)
	_centres.append(stone.global_transform * box.get_center())
	var spread := box.size * stone.global_transform.basis.get_scale()
	_radii.append(spread.length() * 0.5 * SNUGNESS)
	_fades.append(0.0)


## What the camera has faded, for the headless check to read.
func fades() -> PackedFloat32Array:
	return _fades


func centres() -> PackedVector3Array:
	return _centres
