- **Every run dealt the same five tracks in the same order.** The shuffle bag is meant to be seeded
  from the run, so a recording of one run has the same music twice — but it latched at boot, against
  whatever seed the title screen happened to hold, and starting a run re-rolls that seed with nothing
  watching. It now notices when the run changed, and still deals only once within a run, which is
  what stops a shuffle shuffling to the same thing every round. **And the telemetry keeps every
  purchase of a wave**, not the last: the merchant sells one more card every three waves, so from
  wave 4 the row threw away all but the final one — and which tracks a player takes *together* is
  most of what the record is for.
