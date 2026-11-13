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

## Measured

### The game writes `mod-list.json` into an empty mod directory when it starts

Measured on 2026-11-13 for trulsjo/grado-factorio-tools#434, on the development machine, on the
build `Factorio.exe --version` printed as `Version: 2.1.24 (build 87808, win64, steam)`. The
command, run through `load-harness-lib.ps1`'s `Invoke-Factorio`, from a scratch directory holding
`steam_appid.txt`, so that the Steam API does not relaunch the game:

```text
Factorio.exe --config <scratch>/factorio-config.ini --mod-directory <scratch>/mods --dump-data
```

`<scratch>` was a new folder under `%TEMP%`; `mods` in it was new and empty, and the config gave
the run a write-data of its own, `<scratch>/write-data`, as the load harness gives every run. The
game exited 0. The run's log names the `--mod-directory` given and that write-data. Then
`Get-ChildItem -Force <scratch>/mods` printed one file, `mod-list.json`, 355 bytes, which enables
`base` and the four bundled mods. Its content, each entry here on one line where the file spreads
it over four, with blank lines between:

```json
{
  "mods":
  [
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": true },
    { "name": "quality", "enabled": true },
    { "name": "recycler", "enabled": true },
    { "name": "space-age", "enabled": true }
  ]
}
```

The player's `%APPDATA%\Factorio` was listed before and after the run, with
`Get-ChildItem -Recurse -Force -File`, as each file's path, last write time and size, leaving out
the `saves` and `temp` folders. `Compare-Object` of the two listings found no difference: the run
changed neither the player's mods nor their write-data outside `saves` and `temp`, which were not
listed.

What it cannot see: a start of the game with its window, which `--dump-data` is not; that such a
start writes the file too is read from both loading the mods the same way, not measured. A zip
install was not run.
