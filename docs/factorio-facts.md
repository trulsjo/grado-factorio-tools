# Factorio facts to check, not remember

**The facts about the game every repository that links this page works by.** Each keeps its own
beside the link: the version breaks its code runs through, its ancestors. The mod portal's facts
are on [`mod-portal.md`](mod-portal.md).

Ruled by Truls on 2026-11-06 in
[*Rulings: the shared parts of each CLAUDE.md*](https://github.com/trulsjo/grado-factorio-tools/issues/328),
ruling 1. Gathered from the *Factorio specifics* of three `CLAUDE.md` files, read 2026-11-06:
trulsjo/grado-factorio-modpack at `987e638`, trulsjo/realistic-fusion-refreshed at `9fd78b5` and
trulsjo/true-nukes-refreshed at `78486d2`; and from trulsjo/grado-factorio-tools's *Factorio
facts to check, not remember* at `e70669f`.

- **Mods are Lua, and the API has three stages**: `settings` and `prototype` run at start-up,
  `runtime` during play. Know which stage code belongs to before writing it.
- **The installed build is read, never remembered**: `Factorio.exe --version` prints it after
  `Version:` (trulsjo/grado-factorio-tools#199).
- **API docs are published per build** at <https://lua-api.factorio.com/>. A claim is checked
  against the build being targeted, not from memory.
- **A recorded fact pins an explicit build**, as `/2.1.23/`: `/stable/` and `/latest/` both move,
  and `latest` is the experimental build.
