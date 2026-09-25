# Extraction plan

What is earmarked to move here from `realistic-fusion-refreshed`, and how hard each one will be.

**One script has been extracted, and that extraction is finished.** `scripts/commit-check.ps1` is
here and nowhere else; both siblings resolve it from this repo as a submodule.

**Two more are extracted, and finished too.** `fetch-mods.ps1` and the load-check harness are here
and nowhere else: `realistic-fusion-refreshed` deleted its copies, reads its pins from a file of
its own, and takes every harness function from this repository's `load-harness-lib.ps1`. See
*Expanded and contracted* below. Everything else still lives in `realistic-fusion-refreshed`.

This file is an inventory, and — for whatever has moved — the record of where it came from.

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
| `scripts/fetch-mods.ps1` | 1,049 | 3 | **Moved 2026-09-24, finished 2026-09-25.** See *Expanded and contracted* below. Fills a cache directory with third-party mods at pinned versions — git first, portal as fallback. This is half of the coexistence check and the more reusable half. |
| `scripts/pack-mods.ps1` | 322 | 7 | **Move, parameterise.** Builds one distributable zip per mod, named as the portal requires, and enforces the version bounds the portal enforces at upload. The natural home for the upload step that does not exist yet. |
| `scripts/tree-viewer.ps1` + `tree-viewer.template.html` + `tree-layout-probe.js` | 533 + 2 files | 7 | **Move the set.** Renders a mod set's technology tree as a self-contained zoomable HTML viewer. Already takes a mod set rather than assuming one. |
| `scripts/locale-check.ps1` | 391 | — | **Probably move.** Fails if a prototype would show a player something other than its proper name. The rule is general; only the prototype list is local. |
| `scripts/name-check.ps1` | 1,749 | — | **Probably move.** Fails if a repo defines a prototype name that is not its own, or one another mod already claims. General rule, large implementation. |
| `scripts/factorio-lib.ps1` | 1,357 | **22** | **Split, do not move whole.** The shared PowerShell library, and the most entangled file in the list. Needs a real read to separate what is generic from what is RFR's. |
| `scripts/load-check.ps1` | 2,294 | many | **Harness moved 2026-09-24, finished 2026-09-25**, as `load-harness.ps1` and `load-harness-lib.ps1`; see below. **Move the harness, not the file.** Most of it is thirteen RFR-specific invariants that belong to that mod. What is generic is the surrounding machinery: build an isolated mod directory, junction or zip the mods in, create a throwaway map, report which way it loaded. That harness is the other half of the coexistence check. |

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

**Both siblings wired, both copies gone.** Each carries this repo as a submodule at
`vendor/grado-factorio-tools`, pinned to a commit it bumps deliberately:

| Consumer | Wired in | Pinned at | Bump commit | On |
|---|---|---|---|---|
| `grado-factorio-modpack` | issue #9 | `5d3c561` → `0e421eb` | `93dd5f3` | `bump-shared-check-convention` |
| `realistic-fusion-refreshed` | issue #4 | `5d3c561` → `0e421eb` | `5f54299` | `bump-shared-check-convention` |

**The bumps are on branches, not on either `main`.** Both siblings landed their wiring through a
pull request and this follows that; until each is merged, a clone of either `main` still resolves
the check at `5d3c561` and still prints the old rejection text. The `Pinned at` column is what the
bump commit sets, not what `main` reads today.

The modpack was wired first on purpose — it is the cheaper consumer to be wrong in, so a failure
there would have been the mechanism rather than the other repository.

