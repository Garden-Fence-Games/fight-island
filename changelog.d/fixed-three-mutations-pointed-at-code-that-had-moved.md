- **Three of the mutations pointed at code that had moved, so `mutate.sh` could not run.** An entry
  whose original text is no longer in the file it names is reported `STALE` and counted as a
  survivor, which fails the whole run. `PEAK` had moved from `AudioManager` to `SoundBank`,
  `HEADROOM` had become `MixTable.HEADROOM_DB` and changed units with it, and one entry still broke
  the thrower's telegraph. Both survivors are repointed and proved — the peak mutation makes
  `verify_audio` report two sounds twenty decibels under what they declared, and the headroom
  mutation makes `verify_mix` say in as many words that a night wave clips.
  - **And with the table able to run again, two entries turned out to measure nothing.** The tide's
    `drains` and `drains_from` were mutated on the `@export` default in `tide_data.gd`, which
    `data/combat/tide.tres` overrides on every load — so the game got the shipped figure whatever
    the mutation said, and `verify_drowning` was right not to notice. Both now mutate the `.tres`,
    where the number actually lives, and both are caught. They were the only two of their kind.
