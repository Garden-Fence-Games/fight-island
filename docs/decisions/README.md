# Architecture decision records

One short file per decision that would otherwise be re-argued every few months. Half a page each.

Format: `# NNNN — Title`, then **Status** (Accepted · Proposed · Superseded), **Date**,
**Context**, **Decision**, **Consequences**, **Alternatives rejected**.

A decision closes by a written record here — not by a conversation. When an entry in the ZenNotes
note *Décisions à trancher* is settled, it becomes a file in this folder and its line is deleted
from that note.

| # | Decision |
|---|---|
| [0001](0001-gdscript-over-csharp.md) | GDScript, not C# |
| [0002](0002-godot-file-naming.md) | Godot file naming overrides the global kebab-case rule |
| [0003](0003-gltf-over-blend.md) | glTF `.glb` as the engine-facing source, not direct `.blend` import |
| [0004](0004-three-autoloads.md) | Three autoloads, and `SaveManager` as a static class |
| [0005](0005-docs-split-repo-zennotes.md) | What lives in the repo and what lives in ZenNotes |
