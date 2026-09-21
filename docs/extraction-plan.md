# Extraction plan

What is earmarked to move here from `realistic-fusion-refreshed`, and how hard each one will be.

**One script has been extracted, and only partly.** `scripts/commit-check.ps1` is here; the
siblings are not yet repointed at it. Everything else below still lives in that repo, works there,
and is covered by its gates. This file is an inventory, and — for whatever has moved — the record
of where it came from.

## Method

Line counts and reference counts measured 2026-09-20 against
`C:/src/factorio/realistic-fusion-refreshed`. "Project references" is
`grep -ci "realistic-fusion\|rf-"` — a crude proxy for entanglement, but it separates *generic with a
hardcoded path* from *generic in name only*. It undercounts: a script can be tied to the project
through an assumed directory layout or an invariant without ever naming it.

## Candidates, least entangled first

| Script | Lines | Project refs | Verdict |
|---|---|---|---|
| ~~`scripts/commit-check.ps1`~~ | 393 | **0** | **Moved 2026-09-21.** See *Extracted* below. |
| `scripts/fetch-mods.ps1` | 1,049 | 3 | **Move, parameterise the three.** Fills a cache directory with third-party mods at pinned versions — git first, portal as fallback. This is half of the coexistence check and the more reusable half. |
| `scripts/pack-mods.ps1` | 322 | 7 | **Move, parameterise.** Builds one distributable zip per mod, named as the portal requires, and enforces the version bounds the portal enforces at upload. The natural home for the upload step that does not exist yet. |
| `scripts/tree-viewer.ps1` + `tree-viewer.template.html` + `tree-layout-probe.js` | 533 + 2 files | 7 | **Move the set.** Renders a mod set's technology tree as a self-contained zoomable HTML viewer. Already takes a mod set rather than assuming one. |
| `scripts/locale-check.ps1` | 391 | — | **Probably move.** Fails if a prototype would show a player something other than its proper name. The rule is general; only the prototype list is local. |
| `scripts/name-check.ps1` | 1,749 | — | **Probably move.** Fails if a repo defines a prototype name that is not its own, or one another mod already claims. General rule, large implementation. |
| `scripts/factorio-lib.ps1` | 1,357 | **22** | **Split, do not move whole.** The shared PowerShell library, and the most entangled file in the list. Needs a real read to separate what is generic from what is RFR's. |
| `scripts/load-check.ps1` | 2,294 | many | **Move the harness, not the file.** Most of it is thirteen RFR-specific invariants that belong to that mod. What is generic is the surrounding machinery: build an isolated mod directory, junction or zip the mods in, create a throwaway map, report which way it loaded. That harness is the other half of the coexistence check. |

## Extracted

**`scripts/commit-check.ps1`** — from `realistic-fusion-refreshed` at
`8a4fb90e370540fa963c127c9bcece8f4fc7be8d`, on 2026-09-21. Transferred byte-identical. No edit was
needed to run it outside its origin repo, which is what "self-contained" was asserting.

Two things measured during the move, both of which correct what this plan and
[issue #1](https://github.com/trulsjo/grado-factorio-tools/issues/1) had said:

- **`grado-factorio-modpack` already held a byte-identical copy**, with its own
  `.githooks/commit-msg`, added in `172848a`. So the duplication this extraction removes is real
  rather than hypothetical. That repo has been gated since `172848a`, its fourth commit — the three
  before it are ungated and all three fail the check.
- **Nothing but the hook depended on it in `realistic-fusion-refreshed`.** `commit-check` is named
  only by `.githooks/commit-msg` and twice in prose in that repo's `CLAUDE.md`. `ship-check.ps1`
  does not call it, so the "a move that breaks `ship-check`" risk below does not apply to this
  script.

**Not finished.** The copies in both siblings stand until each is wired to this repo as a submodule
at `vendor/grado-factorio-tools`.

## What has to be written, not moved

**Mod portal upload.** It does not exist in any repo. `pack-mods.ps1` is explicit in its own header:

> Build one distributable zip per mod, named the way the mod portal requires. […] It uploads nothing
> and it changes no version — the version is read out of the mod.

The portal has a publish API that needs an API key (distinct from the `player-data.json` token
`fetch-mods.ps1` uses for downloads). Writing it means deciding where the key lives and how a release
is gated — neither decided.

## Risks worth naming before anything moves

- **`realistic-fusion-refreshed` is actively developed and its gates depend on these scripts.**
  Extraction is a refactor of a working repo, not a copy. A move that breaks `ship-check` or
  `load-check` costs more than the duplication it removes.
- ~~**There is no dependency mechanism between the repos yet.**~~ **Settled 2026-09-21: a git
  submodule**, per [ADR 0001](adr/0001-siblings-consume-this-repo-as-a-submodule.md). A vendored
  copy was rejected on two grounds: its drift gate would need a network fetch on every commit to
  know it had drifted, and — the heavier one — a copy left behind in a sibling is the thing this
  repo exists to prevent. Cost was what ruled out the published module, not vendoring.
- **Copying is not extracting.** Two copies that drift are worse than one file in the wrong repo.
  Whatever moves should leave nothing behind.
- **The reference counts above are a proxy.** A low count does not prove a script is generic; it
  proves it does not say the project's name.
