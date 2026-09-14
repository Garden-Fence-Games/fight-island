- **Two headless checks no longer leave a developer's machine changed.** `verify_access` bailing out
  early — a renamed node in the arena is enough — put the switches back but not the run, and by then
  `begin_run()` had already overwritten `run.json`: a saved game at wave seven came back at wave
  zero with no money. `verify_aim` moved aim assist five times and never put it back, so it exited
  with the setting reading Strong on disk, and in CI every check scheduled after it ran against an
  assist nobody chose. Both now restore what they touched, from one place each, so a future early
  return cannot take half of it.
