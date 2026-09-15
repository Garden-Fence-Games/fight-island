- **The build says the version it actually is.** 1.0.0's macOS bundle introduced itself to the
  system as 0.1.0, and the Windows executable did the same in its file properties — the number a
  player reads in Finder or in a right-click, long after the download page is gone. `project.godot`
  was right; the four version fields in `export_presets.cfg` still held the number they were born
  with, and nothing read one from the other. They agree now, and the headless config check fails if
  they ever stop.
