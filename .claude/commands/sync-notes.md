---
description: Draft the ZenNotes status refresh for Fight Island
---

Refresh the Fight Island notes in ZenNotes so they stop lying about where the project is.

1. Read `docs/roadmap.md` to see which milestone is current and what its exit criteria are.
2. Run `git log --oneline -30` and `gh pr list --state merged --limit 20` to see what actually
   landed since the notes were last touched.
3. Read the hub note at
   `~/Documents/ZenNotes/inbox/Garden Fence/Fight Island/Fight Island.md`, in particular
   its `## État` section.
4. Read the hub's `## Décisions à trancher` section and check whether any listed question has
   since been answered — a closed question becomes an ADR in `docs/decisions/` and its line is
   **deleted** from the section.

Then propose edits. Rules:

- French, following `~/Documents/ZenNotes/inbox/Standard de documentation.md`: rule plus
  reason, present tense, tables over prose, no history.
- **No numbers.** Balance values live in `docs/game-design.md` and `data/*.tres`. A note may
  state an intention, never a coefficient.
- Keep the frontmatter (`title`, `tags`, `dateCreated`) untouched.
- `[[wikilinks]]` are bare note names, no folder path.
- Only touch what became false. Do not rewrite a section that is still accurate.

Show the diff and wait for approval before writing.
