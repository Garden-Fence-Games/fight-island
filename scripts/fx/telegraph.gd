class_name Telegraph
extends Node3D
## The ring on the ground under an enemy that is winding up, filling as the wind-up runs.
##
## **A shape, not a colour.** A telegraph a player cannot read is the same as no telegraph, and
## colour alone fails a sizeable fraction of players, every greyscale screenshot, and any camera far
## enough away that a tint is a few pixels. A ring that fills survives all three.
##
## It lies on the ground rather than on the body because that is where it is never occluded: from a
## camera this high the ground under a farmer is always in shot, and his chest may not be.

signal spent

## Clear of the ground, or it fights the terrain for the same pixels.
const HOVER: float = 0.05
## How far the ring sits outside the body, so it is not read as part of him.
const SPAN: float = 2.6


func _ready() -> void:
	visible = false


## Puts the ring under a body and starts it empty. The owner drives the fill.
func begin(under: Node3D, colour: Color) -> void:
	if under == null:
		return
	global_position = under.global_position + Vector3.UP * HOVER
	scale = Vector3.ONE * SPAN
	_material().set_shader_parameter(&"tint", colour)
	# Stored rather than read per frame: the setting is a toggle a player flips in a menu, and the
	# ring is redrawn sixty times a second under every body that is committing.
	var shout := 1.0 if bool(Settings.get_value(&"access_colourblind_telegraphs")) else 0.0
	_material().set_shader_parameter(&"high_contrast", shout)
	fill(0.0)
	visible = true


## Nought to one, driven by whoever owns the wind-up. The ring and the timing cannot drift apart,
## because there is only one number.
func fill(amount: float) -> void:
	_material().set_shader_parameter(&"progress", clampf(amount, 0.0, 1.0))


## The wind-up ended, whether it became a swing or was interrupted.
func finish() -> void:
	visible = false
	spent.emit()


func follows(under: Node3D) -> void:
	if under != null and visible:
		global_position = under.global_position + Vector3.UP * HOVER


func _material() -> ShaderMaterial:
	return ($Ring as MeshInstance3D).material_override as ShaderMaterial
