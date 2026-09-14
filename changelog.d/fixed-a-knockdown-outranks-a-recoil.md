- **Dying in the instant after firing drops the body instead of freezing it upright.** A shot hands
  the shooting arm to the physics for a tenth of a second, and that recoil owned the ragdoll's
  frame while it lasted — so a killing blow landing inside those six frames started a fall that was
  never advanced, and then the recoil ran out, faded the simulator to nothing and stopped the very
  simulation the fall had begun. The player died standing still, frozen, which is what a death looks
  like when the one thing that sells it never happens. A knockdown now takes the recoil's place
  rather than queueing behind it. Held by `tools/verify_knockdown.tscn`.
