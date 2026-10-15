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

### The whole check on Linux

Measured 2026-10-12 (grado-factorio-tools#117). The first row is the run taken for #113, a
workflow of its own on a branch made for it. Each of the other four is a run of the `check`
workflow started with `gh workflow run check.yml --ref <branch>`, on `ubuntu-latest` (image
`ubuntu-24.04`) beside `windows-latest`: three on a scratch branch, deleted since, and the last
on the branch of the pull request that added the Linux job. `gh run view <id> --log` shows
each.

| Run | What the branch held | The Linux job |
|---|---|---|
| 38212614538, for #113 | `main`'s scripts of that day | `fetch-mods.ps1 -SelfTest ran no case`: `Cannot bind argument to parameter 'Path' because it is null.` |
| 38220690042 | the default for `-PlayerDataPath` built only where `%APPDATA%` is set | `fetch-mods.ps1 -SelfTest exited 1`: five of its six checks passed, and the last said `the token never reached the download request` |
| 38223060549 | the same commit, started again by mistake | the same |
| 38223847158 | also a wait in the fake portal until its port answers; and a mutant of the mod-cache hook | `fetch-mods.ps1 -SelfTest -- ok`; `refuse-cd-into-mod-cache.ps1 -SelfTest exited 1` |
| 38224508987 | the pull request's branch, without the mutant | `OK - check passed.` |

So two things kept `fetch-mods.ps1 -SelfTest` from passing on Linux. `Join-Path` was handed
`$env:APPDATA`, which is not set there, before any check ran. And the last check calls the fake
portal from the self-test's own process, where the three before it that use the portal start
a pwsh first: the portal listens on a thread job, and the call reached the port before the
listener did. With
the wait it passed in both runs that had it. Why Windows never showed the same was not looked
into.

The mutant removed the `$IsWindows` guard in `Test-EntersCache`, so that `/c/...` was rewritten
to a drive on every platform. The Linux job failed on it, `1 of 41 case(s) did not hold`, the
one being the absolute path under `/t/`; the Windows job of the same run passed.

In the last run the Linux job took 39 seconds and the Windows job 51, each from its
`startedAt` to its `completedAt` (`gh run view 38224508987 --json jobs`). Every self-test the
check runs, it ran on both, and none was left out on Linux.

## `markdown-check.ps1`

### Which indented lines PowerShell's parser and GitHub's renderer call code

Measured 2026-10-10 (grado-factorio-tools#95), with pwsh 7.6.6 on the development machine. The
length rule asks `ConvertFrom-Markdown` which lines are an indented code block, and a page is
read on GitHub, so the two were compared. Each shape below ends in a line holding the word
`WIDE`. It was rendered both ways and counted as code where `WIDE` came out inside
`<pre><code>`:

    (ConvertFrom-Markdown -InputObject $text).Html
    gh api markdown -f text=$text -f mode=gfm

| The line with `WIDE` is indented | Parser | GitHub |
|---|---|---|
| four spaces, after text and a blank line | code | code |
| four spaces, after a bullet item, a blank line, a rule indented two spaces and a blank line | code | **prose** |
| four spaces, after the same, a paragraph at the margin below the rule and a blank line | code | code |
| four spaces, after a bullet item, a blank line, a rule at the margin and a blank line | code | code |
| four spaces, after a bullet item and a blank line | prose | prose |
| six spaces, after a bullet item and a blank line | code | code |
| four spaces, after a `1.` item and a blank line | prose | prose |
| seven spaces, after a `1.` item and a blank line | code | code |
| five spaces, after a `10.` item and a blank line | prose | prose |
| six spaces, after a bullet nested in a bullet and a blank line | prose | prose |
| eight spaces, after a bullet nested in a bullet and a blank line | code | code |
| by a tab, after text and a blank line | code | code |
| by a tab, after a bullet item and a blank line | prose | prose |
| four spaces, straight after text | prose | prose |
| four spaces, straight after a `#` heading | code | code |
| four spaces, after a fence closed inside a bullet item, an unindented line and a blank line | code | code |
| four spaces, after a bullet item, a lazy line and a blank line | prose | prose |
| five spaces after `>`, after a quoted line and a bare `>` | code | code |
| four spaces, after a bullet item, a table at the margin and a blank line | code | code |
| four spaces, after a footnote definition and a blank line | prose | prose |
| four spaces, after `---`, `title: x`, `---` and a blank line | code | code |
| four spaces, after `<details>` and a blank line | code | code |
| four spaces, after an empty bullet and a blank line | code | code |
| four spaces, after a `term` line, a `:   def` line and a blank line | **prose** | code |

They agree on 22 of the 24. The second row's difference is the rule's: the parser ends the list
at a rule indented into the item and GitHub keeps the rule inside it. So with the third row's
paragraph indented two spaces as well, GitHub still has an item and calls the line prose, and
the parser still calls it code (PR #98's second review, run again here the same day).

PR #98's first review ran a set of its own, 105 shapes that were not kept,
and reported two more differences, each run again here the same day:

| The line with `WIDE` is indented | Parser | GitHub |
|---|---|---|
| four spaces, straight after a `^^^` line, and the same after a `:::note` line | code | **prose** |
| four spaces, on the first line, after a byte-order mark | **prose** | code |

The check follows the parser in all four. What the parser reads that GitHub does not is Markdig's
extensions, as PowerShell turns them on: a definition list, a figure opened with `^^^`, a
container opened with `:::`. That reading is from the block types the parser reported, not from
its documentation.

The parser also gives up on some input: a bullet list nested 90 deep throws "Markdown elements
in the input are too deeply nested - depth limit exceeded", and PR #98's review reported the
same for a table of 10 columns and 1,000 rows, with 10 by 500 parsing. The check says so for the
page and takes none of its lines for code.

### Where `-All` spends its time over a large repository

Measured 2026-10-12 (grado-factorio-tools#125) on the development machine, pwsh 7.6.6 and
git 2.37.3.windows.1. The corpus is `realistic-fusion-refreshed` at `9a8ab36`, cloned to a
scratch directory with nothing staged and its submodule not initialised: 114 tracked Markdown
files, 36,783 lines (`git ls-files '*.md' | xargs cat | wc -l`), of which 3,616 begin with a `|`
after any indentation or `>`. The ticket's 36,787 was counted in that repository's working tree.
"Before" is the script at `41b5488`. Other sessions were running on the machine throughout, and
how loaded it was, was not measured: the third round below shows it.

**The whole run**, `pwsh -NoProfile -File <script> -All`, in seconds, three rounds, before and
after taking turns:

| Round | Before | After | Before, `-MaxLineLength 100` | After, `-MaxLineLength 100` |
|---|---|---|---|---|
| 1 | 153.4 | 37.3 | 177.8 | 90.7 |
| 2 | 137.9 | 28.5 | 142.7 | 52.2 |
| 3 | 429.8 | 37.2 | 501.7 | 159.0 |

With no limit each run exited 0, and with one each exited 1: the corpus is not wrapped, and has
3,031 lines over 100.

**By part, before.** A probe loaded the script's functions, put a stopwatch round `Test-Inline`
and round `ConvertFrom-Markdown`, and read every file as `Invoke-Check` did, one run each:

| Part | No limit | `-MaxLineLength 100` |
|---|---|---|
| a `git show` for each file, 114 processes | 16.2 s | 45.4 s |
| `Test-Markdown`, all of it | 114.9 s | 155.8 s |
| of that, `Test-Inline`, in 21,464 calls | 95.3 s | 109.0 s |
| of that, `ConvertFrom-Markdown` | 0 s | 1.5 s |
| of that, the rest | 19.6 s | 45.3 s |

The two top rows add up to 131 s where the whole run took 138 and 153 in the first two rounds
above; the difference is
PowerShell starting and git listing the files, and was not measured apart. The same 114
`git show` calls took between 21 and 47 s in six more runs of the probe that day, and 21 and
74 s in a PowerShell loop of their own.

**What it grows with: table cells.** `Test-Inline` is called once for every paragraph and once
for every cell of a table, and its time went with the calls and not with the characters. The
five slowest pages before, all under `docs/research/`, are the five with the most table lines
among the slowest eight:

| Page | Lines | Lines beginning `\|`, as above | `Test-Markdown` | of it `Test-Inline` |
|---|---|---|---|---|
| `exchanger-coverage.md` | 1,473 | 356 | 8.5 s | 7.5 s |
| `quality.md` | 1,733 | 292 | 6.7 s | 5.7 s |
| `reactor-runtime-cost.md` | 2,294 | 214 | 6.3 s | 5.3 s |
| `plasma-input-box.md` | 994 | 224 | 6.0 s | 5.1 s |
| `further-reactions.md` | 1,367 | 165 | 5.7 s | 5.0 s |

**Inside one call.** `Test-Inline` on one table cell holding a code span and one emphasis, 1,000
calls, took 9.1 ms a call: 0.6 ms to enter, 0.3 ms masking code spans, 3.3 ms in the two
`[regex]::Replace` calls that hide link targets and addresses, and 4.9 ms reading emphasis. On a
cell of plain words the two `Replace` calls were 2.7 of 3.2 ms, with nothing for them to match.
Each was handed a script block as its evaluator, made anew on every call; reading emphasis
called two script blocks as helpers and made a third as a predicate. The same `Replace` with a
script block made once took 0.1 ms.

**What was changed.** `Test-Inline` makes and calls no script block of its own. `Invoke-Check`
reads every file through one `git cat-file --batch`. One per-line pipeline in `Test-Markdown`
became a loop.

**By part, after**, the probe again, which still reads with `git show`:

| Part | No limit | `-MaxLineLength 100` |
|---|---|---|
| `Test-Markdown`, all of it | 34.1 s | 60.6 s |
| of that, `Test-Inline`, in 21,464 calls | 17.3 s | 17.8 s |
| of that, `ConvertFrom-Markdown` | 0 s | 1.6 s |
| of that, the rest | 16.8 s | 41.3 s |

One `git cat-file --batch` gave all 114 files in 1.0 s, from Git Bash.

**The output is unchanged.** The whole output of `-All`, with no limit and with
`-MaxLineLength 100`, was saved from the script before and after and compared with `diff -q`,
which printed nothing for any of the six pairs:

| Repository | No limit | `-MaxLineLength 100` |
|---|---|---|
| the corpus | 2 lines | 3,034 lines |
| this repository | 1 line | 1 line |
| a scratch repository of seven edge files | 6 lines | 6 lines |

The seven: a byte-order mark, CRLF line ends with no last one, a lone carriage return, bytes
that are not UTF-8, an empty file, three blank lines, and a name outside ASCII. For every
Markdown file of the three repositories, 135 in all, the lines read through `cat-file --batch`
were compared one by one with those `git show` gave, and none differed.

**This repository's own 14 files** with `-All -MaxLineLength 100`, before and after taking
turns: 20.4 and 19.7 s before, 22.8 and 9.6 s after. The machine's load moved more than the
change did, and no figure is claimed here.

**Tried and dropped.** Having .NET find the next backslash or backtick, in place of the loop
over every character that masks code spans: `Test-Inline` took 100.6 s where it had taken 95.3,
so the loop was not the cost.

**Not tried.** The regular expressions `Test-Markdown` runs on every line, which are the 17 s
of "the rest". Why the rest grows to 41 s with a limit: the corpus has 3,031 lines over it, and
each is a finding that is made, sorted and printed, and has its code spans masked by a
`Replace` with a script block; which of those costs was not measured, and a wrapped repository
has none of them. What PowerShell takes to start. A cache between runs, reading fewer files,
and pages in parallel, which grado-factorio-tools#125 leaves to Truls.

### Where a bare address ends, by the spec and by GitHub's renderer

Read and asked 2026-10-12 (grado-factorio-tools#124).

**The spec**, GitHub Flavored Markdown 0.29-gfm (2019-04-06), <https://github.github.com/gfm/>,
section 6.9, *Autolinks (extension)*. Of an address with a scheme it says it is "followed by a
valid domain, then zero or more non-space non-`<` characters according to extended autolink
path validation", and of that validation:

> Trailing punctuation (specifically, `?`, `!`, `.`, `,`, `:`, `*`, `_`, and `~`) will not be
> considered part of the autolink, though they may be included in the interior of the link

> When an autolink ends in `)`, we scan the entire autolink for the total number of
> parentheses. If there is a greater number of closing parentheses than opening ones, we don’t
> consider the unmatched trailing parentheses part of the autolink [...]

> If an autolink ends in a semicolon (`;`), we check to see if it appears to resemble an entity
> reference; if the preceding text is `&` followed by one or more alphanumeric characters. If
> so, it is excluded from the autolink

> `<` immediately ends an autolink.

**The renderer**, asked with `gh api markdown -f mode=gfm -F text=@<file>`, each line a paragraph
of its own. What follows `see https://u.nu/` and stands before ` end`, and how much of it the
renderer put inside the link:

| Written | In the link | | Written | In the link |
|---|---|---|---|---|
| `x".` | `x` | | `x)` | `x` |
| `x."` | `x` | | `x))` | `x` |
| `x"'"` | `x` | | `a(b)` | `a(b)` |
| `x;` | `x` | | `a(b))` | `a(b)` |
| `x;;` | `x` | | `a(b` | `a(b` |
| `x:` | `x` | | `a)b` | `a)b` |
| `x~` | `x` | | `x]` | `x]` |
| `x*_~` | `x` | | `x].` | `x]` |
| `x?q=1.` | `x?q=1` | | `x[1]` | `x[1]` |
| `x.)` | `x` | | `a]b` | `a]b` |
| `x).` | `x` | | `a[b]c` | `a[b]c` |
| `x!)` | `x` | | `x&amp;` | `x` |
| `x,)` | `x` | | `x&amp` | `x&amp` |
| `x&frac12;` | `x&frac12` | | `x&a1;` | `x&a1` |
| `a"b` | `a"b` | | `x>.` | `x>` |
| `a'b` | `a'b` | | `x>y` | `x>y` |
| `a"b"c` | `a"b"c` | | `x<b`, in emphasis | `x` |
| `a*b*` | `a*b` | | `a_b_` | `a_b` |

Each of `x}`, `x=`, `x-`, `x/`, `x#`, `x%`, `x+`, `x&`, `x@`, `x$`, `x^`, `x\` and `x|`
was in the link whole.

So the renderer gives back more than the spec names: a `"` or a `'` that stands last, and a
`;` that ends no entity. Of an entity it gives back the whole only where the name is letters,
where the spec says alphanumeric. A `]` it keeps, opened or not. The check follows the renderer
in all of these. In one it does not: it ends an address at a `>`, which the renderer takes in,
because in `<a href="https://u.nu/x">*open</a>` the renderer makes no link of the address and
reads `*open` as prose, and the check has to see that `*`.

The first commit of grado-factorio-tools#124's pull request had the check give back a `]`
that nothing opened, from a misreading of these answers that its review found. With that,
`_see https://u.nu/a_]` and `*see https://u.nu/x*]` passed, which the renderer leaves open;
both are reported.

An address followed by a `<placeholder>` ends at the `<`: in `*see https://u.nu/<id>/a*b` the
renderer's link is `https://u.nu/` and the emphasis closes before the `b`. The same commit
reported that line as left open, and it passes.

**Inside square brackets the renderer makes no link of an address**, asked the same day. It
closed the emphasis in `[*see https://u.nu/x*]`, `[ and *see https://u.nu/x*]`,
`[*see https://u.nu/x* more]`, `*[see https://u.nu/x]*` and `[*see https://u.nu/x*](there.md)`,
with no link of the address in any. In `[a] *see https://u.nu/x*]`, where the brackets before
the address are a pair, the link is `https://u.nu/x*]` and the emphasis is left open. So the
check ends an address at the `]` that closes a `[` standing open before it, and at no other.
What it hides is still hidden, though to the renderer it is prose there.

**Emphasis round an address**, the same day and the same way. The renderer closed the
emphasis in each of these:

```
*"colors from https://u.nu/factoriogfx"*
*see https://u.nu/factoriogfx*
_see https://u.nu/a_b_
**see https://u.nu/x**
*see https://u.nu/x.* and *more*
*see https://u.nu/a*b c*
~~see https://u.nu/x~~
*see <https://u.nu/x>*
(*see https://u.nu/x*) and *(see https://u.nu/x)*
*see https://u.nu/a_(b)* end
*'https://u.nu/x'* end
*see https://u.nu/x?!.,:* end
*see https://u.nu/x&amp;* end
```

and in a table, in both cells of `| *"from https://u.nu/x"* | *see https://u.nu/y* |`. It left
`*see https://u.nu/x and never closed` open. In the sixth the link is `https://u.nu/a*b`, and
in the third `https://u.nu/a_b`.

It also linked `HTTPS://U.NU/x`, `www.u.nu/x` and `a.b@u.nu`, and made no link of
`ftp://u.nu/x`, of `xhttps://u.nu/x`, or of an address inside square brackets, as in
`[*see https://u.nu/x*]`, where it still closed the emphasis.

**The check, before and after**, on the development machine, pwsh 7.6.6. Before, at `41b5488`,
run with no arguments on a staged file holding the first five lines above, the open one, the
sixth and the seventh, it reported the first five and the open one. After, it reported the open
one alone. With `-MaxLineLength 40`, a line of 35 characters of words followed by
`(*"https://example.com/` and sixty more characters and then `"*).` was not reported for its
length before, and after is reported as 42 characters.

Over `realistic-fusion-refreshed` at `9a8ab36`, the corpus of the section above, the whole
output of `-All` was the same before and after the change, with no limit and with
`-MaxLineLength 100`: `diff` printed nothing. That repository had put its one such address in
angle brackets.

### The anchor GitHub gives a heading

Asked 2026-10-15 (grado-factorio-tools#155), with gh 2.102.0.

**`gh api markdown` gives no anchor.** With `-f mode=gfm`, as above, every heading came back as
`<h1 dir="auto">Results</h1>` with no `id`. Only a `<span id="...">` written in the source had
one.

**The repository's contents API does.** One file of headings was pushed as the only file of a
throwaway branch, `155-anchor-probe` at `f2b38ed`, read with
`gh api "repos/trulsjo/grado-factorio-tools/contents/probe.md?ref=155-anchor-probe" -H "Accept: application/vnd.github.html"`,
and the branch deleted. Each heading's anchor is the `href` of the `<a class="anchor">` after it.
In order, each written as it was and what GitHub gave it:

| Written | Anchor |
|---|---|
| `# Results` | `results` |
| `# Results` | `results-1` |
| `# Results-1` | `results-1-1` |
| `# Results` | `results-2` |
| ``## A `code_span` heading, with punctuation: (yes!) & "quotes"?`` | `a-code_span-heading-with-punctuation-yes--quotes` |
| `## Temperature 150 °C × 2` | `temperature-150-c--2` |
| `## _Underscore emphasis_ and snake_case_name` | `underscore-emphasis-and-snake_case_name` |
| `## *Star emphasis* and **strong**` | `star-emphasis-and-strong` |
| `## __Strong underscores__ done` | `strong-underscores-done` |
| `## Escaped \_under\_ and \*star\*` | `escaped-_under_-and-star` |
| `## A [link](https://example.com) in it` | `a-link-in-it` |
| `## Closing hashes ##` | `closing-hashes` |
| `## Æble Ö CAPS` | `æble-ö-caps` |
| `## Dots.and/slashes—dash – en` | `dotsandslashesdash--en` |
| `## Trailing space`, three spaces after it | `trailing-space` |
| `Setext one` over `==========` | `setext-one` |
| `Setext two` over `----------` | `setext-two` |
| `## <span id="custom">Raw html</span> heading` | `raw-html-heading` |
| `## Emoji :tada: here` | `emoji-tada-here` |
| `## 10² superscript` | `10-superscript` |
| `## Tab`, a tab, `inside` | `tabinside` |
| `## Multiple   spaces` | `multiple---spaces` |
| `## _open underscore` | `_open-underscore` |
| `## a _ b` | `a-_-b` |
| ``## `__init__` and `a*b` `` | `__init__-and-ab` |
| `## ![alt text](x.png) image` | `-image` |
| `## 1. Numbered-looking heading` | `1-numbered-looking-heading` |
| `## Hyphens - and -- double` | `hyphens---and----double` |
| `## <code>tag</code> heading` | `tag-heading` |
| `## &amp; entity &copy;` | `-entity-` |
| `## foo_ trailing` | `foo_-trailing` |
| `## *emphasis_with_under*` | `emphasis_with_under` |
| `## Café` | `café` |
| `## 💥 Emoji literal` | `-emoji-literal` |
| `> ## Quoted heading` | `quoted-heading` |
| `- ## Heading in a list item` | `heading-in-a-list-item` |
| `## Indented four`, four spaces in, after the list item | `indented-four` |
| `## Indented three`, three spaces in | `indented-three` |

So the anchor is made from the text as it renders, not as it is written: a code span's content
is kept and its backticks drop, a link keeps its text, an image and a tag drop whole, and `_`
emphasis that closes drops its underscores, where an unclosed `_` and an escaped one stay. An
emoji written as `:tada:` is read as written, so its name is kept. An entity is read before the
drop: `&amp;` leaves nothing, not `amp`. A tab drops; only a space becomes a hyphen. A repeat
counts per anchor: the third `Results-1` is `results-1-1`, because `results-1` was taken.

The check follows all of these but the list item: a heading inside one is not read, so a link to
it fails. The row after it, `Indented four`, was a heading only because it continued that list
item. The self-test holds `Get-HeadingAnchor` to every row but those two.
Not asked: whether GitHub follows a link whose fragment differs from an anchor only in case.

**The check, before and after**, on the development machine, pwsh 7.6.6. Run with `-All` over
fresh clones of `realistic-fusion-refreshed` at `f3238c5` and `grado-factorio-modpack` at
`8334481`, and over this repository. Before, at `14f1066`, all three passed. After, the modpack
and this repository passed and `realistic-fusion-refreshed` had two findings, both a link to a
heading that is not there: `docs/research/mod-set-coexistence-targets.md:28` and
`docs/research/socket-underside-cut.md:47`. `diff` of its two outputs showed only those, and of
the modpack's printed nothing. That repository's
clone's checkout had not finished the first time, which left no index, and so `-All` read 0
files and passed; a `git reset --hard` with `core.longpaths=true` made the index, and the run
read 115.

Over that clone, timed with `Measure-Command` one run at a time: the check before took 12.1 to
16.0 s in five runs. The first version of this change called the link rule, a script block, for
every line, and took 18.6 to 22.8 s in five runs, two of them with the anchors or the table
rows stubbed out, which made no difference. Called only for a line holding `](` or `]:`, it took
12.1 and 14.0 s.

## `refuse-cd-into-mod-cache.ps1`

### The self-test on Windows and on Linux

Measured 2026-10-12 (grado-factorio-tools#113), with pwsh 7.6.6 on both.

| Where | Command | What it ended with |
|---|---|---|
| Windows, the development machine | `-SelfTest` | `OK - self-test passed: all 40 cases.` |
| Windows, the development machine | `-SelfTest -Settings <modpack>/.claude/settings.json` | the same |
| Linux, `ubuntu-latest` | `-SelfTest` | `OK - self-test passed: 36 of 40 cases; 4 skipped off Windows, each named above.` |
| Linux, `ubuntu-latest` | `-SelfTest -Settings consumer/.claude/settings.json` | the same |

The Linux rows are run 38212614538 of this repository, a workflow on a branch made for the
measurement and deleted after it: `gh run view 38212614538 --log`. `consumer` there is a checkout
of `grado-factorio-modpack` at `1b30cbe`, with this repository's `scripts/` put where its
submodule stands, so its wired command reached the script being measured. On Windows the settings
file was the modpack checkout's own, at the same commit, whose submodule holds the script as it
was before this change; that row shows the wiring is reached, and the Linux one that the changed
script answers through it.

Before the change the same self-test failed 4 of 39 cases on `ubuntu-latest`, at this
repository's `20ef896`: run 38165530088 of `grado-factorio-modpack`, 2026-10-11.

The same Linux run put the drive rewrite back on every platform, by replacing `if ($IsWindows)`
with `if ($true)` in a scratch file made from the script. That file's self-test ended
`FAILED - self-test: 1 of 40 case(s) did not hold.`, and the one was the absolute path under
`/t/`.

Not measured: the hook under WSL, and any command through the hook on Linux but the three the
last case sends.

`scripts/check.ps1` was run on Linux in the same run, for information. It failed on one line,
`fetch-mods.ps1 -SelfTest ran no case`, and every other step passed. ~~Why that self-test ran no
case there was not looked into.~~ **Looked into 2026-10-12** (grado-factorio-tools#117): see
*The whole check on Linux* under `check.ps1` above.

**Since 2026-10-12** (grado-factorio-tools#115) the self-test has 41 cases: the last runs the
wired command for a project that holds no hook script. Measured that day on the development
machine, pwsh 7.6.6:

| Settings file | What it ended with |
|---|---|
| none | `OK - self-test passed: all 41 cases.` |
| `grado-factorio-modpack`'s at `43c30f3` | the same |
| the same file with `"not found"` in quotes in its message | `FAILED - self-test: 1 of 41 case(s) did not hold.` |

The two files were each put in a scratch directory of their own with this repository's script
where the submodule stands, so the wired command reached the script being measured. The failing
case was the forty-first: the command exited 0 and printed JSON that does not parse. On Linux
the case ran in CI with no settings file, in the run under `check.ps1` above; with a consumer's
file it was not run there.

## `hook-matcher.ps1`

### A narrowed matcher fails both hooks' self-tests

Measured 2026-10-12 (grado-factorio-tools#120) on the development machine, pwsh 7.6.6. Each
settings file stood in a scratch directory of its own, with this repository's `scripts/` where
its wired command looks for the hook, and differed from the first of its group in its `matcher`
and nothing else.

`refuse-git-hook-skip.ps1 -SelfTest -Settings <file>`, the first file being this repository's
own:

| `matcher` | What it ended with | The failing case said |
|---|---|---|
| `Bash\|PowerShell`, unchanged | `OK - self-test passed: all 55 cases.` | |
| `Bash` | `FAILED - self-test: 1 of 55 case(s) did not hold.` | ``the matcher `Bash` does not start the hook for the PowerShell tool`` |
| `PowerShell` | the same failure | ``the matcher `PowerShell` does not start the hook for the Bash tool`` |
| `BashOutput\|PowerShell` | the same failure | ``the matcher `BashOutput\|PowerShell` does not start the hook for the Bash tool`` |
| none: the line removed | `OK - self-test passed: all 55 cases.` | |

Without `-Settings` it ended `OK - self-test passed: all 55 cases.`

`refuse-cd-into-mod-cache.ps1 -SelfTest -Settings <file>`, the first file being
`grado-factorio-modpack`'s at `2d84189`, which is after `43c30f3`:

| `matcher` | What it ended with | The failing case said |
|---|---|---|
| `Bash\|PowerShell`, unchanged | `OK - self-test passed: all 42 cases.` | |
| `Bash` | `FAILED - self-test: 1 of 42 case(s) did not hold.` | ``the matcher `Bash` does not start the hook for the PowerShell tool`` |
| `PowerShell` | the same failure | ``the matcher `PowerShell` does not start the hook for the Bash tool`` |
| `BashOutput\|PowerShell` | the same failure | ``the matcher `BashOutput\|PowerShell` does not start the hook for the Bash tool`` |

Without `-Settings` it ended `OK - self-test passed: all 41 cases.`: the forty-second case
reads a settings file. What each failing case said stood on a line above it, after the
settings file's path.

Before the change, at `ee1aa9f`, both passed with the matcher changed to `Bash`: all 41 cases
and all 54, by the account of grado-factorio-tools#120's brief, measured the same day and not
run again here.

The rule the check follows was read 2026-10-12 from *Matcher patterns* in Claude Code's hooks
reference, <https://code.claude.com/docs/en/hooks>, and is quoted in the script's header. The
client on the machine that day was Claude Code 2.1.296 (`claude --version`).

Not measured: a session with a narrowed matcher running a command from the tool left out.
