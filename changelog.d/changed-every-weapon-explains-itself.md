- **Every weapon explains itself when it reaches the hand.** There was one line, shown once a run,
  for whichever weapon happened to be found first — so the gun taught nothing at all, and a stick
  found second would have taught the gun's lesson. Now the stick says *[attack] to swing it —
  [weapon_next] to switch weapons* and the gun says *[attack] to fire — walk over rounds to get
  more*, each the first time that weapon goes in the bag.
  - **The stick carries the swap key** because it is the first thing the bag has to switch between.
    Nothing else in the game names that key, so `verify_tutorial` asserts the stick's line still
    does rather than trusting the copy to stay right.
  - Both weapons drop on wave 1, so two can be found seconds apart: the second **queues** behind the
    first instead of replacing a line the player is still reading. The check pushes a weapon in
    halfway through another's line, which is the case a queue filled before the first line was ever
    shown does not exercise.
  - The glyph is read off the binding as always, so the swap reads **E** and not the `Tab` the notes
    for 0.2.0 claimed — that key moved when swapping became `E` and picking up became `F`.
