- **A resumed run keeps the weapon upgrades it paid for.** Quitting to the title and pressing
  Continue, or loading a run from disk, rebuilt the arena around a run already in progress — and the
  upgrade component, being a child of the player, priced the weapon tracks before the player had
  taken the carried weapon out of the loadout. It read the scene's exported fallback, the fists, so
  every level bought for the stick or the gun was skipped and the player fought the next wave at
  base damage and base reach. Nothing reported it: the merchant card still showed the level it had
  charged for, and the next purchase silently repaired it. The component now asks the loadout, which
  is the same source the HUD and the weapon rack already use. Held by `tools/verify_merchant.tscn`.
