class_name CorpseHurtbox
extends Hurtbox
## A dead body can still be hit, and hitting it is not a hit.
##
## It is a `Hurtbox` so every swing already finds it — the player's hitbox asks for nothing else —
## but it **never consumes the blow**. `take_hit` answering false is what tells a hitbox that
## nothing landed, so a corpse gives no combo, no money, no hitstop and no `attack_landed`: the
## body bleeds and moves, and the fight goes on as if the swing had whiffed. A corpse that fed the
## combo counter would make a pile a free source of perfect hits.

## The body this is the hurtbox of. Set by the corpse that makes it.
var corpse: Corpse = null


func take_hit(info: HitInfo) -> bool:
	hurt.emit(info)
	if corpse != null and is_instance_valid(corpse):
		corpse.strike(info)
	return false
