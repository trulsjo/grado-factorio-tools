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
holding a copy. No copy of it remains anywhere. Everything else named below still lives in
`realistic-fusion-refreshed` and is still that repo's, working and gated. See
[docs/extraction-plan.md](docs/extraction-plan.md) for what is earmarked, how entangled each piece
is, what has moved, and what has to be written from nothing.

The commit-message convention this repo and its siblings share is declared in
[docs/commit-convention.md](docs/commit-convention.md).

Nothing is moved out of a working repo until it is agreed — see `CLAUDE.md`.

## What belongs here

Three things, in the order Truls named them:

1. **Coexistence checking** — loading a mod alongside other mod sets and proving they still load.
   In `realistic-fusion-refreshed` this is `load-check.ps1 -AlsoModDirectory` plus `fetch-mods.ps1`,
   which fills a cache with third-party mods at pinned versions, git first and the portal as fallback.
2. **Technology tree viewer** — renders a mod set's tech tree as a self-contained zoomable HTML page.
3. **Mod portal upload** — **does not exist yet, anywhere.** `pack-mods.ps1` builds the zips and says
   so in its own header: *"It uploads nothing and it changes no version."* This repo is where that
   machinery gets written.

Likely to follow, because they are about *a* Factorio mod rather than *this* Factorio mod: the
locale and prototype-name checks, and the parts of the shared PowerShell library that are not
RFR-specific. The commit-message check has already moved — see Status above.

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
