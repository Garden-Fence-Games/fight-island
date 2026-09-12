class_name Loadout
extends RefCounted
## What the player is carrying: which weapons have been found, which is in hand, and how many
## rounds are in the gun and in the pocket.
##
## A slice of run state with its own behaviour, exactly like `RunStats` — and for the same reason.
## `GameState` warns in its own docstring about becoming a god object, and "the bag" is a coherent
## thing with rules of its own: a weapon that has not been found cannot be equipped, a shot the
## magazine cannot pay for is a reload the player has to choose to make, and **the reserve only
## grows between waves**.
##
## That last one is the gun's entire rhythm. The magazine decides how long a fight lasts and the
## reserve decides how many fights there are, so running dry mid-wave is a designed moment rather
## than an accident of balance.
##
## It announces on the bus rather than carrying signals of its own: a listener that connected to a
## `Loadout` would lose its connection the moment a new run built a new one.

## Weapon ids the player has picked up. Fists are never in here — they are never not in hand, and
## an entry that is always present is one something eventually forgets to add.
var found: Array = []
var equipped: StringName = Arsenal.STARTING
var magazine: int = 0
var reserve: int = 0


static func from_dict(data: Dictionary) -> Loadout:
	var bag := Loadout.new()
	var stored: Variant = data.get("found", [])
	if stored is Array:
		for id: Variant in stored as Array:
			# JSON has no StringName, and a String key would never answer `owns`.
			bag.found.append(StringName(id))
	bag.equipped = StringName(str(data.get("equipped", Arsenal.STARTING)))
	if not bag.owns(bag.equipped):
		bag.equipped = Arsenal.STARTING
	bag.magazine = maxi(int(data.get("magazine", 0)), 0)
	bag.reserve = maxi(int(data.get("reserve", 0)), 0)
	return bag


func owns(id: StringName) -> bool:
	return id == Arsenal.STARTING or found.has(id)


## The weapon in hand, as a resource. Everything that swings or shoots asks here rather than
## carrying its own copy, so a swap reaches all of them at once.
func weapon() -> WeaponData:
	return Arsenal.find(equipped)


## Whether this was the first time. A pickup walked over twice must not pay out twice, and must not
## re-arm a gun the player has already half emptied.
func find_weapon(id: StringName) -> bool:
	if id.is_empty() or owns(id):
		return false
	found.append(id)
	var picked := Arsenal.find(id)
	if picked != null and picked.is_ranged:
		# It comes loaded. A gun handed over empty is a gun the player thinks is broken.
		magazine = picked.magazine
		reserve = picked.reserve_start
	EventBus.weapon_found.emit(id)
	equip(id)
	return true


## Whether what is in hand changed. Refusing a weapon that has not been found is what keeps the
## wheel honest about what is in the bag.
func equip(id: StringName) -> bool:
	if not owns(id) or id == equipped:
		return false
	equipped = id
	EventBus.weapon_equipped.emit(weapon())
	announce()
	return true


## Whether there was anything to fire. The magazine is the gate, not the reserve.
func spend(rounds: int) -> bool:
	if rounds <= 0:
		return true
	if magazine < rounds:
		return false
	magazine -= rounds
	announce()
	return true


## A charge let go of early hands its round back. Nothing else ever gives one back.
func refund(rounds: int) -> void:
	if rounds <= 0:
		return
	magazine += rounds
	announce()


## Whether a reload is worth starting. Neither a full magazine nor an empty pocket is.
func can_reload(bonus: int = 0) -> bool:
	var held := weapon()
	if held == null or not held.is_ranged:
		return false
	return reserve > 0 and magazine < held.magazine + bonus


func reload(bonus: int = 0) -> void:
	if not can_reload(bonus):
		return
	var moved := mini(weapon().magazine + bonus - magazine, reserve)
	magazine += moved
	reserve -= moved
	announce()


## What a cleared wave adds, and the only moment the reserve ever grows.
func restock(bonus: int = 0) -> void:
	var ranged := Arsenal.find(&"gun")
	if ranged == null or not found.has(ranged.id):
		return
	reserve += ranged.reserve_per_wave + bonus
	announce()


func announce() -> void:
	EventBus.ammo_changed.emit(magazine, reserve)


func to_dict() -> Dictionary:
	var ids: Array = []
	for id: StringName in found:
		ids.append(String(id))
	return {
		"found": ids,
		"equipped": String(equipped),
		"magazine": magazine,
		"reserve": reserve,
	}
