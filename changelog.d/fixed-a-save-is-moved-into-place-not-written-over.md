- **An interrupted save no longer destroys the one already on disk.** `FileAccess.WRITE` truncates
  the target the instant it opens, and a run is written on every wave and every purchase — so a
  force quit, a power cut or an OOM kill during any of those forty-odd writes left a truncated file,
  which the next launch refused and deleted. The player lost the whole run, not the last wave. Every
  save now lands in a sibling file and is renamed over the target only once it is closed; a rename
  that never finished is recovered on the next read, and a whole file always wins over a sibling,
  because the only way both exist is a write that was never confirmed. Discarding a run takes the
  sibling with it — without that, a deleted run walks back in. Held by `tools/verify_save.tscn`.
