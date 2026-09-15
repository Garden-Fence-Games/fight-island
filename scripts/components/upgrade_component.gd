class_name UpgradeComponent
extends Node
## Turns bought levels into numbers on the body that carries it, and knows nothing about who that
## body is beyond the components it can find.
##
## **It reads the base values once, in `_ready`, before anything has changed them**, so applying is
## always `base + level × step` rather than a running total. That is what makes it safe to run
## again — on a purchase, on a weapon swap, and on a player who walked back into the arena with a
## run already under way.

## What the bought levels come to, for the body to do with as it likes. **Emitted rather than
## written**: health, stamina and reach belong to components this one can find by name, but a damage
## multiplier and a stamina cost belong to whoever is swinging — and naming that owner was the one
## place in `scripts/components/` where a component knew what carried it, in the file whose own
## docstring claims it does not.
##
## The same shape `FrenzyComponent` already uses for the same problem.
signal applied(damage: float, stamina_cost: float)

var _base_max_health: float = 0.0
var _base_max_stamina: float = 0.0
var _base_regen: float = 0.0

@onready var health: HealthComponent = get_node_or_null(^"../Health") as HealthComponent
@onready var stamina: StaminaComponent = get_node_or_null(^"../Stamina") as StaminaComponent
@onready var hitbox: Hitbox = get_node_or_null(^"../Hitbox") as Hitbox


func _ready() -> void:
	if health != null:
		_base_max_health = health.max_health
	if stamina != null:
		_base_max_stamina = stamina.max_stamina
		_base_regen = stamina.regen_per_second
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	apply_all(false)


## `heal` is false everywhere except a fresh health purchase: re-applying on a weapon swap must not
## quietly top the player up in the middle of a fight.
func apply_all(heal: bool) -> void:
	var max_health := _base_max_health
	var max_stamina := _base_max_stamina
	var regen := _base_regen
	var damage := 1.0
	var cost := 1.0
	var reach := 1.0
	# From the loadout, not from `player.weapon`. This component is a child, so its `_ready` runs
	# before its owner's — and on a resumed run the owner has not yet copied the carried weapon out
	# of the loadout, so reading the field here would price every weapon track against the scene's
	# exported fallback and skip the ones the player paid for.
	var carried := GameState.loadout.weapon()
	var held: StringName = carried.id if carried != null else &""
	for track: UpgradeTrack in Upgrades.all():
		var level := float(GameState.level_of(track))
		if is_zero_approx(level):
			continue
		max_health += track.max_health * level
		max_stamina += track.max_stamina * level
		regen += track.stamina_regen * level
		# A weapon track only pays out while its weapon is in hand.
		if track.weapon.is_empty() or track.weapon != held:
			continue
		damage += track.damage * level
		cost += track.stamina_cost * level
		reach += track.reach * level
	if health != null:
		health.set_max_health(max_health, heal)
	if stamina != null:
		stamina.set_max_stamina(max_stamina)
		stamina.regen_per_second = regen
	if hitbox != null:
		hitbox.reach_scale = reach
	applied.emit(damage, cost)


func _on_upgrade_purchased(track: UpgradeTrack, _level: int) -> void:
	apply_all(track.heals_on_purchase)


func _on_weapon_equipped(_weapon: WeaponData) -> void:
	apply_all(false)
