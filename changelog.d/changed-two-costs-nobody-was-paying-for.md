- **Two per-frame costs that bought nothing are gone.** Turning the pixel look off removed its two
  compute dispatches and nothing else: the effect stayed on the camera asking for a normal-roughness
  buffer, so the renderer went on running its depth prepass in that mode and allocating a
  full-screen target every frame for a callback that returned without reading it — a cost paid per
  pixel at 1080p whether one farmer was on screen or thirty. And every neck in the game resolved its
  head bone by *name* each frame, building a String out of a StringName to do it, on all thirty-one
  bodies at the crowd budget, for an index that cannot change while the rig is the same. Neither
  changes what anything looks like.
