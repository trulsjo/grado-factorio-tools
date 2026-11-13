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

The player's `%APPDATA%\Factorio` was listed before and after the run, each file as one string of
its path, last write time in ticks and size, so that `Compare-Object` compares all three, with
`$player` set to `Join-Path $env:APPDATA 'Factorio'`:

```powershell
$watch = { Get-ChildItem -LiteralPath $player -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\saves\\|\\temp\\' } |
    ForEach-Object { "$($_.FullName)|$($_.LastWriteTimeUtc.Ticks)|$($_.Length)" } | Sort-Object }
$before = & $watch
# ... the run ...
$after = & $watch
Compare-Object @($before) @($after)
```

`Compare-Object` returned nothing, 0 differences: the run changed neither the player's mods nor
their write-data outside `saves` and `temp`, which were not listed. A file the listing could not
read would have been left out unnamed, by `-ErrorAction SilentlyContinue`.

What it cannot see: a start of the game with its window, which `--dump-data` is not; ~~that such
a start writes the file too is read from both loading the mods the same way, not measured. A zip
install was not run.~~ both, and the zip install, were run on 2026-11-13 for
trulsjo/grado-factorio-tools#439, below: the zip install's `--dump-data` start wrote the file as
this one did, and a start with the window, closed by its pid at the main menu, wrote nothing.

### A start with the game's window, closed at the main menu, writes nothing there

Measured on 2026-11-13 for trulsjo/grado-factorio-tools#439, on the development machine, three
starts, each on a new, empty `mods` folder in a new scratch folder under `%TEMP%`, with a
write-data of its own, `<scratch>/write-data`, given by a `--config` file as the load harness
writes one. Each was started from `<scratch>`, which held `steam_appid.txt` (`427520`), as
`dev-launch.ps1` starts the game. No Factorio was running before each, by `Get-Process -Name
factorio`. Each run's log names the `--mod-directory` given and that write-data on its `Program
arguments` and `Write data path` lines.

| Start | Build, from `--version` | Folder after |
|---|---|---|
| The zip install, headless, 19:06 UTC | `Version: 2.1.24 (build 87808, win64, full)` | `mod-list.json`, 355 bytes |
| The Steam build, with its window, 20:11 UTC | `Version: 2.1.24 (build 87808, win64, steam)` | empty |
| The zip install, with its window, 20:13 UTC | `Version: 2.1.24 (build 87808, win64, full)` | empty |

The zip install is `D:\factorio-2.1\bin\x64\factorio.exe`, the Steam build
`D:\SteamLibrary\steamapps\common\Factorio\bin\x64\Factorio.exe`. The headless start was the
command #434 ran above, through `Invoke-Factorio`; it exited 0, and its `mod-list.json` held the
five entries #434's did, in the same order. A start with the window was

```text
Factorio.exe --config "<scratch>/factorio-config.ini" --mod-directory "<scratch>/mods"
```

run by `Start-Process -WorkingDirectory <scratch> -PassThru`. Once `factorio-current.log` in its
write-data held the line `Factorio initialised`, the main menu, at 92.1 s for the Steam build and
within 88 s for the zip install, it ran 5 s more and was closed by its pid alone,
`Stop-Process -Id <pid> -Force`. Then `Get-ChildItem -Force <scratch>/mods` printed nothing for
either.

The player's folders were listed before and after each start as #434's record lists them, by
the `$watch` block above: `%APPDATA%\Factorio` for the Steam build, 65 files, and for the zip
install `D:\factorio-2.1`, 21168 files, its own write-data and mod folder by its
`config-path.cfg`, `use-system-read-write-data-directories=false`. `Compare-Object` returned 0
differences each time.

What it cannot see: a start the player ends by quitting from the game's menu, which may write
the file as it exits where a kill by pid gives it no chance to; that was not run. A start with
the window that loads a save or a mod. A build other than these two.

## Read

### A zip install keeps its mods at its root, two folders above its executable

Read on 2026-11-14 for trulsjo/grado-factorio-tools#454, on the development machine, from the
zip install at `D:\factorio-2.1`, whose `bin\x64\factorio.exe --version` printed
`Version: 2.1.24 (build 87808, win64, full)`. No game was started.

- Its `config-path.cfg` holds `config-path=__PATH__executable__/../../config` and
  `use-system-read-write-data-directories=false`, which its own comment says is the zip package's
  default: the paths are generated from the application's root directory, not from
  `%APPDATA%\Factorio`.
- Its `config\config.ini`, under `[path]`, holds `write-data=__PATH__executable__\..\..`: two
  folders above `bin\x64`, the install's root.
- `D:\factorio-2.1\mods` is there, and holds `mod-list.json` beside the player's mods.

So a zip install's player mod directory is `<root>\mods` for `<root>\bin\x64\factorio.exe`, which
`dev-launch.ps1`'s `Get-PlayerModDirectory` refuses. The Steam build's is
`%APPDATA%\Factorio\mods`, as #434's record above lists it.

What it cannot see: a `config.ini` whose `write-data` the player changed, or a `config-path.cfg`
that names another config folder; the comment says the generated values stand once written. An
install by the game's installer, which that comment says uses the system's directories, as the
Steam build does. A build other than this one.
