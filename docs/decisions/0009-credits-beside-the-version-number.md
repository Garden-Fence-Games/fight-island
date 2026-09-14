# 0009 — The credits sit beside the version number, not on the title list

**Status:** Accepted
**Date:** 2026-09-14

## Context

The game owes an attribution screen: the island is built out of CC0 packs, the fonts are OFL, the
soundtrack is licensed, and the rigs come from a service whose terms are flagged `prototype only`.
Attribution is not optional and it is not a courtesy.

Where it goes was open, and the two obvious homes were both bad. The recommended default when the
question was written was a discreet entry on the title screen. That default did not survive contact
with the layout.

## Decision

Credits are **neither a title entry nor an Options tab**. They sit **beside the version number**, as
a discreet line under the menu, and open as an overlay the way Options does.

The title holds three entries — Play · Options · Quit — and a fourth row that nobody opens twice is
not worth the height it costs the logo. The Options screen draws five tabs, and the design draws
five; a sixth for a read-only list would make the tab strip carry something that is not a setting.

The content is not written anywhere near the screen. `docs/credits.md` is the list, the game reads
`data/credits.tres` baked from that document by `tools/build_credits.gd`, and
`tools/verify_credits.tscn` fails the build when the two come apart or when a baked row never
reaches a label.

## Consequences

- Adding an asset is a row in a document and a rebuild. Nobody edits a screen to credit a rock.
- The credits cannot silently fall behind what the game ships, because the check that compares them
  runs in CI rather than in somebody's memory.
- The version number gets a neighbour, which is the right company: both are things a player looks
  for once, deliberately, and never again.
- A player who wants the credits has to find them. That is the accepted cost of not spending a title
  row on them.

## Alternatives rejected

**A fourth title entry.** The recommended default, and the layout answered it: three rows sit under
the logo without crowding it and four do not.

**A sixth Options tab.** Puts a list of other people's names in the place a player goes to change
something, and stretches a tab strip that is already at the width the design drew.

**A scroll at the end of a run.** Games that do this are games with an ending. A run here ends in
death far more often than in victory, and crediting Kenney over a corpse is not a tribute.
