# Extraction plan

What is earmarked to move here from `realistic-fusion-refreshed`, and how hard each one will be.
Since 2026-10-08 three scripts of `grado-factorio-modpack` are ruled to move too: see *From the
modpack* below.

**One script has been extracted, and that extraction is finished.** `scripts/commit-check.ps1` is
here and nowhere else; both siblings resolve it from this repo as a submodule.

**Two more are extracted, and finished too.** `fetch-mods.ps1` and the load-check harness are here
and nowhere else: `realistic-fusion-refreshed` deleted its copies, reads its pins from a file of
its own, and takes every harness function from this repository's `load-harness-lib.ps1`. See
*Expanded and contracted* below.

**So is a fourth.** `pack-mods.ps1` is here and nowhere else: `realistic-fusion-refreshed`
deleted its copy and `grado-factorio-modpack` deleted `Publish-PackZip`, its own zipper, and both
pack through this repository's. See *The packer, expanded and contracted* below. Everything else
in the table below still lives in `realistic-fusion-refreshed`.

This file is an inventory, and — for whatever has moved — the record of where it came from.

## Method

Line counts and reference counts measured 2026-09-20 against
`C:/src/factorio/realistic-fusion-refreshed`. "Project references" is
`grep -ci "realistic-fusion\|rf-"` — a crude proxy for entanglement, but it separates *generic with
a hardcoded path* from *generic in name only*. It undercounts: a script can be tied to the project
through an assumed directory layout or an invariant without ever naming it.

## Candidates, least entangled first

| Script | Lines | Project refs | Verdict |
|---|---|---|---|
| ~~`scripts/commit-check.ps1`~~ | 393 | **0** | **Moved 2026-09-21.** See *Extracted* below. |
| ~~`scripts/fetch-mods.ps1`~~ | 1,049 | 3 | **Expanded 2026-09-24, contracted 2026-09-25.** See *Expanded and contracted* below. Fills a cache directory with third-party mods at pinned versions — git first, portal as fallback. This is half of the coexistence check and the more reusable half. |
| ~~`scripts/pack-mods.ps1`~~ | 322 | 7 | **Moved 2026-09-28: expanded 2026-09-25, contracted 2026-09-28.** See *The packer, expanded and contracted* below. Builds one distributable zip per mod, named as the portal requires, and enforces the version bounds the portal enforces at upload. The natural home for the upload step that does not exist yet. |
| `scripts/tree-viewer.ps1` + `tree-viewer.template.html` + `tree-layout-probe.js` | 533 + 2 files | 7 | **Move the set.** Renders a mod set's technology tree as a self-contained zoomable HTML viewer. Already takes a mod set rather than assuming one. |
| `scripts/locale-check.ps1` | 391 | — | **Probably move.** Fails if a prototype would show a player something other than its proper name. The rule is general; only the prototype list is local. |
| `scripts/name-check.ps1` | 1,749 | — | **Probably move.** Fails if a repo defines a prototype name that is not its own, or one another mod already claims. General rule, large implementation. |
| `scripts/factorio-lib.ps1` | 1,357 | **22** | **Split, do not move whole.** The shared PowerShell library, and the most entangled file in the list. Needs a real read to separate what is generic from what is RFR's. |
| `scripts/load-check.ps1` | 2,294 | many | **Harness expanded 2026-09-24, contracted 2026-09-25**, as `load-harness.ps1` and `load-harness-lib.ps1`; see below. **Move the harness, not the file.** Most of it is thirteen RFR-specific invariants that belong to that mod. What is generic is the surrounding machinery: build an isolated mod directory, junction or zip the mods in, create a throwaway map, report which way it loaded. That harness is the other half of the coexistence check. |

## Extracted

This section is the commit check's. The three extracted since each have one of their own, with
origin and pins: `fetch-mods.ps1` and the harness under *Expanded and contracted*, and
`pack-mods.ps1` — from `realistic-fusion-refreshed` `5671460`, pinned at `fc322ff` there and
`d09fba3` in the modpack — under *The packer, expanded and contracted*.

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

