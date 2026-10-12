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
the modpack deleted its own zipper, and both pack through this one. Everything else earmarked
still lives in `realistic-fusion-refreshed`, working and gated. See
[docs/extraction-plan.md](docs/extraction-plan.md) for what is earmarked, how entangled each piece
is, what has moved, and what has to be written from nothing.

**Three scripts have moved here from `grado-factorio-modpack`, and that repository still holds
its copies.** `scripts/markdown-check.ps1`, `scripts/get-dump.ps1` and
`scripts/refuse-cd-into-mod-cache.ps1`, all below, were ruled to move on 2026-10-08. Each copy
goes when the modpack's contraction ticket for it lands.

**Two more have moved here from `realistic-fusion-refreshed`, which still holds its copies.**
The tree viewer and `scripts/locale-check.ps1`, both below, came on 2026-10-11 with five helpers
they and its name check use between them. Each copy goes when that repository's contraction
ticket for it lands.

**Two tools written here from nothing:** `scripts/resolve-modpack.ps1`
([#14](https://github.com/trulsjo/grado-factorio-tools/issues/14)) and
`scripts/pr-body-check.ps1`
([#96](https://github.com/trulsjo/grado-factorio-tools/issues/96)), both below.

The commit-message convention this repo and its siblings share is declared in
[docs/commit-convention.md](docs/commit-convention.md).

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
the pack's mandatory closure that build would install, and whether those releases satisfy each
other. A Grado pack runs it before every release, to check that its declared `base >=` minimum is
still true. It reads only the public portal API, which needs no login.

    pwsh -File scripts/resolve-modpack.ps1 -Line 2.0 -Build 2.0.77 -PinFile pins.psd1 `
        Grado_NonChanging/info.json Grado_ChangingBase/info.json Grado_ABC/info.json `
        Grado_ABCX/info.json Grado_ABCS/info.json

Pass the pack and every pack it depends on; a pack named by another is read from those files
rather than the portal. It prints, per pack, the effective floor and every violation or
unresolvable member, and exits non-zero on either. `-PinFile` writes the picks as one set per pack.
`-SelfTest` proves it can fail, with no network. What it cannot see is in its header.

The game's own mods (`base`, `space-age`, `quality`, `elevated-rails`) and the exact-case rule they
are matched by live in `scripts/game-mods.ps1`. The resolver dot-sources it, and so does a
consumer that has to agree with the resolver on which names are the game's.

## Checking that mods coexist

Three steps, no glue between them: resolve a pack (above) to a pin file, fetch that set into a
cache, and load the cache.

    pwsh -File scripts/fetch-mods.ps1 -PinFile pins.psd1 -Set Grado_NonChanging
    pwsh -File scripts/load-harness.ps1 .mod-cache/Grado_NonChanging path/to/Grado_NonChanging

`fetch-mods.ps1` reads no pins of its own: `-PinFile` is the consumer's manifest, and its header
shows the format. A mod with a Git entry is cloned at its tag; any other is downloaded from the
portal with the credentials Factorio keeps in `player-data.json`, so sign in to the game once.

`load-harness.ps1` takes mod directories, zips, or directories of them, and never touches the
player's mods, saves or `player-data.json`. `-With space-age` enables bundled mods. A consumer with
checks of its own passes `-Check <script>`, or dot-sources `load-harness-lib.ps1` to dump the data
stage and load again under other mod lists. Both scripts take `-SelfTest`; the harness's needs the
game installed.

`get-dump.ps1` gives the path of a `--dump-data` dump of a directory of mods, and runs the game
only when its cache holds no dump of that set:

    pwsh -File scripts/get-dump.ps1 .mod-cache/Grado_NonChanging -With space-age

The path is the last line it prints. The cache is `.dump-cache` under the current directory, or
`-CacheDirectory`; keep it out of git. A set is the game build, the bundled mods enabled and each
mod's name, version and size, so the same mods in another directory are served the same dump. It
reads sizes and not contents: what that misses is in its header. `-SelfTest` needs no game.

## Seeing a set's technology tree

`tree-viewer.ps1` renders the technology tree of a set of mods as one zoomable HTML page, each
technology coloured by the mod that created it:

    pwsh -File scripts/tree-viewer.ps1 .mod-cache/krastorio2 path/to/my-mod -FocusMod my-mod

It takes the same mod paths as `load-harness.ps1`, loads them the same isolated way, and writes
`tree-viewer-out/tech-tree.html` under the current directory; `-OutName` and `-OutDirectory`
change that. `-FocusMod` names the mods whose items, fluids and entities are paired with
like-named ones of the other mods. It is a probe: exit 0 means it ran and wrote the page, not
that the tree is right. The page loads two libraries from a CDN, so it needs the network to
render. `tree-layout-probe.js` is pasted into the browser console on a rendered page to measure
layout alternatives. `-SelfTest` needs the game. `realistic-fusion-refreshed` still holds its own
copy of all three files, until
[its #676](https://github.com/trulsjo/realistic-fusion-refreshed/issues/676) lands.

## Checking that a mod's prototypes have names

`locale-check.ps1` fails when a prototype of the mods' own would show a player `Unknown key` in
place of its name, or a name or description with an engine error left in it:

    pwsh -File scripts/locale-check.ps1 path/to/my-mod -Prefix my-

It takes the same mod paths as `load-harness.ps1`. `-Prefix` is how it tells the mods' own
prototypes from the game's, so a mod whose prototype names share no prefix cannot use it. It
takes two dumps and creates no map: a pass says nothing about the mod loading, and it does not
read the name of a custom input. `-SelfTest` plants prototypes it must catch, and needs the
game. `realistic-fusion-refreshed` still
holds its own copy, until
[its #677](https://github.com/trulsjo/realistic-fusion-refreshed/issues/677) lands.

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
**Changed 2026-10-12** ([#115](https://github.com/trulsjo/grado-factorio-tools/issues/115)):
that exit told the agent nothing, by the account of grado-factorio-modpack#228, which measured
it that day with Claude Code 2.1.296.

`-SelfTest` proves what is refused and what is not, that the command above reaches the script,
and that it tells the agent where the script is not there. A consumer runs
`-SelfTest -Settings .claude/settings.json` to prove the same of its own wiring: one that
refuses the command in that branch, says nothing, or prints JSON a quote in its message has
broken, fails. What the hook cannot see is in its header.

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
`-SelfTest -Settings .claude/settings.json` runs a consumer's. What the hook cannot see is in
its header: a script or an alias that passes the switch itself and a hook manager turned off
through the environment are two of them.

## Packing mods

`scripts/pack-mods.ps1` builds one zip per mod directory, named `<name>_<version>.zip` from the
mod's own `info.json`, with `info.json` in a single top-level folder — the shape the portal and the
game take.

    pwsh -File scripts/pack-mods.ps1 -OutputDirectory dist my-mod my-mod-graphics

What goes in is what git tracks under each directory, read from the working tree; untracked files
are reported and left out. A version the portal would reject — not `x.y.z`, a component above
65535, or `0.0.0` — is refused, and nothing is written. Any other version's zip of the same mod in
the output directory is deleted, so one copy is left. It uploads nothing. `-SelfTest` proves it
can fail, in a scratch repository of its own.

## Checking Markdown

`scripts/markdown-check.ps1` reads Markdown for three things a machine can decide: emphasis or a
code span left open at the end of its paragraph, a table row whose column count differs from its
header's, and a link to a file git does not track, in exact case. It knows nothing of Factorio.

    pwsh -File scripts/markdown-check.ps1
    pwsh -File scripts/markdown-check.ps1 -Range origin/main...HEAD
    pwsh -File scripts/markdown-check.ps1 -All

With no arguments it reads the staged files as they are staged, which is what a `pre-commit` hook
wants; `-Range` reads the files a range changed, and `-All` every tracked one. With three dots
the files are those the branch at the range's end has changed since it left the base; two dots
would also list each file the base has edited or deleted since then. The check reads the
repository it is run in, so a consumer runs it from the submodule on its own Markdown.
`scripts/check.ps1` runs it here with `-All`. `-SelfTest` proves each of the three can fail. What
it reads as what, and what it cannot see, is in its header.

    pwsh -File scripts/markdown-check.ps1 -All -MaxLineLength 100

Handed `-MaxLineLength`, it also reports a prose line longer than that; without it, it is silent
on length. `scripts/check.ps1` hands it 100 here. Neither sibling is asked to: counted on
2026-10-09 by a throwaway script, `grado-factorio-modpack` had 326 such lines and
`realistic-fusion-refreshed` 3,091.

## Checking a pull request body

`scripts/pr-body-check.ps1` reads a pull request body for commits it cites, and fails on one that
is not on `main`: a rebase-merge rewrites every SHA on a branch, so such a citation names a commit
the merge deletes.

    pwsh -File scripts/pr-body-check.ps1 ../scratch/body.md

It also fails on a closing keyword before an issue reference, such as `fixed` and then a colon
and an issue's number, on any line that is not `Closes #N` alone: GitHub closes that issue when
the pull request merges, whether or not the sentence meant it.

CI runs it on the body of every pull request here, and again when the body is edited. A word that
names no commit in the clone, such as a commit of a sibling, is said to be unchecked and passes.
What else it cannot see is in its header. `-SelfTest` proves it can fail.

## What does not belong here

Anything that encodes one mod's domain. A reactor invariant, a fuel table, a balance figure or a
prototype name is that mod's business. If a script needs to know `rf-`, it stays where it is.

## Layout

```
scripts/     PowerShell entry points, one job each, and the libraries they
             dot-source: load-harness-lib.ps1, game-mods.ps1, mod-info.ps1,
             which reads a mod's info.json for four of them, and
             self-test-halves.ps1, the runner a -SelfTest hands its halves to
.githooks/   this repo's own commit-msg and pre-push hooks, opted into once per
             clone
.claude/     settings.json, which wires the session hook that refuses a commit
             or push skipping those
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
