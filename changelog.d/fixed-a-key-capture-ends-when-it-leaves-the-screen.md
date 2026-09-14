- **A key capture no longer outlives the row that opened it.** Clicking a control to rebind it and
  then clicking another tab left that row listening from behind a page nobody was looking at: it
  swallowed the Escape meant for the options screen, so leaving appeared to do nothing, and the next
  key pressed anywhere rewrote a binding the player had moved on from — written to disk with nothing
  on screen to say it had happened. Clicking a second row had the same shape, with two rows
  listening at once and the next key landing on whichever won. A capture now ends when its row stops
  being visible or stops being the row in hand. Held by `tools/verify_options.tscn`, which is the
  first check to put a row into the listening state at all.
