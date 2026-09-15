- **A hand-edited save no longer costs the run, and a hand-edited bindings file no longer swallows a
  rebind.** Every read of a stored file checked that a field was *there* and never what shape it
  was — and `int()` has no constructor for an object or a list: it does not fall back, it faults,
  and the fault took the whole restore with it. `RunStats` documented the opposite behaviour in as
  many words and did not have it. A wrong shape now costs that one field; the seed and the wave are
  the exception, where unreadable is treated as absent and the file is refused rather than a fresh
  run invented over the player's. The bindings file had the same hole in its third reader, the one
  that runs *after* the key has already changed — so a rebind appeared to work and was gone on the
  next launch, silently. Held by `tools/verify_save.tscn` and `tools/verify_options.tscn`.
