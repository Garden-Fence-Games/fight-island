- **A drag that began on the name of a setting no longer runs its volume to zero.** The row checked
  that a *press* landed on the meter, but nothing recorded whether it had — so a press the row
  correctly turned down still handed the pointer the value the instant the mouse moved, and the
  first movement took the slider to whichever end it drifted towards. The press is now what grants
  the drag, and a press that missed the meter ends any claim the last one had. A drag that did start
  on the meter still owns it past the ends, which is what makes running a volume to zero one
  movement. Held by `tools/verify_options.tscn`.
