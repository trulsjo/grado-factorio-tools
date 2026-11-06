# The mod portal

**The facts about the Factorio mod portal every repository that links this page works by.** How a
repository queries it, a skill or a script, is its own.

Ruled by Truls on 2026-11-06 in
[*Rulings: the shared parts of each CLAUDE.md*](https://github.com/trulsjo/grado-factorio-tools/issues/328),
ruling 2. Gathered from trulsjo/grado-factorio-tools's `CLAUDE.md` at `e70669f` and
trulsjo/grado-factorio-modpack's `CLAUDE.md`, *Checking the mod portal*, at `987e638`, read
2026-11-06.

- **`https://mods.factorio.com/api/mods/<name>/full` says what exists and at what version**, and
  reading it needs no key. Publishing needs a portal API key, which is not the
  `player-data.json` token downloads use.
- **Check `factorio_version` for any `2.x`, not `== "2.0"`.** A mod that has moved to 2.1 is not
  missing.
- **A mod missing under one name may exist under another.** On 2026-09-20 `SpaceMod` had no 2.0
  release, and "SpaceX is dead" was reported from that; `SpaceModFeorasFork` was a live fork on
  2.1. Search titles and summaries, not just names, before concluding anything is gone.
