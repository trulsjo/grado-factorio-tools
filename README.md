# grado-factorio-tools

Shared tooling for the Factorio mod projects — the scripts that are not about any one mod and should
not be maintained twice.

Siblings that will consume it:

- [realistic-fusion-refreshed](https://github.com/trulsjo/realistic-fusion-refreshed) — where most of
  this tooling was written and still lives
- [grado-factorio-modpack](https://github.com/trulsjo/grado-factorio-modpack)

## Status

**Empty skeleton.** Nothing has been extracted yet. The tools named below still live in
`realistic-fusion-refreshed` and are still that repo's, working and gated. See
[docs/extraction-plan.md](docs/extraction-plan.md) for what is earmarked, how entangled each piece is,
and what has to be written from nothing.

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

Likely to follow, because they are about *a* Factorio mod rather than *this* Factorio mod: the commit
message checker, the locale and prototype-name checks, and the parts of the PowerShell helper library
that are not RFR-specific.

## What does not belong here

Anything that encodes one mod's domain. A reactor invariant, a fuel table, a balance figure or a
prototype name is that mod's business. If a script needs to know `rf-`, it stays where it is.

## Layout

```
scripts/     PowerShell entry points, one job each
tools/       Python helpers
docs/        what was extracted, from where, and why
```
