- **The game says when a newer version is out.** A player who installs through the itch.io app has
  always been updated automatically — it fetches only what changed — but one who downloaded the zip
  had no way to learn that a new version existed short of wandering back to the page. The title
  screen now asks itch.io once, and if the published build is ahead of this one the footer reads
  *1.1.0 is out on itch.io* beside the version. It informs and never downloads: a binary that
  replaces itself fights code signing, and the macOS bundle is sealed. It never blocks either —
  offline, timed out, or answered with something unreadable, the game says nothing and carries on.
  It is the only network request the game makes, and it is one press to stop in the gameplay
  options. Figures in `data/update_check.tres`; held by `tools/verify_update_check.tscn`.
