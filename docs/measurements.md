# Measurements

What the game, the mod portal and a repository's history did when a rule in `scripts/` was
measured: the quoted output, and the steps to repeat each run. A script's header states the rule,
what was measured and the citation in a sentence, and points here for the rest.

Moved from the script headers on 2026-10-06
([#68](https://github.com/trulsjo/grado-factorio-tools/issues/68)), because a header loads
whenever its script is read and these records were between 9% and 41% of it. The wording of each
record is the header's, reflowed. A record is dated and names its build; a newer build may answer
differently, and a new measurement is a new entry, not an edit to an old one.

A game run recorded here as headless and isolated went through `scripts/load-harness.ps1` or its
library. The record of 2026-09-26 does not say how it was run.

## `pack-mods.ps1`

### Mod names are case-sensitive

The 2.0.77 mod-structure documentation says nothing about case, so it was measured on 2026-09-26
against Factorio 2.0.77 (build 84539): a zip `Alpha_1.0.0.zip` or a directory `Alpha` holding a
mod named `alpha` is refused with "doesn't match the expected alpha_1.0.0.zip (case sensitive!)",
and a dependency on `Alpha` with only `alpha` present fails as "Missing required dependency
Alpha". The mod portal agrees: /api/mods/Krastorio2 answers and /api/mods/krastorio2 is "Mod not
found". So `Alpha` and `alpha` are two mods.

### A wrong-case `name` or `version` key is refused by the game

Measured against Factorio 2.0.77 (build 84539), headless, isolated from the player's mods
(grado-factorio-tools#49, for grado-factorio-tools#47). A mod `probe-name` spelling `"Name"` logs

    Error Util.cpp:81: Failed to load mod "probe-name": Key "name" not found in property tree at ROOT

and a mod `probe-version` spelling `"Version"` logs

    Error Util.cpp:81: Failed to load mod "probe-version": Key "version" not found in property tree at ROOT

while a lower-case control loads. Only those two keys were measured, and only with the lower-case
key absent.

To repeat it: dot-source load-harness-lib.ps1, build the harness with New-LoadHarness from a valid
info.json, then rewrite the junctioned info.json with the wrong-case key and call
Invoke-HarnessLoad. The rewrite comes after New-LoadHarness because the harness refuses such an
info.json itself, before the game is run.

### A `"Name"` beside `name`, or a `"Version"` beside `version`, is read from the lower-case key

Measured against Factorio 2.0.77 (build 84539), headless, isolated from the player's mods
(grado-factorio-tools#53, for grado-factorio-tools#51). A mod directory `probe-pair-name` holding
`"Name":"probe-other"` beside `"name":"probe-pair-name"` logs

    Loading mod probe-pair-name 1.0.0 (data.lua)

and a mod `probe-pair-version` holding `"Version":"9.9.9"` beside `"version":"1.0.0"` logs

    Loading mod probe-pair-version 1.0.0 (data.lua)

each creating a map, as a lower-case control `probe-control` does. Mods `probe-pair-name-rev` and
`probe-pair-version-rev`, holding the lower-case key first, do the same under their own names.

The first line does not show which key was read, because the directory is named `probe-pair-name`
too. This does: a directory `probe-swap` holding `"Name":"probe-swap"` beside
`"name":"probe-other"` logs

    Error Util.cpp:81: Failed to load mod "probe-swap": Directory name of mod <path>\probe-swap doesn't match the expected probe-other or probe-other_1.0.0 (case sensitive!)

so the name the game expects is the lower-case key's. Only those two pairs were measured.

To repeat it: write each mod directory with an info.json holding the pair beside `title`,
`author`, `factorio_version` `2.0` and a `base` dependency, and a data.lua holding only a comment,
as each measured mod had. Dot-source load-harness-lib.ps1, call New-LoadHarness on the directory
and then Invoke-HarnessLoad, and look for the mod's name in the OutFile it returns. Nothing is
rewritten, because the harness reads the lower-case key too. The exception is `probe-swap`: the
harness would junction it in as `probe-other`, so build the harness from `"name":"probe-swap"`
alone and rewrite the junctioned info.json, as for a lone wrong-case key.

## `game-mods.ps1`

### The game's own mods are matched in exact case

Measured for all four game mods as well as for an ordinary one. Factorio 2.0.77 (build 84539),
headless, fails a dependency on `Alpha` when only `alpha` is present (grado-factorio-tools
607ceef), and on each game mod in another case (grado-factorio-tools#46, for #44).

To repeat it: a throwaway mod `probe-spaceage` whose info.json declares the one dependency
`Space-Age`, loaded alone through `load-harness.ps1 -With space-age`, which keeps it from the
player's mods. The game logs

    Error Util.cpp:81: Failed to load mod "probe-spaceage":
    • probe-spaceage
        • Missing required dependency Space-Age

and refuses `Base`, `Quality` and `Elevated-Rails`, declared the same way, with the same line
naming each. A control declaring `space-age` in lower case, run the same way, loads.

## `get-dump.ps1`

### A real dump, a second request, and the modpack's copy agreeing on the key

Measured 2026-10-08 against Factorio 2.0.77 (build 84539), headless and isolated, for
grado-factorio-tools#75, the day the script moved here. The mods were `grado-factorio-modpack`'s
staged `.mod-cache/Grado_NonChanging`: 29 enabled mods, 1,625 files. The cache was an empty
scratch directory.

    pwsh -File scripts/get-dump.ps1 <modpack>/.mod-cache/Grado_NonChanging -CacheDirectory <scratch>

The first request printed `get-dump: made, no dump of this set was in the cache` and took 14
seconds; the game's log gives `Prototype list checksum: 169335276`, and the dump is
`Grado_NonChanging-169335276-23d35a4614d6.json`, 19,144,547 bytes. The same command again printed
`get-dump: served from the cache, nothing run` and the same path. A count of the files under the
mod directory was 1,625 before the first request and after the second.

Then the modpack's own `scripts/get-dump.ps1`, as it is at that repository's `4cc5805`, was put
in a scratch directory with the `scripts/` of this repository at `d251481`, the modpack's pin,
under `vendor/grado-factorio-tools/`, and a junction to the same mod directory as
`.mod-cache/Grado_NonChanging`. Asked for `Grado_NonChanging` against a copy of that cache, it
printed `served from the cache, nothing run`. So the script here and the one it came from name
the same set by the same key.

Not measured: a dump with `-With` or `-Disabled`, and any build but 2.0.77.

## `commit-check.ps1`

### Why the check exists: a rule nothing was reading

`realistic-fusion-refreshed`, where the check was written, had said "Wrap at 72" in its CLAUDE.md
since that repository started, and nothing was reading it. Measured by the script against the last
fifty commits on its main, 2026-09-06: 21 of the 50 are rejected, on 183 body lines over 72 and 5
subject lines over 72 -- the longest subject being 82 characters. The argument reached for at
review time was that a rule main breaks this widely must not really apply. That is backwards: a
rule nothing enforces is a rule that rots, and the fix is the enforcement rather than the excuse.

### A first count said 201 lines in every one of the fifty

It was wrong in the direction that flatters the finding. It was an awk one-liner over `git log`,
and it charged every `Co-Authored-By:` and every session URL to the rule -- lines the script
exempts on purpose and git would corrupt if they wrapped. The real number is smaller and it is
still 21 commits in 50. Stated because a gate whose own justification is unmeasured is the thing
it exists to prevent.

## `check.ps1`

### How long it takes, on the development machine and in CI

Measured 2026-10-06 (grado-factorio-tools#70), in seconds, from the check's own output. The
development machine was quiet for these three runs; CI is the `check` workflow's run on
grado-factorio-tools#71, on `windows-latest`.

| step | development machine, three runs | CI |
|---|---|---|
| parse of every script | 0.8 to 0.9 | 0.1 |
| `commit-check.ps1 -SelfTest` | 1.0 to 1.1 | 0.6 |
| `fetch-mods.ps1 -SelfTest` | 8.7 to 9.5 | 5.2 |
| `mod-info.ps1 -SelfTest` | 0.7 to 0.9 | 0.5 |
| `pack-mods.ps1 -SelfTest` | 3.5 to 3.6 | 1.9 |
| `resolve-modpack.ps1 -SelfTest` | 1.6 to 1.7 | 0.8 |
| page sizes and links | 0.1 | 0.1 |
| all, each run summed | 16.5 to 17.7 | 9.2 |

So a quiet development machine takes a little under twice as long as CI. Each self-test takes
between 1.4 and 2.1 times its CI time, and the parse 0.7 to 0.8 seconds more: no step carries the
difference. The CI column is one run; the run after it summed to 11.0 seconds.

The same check had taken far longer earlier that day: 63 seconds, 108 seconds and 373 seconds.
The last two ran while two review lanes were each running it, and one of them the game, at the
same time. What else was running during the 63-second run was not recorded. A run timed step by
step between those and the quiet ones took 37 seconds. `fetch-mods.ps1`, `pack-mods.ps1` and
`resolve-modpack.ps1` each took about twice their quiet time, and `commit-check.ps1 -SelfTest`,
which starts no process and opens no file but its own, took 3.6 seconds against 1.0.

And that evening, with the machine's processors fully busy with something that was not this
check, the parse of the nine scripts alone took 56.7 seconds against 0.8 to 0.9 quiet, and the
run was stopped at two minutes with no self-test finished.

What that shows is that the time follows the load on the machine and not anything the check does.
What it does not show is why the machine is slower when quiet. It runs Microsoft Defender for
Endpoint with real-time and behaviour monitoring on, which scans each process as it starts; that
was not turned off to see, so it is a likely cause and not a measured one.
