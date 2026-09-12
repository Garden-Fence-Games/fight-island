class_name Arsenal
extends RefCounted
## The three weapons, loaded from `data/weapons/` once, in the order the wheel cycles them.
##
## Static for the same reason `Upgrades` is: the list is the contents of a directory and nothing
## about it belongs to a scene. The order is fists, stick, gun — which is the order they are
## acquired, so cycling forward always moves towards the thing the player picked up most recently.

const DIRECTORY: String = "res://data/weapons"
const ORDER: PackedStringArray = ["fists", "stick", "gun"]
## Always in hand. Everything else is a pickup, and a run that has found nothing still has these.
const STARTING: StringName = &"fists"

static var _weapons: Array[WeaponData] = []


static func all() -> Array[WeaponData]:
	if not _weapons.is_empty():
		return _weapons
	for name: String in ORDER:
		var weapon := load("%s/%s.tres" % [DIRECTORY, name]) as WeaponData
		if weapon != null:
			_weapons.append(weapon)
	return _weapons


static func find(id: StringName) -> WeaponData:
	for weapon: WeaponData in all():
		if weapon.id == id:
			return weapon
	return null


## The weapon after `id` among the ones the player owns, wrapping round. Cycling through a weapon
## that has not been found yet would be a wheel that lies about what is in the bag.
static func next_owned(id: StringName, owned: Array, step: int) -> StringName:
	var ring: Array[StringName] = []
	for weapon: WeaponData in all():
		if owned.has(weapon.id) or weapon.id == STARTING:
			ring.append(weapon.id)
	if ring.is_empty():
		return STARTING
	var at := ring.find(id)
	if at < 0:
		return ring[0]
	return ring[wrapi(at + step, 0, ring.size())]
