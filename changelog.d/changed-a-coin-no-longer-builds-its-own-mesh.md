- **A payout builds a fraction of what it used to.** Loot was the one thing in a fight that was
  never pooled: every coin and every round constructed its own meshes on the way out, and the runner
  on wave 3 pays thirty-five pieces in a single call — in the frame the kill is meant to land. The
  bodies and the flare quad are now one object each, shared by every piece that will ever exist,
  because nothing writes to them. The flare's **material** stays private to each piece on purpose:
  they twinkle on their own clocks, and one shared material would have every coin on the island
  flicker in step. Held by `tools/verify_loot.tscn`, which now asserts both directions at once.
