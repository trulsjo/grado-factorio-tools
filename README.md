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

**One tool written here from nothing:** `scripts/resolve-modpack.ps1`, below
([#14](https://github.com/trulsjo/grado-factorio-tools/issues/14)).

The commit-message convention this repo and its siblings share is declared in
[docs/commit-convention.md](docs/commit-convention.md).

Nothing is moved out of a working repo until it is agreed — see `CLAUDE.md`.

## What belongs here

Three things, in the order Truls named them:

1. **Coexistence checking** — loading a mod alongside other mod sets and proving they still load.
   Here: `fetch-mods.ps1` fills a cache with third-party mods at pinned versions, git first and the
   portal as fallback, and `load-harness.ps1` loads a set of mods in isolation and says whether it
   loaded. A mod's own invariants stay in its own repository and run on top — see below.
2. **Technology tree viewer** — renders a mod set's tech tree as a self-contained zoomable HTML page.
3. **Mod portal upload** — **does not exist yet, anywhere.** `pack-mods.ps1` builds the zips and says
   so in its own header: *"It uploads nothing and it changes no version."* This repo is where that
   machinery gets written.

Likely to follow, because they are about *a* Factorio mod rather than *this* Factorio mod: the
locale and prototype-name checks, and the parts of the shared PowerShell library that are not
RFR-specific. The commit-message check has already moved — see Status above.

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
            "command": "i=$(cat); case $i in *mod-cache*) printf '%s' \"$i\" | pwsh -NoProfile -File \"$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/refuse-cd-into-mod-cache.ps1\" -Root \"$CLAUDE_PROJECT_DIR\";; esac"
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
call it cannot read. A submodule that is not initialised is the same posture from pwsh itself,
which exits 64 for a script that is not there (measured 2026-10-08, PowerShell 7.6.6).

`-SelfTest` proves what is refused and what is not, and that the command above reaches the
script. A consumer runs `-SelfTest -Settings .claude/settings.json` to prove its own wiring still
does. What the hook cannot see is in its header.

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
    pwsh -File scripts/markdown-check.ps1 -Range origin/main..HEAD
    pwsh -File scripts/markdown-check.ps1 -All

With no arguments it reads the staged files as they are staged, which is what a `pre-commit` hook
wants; `-Range` reads the files a range changed, and `-All` every tracked one. It reads the
repository it is run in, so a consumer runs it from the submodule on its own Markdown.
`scripts/check.ps1` runs it here with `-All`. `-SelfTest` proves each of the three can fail. What
it reads as what, and what it cannot see, is in its header.

## What does not belong here

Anything that encodes one mod's domain. A reactor invariant, a fuel table, a balance figure or a
prototype name is that mod's business. If a script needs to know `rf-`, it stays where it is.

## Layout

```
scripts/     PowerShell entry points, one job each, and the libraries they
             dot-source: load-harness-lib.ps1, game-mods.ps1, and mod-info.ps1,
             which reads a mod's info.json for three of them
.githooks/   this repo's own commit-msg and pre-push hooks, opted into once per
             clone
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
