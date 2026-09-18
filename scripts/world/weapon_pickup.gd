class_name WeaponPickup
extends Area3D
## A weapon lying on the island, waiting to be walked over and taken.
##
## It carries a **weapon id**, not a `WeaponData`: what a pickup grants is a line in the run's bag,
## and the bag is what knows how to load a gun. A pickup that handed over a resource would be a
## second place that decides what "having the gun" means.
##
## The prompt is a `Label3D` on the thing itself rather than a line at the bottom of the screen.
## Two reasons: it points at what it is talking about, and a world-space label cannot collide with
## the tutorial's own prompt, which is the one part of the screen already spoken for.

## How high off the ground the weapon itself sits. What has to be in shot is the thing that reads
## as a weapon, not the air above it — `PickupDirector` asks the camera about this height, and
## `tools/verify_view.tscn` judges it at the same one.
const RESTING_HEIGHT: float = 0.3
## Turns per second, so the thing reads as an object to be taken rather than as scenery.
const SPIN: float = 1.2
## **It carries its own light, and that is not decoration.** A stick is a bar of brown on sand and a
## revolver is a palm of dark metal, both under a camera fixed seventeen metres up, through a filter
## that quantises the frame to fat pixels. They landed in shot every time and were walked past
## anyway. The coconut had the same problem and the same answer: an emissive body with a lit rim,
## and a small lamp that spills onto the sand it is lying on, both breathing together.
##
## The figures live here rather than in `data/`, which is where the coconut keeps its own — a
## pickup's resource carries what it does, and how bright it is belongs to the thing that draws it.
const PULSE_HZ: float = 0.8
const PULSE_DEPTH: float = 0.16
## What the lamp and the body sit at when the breath is at rest, so the pulse has something to
## return to that a later edit of the scene cannot drift.
const LAMP_ENERGY: float = 2.4
const GLOW_ENERGY: float = 0.55
## Where a weapon's look comes from: **the rig that already carries it.** The gun is modelled into
## the player's skeleton, because that is how `idle_gun` and `walk_gun` were authored — so the thing
## lying on the sand is that same mesh rather than a second model of the same object. Two models of
## one gun drift apart the first time either is retouched, and the one on the ground is the one
## nobody looks at closely enough to notice.
const RIG: String = "res://assets/models/char_player.glb"

## One rig read per weapon per run, not per pickup. Instantiating a skeleton and nine clips to copy
## one mesh out of it is not something to do every time a gun is dropped.
static var _borrowed: Dictionary[StringName, Mesh] = {}
static var _borrowed_scale: Dictionary[StringName, Vector3] = {}

@export var weapon_id: StringName = &""
## Weapon id to the mesh node inside `RIG`. A weapon with no entry keeps the carved shape the scene
## ships with — which is what the stick already is, and what an unmodelled weapon should look like
## rather than nothing at all.
@export var rig_meshes: Dictionary[StringName, StringName] = {&"gun": &"Gun"}
## How a borrowed mesh lies. It was modelled standing in a fist, so it is tipped onto its side; the
## shipped shape is laid out by the scene and is left alone.
@export var lying_down: Vector3 = Vector3(-90.0, 0.0, 0.0)
## How long a borrowed weapon lies on the ground, whatever it is a model of.
##
## **A model at its own scale is not a pickup.** The camera is fixed twenty metres up and a revolver
## is a quarter of a metre of dark metal on pale sand — it landed in shot every time and was walked
## past anyway, which is how the gun came to be "not on the map". The carved shape it replaced is
## 0.84 m, so everything borrowed is brought to the same reading and a weapon on the ground looks
## like a thing to pick up before it looks like a scale model of itself.
@export var reads_at: float = 1.0
## The localisation key of the line above it, with `{0}` for the glyph that takes it.
@export var prompt_key: String = "PICKUP_TAKE"

var _player_inside: bool = false
var _pulsing: float = 0.0

@onready var label: Label3D = get_node_or_null("Prompt") as Label3D
@onready var view: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var lamp: OmniLight3D = get_node_or_null("Glow") as OmniLight3D


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.input_device_changed.connect(_on_input_device_changed)
	EventBus.bindings_changed.connect(_write_prompt)
	_show_prompt(false)
	_write_prompt()
	_wear_the_weapons_own_shape()


func _process(delta: float) -> void:
	rotate_y(SPIN * delta)
	_breathe(delta)


## The light, swelling and settling. Brightness rather than size, and slowly: a thing that changes
## size reads as coming closer, and a pulse fast enough to read as an alarm competes with a wind-up.
func _breathe(delta: float) -> void:
	_pulsing = fposmod(_pulsing + delta * PULSE_HZ, 1.0)
	var swell := 1.0 + sin(_pulsing * TAU) * PULSE_DEPTH
	if lamp != null:
		lamp.light_energy = LAMP_ENERGY * swell
	var material := view.get_surface_override_material(0) if view != null else null
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).emission_energy_multiplier = GLOW_ENERGY * swell


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	take()


