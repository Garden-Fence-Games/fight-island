class_name RainbowBird
extends Area3D
## The rainbow bird: sitting still on the sand, shining every colour there is, until the player
## walks over it and takes its power.
##
## **It never flies.** The flock's birds leave the moment anything comes near, and that is right for
## scenery; a power-up that fled would be a chase nobody asked for. So this is not a `Bird` and the
## flock does not know it exists — it is the perched model, a light and a place to stand.
##
## **Walked over, not pressed**, like a coconut: it exists to be grabbed in the middle of a crowd.
## And, like a coconut, **only when it is worth something** — while the power is already on it is
## left lying, because the power does not stack.
##
## **It shines rather than glows.** The same overlay the player wears while the power lasts, so the
## promise and the reward look alike, and a light that runs round the hue wheel so the sand under it
## says so too.

## How fast the light goes round the hue wheel, in turns a second.
const LIGHT_TURNS: float = 0.4
const LIGHT_ENERGY: float = 2.2
## How far it bobs, and how fast. A bird standing perfectly still in the sand reads as a prop.
const BOB_HEIGHT: float = 0.05
const BOB_HZ: float = 0.7

var data: FrenzyData = null

var _clock: float = 0.0
var _overlay: ShaderMaterial = null

@onready var model: Node3D = get_node_or_null(^"Perched") as Node3D
@onready var lamp: OmniLight3D = get_node_or_null(^"Glow") as OmniLight3D


func _ready() -> void:
	monitoring = true
	monitorable = false
	_overlay = ShaderMaterial.new()
	_overlay.shader = load(FrenzyComponent.SHADER) as Shader
	_overlay.set_shader_parameter(
		&"glitter", 0.0 if bool(Settings.get_value(&"access_reduce_flashing")) else 1.0
	)
	if model != null:
		for mesh: MeshInstance3D in _meshes(model):
			mesh.material_overlay = _overlay


func _process(delta: float) -> void:
	_clock += delta
	if lamp != null:
		lamp.light_color = Color.from_hsv(fposmod(_clock * LIGHT_TURNS, 1.0), 0.75, 1.0)
		lamp.light_energy = LIGHT_ENERGY
	if model != null:
		model.position.y = sin(_clock * TAU * BOB_HZ) * BOB_HEIGHT


func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		if body.is_in_group(&"player") and _give_to(body):
			return


## Whether the player took it. The power lives on the body, so the bird only hands it over.
func _give_to(body: Node3D) -> bool:
	var frenzy := body.get("frenzy") as FrenzyComponent
	if frenzy == null or data == null or not frenzy.start(data):
		return false
	EventBus.rainbow_bird_taken.emit(data.lasts)
	queue_free()
	return true


func overlay() -> ShaderMaterial:
	return _overlay


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null:
			found.append(mesh)
		found.append_array(_meshes(child))
	return found
