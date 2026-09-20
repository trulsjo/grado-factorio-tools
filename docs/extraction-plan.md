# Extraction plan

What is earmarked to move here from `realistic-fusion-refreshed`, and how hard each one will be.

**Nothing has been extracted.** Every script below still lives in that repo, works there, and is
covered by its gates. This file is an inventory, not a record of work done.

## Method

Line counts and reference counts measured 2026-09-20 against
`C:/src/factorio/realistic-fusion-refreshed`. "Project references" is
`grep -ci "realistic-fusion\|rf-"` — a crude proxy for entanglement, but it separates *generic with a
hardcoded path* from *generic in name only*. It undercounts: a script can be tied to the project
through an assumed directory layout or an invariant without ever naming it.

## Candidates, least entangled first

| Script | Lines | Project refs | Verdict |
|---|---|---|---|
| `scripts/commit-check.ps1` | 393 | **0** | **Move as is.** Checks a commit message against Conventional Commits plus gitmoji. Nothing in it knows what the repo contains. Both sibling repos already declare the same convention. |
| `scripts/fetch-mods.ps1` | 1,049 | 3 | **Move, parameterise the three.** Fills a cache directory with third-party mods at pinned versions — git first, portal as fallback. This is half of the coexistence check and the more reusable half. |
| `scripts/pack-mods.ps1` | 322 | 7 | **Move, parameterise.** Builds one distributable zip per mod, named as the portal requires, and enforces the version bounds the portal enforces at upload. The natural home for the upload step that does not exist yet. |
| `scripts/tree-viewer.ps1` + `tree-viewer.template.html` + `tree-layout-probe.js` | 533 + 2 files | 7 | **Move the set.** Renders a mod set's technology tree as a self-contained zoomable HTML viewer. Already takes a mod set rather than assuming one. |
| `scripts/locale-check.ps1` | 391 | — | **Probably move.** Fails if a prototype would show a player something other than its proper name. The rule is general; only the prototype list is local. |
| `scripts/name-check.ps1` | 1,749 | — | **Probably move.** Fails if a repo defines a prototype name that is not its own, or one another mod already claims. General rule, large implementation. |
| `scripts/factorio-lib.ps1` | 1,357 | **22** | **Split, do not move whole.** The shared PowerShell library, and the most entangled file in the list. Needs a real read to separate the generic helpers from the RFR ones. |
| `scripts/load-check.ps1` | 2,294 | many | **Move the harness, not the file.** Most of it is thirteen RFR-specific invariants that belong to that mod. What is generic is the surrounding machinery: build an isolated mod directory, junction or zip the mods in, create a throwaway map, report which way it loaded. That harness is the other half of the coexistence check. |

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
- **There is no dependency mechanism between the repos yet.** A git submodule, a vendored copy, or a
  published module are all different answers with different costs, and none is chosen.
- **Copying is not extracting.** Two copies that drift are worse than one file in the wrong repo.
  Whatever moves should leave nothing behind.
- **The reference counts above are a proxy.** A low count does not prove a script is generic; it
  proves it does not say the project's name.
