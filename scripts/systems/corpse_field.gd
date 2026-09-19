class_name CorpseField
extends Node3D
## The bodies that stay where they fell.
##
## A wave is a fight you win by killing everybody in it, and until now the evidence sank into the
## sand. The pile is the record: by wave ten the island should look like what has happened on it.
##
## **A corpse is not an enemy.** The bodies are pooled — thirty-two of them, leased and handed back
## — and a run of fifteen waves kills several hundred. Keeping each one alive as a `CharacterBody3D`
## with a state machine, two areas, a navigation agent and a ragdoll would be several hundred of all
## of those, and the pool could never reclaim any of them. So the visual is copied into a `Corpse`,
## which takes over the tumble and keeps a ragdoll and nothing else: no script of the enemy's, no
## navigation, no sound.
##
## **But it is still a body.** Walked into, it is shoved along; struck, it bleeds and moves. A
## corpse only costs a skeleton while it is moving — see `Corpse` for how it rests.
##
## **There is a ceiling.** Past it the oldest corpse goes, which is the right one to lose: the pile
## near the player is what they just did, and the one at the far end is from a wave they have
## stopped thinking about.

## How many bodies may lie on the island at once. Past this the oldest goes. See
## `docs/architecture.md`.
@export var most: int = 48
## How big a corpse is to a swing: a sphere about its hips, in metres. Big enough that a body
## lying at a player's feet is inside the swing aimed at it. The gun's ray passes over it either
## way, because `Hitscan` looks past corpses.
@export var body_radius: float = 0.8
## Walking into a body: how fast the player must be moving before it counts, what share of their
## speed the body is shoved at, the lift **as a share of that shove**, and how far from their feet a
## limb is caught.
##
## `trample_speed` is barely more than standing still on purpose. It used to be a metre a second,
## which is under half of walking pace — so a player crossing a body slowly went through it with
## nothing happening at all, no contact and no push. It is now only there to keep a stationary
## player from doing work, and the shove is proportional the whole way down rather than switched on
## at a threshold.
@export var trample_speed: float = 0.2
@export var trample_share: float = 0.9
@export var trample_lift: float = 0.2
@export var trample_reach: float = 0.8
## Striking a body: how hard it is thrown along the blow in metres per second, how much of that goes
## upward, how far from the hips a limb is caught, and how much further a perfect blow throws it.
@export var struck_push: float = 3.5
@export var struck_lift: float = 0.35
@export var struck_reach: float = 1.6
@export var perfect_push_scale: float = 1.6

var _laid: Array[Corpse] = []
var _walker: CharacterBody3D = null


func _ready() -> void:
	add_to_group(&"corpses")


func _physics_process(_delta: float) -> void:
	if _laid.is_empty():
		return
	if _walker == null or not is_instance_valid(_walker):
		_walker = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		if _walker == null:
			return
	trample_near(_walker.global_position, _walker.velocity)


## Every body the feet at `feet`, moving at `velocity`, are close enough to disturb.
##
## **Public because the headless check drives it.** Steering a real player past a body makes the
## measurement depend on which node's `_physics_process` ran first that frame, which is how a check
## reports the weather instead of the code.
##
## Each body is asked whether it can be reached rather than measured against a sphere around its
## hips. The sphere admitted anything within `body_radius + trample_reach` and `Corpse.trample` then
## woke it before `push_near` found there was no bone inside `trample_reach` to push — so walking
## near the pile put a `Skeleton3D` back in the tree for every body in 1.6 m and pushed none of
## them.
func trample_near(feet: Vector3, velocity: Vector3) -> void:
	if Vector2(velocity.x, velocity.z).length() < trample_speed:
		return
	for corpse: Corpse in _laid:
		if corpse.reaches(feet):
			corpse.trample(feet, velocity)


## Lays a body down where it fell and takes its tumble over, and returns the corpse. Null when there
## is nothing to copy: a body with no rig, or a rig whose ragdoll never resolved.
##
## Called while the dying body's ragdoll is **still running** — the corpse starts every one of its
## bones where that one's is and moving the way it moves, and then the pool can have the body back.
func lay(body: Node3D) -> Corpse:
	var visual := body.get_node_or_null(^"Visual") as Node3D
	var living := body.get_node_or_null(^"Ragdoll") as RagdollComponent
	if visual == null or living == null or not living.is_ready():
		return null
	var copy := visual.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
	if copy == null:
		return null
	_strip(copy)
	var corpse := Corpse.new()
	corpse.name = "Corpse"
	add_child(corpse)
	corpse.global_transform = visual.global_transform
	corpse.assemble(copy, living, self)
	if corpse.ragdoll == null or not corpse.ragdoll.is_ready():
		corpse.queue_free()
		return null
	_laid.append(corpse)
	_make_room()
	return corpse


## How many are lying there. Read by the headless check, which cannot see a pile but can count one.
func count() -> int:
	return _laid.size()


## The corpses, oldest first. For the headless check.
func laid() -> Array[Corpse]:
	return _laid


## Everything goes. A new run starts on a clean island — the pile is this run's record, and
## inheriting the last one's would be the game telling the player about somebody else.
func clear_field() -> void:
	for corpse: Corpse in _laid:
		if is_instance_valid(corpse):
			corpse.queue_free()
	_laid.clear()


## Everything that animated the copy. A duplicated subtree brings whatever the original had: the
## clip player, the head-look modifier and the dying body's own ragdoll, which would fight the
## corpse's for the same bones. Freed now rather than queued, so the corpse's ragdoll never meets
## them.
func _strip(copy: Node) -> void:
	for node: Node in _everything_under(copy):
		if not is_instance_valid(node) or node == copy:
			continue
		if (
			node is AnimationMixer
			or node is SkeletonModifier3D
			or node is PhysicalBone3D
			or node is CollisionObject3D
		):
			node.get_parent().remove_child(node)
			node.free()
			continue
		node.set_script(null)
	copy.set_script(null)


func _make_room() -> void:
	while _laid.size() > most:
		var oldest: Corpse = _laid.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _everything_under(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found.append_array(_everything_under(child))
	return found