~~**The bumps are on branches, not on either `main`.** Both siblings landed their wiring through a
pull request and this follows that; until each is merged, a clone of either `main` still resolves
the check at `5d3c561` and still prints the old rejection text.~~ **Both merged 2026-09-22**, as
`realistic-fusion-refreshed` `7567254` and `grado-factorio-modpack` `828ce4b`. The `Pinned at`
column is what those bumps set, not what either `main` reads today. ~~**Both now pin `99d4b57`**,
moved by `grado-factorio-modpack` `ad9ead7` on 2026-09-24 and by `realistic-fusion-refreshed`
`84db1b6`, on that repository's `main` since PR #465 was merged on 2026-09-25 (see *The contract
half* of *Expanded and contracted*).~~ **The pins differ since 2026-09-28:** each consumer moved off
`99d4b57` to take the packer, `realistic-fusion-refreshed` to `fc322ff` and `grado-factorio-modpack`
to `d09fba3` — see *The packer, expanded and contracted*.

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
those sixteen and the old self-test fixture — identically through `-PinFile`, and
`-SelfTest -PinFile` certifies that file's five lanes the way the old self-test certified its own.
So #456 is a file move plus call sites. The self-test now brings a fixture manifest of its own,
which is the one change to its first half; the credential path, `Protect-Token`, the `$Error` scrub
and the sha1 checks are unchanged, halves 2 to 6 assert what they did — their child runs are only
handed the fixture's `-PinFile` — and all six pass. `resolve-modpack.ps1` writes this format, and
the chain runs with no glue: resolved, fetched and loaded on 2026-09-24, `Grado_NonChanging`'s 28
mods at 2.0.77 load and create a map.

