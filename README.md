# grado-factorio-tools

Shared tooling for the Factorio mod projects — the scripts that are not about any one mod and should
not be maintained twice.

Siblings that consume it, each carrying this repo as a submodule at `vendor/grado-factorio-tools`:

- [realistic-fusion-refreshed](https://github.com/trulsjo/realistic-fusion-refreshed) — where most of
  this tooling was written and still lives
- [grado-factorio-modpack](https://github.com/trulsjo/grado-factorio-modpack)

## Status

**One tool extracted, and that extraction is finished.** `scripts/commit-check.ps1` is here, this
repo's own `commit-msg` hook runs it, and both siblings resolve it from the submodule rather than
holding a copy. No copy of it remains anywhere.

**Three more are extracted and finished.** `scripts/fetch-mods.ps1` and the load harness are here
and nowhere else: `realistic-fusion-refreshed` deleted its copies and takes both from the
submodule. So is `scripts/pack-mods.ps1`, below: `realistic-fusion-refreshed` deleted its copy,
the modpack deleted its own zipper, and both pack through this one. ~~Everything else earmarked
still lives in `realistic-fusion-refreshed`, working and gated.~~ What is earmarked and has not
moved, `scripts/name-check.ps1`, the rest of `scripts/factorio-lib.ps1` and
`scripts/load-check.ps1`, whose harness alone moved, still lives in
`realistic-fusion-refreshed`, working and gated. See
[docs/extraction-plan.md](docs/extraction-plan.md) for what is earmarked, how entangled each piece
is, what has moved, and what has to be written from nothing.

**Three scripts have moved here from `grado-factorio-modpack`, ~~and that repository still holds
its copies~~ and that repository deleted its copies on 2026-10-11.** `scripts/markdown-check.ps1`,
`scripts/get-dump.ps1` and `scripts/refuse-cd-into-mod-cache.ps1`, all below, were ruled to move
on 2026-10-08. ~~Each copy goes when the modpack's contraction ticket for it lands.~~
grado-factorio-modpack#221 deleted all three.

**Two more have moved here from `realistic-fusion-refreshed`, ~~which still holds its copies~~
which deleted its copies by 2026-10-14.** The tree viewer and `scripts/locale-check.ps1`, both
below, came on 2026-10-11 with five helpers they and its name check use between them. ~~Each copy
goes when that repository's contraction ticket for it lands.~~ realistic-fusion-refreshed#686
deleted the five helpers on 2026-10-12, and realistic-fusion-refreshed#690 the tree viewer and
the locale check on 2026-10-14. Each contraction, with its tickets and commits, is in
[docs/extraction-plan.md](docs/extraction-plan.md), *The contractions of 2026-10-11 to
2026-10-14*.

**Two tools written here from nothing:** `scripts/resolve-modpack.ps1`
([#14](https://github.com/trulsjo/grado-factorio-tools/issues/14)) and
`scripts/pr-body-check.ps1`
([#96](https://github.com/trulsjo/grado-factorio-tools/issues/96)), both below. The second's
heading check is ported from `grado-factorio-modpack`
([#171](https://github.com/trulsjo/grado-factorio-tools/issues/171)).

The commit-message convention this repo and its siblings share is declared in
[docs/commit-convention.md](docs/commit-convention.md). The three claim grades, for a sibling
that adopts them, and the rules of review that go with them are in
[docs/claim-grades.md](docs/claim-grades.md). This repo does not apply them to its own docs.

Nothing is moved out of a working repo until it is agreed — see `CLAUDE.md`.

## What belongs here

Three things, in the order Truls named them:

1. **Coexistence checking** — loading a mod alongside other mod sets and proving they still load.
   Here: `fetch-mods.ps1` fills a cache with third-party mods at pinned versions, git first and the
   portal as fallback, and `load-harness.ps1` loads a set of mods in isolation and says whether it
   loaded. A mod's own invariants stay in its own repository and run on top — see below.
2. **Technology tree viewer** — renders a mod set's tech tree as a self-contained zoomable HTML
   page.
3. **Mod portal upload** — **does not exist yet, anywhere.** `pack-mods.ps1` builds the zips and
   says so in its own header: *"It uploads nothing and it changes no version."* This repo is where
   that machinery gets written.

Likely to follow, because they are about *a* Factorio mod rather than *this* Factorio mod: the
parts of the shared PowerShell library that are not RFR-specific. The commit-message check and
the locale check have already moved — see Status above. The prototype-name check was ruled on
2026-10-11 to stay in `realistic-fusion-refreshed` for now; the extraction plan says why.

## Resolving a modpack

`scripts/resolve-modpack.ps1` answers, for a modpack and a game build, which release of each mod in
the pack's closure, its required and recommended (`+`) mods, that build would install, and
whether those releases satisfy each other. A Grado pack runs it before every release, to check
that its declared `base >=` minimum is still true. It reads only the public
portal API, which needs no login.

    pwsh -File scripts/resolve-modpack.ps1 -Line 2.1 -Build 2.1.23 -PinFile pins.psd1 `
        Grado_NonChanging/info.json Grado_ChangingBase/info.json Grado_ABC/info.json `
        Grado_ABCX/info.json Grado_ABCS/info.json

Pass the pack and every pack it depends on, as `-InfoJson`, the trailing arguments; a pack named by
another is read from those files rather than the portal. `-PortalBaseUrl` names another portal
address; only `/api/mods/<name>/full` is read. It prints, per pack, the effective floor and every
violation or unresolvable member, and exits non-zero on either. A `-Build` off its `-Line`, as
`2.1.20` with `2.0`, is refused before the portal is asked. `-PinFile` writes the picks as one set
per pack. `-SelfTest` proves it can fail, with no network. What it cannot see is in its header.

The game's own mods (`base`, `space-age`, `quality`, `elevated-rails`, `recycler`) and the
exact-case rule they are matched by live in `scripts/game-mods.ps1`. The resolver dot-sources it,
and so does a consumer that has to agree with the resolver on which names are the game's.

## Checking that mods coexist

Three steps, no glue between them: resolve a pack (above) to a pin file, fetch that set into a
cache, and load the cache.

    pwsh -File scripts/fetch-mods.ps1 -PinFile pins.psd1 -Set Grado_NonChanging
    pwsh -File scripts/load-harness.ps1 .mod-cache/Grado_NonChanging path/to/Grado_NonChanging

`fetch-mods.ps1` reads no pins of its own: `-PinFile` is the consumer's manifest, and its header
shows the format. A mod with a Git entry is cloned at its tag; any other is downloaded from the
portal with the credentials Factorio keeps in `player-data.json`, so sign in to the game once.
`-Force` fetches again a version the cache already holds. `-PreferPortal` takes the portal even
for a mod with a Git entry, to exercise the credential path. `-PlayerDataPath` names another
`player-data.json`, which a run off Windows must, having no default, and `-PortalBaseUrl` another
portal address; `-SelfTest` points both at its own.

`load-harness.ps1` takes mod directories, zips, or directories of them, and never touches the
player's mods, saves or `player-data.json`. `-With space-age` enables bundled mods. A consumer with
checks of its own passes `-Check <script>`, or dot-sources `load-harness-lib.ps1` to dump the data
stage and load again under other mod lists. `-FactorioExe` names the game; without it, the game is
`$env:FACTORIO_EXE`, then a Steam path on the machine the harness was written on, so on any other
machine pass one of the two. The scripts below that start the game take `-FactorioExe` too, except
`dump-walk.ps1`: its self-test starts the game through `get-dump.ps1` and passes none, so only
`$env:FACTORIO_EXE` or that Steam path reaches it. Both scripts take `-SelfTest`; the harness's
needs the game installed.

`get-dump.ps1` gives the path of a `--dump-data` dump of a directory of mods, and runs the game
only when its cache holds no dump of that set:

    pwsh -File scripts/get-dump.ps1 .mod-cache/Grado_NonChanging -With space-age

The path is the last line it prints. The cache is `.dump-cache` under the current directory, or
`-CacheDirectory`; keep it out of git. A set is the game build, the bundled mods enabled and each
mod's name, version and size, so the same mods in another directory are served the same dump. It
reads sizes and not contents: what that misses is in its header. `-Disabled` loads the named mods
of the directory disabled, or a bundled one such as quality, a comma list in exact case, and
`-FactorioExe` names the game, as the harness takes it. `-SelfTest` needs no game.

## Reading a dump

Five scripts each take dumps from `get-dump.ps1` and print Markdown, so a figure in a page is
pasted and not retyped. They were written for
[grado-factorio-modpack#139](https://github.com/trulsjo/grado-factorio-modpack/issues/139), from
the measurements that repository's catalogue and load records hold. Four name no mod;
`dump-walk.ps1` knows three names of Space Age's, which its header lists. Each header says what
the script reads and what it does not see.

| Script | Dumps | Prints |
|---|---|---|
| `dump-walk.ps1` | one, or two with `-Against` | what can be researched and made from what the surfaces supply, and what each surface makes from its own materials |
| `dump-planets.ps1` | one, or two with `-Against` | each planet's resources and settings, and whether they name anything the dump lacks |
| `dump-shared-names.ps1` | four: `-Base`, `-First`, `-Second`, `-Both` | the names two mod sets each define, and which definition the two together hold |
| `dump-keys.ps1` | one, or two with `-Below`, and a `config.ini`, `-Config`, the player's unless named | the custom inputs that share a default key with an engine control or are linked to one |
| `dump-diff.ps1` | two | the prototypes one has and the other has not, and those that differ, by field; a row lists its names up to `-MaxNames` and counts them above |

    pwsh -File scripts/dump-walk.ps1 <pack dump> -Against <Space Age dump> -BroughtIn wood

All five take `-SelfTest`. The walk's runs on a dump of Space Age with Quality, which it makes
through `get-dump.ps1` and so needs the game, unless `-Dump` names one; the other four read
fixtures.

## Tracing which mods define a name

A dump says which definition of a name stands, not which mods wrote one.
`scripts/trace-definitions.ps1` loads a set of mods through the harness with a tracing mod it
writes into the harness's mod directory, which logs every `data.extend` with the mod whose stage
file made it. It prints each name two or more mods define, each definer with its stage in order,
and the one that stands. Names core or base define are counted apart. Written for
[#173](https://github.com/trulsjo/grado-factorio-tools/issues/173), for
[grado-factorio-modpack#331](https://github.com/trulsjo/grado-factorio-modpack/issues/331).

    pwsh -File scripts/trace-definitions.ps1 .mod-cache/Grado_ABCS -With space-age

`-SelfTest` loads five fixture mods, and so needs the game; `-SelfTest -NoGame` reads only two logs
written for it, and `scripts/check.ps1` runs that. `-KeepTemp` keeps the harness, the game's
`trace-stdout.txt` in it. `-FactorioExe` names the game, as the harness takes it. What the tracing
mod cannot see, such as a prototype assigned into `data.raw` directly, is in the header.

## Counting resources on a new map

Two scripts and a mod answer which resources a mod leaves with no entity, on a map of the same
seed and set with it and without it. They were written for
[#161](https://github.com/trulsjo/grado-factorio-tools/issues/161), from the throwaway scripts of
[grado-factorio-modpack#307](https://github.com/trulsjo/grado-factorio-modpack/issues/307).

```powershell
pwsh -File scripts/count-resources.ps1 .mod-cache/Grado_ABCS -With space-age -Seed 140140 `
    -Radius 48 -NoPlanets -Name abcs-rso-r48 -OutDirectory counts
pwsh -File scripts/compare-resource-counts.ps1 -Under rso-mod `
    -With counts/abcs-rso-r48.json,counts/abcs-rso-r24.json `
    -Without counts/abcs-norso-r48.json,counts/abcs-norso-r24.json `
    -AlsoDiffers Grado_ABC,Grado_ABCS,Grado_ChangingBase,Grado_NonChanging
```

The cache is the modpack's, from its checkout. Its four pack mods require `rso-mod`, so a run
without `rso-mod` leaves them out too, and `-AlsoDiffers` names them.

`count-resources.ps1` loads the mods through the harness with `scripts/grado-count`, a mod that
counts every `resource` entity by name in a square of chunks around each surface's origin. It
creates the map, runs it 700 ticks, and copies out the counts, the game's stdout, the mods it
resolved, and a fingerprint of each mod directory before and after. It needs the game, which
`-FactorioExe` names, as the harness takes it.
`-Mods` and `-With` each take a comma list, as `-With space-age,quality`.
`-Radius` sets the square, and `-NoPlanets` creates no planet's surface, so with Space Age the
map has Nauvis alone.

`compare-resource-counts.ps1` prints each resource one side places and the other places on no
surface, and per surface what each places that the other does not. A side may be several runs:
each surface is read from the run that generated the most chunks there. It refuses, and prints
only why, when the seeds, a surface's square, the surfaces counted, or the mods differ;
`-AlsoDiffers` names the mods that may differ besides `-Under`'s. `-SelfTest` runs a case
of each refusal and one of a resource neither side places, with no game. What each cannot see
is in its header, and grado-count's in its `control.lua`.

## Seeing a set's technology tree

`tree-viewer.ps1` renders the technology tree of a set of mods as one zoomable HTML page, each
technology coloured by the mod that created it:

    pwsh -File scripts/tree-viewer.ps1 .mod-cache/krastorio2 path/to/my-mod -FocusMod my-mod

It takes the same mod paths as `load-harness.ps1`, loads them the same isolated way, and writes
`tree-viewer-out/tech-tree.html` under the current directory; `-OutName` and `-OutDirectory` change
that, and `-FactorioExe` names the game, as the harness takes it. `-FocusMod` names the mods whose
items, fluids and entities are paired with like-named ones of the other mods. It is a probe: exit 0
means it ran and wrote the page, not that the tree is right. The page loads two libraries from a
CDN, so it needs the network to render. `tree-layout-probe.js` is pasted into the browser console on
a rendered page to measure layout alternatives. `-SelfTest` needs the game.
~~`realistic-fusion-refreshed` still holds its own copy of all three files, until [its
#676](https://github.com/trulsjo/realistic-fusion-refreshed/issues/676) lands.~~
`realistic-fusion-refreshed` deleted its copy of all three files on 2026-10-14, for
[realistic-fusion-refreshed#676](https://github.com/trulsjo/realistic-fusion-refreshed/issues/676).

## Checking that a mod's prototypes have names

`locale-check.ps1` fails when a prototype of the mods' own would show a player `Unknown key` in
place of its name, or a name or description with an engine error left in it:

    pwsh -File scripts/locale-check.ps1 path/to/my-mod -Prefix my-

It takes the same mod paths as `load-harness.ps1`. `-Prefix` is how it tells the mods' own
prototypes from the game's, so a mod whose prototype names share no prefix cannot use it. It
takes two dumps and creates no map: a pass says nothing about the mod loading, and it does not
read the name of a custom input. `-Nameless` names prototype types it must not ask a name of, a
comma list: a type with no name a player sees. `-FactorioExe` names the game, as the harness
takes it. `-SelfTest` plants prototypes it must catch, and needs the
game. ~~`realistic-fusion-refreshed` still
holds its own copy, until
[its #677](https://github.com/trulsjo/realistic-fusion-refreshed/issues/677) lands.~~
`realistic-fusion-refreshed` deleted its copy on 2026-10-14, for
[realistic-fusion-refreshed#677](https://github.com/trulsjo/realistic-fusion-refreshed/issues/677).

## Keeping an agent session out of the mod cache

An agent session's tooling writes state files into the directory its shell stands in, and a file
inside a mod in the cache is part of what the game loads. `scripts/refuse-cd-into-mod-cache.ps1`
is a hook that refuses a shell command which would stand in `.mod-cache` under a repository root,
and lets through one that reads the cache by path.

This repository cannot wire it for a consumer: a session reads its hooks from the consumer's own
tracked settings. In the consumer's `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|PowerShell",
        "hooks": [
          {
            "type": "command",
            "command": "i=$(cat); case $i in *mod-cache*) h=\"$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-cd-into-mod-cache.ps1\"; if [ -f \"$h\" ]; then printf '%s' \"$i\" | pwsh -NoProfile -File \"$h\" -Root \"$CLAUDE_PROJECT_DIR\"; else printf '%s' '{\"systemMessage\":\"refuse-cd-into-mod-cache: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it.\",\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"refuse-cd-into-mod-cache: the hook script was not found, so this command was NOT checked. git submodule update --init fetches it.\"}}'; fi;; esac"
          }
        ]
      }
    ]
  }
}
```

`-Root` is the repository whose cache is guarded, and `-CacheName` names a cache that is not
`.mod-cache`; the `case` has to name it too. The `case` keeps PowerShell from starting before
every shell command. Exit 2 refuses and says what to do instead. Any other failure exits
non-zero and not 2, and says on stderr that the command was not checked: no `-Root`, or a tool
call it cannot read.

Where the script is not there, as in a clone whose submodule is not initialised, the command
above lets the shell command run and prints JSON whose `additionalContext` tells the agent it
was not checked. ~~A submodule that is not initialised is the same posture from pwsh itself,
which exits 64 for a script that is not there (measured 2026-10-08, PowerShell 7.6.6).~~
**Changed 2026-10-12** ([#115](https://github.com/trulsjo/grado-factorio-tools/issues/115)).
What reaches the agent from that exit was not measured. By the account of
grado-factorio-modpack#228, read 2026-10-12, a wiring of that repository's that said so on
stderr and exited 1 was measured on 2026-10-11 with Claude Code 2.1.296, and what the tool call
returned to the agent held nothing of it.

`-SelfTest` proves what is refused and what is not, that the command above reaches the script,
and that it tells the agent where the script is not there. A consumer runs
`-SelfTest -Settings .claude/settings.json` to prove the same of its own wiring: one that
refuses the command in that branch, says nothing on stdout, or prints JSON a quote in its
message has broken, fails. So does one whose `matcher` would not start the hook for the `Bash`
tool and for the `PowerShell` tool: a line above the failing case names the tool and the file.
How a matcher is read is in `scripts/hook-matcher.ps1`, from the client's hooks reference. What
the hook cannot see is in its header.

## Keeping an agent session from skipping the hooks

A session that finds a hook slow is tempted to go round it. `scripts/refuse-git-hook-skip.ps1`
is a hook that refuses a shell command running `git commit` or `git push` with `--no-verify`,
`git commit -n`, or either with a `-c core.hooksPath=` of its own, and says to run it without
the switch. `git push -n`, which is a dry run, passes, and so does a switch that is only named in
a quoted message.

This repository wires it for its own sessions in its tracked `.claude/settings.json`. A consumer
adds it to its own, beside the mod-cache hook where it has that one:

```json
{
  "type": "command",
  "command": "i=$(cat); case $i in *commit*|*push*) printf '%s' \"$i\" | pwsh -NoProfile -File \"$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-git-hook-skip.ps1\";; esac"
}
```

The `case` keeps PowerShell from starting before every shell command. Exit 2 refuses; a tool
call it cannot read exits 1 and says on stderr that the command was not checked. `-SelfTest`
proves what is refused and what is not, and runs the command this repository's settings wire;
`-SelfTest -Settings .claude/settings.json` runs a consumer's. Either way it fails a wiring
whose `matcher` would not start the hook for both shell tools. What the hook cannot see is in
its header: a script or an alias that passes the switch itself and a hook manager turned off
through the environment are two of them.

## Keeping an agent session from running Python from a heredoc

A Python edit script fed through a heredoc, `python - <<'EOF'`, cannot be read back or run
again, and one with a string that is not raw changes a regex's or a path's backslash escapes
unseen (#240). `scripts/refuse-python-heredoc.ps1` is a hook that refuses a shell command
running `python`, `python3`, `py` or another Python with its script read from a heredoc. It
says to write the script to a file with the Write tool, with raw strings, and run
`python -I <file>`, or to use the Edit tool. `python -c`, `python -m`, a script file given a
heredoc as its input, `python - < edit.py`, and a here-string, `<<<`, pass.

This repository wires it for its own sessions in its tracked `.claude/settings.json`, beside the
hook-skip hook. A consumer adds it to its own:

```json
{
  "type": "command",
  "command": "i=$(cat); case $i in *py*'<<'*) printf '%s' \"$i\" | pwsh -NoProfile -File \"$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-python-heredoc.ps1\";; esac"
}
```

The `case` keeps PowerShell from starting unless the command holds `py` and `<<`. Exit 2
refuses; a tool call it cannot read exits 1 and says on stderr that the command was not checked.
`-SelfTest` proves what is refused and what is not, and runs the command this repository's
settings wire; `-SelfTest -Settings .claude/settings.json` runs a consumer's, and fails a wiring
whose `matcher` would not start the hook for both shell tools. What the hook cannot see is in
its header: a heredoc piped into Python, `cat <<EOF | python -`, is one.

## Packing mods

`scripts/pack-mods.ps1` builds one zip per mod directory, named `<name>_<version>.zip` from the
mod's own `info.json`, with `info.json` in a single top-level folder — the shape the portal and the
game take.

    pwsh -File scripts/pack-mods.ps1 -OutputDirectory dist my-mod my-mod-graphics

The mod directories are `-ModDirectory`, the trailing arguments, each inside a git work tree.

What goes in is what git tracks under each directory, read from the working tree; untracked files
are reported and left out. A version the portal would reject — not `x.y.z`, a component above
65535, or `0.0.0` — is refused, and nothing is written. Any other version's zip of the same mod in
the output directory is deleted, so one copy is left. It uploads nothing. `-SelfTest` proves it
can fail, in a scratch repository of its own.

## Checking commit messages

`scripts/commit-check.ps1` holds a commit message to
[docs/commit-convention.md](docs/commit-convention.md). This repository's `commit-msg` hook runs
it on each message, and both siblings run it from the submodule.

    pwsh -File scripts/commit-check.ps1 -ScopeFile commit-scopes.txt -Range origin/main..HEAD -RequireCommits
    pwsh -File scripts/commit-check.ps1 -ScopeFile commit-scopes.txt -Title "<pull request title>"

`-Range` checks every commit in a range. A range with none passes and says so, unless
`-RequireCommits` is given: a consumer's CI passes it, where a pull request's range is never
empty, and a local run on a branch with nothing on it yet need not (#196). `-Title` checks a pull
request title, which needs a scope. `-ScopeFile` names the repository's scopes, one to a line;
without it any scope passes. `-SelfTest` proves it can fail. What it lets through is in its
header.

## Checking Markdown

`scripts/markdown-check.ps1` reads Markdown for three things a machine can decide: emphasis or a
code span left open at the end of its paragraph, or a `*` that can only close with nothing open
to close; a table row whose column count differs from its header's; and a link to a file git
does not track, in exact case, or to a heading its file does not have. It knows nothing of Factorio.

    pwsh -File scripts/markdown-check.ps1
    pwsh -File scripts/markdown-check.ps1 -Range origin/main...HEAD
    pwsh -File scripts/markdown-check.ps1 -All
    pwsh -File scripts/markdown-check.ps1 -Path README.md,docs/note.md

With no arguments it reads the staged files as they are staged, which is what a `pre-commit` hook
wants; `-Range` reads the files a range changed, and `-All` every tracked one, failing when
there is none, since then nothing was checked. `-Path` reads the files it names as they are on
disk, staged or not, so an edit can be checked before it is staged; it fails on a name it cannot
read as Markdown, and beside `-All` or `-Range`. With three dots
the files are those the branch at the range's end has changed since it left the base; two dots
would also list each file the base has edited or deleted since then. The check reads the
repository it is run in, so a consumer runs it from the submodule on its own Markdown.
`scripts/check.ps1` runs it here with `-All`, and so does this repository's `pre-commit` hook,
before each commit. `-SelfTest` proves each of the three can fail, and
runs the check over CommonMark's own emphasis and raw-HTML examples, failing one that draws more
emphasis findings than the spec's HTML shows literal marks; they are in
`scripts/commonmark-examples.json`, under the spec's licence (see Licence below). What it reads
as what, and what it cannot see, is in its header.

    pwsh -File scripts/markdown-check.ps1 -All -MaxLineLength 100

Handed `-MaxLineLength`, it also reports a prose line longer than that; without it, it is silent
on length. `scripts/check.ps1` hands it 100 here. Neither sibling is asked to: counted on
2026-10-09 by a throwaway script, `grado-factorio-modpack` had 326 such lines and
`realistic-fusion-refreshed` 3,091.

    pwsh -File scripts/markdown-rewrap.ps1 -MaxLineLength 100
    pwsh -File scripts/markdown-rewrap.ps1 -Comment -Path .github/workflows/check.yml -MaxLineLength 100

`scripts/markdown-rewrap.ps1` repairs what that reports (#215): each paragraph holding a line
over the limit is rewrapped from that line to its end, never inside a code span, a link or an
HTML comment, and never into a line that starts a list item, a heading or another block. It takes
the check's `-Range`, `-All` and `-Path`, and with none the staged files; it writes the working
tree only, and never stages. Which lines are prose and which are over is the check's own reading,
through `scripts/markdown-lib.ps1`, which both load. `-Comment` does the same for a script's or a
workflow's comment lines over the limit, a `#` block or a paragraph of a block comment, found by
length. `-SelfTest` needs no git and no game.

## Checking a pull request body

`scripts/pr-body-check.ps1` reads a pull request body for commits it cites, and fails on one that
is not on `main`: a rebase-merge rewrites every SHA on a branch, so such a citation names a commit
the merge deletes.

    pwsh -File scripts/pr-body-check.ps1 ../scratch/body.md
    pwsh -File scripts/pr-body-check.ps1 -Body "$env:PR_BODY" -CiteSiblings

`-Body` takes the body itself, as CI has it in the environment; quote it, or an unset variable
hands over no argument. `-Main` names the branch a cited commit must be on, `origin/main` unless
said.

It also fails on a closing keyword before an issue reference, such as `fixed` and then a colon
and an issue's number, on any line that is not `Closes #N` alone: GitHub closes that issue when
the pull request merges, whether or not the sentence meant it. And it fails a body that lacks
the `mattpocock-skills:pr` template's `## Summary`, `## Evidence` and `## Merge Danger`, once
each and in that order: Truls's ruling of 2026-10-19 (grado-factorio-modpack#320), held here
since #171 (2026-10-20). The rule is ported from that repository's `Get-DraftProblem`
(`scripts/pr-body.ps1` at `0a58b02`, read 2026-10-20). It fails, too, a body that lacks one of
the template's four markers under its heading: **Before:** and **After:** under `## Evidence`,
**Door:** and **Blast Radius:** under `## Merge Danger` (#185, Truls's ruling of 2026-10-21). A
change with nothing to show says none after **Before:** and **After:**.

With `-CiteSiblings` it also fails a sentence about a sibling repository that lacks a commit or
an ISO date (#177). That is this repository's rule, so it is asked for; a run that does not ask,
as a sibling's CI does, checks what it did before.

CI runs it, with `-CiteSiblings`, on the body of every pull request here, and again when the
body is edited. A word that names no commit in the clone, such as a commit of a sibling, is
said to be unchecked and passes. What else it cannot see is in its header. `-SelfTest` proves
it can fail.

## Checking that list parameters are split

Under `pwsh -File`, a `[string[]]` parameter gets `-With a,b` as one string, `"a,b"`.
`scripts/param-check.ps1` reads the param block of each script in a directory, and fails on a
`[string[]]` parameter that neither takes the remaining arguments nor is split on a comma by a
statement of its script. A function's param block is not read.

    pwsh -File scripts/param-check.ps1 scripts

`scripts/check.ps1` runs it on `scripts/`. It reads that a split exists, not that it runs before
the parameter is used; the rest it cannot see is in its header. `-SelfTest` proves it can fail.

## Checking this repository

`scripts/check.ps1` is the one command before a push. It parses every script here, runs each
self-test that needs neither the game nor the network, runs `param-check.ps1` and
`markdown-check.ps1` over this repository, holds the agent pages to their size limits, and fails
on a script parameter this README never names as `-<Name>` (#194), or a script's comment line over
100 characters; the `pre-commit` hook holds the staged scripts to that rule too, loaded from
`scripts/comment-line-lib.ps1` (#225). CI runs it, and so does the
`pre-push` hook, with `-SkipIfPassed`, which runs nothing when a recorded run passed this same
tree. What it cannot see is in its header.

    pwsh -File scripts/check.ps1

## What does not belong here

Anything that encodes one mod's domain. A reactor invariant, a fuel table, a balance figure or a
prototype name is that mod's business. If a script needs to know `rf-`, it stays where it is.

## Layout

```
scripts/     PowerShell entry points, one job each, and the libraries they
             dot-source: load-harness-lib.ps1, dump-lib.ps1, game-mods.ps1, mod-info.ps1,
             markdown-lib.ps1, the reading markdown-check.ps1 and markdown-rewrap.ps1 share,
             comment-line-lib.ps1, the comment-line rule check.ps1 and pre-commit share,
             which reads a mod's info.json for four of them,
             self-test-halves.ps1, the runner a -SelfTest hands its halves to,
             and hook-matcher.ps1, which reads a session hook's matcher;
             grado-count/, the counting mod count-resources.ps1 loads;
             commonmark-examples.json, CommonMark's examples, which
             markdown-check.ps1 -SelfTest reads (CC BY-SA 4.0)
.githooks/   this repo's own pre-commit (the staged Markdown and scripts), commit-msg and
             pre-push hooks, opted into once per clone
.claude/     settings.json, which wires the session hooks: one refuses a commit
             or push skipping those, and one Python run from a heredoc
.github/     the workflow that runs scripts/check.ps1 on pull requests and main
docs/        the commit convention, the ADRs, the notes agents read, the
             extraction record — what moved, from where, and why — and
             measurements.md, the runs behind the rules the scripts state
GLOSSARY.md  the glossary this repo's own prose is held to
commit-scopes.txt
             the scopes this repo's commits and pull request titles take
LICENSE      MIT; see Licence below for why it is not a sibling's
```

There is no Python here, and nothing is written in anticipation of any. An entry appears above once
it exists.

## Licence

MIT, in `LICENSE`. Decided 2026-09-21. The sibling `realistic-fusion-refreshed` is LGPLv3 because
it carries Krastorio 2 code; that reasoning does not transfer to tooling written from scratch.
Forced then rather than later because a submodule makes this repo a build dependency of two
others, so "all rights reserved by default" stopped being harmless.

One file is not under MIT: `scripts/commonmark-examples.json` holds the examples of two sections
of the [CommonMark Spec](https://spec.commonmark.org/0.31.2/) by John MacFarlane, version 0.31.2,
each example's text and HTML unchanged, under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). That file stays
under that licence, as its own header says. Truls chose to keep it here on 2026-10-19 (#167).
