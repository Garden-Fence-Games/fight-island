- **Five constants nothing read, and the comments that vouched for them.** `Enemy.CHEST_HEIGHT`
  named `verify_sightlines` as its keeper, and that check went out with the thrower.
  `WeaponPickup.LABEL_HEIGHT` was a second home for a height the scene already sets — the same 1.3,
  written twice. `AudioManager.BODY_DECAY` said it was "the thud both hits share" long after each
  impact family got a decay of its own. `PosedMesh.PER_VERTEX` was a hard-coded four under a
  docstring saying the figure is read rather than assumed — which the code does, from the arrays,
  three lines further down. `Emphasis.NOTHING` was never returned; the decision it was written to
  record, that an ordinary hit gets no mark at all, moves onto `for_hit`, which is what makes it.