**`scripts/load-harness.ps1` and `scripts/load-harness-lib.ps1`** — from
`realistic-fusion-refreshed` at the same `19e2d92`: `load-check.ps1` (blob `ddf0672`, last changed
`c3758f7`) and `factorio-lib.ps1` (blob `e7da675`, last changed `463aa6e`), on 2026-09-24,
[#16](https://github.com/trulsjo/grado-factorio-tools/issues/16).

Taken from `factorio-lib.ps1` with names and code kept, and some doc comments trimmed to what is
true outside that repository: `Resolve-FactorioExe`, `Get-FactorioDataDirectory`,
`ConvertTo-NativeArgument`, `Invoke-Factorio`, `Write-FactorioTail`, `Remove-TempDirectory`,
`Get-BundledMods`, `Resolve-BundledSelection`, `Write-ModList`, `Remove-ModJunctions`.
`New-ModJunctions` takes a map of link name to source rather than a repo root and a list, because a
harness does not know where the mods came from. The rest of that library did not move.

From `load-check.ps1`, the shape rather than the code: an isolated mod directory under temp, the
mods junctioned or zipped in, a throwaway map, "exit 0 but no save" as a failure, and a
`--dump-data` whose path is deleted first and whose copy is kept aside. Those are now
`New-LoadHarness`, `Invoke-HarnessLoad`, `Invoke-HarnessDump` and `Remove-LoadHarness`, which a
consumer dot-sources to run its own checks; `load-harness.ps1` is the same as a command, with
`-Check` for a caller with one script to run. **Nothing of Realistic Fusion's own came across**:
not the invariants (`check_prototypes()` runs them inside the game, on the map the harness creates),
not the asset, containment, render, socket or mockup gates, and not `Find-MissingAssets`, which is
generic but a check rather than harness and is a candidate of its own.

### The contract half

All of it landed in `realistic-fusion-refreshed` through
[PR #465](https://github.com/trulsjo/realistic-fusion-refreshed/pull/465), rebase-merged on
2026-09-25, which put that repository's `main` at `5671460`. It superseded
[PR #464](https://github.com/trulsjo/realistic-fusion-refreshed/pull/464), which held only the first
two commits, under their pre-rebase hashes, and was closed unmerged. The measurements are the
commits' own, and the PR's, and none was re-run here; the one check made here is the last
paragraph's, that no copy is left.

| Consumer commit | Ticket | What it did |
|---|---|---|
| `84db1b6` | [#456](https://github.com/trulsjo/realistic-fusion-refreshed/issues/456) | bumped `vendor/grado-factorio-tools` `0e421eb` → `99d4b57`; deleted `scripts/fetch-mods.ps1`; the two pin literals moved, comments included, into `scripts/mod-sets.psd1` |
| `7b6e51e` | [#457](https://github.com/trulsjo/realistic-fusion-refreshed/issues/457) | `load-check.ps1` loads and dumps through `load-harness-lib.ps1`; its temp and mod directory, `Invoke-LoadCheck`, `Invoke-DataDump` and the junction and zip-copy code deleted |
| `42629a2` | [#458](https://github.com/trulsjo/realistic-fusion-refreshed/issues/458) | `factorio-lib.ps1` dot-sources the harness and deletes its copies of the ten functions whose code matched it |
| `27d915e`, `d2598d2`, `f4cbb25` | [#459](https://github.com/trulsjo/realistic-fusion-refreshed/issues/459)–[#461](https://github.com/trulsjo/realistic-fusion-refreshed/issues/461) | every `New-ModJunctions` call site — 13 rigs, 22 in 17 probes, 14 elsewhere — moved to the harness's `-Links` form |
| `8aece32` | [#462](https://github.com/trulsjo/realistic-fusion-refreshed/issues/462) | deleted `factorio-lib.ps1`'s own `New-ModJunctions` |

Four fixes followed on the same PR: `e037275` (#463, a bad `-With` refused before any zip is
built, as before #457); `181f9c5` and `5671460` from its reviews; and `bf001d9`, which a full sweep
of the gates caught — a regression #458 introduced, where `ship-check -SelfTest`'s runner canary
copied `factorio-lib.ps1` to `%TEMP%` and could no longer find the submodule from there.

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

## The packer, expanded and contracted

**`scripts/pack-mods.ps1`**, from `realistic-fusion-refreshed` at `5671460`; now pinned by that
repository at `fc322ff` and by `grado-factorio-modpack` at `d09fba3`.

Called *Expanded, not yet contracted* until 2026-09-28 (UTC), when the second
consumer's rewire merged. **No copy is left**: see *The contract half* at the end of this section.

### The expand half

**`scripts/pack-mods.ps1`** — from `realistic-fusion-refreshed` at
`5671460c05c6c38d5895b6d4d04edc9cc75e1709` (the file last changed in `0b40a22`; blob `efb098a`),
on 2026-09-25, [#19](https://github.com/trulsjo/grado-factorio-tools/issues/19). Issue #19 names
that repository's HEAD as `2e7b034` when it was filed. That commit is on branch `pr-465` only; it
is the pre-rebase form of `bf001d9`, which is on `main`. The file is blob `efb098a` at all three.

**Why now:** `grado-factorio-modpack` grew a second, weaker zipper — `stage-pack.ps1`'s
`Publish-PackZip` (grado-factorio-modpack#24, PR #56), which packed every file under the pack
directory and checked only `x.y.z`. ~~So three zippers stand — the origin, `Publish-PackZip` and
this one — until both rewires land.~~ **One stands since 2026-09-28**: both rewires landed and
deleted the other two.

Of the seven references the grep counts, all seven are the self-test — its temp prefix, one comment,
and five uses of `realistic-fusion-refreshed-core` as the fixture. The entanglement it missed is
the layout, as the method section warns:

| Was | Is now |
|---|---|
| The mods, from `factorio-lib.ps1`'s `Get-RepoMods` | the mod directories, as trailing arguments |
| Paths relative to the script's parent directory | each directory's own git work tree, so the mods need not share one |
| `-OutputDirectory` defaulting to `dist/` in that repository | required |
| The self-test packing that repository's three mods, with the plant in `realistic-fusion-refreshed-core/prototypes/.omc` | a scratch git repository of fixture mods; the planted-file half kept, the plant still under an ignored `.omc/` |
| A closing hint to run `load-check.ps1 -FromZips` | dropped |

**One behaviour changed, as #19 asked: one copy per mod.** The origin replaces only a zip of the
same name and version, so a version bump left the old zip beside the new. Here, once a mod's new zip
is in place, every other `<name>_<x.y.z>.zip` of it in the output directory is deleted; a mod whose
name only contains this one stays, and so does anything that is not a zip. That is narrower than
`Publish-PackZip`, which also removed `<name>_<x.y.z>` and `<name>` directories — ~~the modpack's
rewire has to decide whether it still needs that~~ **it does** (`dc63a87`): `stage-pack` still
removes those directories itself, and leaves the zips to the packer. The rewire changes one more
thing: the folder inside the zip is `<name>/`, as the origin's is, where `Publish-PackZip` wrote
`<name>_<version>/`.
The portal and the game take either. Two refusals are new too: the same mod given
twice, and a directory outside any git work tree. And every manifest is now read before any zip is
written, so a refused mod stops the run with nothing packed, where the origin had already packed
every mod before it.

**The name check is case-sensitive since
[#23](https://github.com/trulsjo/grado-factorio-tools/issues/23), 2026-09-26.** The origin refuses
a mod directory whose name is not its `info.json` `name`, and compares without regard to case; the
first extraction kept that, while its new one-copy rule matched case-sensitively. So `Alpha`
holding `alpha` was packed and left `alpha_*.zip` beside an earlier `Alpha_*.zip`. Factorio 2.0.77
and the mod portal both treat mod names as case-sensitive — measured, and recorded in the script's
header — so both halves now do too: that directory is refused, and `Alpha_*.zip` is another mod's
zip, left alone at any other version. `-SelfTest` now passes 15 cases; the new one turns red under
each of three mutations — the name check made case-insensitive, the one-copy rule made
case-insensitive, and the directory's name read from the path as typed rather than from disk. That
last one is measured on Windows and is only reachable on a case-insensitive file system, since the
case passes the wrong-case path only where it resolves; elsewhere the case cannot see it.

**Measured, 2026-09-25**, against `realistic-fusion-refreshed` at `5671460`: the three mods packed
by the origin and by this script give the same entries, the same sizes and the same CRC-32s — 41,
20 and 178, 239 in all. `-SelfTest` passed 14 cases (15 since #23, above), and each of eight
mutations to the script turns at least one red: packing the untracked and ignored set, dropping
the 65535 bound, dropping the 0.0.0 bound, dropping the one-copy removal, unanchoring its pattern,
dropping the duplicate guard, dropping the up-front missing-file guard, and leaving a relative
output directory unresolved. PR #22's record gives the count and names none of them, so the
source is a re-run: on 2026-09-28 each of the eight was applied to the script as PR #22 merged it
(`bb8991c`), and each turned at least one of its 14 cases red
([#25](https://github.com/trulsjo/grado-factorio-tools/issues/25)).

### The contract half

~~**Contract half, not started.**~~ Each consumer adopted it in a ticket of its own, through a pull
request that was rebase-merged. The measurements are the commits' own and none was re-run here;
the one check made here is the last paragraph's, that no copy is left.

| Consumer | Ticket | Merged | Commit | Pin | What it did |
|---|---|---|---|---|---|
| `realistic-fusion-refreshed` | [#466](https://github.com/trulsjo/realistic-fusion-refreshed/issues/466) | [PR #471](https://github.com/trulsjo/realistic-fusion-refreshed/pull/471), 2026-09-28 18:22 UTC | `69f36a2` | `99d4b57` → `fc322ff` | deleted `scripts/pack-mods.ps1`; `load-check.ps1 -FromZips` passes its three mod directories to the shared packer |
| `grado-factorio-modpack` | [#64](https://github.com/trulsjo/grado-factorio-modpack/issues/64) | [PR #67](https://github.com/trulsjo/grado-factorio-modpack/pull/67), 2026-09-28 22:19 UTC | `dc63a87`, and `5c89815` from its review | `99d4b57` → `d09fba3` | deleted `Publish-PackZip`; `stage-pack.ps1` zips a pack and every pack under it in one call to the shared packer |

**`realistic-fusion-refreshed`**, measured in `69f36a2`: before its copy was deleted, the old and
shared packers gave the same three zips at `5671460`, with the same top-level folder and the same
239 entries by name, size and CRC-32. On 2026-09-28, against Factorio 2.0.77 build 84539,
`load-check.ps1 -FromZips` loaded all three mods, `-SelfTest -FromZips` passed, and `ship-check.ps1`
ran 210 checks with no failure.

**`grado-factorio-modpack`**, measured in `dc63a87`: a stage of `Grado_NonChanging` loaded through
the load harness on 2.0.77 on 2026-09-28, base only — 29 mods validated, a map created — and the
`stage-pack` self-test passed 13 of 13. No `info.json` was modified. `5c89815` widened that
self-test to stage a two-pack chain, as a real stage does.

**The two pins differ since 2026-09-28.** `fc322ff` is where PR #22 (#19) merged; `d09fba3`
carries #23's fix, `607ceef`, so `realistic-fusion-refreshed` packs with the name check that ignores
case, and the modpack with the one that does not. Both are this file, at two commits, which is what
a pin is for — not a copy. Moving `realistic-fusion-refreshed` onto #23 is a bump of its own, and
its decision.

**Nothing is left duplicated.** Checked here on 2026-09-29, against `realistic-fusion-refreshed`
`main` at `433cc4b` and `grado-factorio-modpack` `main` at `5c89815`: `scripts/pack-mods.ps1` is
gone from the first, `Publish-PackZip` is defined nowhere in the second, and outside `vendor/`
neither writes a zip. The only zip code left in either reads or unpacks one: `bench-reactors.ps1`
and `load-check.ps1 -FromZips` there, and `stage-pack`'s self-test in the modpack.

## From the modpack

**Ruled by Truls on 2026-10-08, on
[#73](https://github.com/trulsjo/grado-factorio-tools/issues/73): all three move.** ~~Nothing has
moved yet.~~ **All three are expanded, 2026-10-08, and none is contracted:** two copies of each
stand until its contraction ticket lands. `grado-factorio-modpack` wrote the three in its PR #170,
merged 2026-10-06, because their tickets were there. Each move is an expand-contract pair, a ticket
here and one in the modpack, so no copy is left behind. ~~The order of the three is not ruled.~~
Ruled the same day: #74, #75, #76.

| Script in `grado-factorio-modpack` | Lines | Last changed | Blob | Move | Contraction |
|---|---|---|---|---|---|
| `scripts/markdown-check.ps1` | 380 | `fa61c15` | `a2d8ff8` | [#74](https://github.com/trulsjo/grado-factorio-tools/issues/74) | [grado-factorio-modpack#182](https://github.com/trulsjo/grado-factorio-modpack/issues/182) |
| `scripts/get-dump.ps1`, the dump cache | 272 | `d6157a9` | `bf96c8c` | [#75](https://github.com/trulsjo/grado-factorio-tools/issues/75) | [grado-factorio-modpack#183](https://github.com/trulsjo/grado-factorio-modpack/issues/183) |
| `scripts/refuse-cd-into-mod-cache.ps1`, the hook | 189 | `d6157a9` | `7e5d07a` | [#76](https://github.com/trulsjo/grado-factorio-tools/issues/76) | [grado-factorio-modpack#184](https://github.com/trulsjo/grado-factorio-modpack/issues/184) |

Measured 2026-10-08 against that repository's `main` at `4cc5805`, and read from each file, not
counted by grep:

- **The Markdown check** names nothing of the modpack or of Factorio in its code, and finds the
  repository through git. Its header and one comment cite modpack pages. Run with `-All` here at
  `ac96493` it read 13 files and found nothing; in `realistic-fusion-refreshed` at `c608044` it
  found 6 things in 109 files, all under `docs/research/`. It overlaps `check.ps1`'s relative-link
  check, which asks the disk and not git; ~~#74 has to say whether both stay~~ #74 replaced it,
  below. No existing linter
  replaces it: grado-factorio-modpack#174, closed 2026-10-07.
- **The dump cache** takes the repository root from its own path, which in a submodule is
  `vendor/grado-factorio-tools`, and knows `.mod-cache/<Pack>`, `.dump-cache` and `stage-pack.ps1`.
  All of it becomes parameters or is dropped. No gate calls it there, and the modpack is its one
  consumer: `realistic-fusion-refreshed` dumps through its own `load-check.ps1` and does not call
  it.
- **The hook** takes the root the same way and holds `.mod-cache` as a literal. Its self-test
  reads the consumer's `.claude/settings.json`, which a submodule cannot supply, so the wiring
  stays with each consumer. `realistic-fusion-refreshed` ignores `.claude/*` and could not wire
  it from a tracked file as it stands.

~~None of the three has a commit scope here yet, and `CLAUDE.md`, which lists the scopes, is at
3,998 of the 4,000 bytes `check.ps1` allows it.~~ Each gets its scope as it moves; `CLAUDE.md`
lost its opening sentence, which the README's first line says, to make the room.

### The Markdown check, the expand half

**`scripts/markdown-check.ps1`** — from `grado-factorio-modpack` at
`4cc5805e35f42223ff3550a03fd67943b26b6349` (the file last changed in `fa61c15`; blob `a2d8ff8`), on
2026-10-08, [#74](https://github.com/trulsjo/grado-factorio-tools/issues/74). The modpack's copy and
its `pre-commit` hook are untouched; grado-factorio-modpack#182 deletes the one and rewires the
other.

No line of code changed but the closing message, which named the script by the path it had there.
The header and one comment named two of the modpack's pages and its hook file, and now name none
of the three. The header also gained two sentences: that the script reads the repository it is
run in, from its root, and that `check.ps1` here runs it with `-All`.
`-SelfTest` passes the 13 cases it passed there.

**Changed 2026-10-09: the code now differs from the origin's**
([#83](https://github.com/trulsjo/grado-factorio-tools/issues/83)). Run from a directory below the
root, the copy that moved misreported links that resolve, and with `-All` threw at the first file:
`git ls-files` and `git ls-tree` answer for the current directory, and `git show` reads from the
root. Every git call that lists or reads a file now runs from the root, which one `git rev-parse`
finds, so each mode says below the root what it says at it, and `-SelfTest` has a fourteenth
case for it. The modpack's copy is as it was, and stays so until grado-factorio-modpack#182
deletes it: its `pre-commit` hook runs at the root, where the two copies say the same. The
header no longer says the script has to be run at the root.

**Changed again 2026-10-09: an opt-in length limit**
([#93](https://github.com/trulsjo/grado-factorio-tools/issues/93)). Handed `-MaxLineLength`, the
check here also reports a prose line longer than that; handed none, it reports what it did
before, so the modpack's `pre-commit` hook, which hands it none, would see no difference from
this change. `check.ps1` here hands it 100. The modpack's copy has no such parameter, and the two
copies now differ by this as well until grado-factorio-modpack#182.

**Changed 2026-10-10: the length rule asks PowerShell's parser what is code**
([#95](https://github.com/trulsjo/grado-factorio-tools/issues/95)). Which lines are an indented
code block, and so not held to the limit, is now read from `ConvertFrom-Markdown` and no longer
worked out by the script from lists, blank lines and rules. The parser is asked only when a limit
is handed in, so the modpack's hook, which hands it none, would see no difference from this
change either. The modpack's copy has the old tracking, so the two copies differ by this as well
until grado-factorio-modpack#182. The header names the shapes found where the parser and GitHub's
renderer disagree about code, and `docs/measurements.md` has the run.

**`check.ps1`'s own relative-link check is replaced by it, not kept beside it.** `check.ps1` now
runs the Markdown check with `-All`. What that changes for this repository's Markdown:

| | The old link check | Now |
|---|---|---|
| A link's target is asked of | the disk | git, in exact case |
| A `[label]: path` line | not read | read |
| A link from the repository root, `/docs/x.md` | failed, as misread | resolved |
| Emphasis or a code span left open, a ragged table row | not looked for | reported |
| The Markdown is read from | the working tree | the index, so an unstaged edit is not seen |

Run on this repository at `145b221` it reads 13 files and finds nothing, and a file staged with a
dead link and an open `*` turned `check.ps1` red with both named.

### The dump cache, the expand half

**`scripts/get-dump.ps1`** — from `grado-factorio-modpack` at
`4cc5805e35f42223ff3550a03fd67943b26b6349` (the file last changed in `d6157a9`; blob `bf96c8c`),
on 2026-10-08, [#75](https://github.com/trulsjo/grado-factorio-tools/issues/75). The modpack's
copy is untouched; grado-factorio-modpack#183 deletes its caching.

| Was | Is now |
|---|---|
| A pack name, read as `.mod-cache/<Pack>` under the repository root | `-Mods`, a directory of mods, as the first argument |
| The repository root, as the parent of the script's own directory | not read |
| The harness library under `vendor/grado-factorio-tools/scripts/` | beside the script |
| The cache defaulting to `.dump-cache` under the repository root | `-CacheDirectory`, defaulting to `.dump-cache` under the current directory, as `fetch-mods.ps1`'s cache does |
| A dump named for the pack | named for the last part of the mod directory's path, which for `.mod-cache/<Pack>` is the same name |
| A hint to run `stage-pack.ps1` when the pack is not staged | dropped; a directory that is not there is refused |

`Get-PackDump` is `Get-CachedDump` and its `-Pack` is `-Name`. The lines that build the key did
not change. It takes the `coexistence` scope and none of its own.

**Measured 2026-10-08** against Factorio 2.0.77 (build 84539), on the modpack's staged
`.mod-cache/Grado_NonChanging`, 29 mods: a first request made a dump in 14 seconds, a second was
served from the cache with nothing run, and the 1,625 files under the mod directory were the same
1,625 after. The modpack's copy at `4cc5805`, run with the harness library its pin `d251481`
carries, was then asked for the same set against that cache and was served the dump this script
made: the two write the same key. The run is in [measurements.md](measurements.md). `-SelfTest`
passes the 11 cases it passed there.

One thing the modpack's contraction has to know: its own `.dump-cache` held one dump of
`Grado_NonChanging`, made 2026-10-07, and it was not served, because the pack's zip had been
staged again since at another size, 2,892 bytes against 677. That is the key working, not the
move.

### The hook, the expand half

**`scripts/refuse-cd-into-mod-cache.ps1`** — from `grado-factorio-modpack` at
`4cc5805e35f42223ff3550a03fd67943b26b6349` (the file last changed in `d6157a9`; blob `7e5d07a`),
on 2026-10-08, [#76](https://github.com/trulsjo/grado-factorio-tools/issues/76). The modpack's
copy and its `.claude/settings.json` are untouched; grado-factorio-modpack#184 deletes the one
and rewires the other.

| Was | Is now |
|---|---|
| The repository root, as the parent of the script's own directory | `-Root`, which the wiring gives as `$CLAUDE_PROJECT_DIR`; without it nothing is checked, and that is said |
| `.mod-cache`, a literal in the test and the refusal | `-CacheName`, defaulting to `.mod-cache`, where `fetch-mods.ps1` puts a cache |
| The self-test's last case reading the modpack's `.claude/settings.json` | a fixture of its own, the command the header shows pointed at this script; or a consumer's settings file, given as `-Settings` |
| The refusal naming the modpack's ticket and `<Pack>` | names neither |

**The self-test's wiring half does both of what #76 allowed.** With no argument it runs a command
of its own, so `check.ps1` proves here that the script works through `sh` with the tool call on
stdin. Given `-Settings`, it runs the command a consumer wired, so the modpack keeps the case it
had: one that fails when its settings stop reaching the hook.

The 37 commands of the self-test's table moved as they were and give the answers they gave. Two
cases are new, which makes 39 against the origin's 38: a cache given another name is the one
guarded, and the wiring case above. Measured 2026-10-08, PowerShell 7.6.6: through the README's
command a `cd` into the cache exits 2 with the reason, and a read by path exits 0 in silence;
`-SelfTest -Settings` given the modpack's file passes, its first hook being the command it has
at `4cc5805`, though what that wiring reaches today is the modpack's own copy.

## What has to be written, not moved

**Mod portal upload.** It does not exist in any repo. `pack-mods.ps1` is explicit in its own header:

> Build one distributable zip per mod, named the way the mod portal requires. […] It uploads nothing
> and it changes no version — the version is read out of the mod.

The portal has a publish API that needs an API key (distinct from the `player-data.json` token
`fetch-mods.ps1` uses for downloads). Writing it means deciding where the key lives and how a
release is gated — neither decided.

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
