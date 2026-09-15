- **Three pieces of code that were running and having no effect.** A coconut left to rot never dimmed
  its light: the fade wrote the brightness from the physics step and the pulse wrote it again from
  the visual one, and the last writer of a frame is the one the eye gets — so the glow stayed full
  until the coconut vanished under it. The guard that keeps a spawn point out of the sea could never
  fire, because every caller snapped its guess to the ground first and then asked whether the
  snapped point was near the ground; a guess that fell in the water was quietly dragged to the
  nearest shore instead of being thrown away. And `arena.tscn` still set `ranged_tokens`, which went
  out with the thrower — the loader offers it, the object refuses it, and nothing is printed.
