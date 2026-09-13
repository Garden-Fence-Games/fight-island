class_name Loadout
extends RefCounted
## What the player is carrying: which weapons have been found, which is in hand, and how many
## rounds the gun has.
##
## A slice of run state with its own behaviour, exactly like `RunStats` — and for the same reason.
## `GameState` warns in its own docstring about becoming a god object, and "the bag" is a coherent
## thing with rules of its own: a weapon that has not been found cannot be equipped, a shot needs
## the rounds to pay for it, and **there is a hard ceiling on the rounds the player may hold**.
##
## **One count, no magazine.** Every round the player carries can be fired, one after another,
## until there are none; there is nothing to reload and nothing to wait for. Rounds come off the
## bodies of the people who came to kill you and from the merchant, so running dry mid-wave is a
## designed moment, and the answer to it is to walk over the next round rather than to stand still.
##
## It announces on the bus rather than carrying signals of its own: a listener that connected to a
## `Loadout` would lose its connection the moment a new run built a new one.

## Weapon ids the player has picked up. Fists are never in here — they are never not in hand, and
## an entry that is always present is one something eventually forgets to add.
var found: Array = []
var equipped: StringName = Arsenal.STARTING
## Every round the gun has. Nought until the gun is found.
var rounds: int = 0


## A save written before the magazine was taken out carries `magazine` and `reserve`; both were
## rounds the player owned, so they come back as one count.
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
	var held := int(data.get("magazine", 0)) + int(data.get("reserve", 0))
	bag.rounds = maxi(int(data.get("rounds", held)), 0)
	var ranged := bag._ranged()
	if ranged != null:
		bag.rounds = mini(bag.rounds, ranged.ammo_cap)
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
		rounds = mini(picked.rounds_start, picked.ammo_cap)
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


## Whether there was anything to fire. A shot the rounds cannot pay for is refused whole: the double
## tap with one round left does not fire half of itself.
func spend(cost: int) -> bool:
	if cost <= 0:
		return true
	if rounds < cost:
		return false
	rounds -= cost
	announce()
	return true


## A charge let go of early hands its round back. Nothing else ever gives one back.
func refund(cost: int) -> void:
	if cost <= 0:
		return
	rounds += cost
	announce()


## Every round in the bag. Nought without the gun: rounds mean nothing to a player with no gun.
func carried() -> int:
	return rounds if _ranged() != null else 0


## How many more rounds would fit. Zero is a full bag.
func room() -> int:
	var ranged := _ranged()
	if ranged == null:
		return 0
	return maxi(ranged.ammo_cap - rounds, 0)


## Rounds taken into the bag, which is not always the rounds offered. Returns how many landed,
## because a caller that announces "+1" over a bag that could not hold it is telling the player
## something that did not happen.
func take(offered: int) -> int:
	var taken := mini(maxi(offered, 0), room())
	if taken == 0:
		return 0
	rounds += taken
	announce()
	return taken


## How many rounds a body leaves behind: none, or between one and `WeaponData.scavenge_most`, each
## as likely as the others.
##
## **The rolls arrive rather than being made here.** A chance that rolls its own dice can only be
## checked by firing it ten thousand times and squinting at the total; one that is handed numbers
## can be asked the question with a known answer, which is what `verify_weapons` does. `roll`
## decides whether anything drops, `count_roll` how much.
func rounds_dropped(roll: float, count_roll: float) -> int:
	var ranged := _ranged()
	if ranged == null or roll >= ranged.scavenge_chance:
		return 0
	var most := maxi(ranged.scavenge_most, 1)
	return clampi(int(floorf(clampf(count_roll, 0.0, 0.999999) * most)) + 1, 1, most)


## The gun, but only once it has been found. A bag that filled with rounds before the weapon arrived
## would be a bag the player never saw fill.
func _ranged() -> WeaponData:
	var ranged := Arsenal.find(&"gun")
	return ranged if ranged != null and found.has(ranged.id) else null


func announce() -> void:
	EventBus.ammo_changed.emit(rounds)


func to_dict() -> Dictionary:
	var ids: Array = []
	for id: StringName in found:
		ids.append(String(id))
	return {
		"found": ids,
		"equipped": String(equipped),
		"rounds": rounds,
	}
