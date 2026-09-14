- **The launcher wears the logo.** `icon.svg` was still Godot's own placeholder, so the dock, the
  taskbar and the itch launcher all announced the game with a picture of the engine's robot. The
  icon is now the mark on the menu's dark ground, a 1024 square with the corner radius Apple's grid
  uses. `tools/build_icon.gd` renders it from `fight_island_logo_1.svg` rather than keeping a second
  copy of the mark, and both export presets point at it, so the macOS `.icns` and the Windows `.ico`
  are built from the same square. The placeholder is gone, and its credit row with it.