**The pin has been exercised, not just installed.** `0e421eb` changed the check's rejection message
here (issue #10) and changes nothing in either sibling until each bumps.

Measured at each bump, 2026-09-22, and **named by commit rather than by `main`**, because `main`
moves and a span written as `-504 main` stops meaning what it meant:

| Consumer | Span | Commits | Rejected |
|---|---|---|---|
| `realistic-fusion-refreshed` | `-504 e7376b8` | 504 | 144 |
| `grado-factorio-modpack` | all of `main` at `45a3042` | 26 | 3 |

Each produced output byte-identical to the same span swept before the bump — the same commits, for
the same named reasons. Neither figure is a change from the 145 that issue #4 records: that
baseline was the 504 ending at `8a4fb90`, a different set. What is compared here is before against
after on one span, which is the only comparison that means anything.

An earlier draft of this paragraph called the first span "the 504 ending at today's `main`". That
was wrong by one commit — `main` had gained the bump itself by then, and `-504 main` now answers
143. The figure was right and the sentence describing it was not, which is this repository's
signature defect and is why the spans above are pinned.

The check each sibling was wired at is byte-identical to the origin copy: `8a4fb90`'s 393 lines and
19,407 bytes, unchanged through `5d3c561`. `0e421eb` is the first commit for which that stops being
true, and it is after both wirings.

**The abandon tripwire never fired.** It was to stop the work if wiring a sibling needed a third
setup step or a change to `commit-check.ps1` itself. Both siblings are two steps per clone, and
both were wired with the check byte-identical to the origin copy. The edit in `0e421eb` came after
the wiring, as its own ticket, which is what keeps the two distinguishable.

## Expanded and contracted

Ruled on [grado-factorio-modpack#16](https://github.com/trulsjo/grado-factorio-modpack/issues/16),
2026-09-24: both halves of the coexistence check move here, harness only for `load-check`. Each is
an expand-contract pair, the shape #3 and #4 were for the commit check. ~~**Two copies exist between
the halves**, which is tolerable only because an open ticket deletes each one.~~ **Contracted,
and no copy is left**: merged into `realistic-fusion-refreshed` on 2026-09-25 — see *The contract
half* at the end of this section.
Nothing in `realistic-fusion-refreshed` was changed by the expand half.

### The expand half

**`scripts/fetch-mods.ps1`** — from `realistic-fusion-refreshed` at
`19e2d9205b31871076f7b508e3837e58fd7beb58` (the file last changed in `e5019a6`; blob `f7a3970`),
on 2026-09-24, [#15](https://github.com/trulsjo/grado-factorio-tools/issues/15).

The three references to that repository were not the three the grep counts — those are the
self-test fixture's name, twice, and its temp prefix, all renamed. They are:

| Was | Is now |
|---|---|
| The pins, as `$MOD_SETS` and `$COMBINED_SETS` inside the script | `-PinFile`, a `.psd1` of `Sets`, optional `Lanes` and optional `Default` |
| `-Set` defaulting to `krastorio2` | the pin file's `Default` |
| The cache under the script's parent directory, which in a submodule is `vendor/` | `.mod-cache/<set>` under the current directory |

**The pins were the entanglement the proxy missed**: eleven sets and five lanes of one mod's version
decisions, naming the project nowhere. The format did not have to be invented — each entry keeps
the shape it had, and a `.psd1` takes the two hashtable literals verbatim, comments included.
Measured: both literals lifted from `19e2d92` by AST into a `.psd1` resolve all seventeen —
those sixteen and the old self-test fixture — identically through `-PinFile`, and `-SelfTest -PinFile` certifies that file's five lanes the
way the old self-test certified its own. So #456 is a file move plus call sites. The self-test
now brings a fixture manifest of its own, which is the one change to its first half; the credential
path, `Protect-Token`, the `$Error` scrub and the sha1 checks are unchanged, halves 2 to 6 assert
what they did — their child runs are only handed the fixture's `-PinFile` — and all six pass.
`resolve-modpack.ps1` writes this format, and the chain runs with no glue: resolved, fetched and
loaded on 2026-09-24, `Grado_NonChanging`'s 28 mods at 2.0.77 load and create a map.

**`scripts/load-harness.ps1` and `scripts/load-harness-lib.ps1`** — from `realistic-fusion-refreshed`
at the same `19e2d92`: `load-check.ps1` (blob `ddf0672`, last changed `c3758f7`) and
`factorio-lib.ps1` (blob `e7da675`, last changed `463aa6e`), on 2026-09-24,
[#16](https://github.com/trulsjo/grado-factorio-tools/issues/16).

Taken from `factorio-lib.ps1` with names and code kept, and some doc comments trimmed to what is true outside that repository: `Resolve-FactorioExe`,
`Get-FactorioDataDirectory`, `ConvertTo-NativeArgument`, `Invoke-Factorio`, `Write-FactorioTail`,
`Remove-TempDirectory`, `Get-BundledMods`, `Resolve-BundledSelection`, `Write-ModList`,
`Remove-ModJunctions`. `New-ModJunctions` takes a map of link name to source rather than a repo
root and a list, because a harness does not know where the mods came from. The rest of that
library did not move.

From `load-check.ps1`, the shape rather than the code: an isolated mod directory under temp, the
mods junctioned or zipped in, a throwaway map, "exit 0 but no save" as a failure, and a
`--dump-data` whose path is deleted first and whose copy is kept aside. Those are now
`New-LoadHarness`, `Invoke-HarnessLoad`, `Invoke-HarnessDump` and `Remove-LoadHarness`, which a
consumer dot-sources to run its own checks; `load-harness.ps1` is the same as a command, with
`-Check` for a caller with one script to run. **Nothing of Realistic Fusion's own came across**:
not the invariants (`check_prototypes()` runs them inside the game, on the map the harness creates), not the
asset, containment, render or mockup gates, and not `Find-MissingAssets`, which is generic but a
check rather than harness and is a candidate of its own.

### The contract half

All of it landed in `realistic-fusion-refreshed` through
[PR #465](https://github.com/trulsjo/realistic-fusion-refreshed/pull/465), rebase-merged on
2026-09-25, which put that repository's `main` at `5671460`. It superseded
[PR #464](https://github.com/trulsjo/realistic-fusion-refreshed/pull/464), which held only the first
two commits, under other hashes, and was closed unmerged. The measurements are the commits' own, and
the PR's; none was re-run here.

| Consumer commit | Ticket | What it did |
|---|---|---|
| `84db1b6` | [#456](https://github.com/trulsjo/realistic-fusion-refreshed/issues/456) | bumped `vendor/grado-factorio-tools` `0e421eb` → `99d4b57`; deleted `scripts/fetch-mods.ps1`; the two pin literals moved, comments included, into `scripts/mod-sets.psd1` |
| `7b6e51e` | [#457](https://github.com/trulsjo/realistic-fusion-refreshed/issues/457) | `load-check.ps1` loads and dumps through `load-harness-lib.ps1`; its temp and mod directory, `Invoke-LoadCheck`, `Invoke-DataDump` and the junction and zip-copy code deleted |
| `42629a2` | [#458](https://github.com/trulsjo/realistic-fusion-refreshed/issues/458) | `factorio-lib.ps1` dot-sources the harness and deletes its copies of the ten functions whose code matched it |
| `27d915e`, `d2598d2`, `f4cbb25` | [#459](https://github.com/trulsjo/realistic-fusion-refreshed/issues/459)–[#461](https://github.com/trulsjo/realistic-fusion-refreshed/issues/461) | every `New-ModJunctions` call site — 13 rigs, 22 in 17 probes, 14 elsewhere — moved to the harness's `-Links` form |
| `8aece32` | [#462](https://github.com/trulsjo/realistic-fusion-refreshed/issues/462) | deleted `factorio-lib.ps1`'s own `New-ModJunctions` |

Four fixes followed on the same PR: `e037275` (#463, a bad `-With` refused before any zip is
built, as before #457), and `181f9c5`, `bf001d9` and `5671460` from its reviews — one of them a
regression #458 introduced, where `ship-check -SelfTest`'s runner canary copied `factorio-lib.ps1`
to `%TEMP%` and could no longer find the submodule from there.

**The fetcher.** Measured at `84db1b6`: all 16 sets and lanes resolve to the same names, versions,
git URLs and tags from the old literals and from `mod-sets.psd1`; fresh fills of `fluid`, `riteg`
and `krastorio2` by the old and new fetchers are byte-identical — 2,903 files outside `.git`, the
same five git HEADs; and `-SelfTest -PinFile scripts/mod-sets.psd1` passes. Sixteen, not the
seventeen measured here at the expand half: the old self-test fixture set was dropped from the pin
file, because the shared self-test brings its own.

**The harness.** Measured across `7b6e51e`: one full run of 20 lanes before and after — plain,
`-With space-age`, `-FromZips`, `-SelfTest`, `-SelfTest -FromZips`, and `-AlsoModDirectory` over
all 14 cached sets plus seablock `-With quality` — gives the same exit code on every lane, 12 pass
and 8 fail, and each red lane fails with the same first FAILED line and the same missing-asset
list. The invariants' self-test halves and the asset, containment, render, socket and mockup gates
stayed there, as ruled. By design, a failed `--dump-data` now throws (exit 1) rather than exiting
with Factorio's code; the verdict is the same.

**Nothing is left duplicated.** Checked here against that repository's `main` at `5671460`: none of
the eleven functions taken from `factorio-lib.ps1` is defined anywhere under its `scripts/`, which
now dot-sources `load-harness-lib.ps1` from the submodule, and `scripts/fetch-mods.ps1` is gone.
`8aece32` states the wider check, by parsing: none of the 17 functions `load-harness-lib.ps1`
defines is defined under `scripts/` or `tools/` there. One consequence is recorded in PR #465:
every script there that loads `factorio-lib.ps1` — `ship-check.ps1` and `pack-mods.ps1` included,
which start no game — now needs the submodule initialised.
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
