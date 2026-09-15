- **The gun's ray aims at a named layer instead of the number 64.** `PhysicsLayers` exists so a mask
  is never spelled as an integer — its own docstring says a mask written as `1` says nothing about
  what it collides with — and the gun was the last script still writing one. Renumbering a layer
  would have left every shot raying against the wrong thing: no error, no log line, the gun simply
  stops hitting people. `verify_project_config` now refuses any physics layer written as a number in
  `scripts/`, so the rule is enforced on the code side and not only on the layer names.
