- **Pulling the trigger on an empty gun no longer tells the game the wrong thing twice.** A state is
  allowed to leave from inside its own arrival — an attack that finds no round does exactly that —
  and the machine announced the result twice while never announcing the state it had actually left.
  Anything listening for what the body is doing heard something it had already been told and missed
  something else entirely. Held by `tools/verify_combat.tscn`.
