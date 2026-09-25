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

**Two more are extracted and finished.** `scripts/fetch-mods.ps1` and the load harness are here and
nowhere else: `realistic-fusion-refreshed` deleted its copies and takes both from the submodule.
Everything else named below still lives there, working and gated. See
[docs/extraction-plan.md](docs/extraction-plan.md) for what is earmarked, how entangled each piece
is, what has moved, and what has to be written from nothing.

**One tool written here from nothing:** `scripts/resolve-modpack.ps1`, below.

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

## What does not belong here

Anything that encodes one mod's domain. A reactor invariant, a fuel table, a balance figure or a
prototype name is that mod's business. If a script needs to know `rf-`, it stays where it is.

## Layout

```
scripts/     PowerShell entry points, one job each
.githooks/   this repo's own commit-msg hook, opted into once per clone
docs/        the commit convention, the ADRs, the notes agents read, and the
             extraction record — what moved, from where, and why
CONTEXT.md   the glossary this repo's own prose is held to
LICENSE      MIT; see CLAUDE.md for why this repo's licence is not a sibling's
```

There is no Python here, and nothing is written in anticipation of any. An entry appears above once
it exists.