## Swaps the carved placeholder for the mesh the rig carries, when there is one for this weapon.
##
## The mesh is copied rather than the rig instanced and kept: a pickup is one object on the sand and
## has no business owning a skeleton, nine animation clips and a second copy of the player's texture
## for as long as it lies there.
func _wear_the_weapons_own_shape() -> void:
	if view == null or not rig_meshes.has(weapon_id):
		return
	var wanted: StringName = rig_meshes[weapon_id]
	var borrowed := _borrow(wanted)
	if borrowed == null:
		# Not a failure worth stopping for: the carved shape is still a weapon on the ground, and a
		# rig that has been reworked should not take the pickup with it.
		push_warning("no mesh named %s in %s — the pickup keeps its carved shape" % [wanted, RIG])
		return
	view.mesh = borrowed
	# **And the carved shape's paint goes with it.** The scene overrides surface 0 with the brown
	# wood that makes the placeholder read as a stick; left in place it repaints the borrowed mesh
	# in it, and the gun lies on the sand the same colour as the stick it was meant to stop looking
	# like. The mesh brings its own material, which is the one the rig is drawn with.
	for surface: int in view.get_surface_override_material_count():
		view.set_surface_override_material(surface, null)
	_light_its_own_paint()
	# The mesh comes out in the space it was modelled in, at whatever scale the rig node carries, and
	# its origin is wherever the modeller left it — so it is scaled back, tipped over, and recentred
	# on its own bounds rather than trusted to be centred already.
	var grown: Vector3 = _borrowed_scale.get(wanted, Vector3.ONE)
	var turned := Basis.from_euler(
		Vector3(deg_to_rad(lying_down.x), deg_to_rad(lying_down.y), deg_to_rad(lying_down.z))
	)
	var sized := _read_at_arms_length(turned.scaled(grown), borrowed)
	var middle := sized * borrowed.get_aabb().get_center()
	view.transform = Transform3D(sized, Vector3(0.0, RESTING_HEIGHT, 0.0) - middle)


## A borrowed weapon glows in **its own paint**, not in a wash laid over it.
##
## The rig's material is duplicated rather than edited — it is shared with the player's own gun, and
## lighting that one would set the weapon in his hand glowing for the rest of the run. The paint
## becomes the emission through `emission_texture`, so what lifts off the sand is the gun the artist
## drew and not an orange gun-shaped smear. `verify_weapons` holds it to that.
func _light_its_own_paint() -> void:
	if view == null:
		return
	for surface: int in view.mesh.get_surface_count() if view.mesh != null else 0:
		var worn := view.get_active_material(surface) as StandardMaterial3D
		if worn == null:
			continue
		var lit := worn.duplicate() as StandardMaterial3D
		lit.rim_enabled = true
		lit.rim = 0.7
		lit.rim_tint = 0.4
		lit.emission_enabled = true
		lit.emission = Color.WHITE
		lit.emission_texture = worn.albedo_texture
		lit.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		lit.emission_energy_multiplier = GLOW_ENERGY
		view.set_surface_override_material(surface, lit)


## The same lie-down, grown or shrunk until its longest side is `reads_at`. Measured on the mesh's
## own bounds after it has been turned, because what has to read is the shape as it will lie, not
## the shape as it was modelled.
func _read_at_arms_length(sized: Basis, borrowed: Mesh) -> Basis:
	if reads_at <= 0.0:
		return sized
	var lying := (sized * borrowed.get_aabb().size).abs()
	var longest := maxf(maxf(lying.x, lying.y), lying.z)
	if longest <= 0.0:
		return sized
	return sized.scaled(Vector3.ONE * (reads_at / longest))


## The mesh a rig node carries, read once and kept. Null when the rig has no such node.
static func _borrow(node_name: StringName) -> Mesh:
	if _borrowed.has(node_name):
		return _borrowed[node_name]
	var packed := load(RIG) as PackedScene
	if packed == null:
		return null
	var rig := packed.instantiate()
	var found: Mesh = null
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.name == String(node_name):
			found = mesh.mesh
			_borrowed_scale[node_name] = mesh.scale
			break
	# Freed rather than kept: everything wanted out of it has been copied, and a rig parked off
	# screen for the life of the run is a skeleton being posed for nobody.
	rig.free()
	_borrowed[node_name] = found
	return found


## Taking it is the bag's decision, and a bag that already has this weapon says no — which is what
## stops a pickup nobody removed from re-arming a gun the player has half emptied.
func take() -> void:
	if not GameState.loadout.find_weapon(weapon_id):
		return
	queue_free()


func _show_prompt(visible_now: bool) -> void:
	if label != null:
		label.visible = visible_now


func _write_prompt() -> void:
	if label == null:
		return
	label.text = tr(prompt_key).format([Devices.glyph("interact")])


func _on_input_device_changed(_device: int) -> void:
	_write_prompt()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = true
	_show_prompt(true)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = false
	_show_prompt(false)
