class_name Loadout
extends RefCounted
## What the player is carrying: which weapons have been found, which is in hand, and how many
## rounds are in the gun and in the pocket.
##
## A slice of run state with its own behaviour, exactly like `RunStats` — and for the same reason.
## `GameState` warns in its own docstring about becoming a god object, and "the bag" is a coherent
## thing with rules of its own: a weapon that has not been found cannot be equipped, a shot the
## magazine cannot pay for is a reload the player has to choose to make, and **there is a hard
## ceiling on the rounds the player may hold, magazine included**.
##
## That ceiling is the gun's entire rhythm. Nothing refills on a clock: rounds come off the bodies
## of the people who came to kill you and from the merchant, so running dry mid-wave is a designed
## moment and the answer to it is to close rather than to wait it out.
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
		reserve = mini(picked.reserve_start, maxi(picked.ammo_cap - magazine, 0))
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


## Every round in the bag, magazine included. The one number the ceiling is measured against, and
## the one a player counts: a reload moves rounds between two pockets, it never makes any.
func carried() -> int:
	var ranged := _ranged()
	return magazine + reserve if ranged != null else 0


## How many more rounds would fit. Zero is a full bag, and a full bag is what makes the merchant's
## rounds worth timing rather than buying the moment they are affordable.
func room() -> int:
	var ranged := _ranged()
	if ranged == null:
		return 0
	return maxi(ranged.ammo_cap - carried(), 0)


## Rounds taken into the pocket, which is not always the rounds offered. Returns how many landed,
## because a caller that announces "+1" over a bag that could not hold it is telling the player
## something that did not happen.
func take(rounds: int) -> int:
	var taken := mini(maxi(rounds, 0), room())
	if taken == 0:
		return 0
	reserve += taken
	announce()
	return taken


## Whether a body leaves a round behind. The round is thrown on the sand by `LootDirector` and only
## reaches the bag when it is walked over, which is where the room is checked.
##
## **The roll arrives rather than being made here.** A chance that rolls its own dice can only be
## checked by firing it ten thousand times and squinting at the total; one that is handed a number
## can be asked the question with a known answer, which is what `verify_weapons` does.
func rolls_a_round(roll: float) -> bool:
	var ranged := _ranged()
	return ranged != null and roll < ranged.scavenge_chance


## The gun, but only once it has been found. Rounds mean nothing to a player who has no gun to put
## them in, and a pocket that filled up before the weapon arrived would be a pocket the player
## never saw fill.
func _ranged() -> WeaponData:
	var ranged := Arsenal.find(&"gun")
	return ranged if ranged != null and found.has(ranged.id) else null


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
