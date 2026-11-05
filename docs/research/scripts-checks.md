# Survey: scripts and checks across the mod repositories

The findings of [#310](https://github.com/trulsjo/grado-factorio-tools/issues/310), one of the
surveys of the map [#309](https://github.com/trulsjo/grado-factorio-tools/issues/309). Every ruling
below is a proposal with its reason. Truls rules.

## What was read

Read 2026-11-06, each repository's `main` checked out and equal to its `origin/main`:

| Repository | Commit | Tools pin (`vendor/grado-factorio-tools`) |
|---|---|---|
| `grado-factorio-tools` | `e70669f` | none, it is the tools |
| `grado-factorio-modpack` | `987e638` | `36b34f7` |
| `realistic-fusion-refreshed` | `9fd78b5` | `36b34f7` |
| `true-nukes-refreshed` | `78486d2` | `36b34f7` |

All three siblings pin the same commit, two behind the tools' `main` (`04e03bd`, `e70669f`, both
`pin-hook` documentation). The pinned copy was not surveyed as any sibling's own.

The inventory is `git ls-files` under `scripts/`, `tools/`, `tests/` and `.github/`. Git hooks,
`.claude/settings.json` and agent docs are the other three surveys'; a script under `scripts/`
that is a Claude Code hook is listed here and its ruling left to the hooks survey. Each script was
triaged by its comment header (`.SYNOPSIS`, or a Python docstring), its line count, and a count of
lines matching the project's prefix (`rf-|realistic` for Realistic Fusion, `TN-|true-nukes|warheads`
for True Nukes, `grado_|.mod-cache|catalogue|pack` for the modpack). As
[`extraction-plan.md`](../extraction-plan.md) warns of its own count, that is a proxy: it misses
entanglement through layout. Scripts named as candidates were read further, as each row says.
Drift is `git diff --no-index --numstat` between the two files, or the part of a file named.
Which sibling uses a tools script was counted as the tracked files outside `vendor/` that name it
(`git grep -l -F <name>.ps1`), which says that a script is named, not that it is wired.

## What each repository has

**`grado-factorio-tools`**: 47 tracked files under `scripts/`, the shared tools; their jobs are in
its `README.md`. One workflow, `.github/workflows/check.yml` (60 lines): `scripts/check.ps1` on
`windows-latest` and `ubuntu-latest`, then the pull request's title through `commit-check.ps1` and
its body through `pr-body-check.ps1 -CiteSiblings -RequireSummaryVisual`.

**`grado-factorio-modpack`**: 13 scripts and one `.psd1` under `scripts/`. Four are about packs
(`stage-pack.ps1`, `member-change-check.ps1`, `overlap-rows-check.ps1`, `player-page-check.ps1`),
one is a session hook (`ask-before-download.ps1`), and eight are about writing, reviewing and
committing (`absolute-words.ps1`, `glossary-check.ps1`, `header-length-check.ps1`, `mentions.ps1`,
`pr-body.ps1`, `probe-session.ps1`, `reword-commit.ps1`, and `pin-forms.psd1`, the forms file the
tools' `pin-measure.ps1` reads). One workflow, `check.yml` (146 lines), on `ubuntu-latest`.

**`realistic-fusion-refreshed`**: 53 PowerShell scripts and 6 other files under `scripts/`, 32
files under `tools/` (26 Python, and 6 under `tools/endf/`), 7 Lua files under `tests/`, and one
workflow, `gates.yml` (117 lines). Nearly all of it is the mod's own: 13 `check-*` gates, 28
`probe-*.ps1` rigs, 3 `bench-*`, the art and render tools, and `load-check.ps1`'s invariants. The
generic part is `ship-check.ps1`'s prose sections, `run-gates.ps1`, `dev-launch.ps1`,
`dump-data.ps1`, some functions of `factorio-lib.ps1`, and four Python tools: `rewrap.py`,
`review-coverage.py`, `review-usage.py` and the hook `refuse-hanging-bash.py`.

**`true-nukes-refreshed`**: 3 runners under `scripts/` (`load-check.ps1`, `port-probe.ps1`,
`freeze-time.ps1`), two in-game mods for them (`scripts/port-probe/`, `scripts/freeze-timer/`), and
`scripts/tests/`: 7 tests, 5 fixture scripts and a fixture mod. **No CI workflow.** Three of the
tests are generic PowerShell checks that name nothing of the mod: `strict-lists.ps1`,
`script-help.ps1`, and in its method `asset-paths.ps1`.

## The candidates

One row per practice. "Generic" asks whether the code needs to know `rf-`, `TN-`, `Grado_` or one
repository's layout. Line counts are `wc -l`.

| Practice | Lives in (repo: path) | Copies elsewhere, and how far they have drifted | Generic? | Proposed ruling, and why |
|---|---|---|---|---|
| **1. Script help that PowerShell can read** | rf: `scripts/ship-check.ps1` section 5 (64 lines); tn: `scripts/tests/script-help.ps1` (91 lines) | Two independent implementations of one rule: of section 5's 64 lines, 56 are removed and 83 added against `script-help.ps1`, so about 8 lines are common, and those are blank or braces. rf asks `Get-Help` for three symptoms (no `.DESCRIPTION`, the generated syntax line as `.SYNOPSIS`, `#Requires` absorbed into the help); tn blanks each help block out, reparses, and compares what the parser gives the script and every function, and fails a script that does not parse. tools: `check.ps1` parses every script and checks no help; modpack: none. | Yes. Both count 0 project lines; rf's reads only its own `scripts/` directory, tn's a path it is given. | **Lift**, one script from the two, then contract both and spread to tools' `check.ps1` and the modpack. tn's catches more (functions too, any malformed keyword); rf's names the `#Requires` cause, which tn's would see only as a block the parser drops. Each repository found its rule by being bitten (rf #151, 27 scripts; tn three times on 2026-11-05). |
| **2. Strict-mode property reads** (`.Count`, `.Id`, `.Name` off a command result) | tn: `scripts/tests/strict-lists.ps1` (511 lines) and five fixtures under `scripts/tests/strict-lists/` (285 lines) | No copy. The same family as tools' `param-check.ps1` (177) and `variable-case-check.ps1` (239): an AST lint over a directory of scripts. Those two are run by tools' `check.ps1` only; no sibling names either. | Yes, 0 project lines. | **Lift** beside the two tools lints, then **spread** all three to every sibling with PowerShell scripts: rf has 53, the modpack 12, tn 10. The failures it catches appear only on the run that finds nothing or one, "often minutes into a real check" (its header; six times on 2026-11-05). |
| **3. Every asset path a mod names is a file** | rf: `scripts/factorio-lib.ps1` `Find-MissingAssets` (87 lines), called by `load-check.ps1`; tn: `scripts/tests/asset-paths.ps1` (54 lines) | Two methods for one job. rf reads the `--dump-data` JSON, so a path built by concatenation is seen; its doc comment records that its first version scanned Lua source and "would have reported a clean pass over the graphics this repo actually ships". tn scans Lua source for literal paths and its header lists what that misses: a path built at run time or joined from two literals. | rf's function: yes, it takes a dump, a data directory and a map of mod name to directory. tn's: names its three mods. | **Lift `Find-MissingAssets`** into the harness library and have tn replace `asset-paths.ps1` with it. This reopens the ruling that the rest of `factorio-lib.ps1` stays, on a named new fact: a second repository needed the check and wrote the weaker method. The plan itself called this function "generic but a check rather than harness and ... a candidate of its own". Whether tn's mods build paths by concatenation was not measured. |
| **4. Prose line length in Markdown, and the rewrap** | tools: `markdown-check.ps1 -MaxLineLength` and `markdown-rewrap.ps1` (461); rf: `ship-check.ps1` section 12 (139 lines, `Find-OverlongProseLines`) and `tools/rewrap.py` (259) | Two implementations of a 100-character prose rule, in two languages. rf runs the shared check in section 11 with `-All` and no `-MaxLineLength`, and holds 8 named files to its own section 12, which adds a rule the shared one lacks: a figure grouped in thousands is not split across a line end (#662). The modpack hands the shared check 100 in its hook and CI; tn runs neither. | Both rules: yes, 0 project lines in section 12 and `rewrap.py`. Section 12's file list is rf's. | **Lift** the grouped-figure rule into `markdown-check.ps1` and `markdown-rewrap.ps1`, then rf **drops** section 12's reader and `rewrap.py` and hands the shared check `-MaxLineLength 100` over its own file list. Open for the grilling: the shared check limits every tracked Markdown file, rf's only eight, so the contraction either widens rf's scope or needs a path filter. |
| **5. Comment and header lines of scripts at 100 characters** | tools: `scripts/comment-line-lib.ps1` `Get-LongCommentLine` (66 lines), run by `check.ps1` and `pre-commit`; modpack: `scripts/header-length-check.ps1` `Find-Long` (255), run by CI | Independent: 56 of the library's 66 lines are removed and 245 added against the modpack's script. Scopes differ: tools reads `scripts/*.ps1`; the modpack reads `scripts/*.ps1` headers and every `#` line of the scripts, `.githooks/` and the workflows (#378). rf and tn: none. | Yes; the modpack's names `vendor/grado-factorio-tools` only in the commands it prints. | **Lift**: one shared check that takes the wider scope as parameters, then the modpack contracts. **Spread** to rf and tn is a separate call; neither states a comment width today that this survey found. |
| **6. Markdown check in a sibling** | tools: `scripts/markdown-check.ps1` | Shared, and consumed unevenly: the modpack in `pre-commit` and CI (`-Range`, 100), rf in `ship-check.ps1` section 11 (`-All`, no limit), tn nowhere. | Yes. | **Spread** to tn. tn's `CLAUDE.md` keeps it out "for now (#8)" and says wiring it in is Truls's call, so this row is that call. |
| **7. Locale check in a sibling** | tools: `scripts/locale-check.ps1 -Prefix` | rf names it in 15 files; modpack and tn in none. tn's prototypes carry `TN-` and it ships `en` and `de` locales. | Yes, with `-Prefix`. | **Spread** to tn, on the same footing as row 6: listed in tn's `CLAUDE.md` as out for now, Truls's call. Not to the modpack, which ships no prototype. |
| **8. Commit messages checked in CI** | tools: `commit-check.ps1` | modpack CI: `-Range origin/main..HEAD -RequireCommits`, the pull request's head checked out; rf CI: `-Range base.sha..head.sha`, also on push to `main`; tools CI: the title only, its commits through `pre-push`; tn: no CI, the `commit-msg` hook only, opt-in per clone. | Yes. | **Spread** a CI step to tn: a clone that never ran `git config core.hooksPath .githooks` commits unchecked, which tn's `CLAUDE.md` says is "loud rather than silent" for the hook but not caught after. |
| **9. Pull request body checked in CI** | tools: `pr-body-check.ps1` | tools CI with `-CiteSiblings -RequireSummaryVisual`; modpack and rf CI with neither switch; tn none. Each workflow passes the body through `env`, as the script's header asks. | Yes. | **Spread** to tn with row 8. Whether the siblings take the two switches tools uses is a question for the grilling, not proposed here. |
| **10. The CI workflow itself** | tools `check.yml` (60), modpack `check.yml` (146), rf `gates.yml` (117) | Three hand-written files. 125 lines added and 39 removed tools to modpack; 96 added and 125 removed modpack to rf. Drift that is not a choice the comments explain: `actions/checkout` pinned to a commit (`v7.0.1`) in the modpack and `@v4` in tools and rf. The range forms differ and each comment says why. | The steps are generic; the lists of self-tests are each repository's. | **Leave** each workflow local. A shared reusable workflow (`workflow_call`) would be consumed by `owner/repo@ref`, a second pin beside the submodule that ADR 0001 chose. The checkout pin is a one-line **spread** candidate, either way round. |
| **11. Commits cited in prose are on `origin/main`** | rf: `ship-check.ps1` section 17 (80 lines); tools: `pr-body-check.ps1`, for a body; modpack: `pr-body.ps1`, for a reviewer's report | Three places ask git the same question of three texts: tracked prose, a pull request body, a review report. rf's comment names the shared body check as the same refusal. Not diffed: the body check's logic sits inside a 661-line script. | rf's: yes, 0 project lines; which pages are records exempt from it is rf's list (`$RECORDS`). | **Lift** a tree-wide form into tools, beside the body check that already holds the ancestor test, then rf contracts section 17. **Spread** is for the grilling: it helps a repository whose prose cites commits, as all four do. |
| **12. No prose cites our own code by line number** | rf: `ship-check.ps1` section 7 (183 lines, 5 project lines) | The rule is written in tools', rf's and tn's `CLAUDE.md` ("Cite our own code by symbol"); only rf enforces it. | Mostly. Its matcher's ambiguity handling (a bare `:155` continuing an earlier path) was tuned on rf's prose; how much was not measured. | **Lift**, after a read of section 7 that separates the matcher from rf's exemptions, then **spread** to tools and tn, which state the rule and do not check it. |
| **13. Cited `docs/` paths and scripts exist** | rf: `ship-check.ps1` section 6 (113 lines, 3 project lines) | Overlaps the shared Markdown check's link check, which reads links and `[label]: path` lines; section 6 reads paths in backticks and in scripts. | Partly: it reads rf's directories. | **Leave**, for now: the shared link check covers the part every repository has, and the rest was not separated in this survey. |
| **14. Self-test halves named in help and not cited by ordinal** | rf: `ship-check.ps1` sections 9 (139) and 13 (68) | tools' `self-test-halves.ps1` is the shared runner; rf names it in 3 files, no other sibling does. | Generic to a repository that uses the runner. | **Leave** until a second repository uses the halves runner. |
| **15. Tracked tree unchanged while a check reads it** | rf: `factorio-lib.ps1` `Get-TrackedTreeFingerprint`, `Get-TrackedTreeChanges`; `ship-check.ps1` section 16 and `run-gates.ps1` (#812) | tools' `check.ps1 -SkipIfPassed` records a passing tree, a different question. No other copy. | Yes, 0 project lines in section 16. | **Leave**: one consumer. Named for the grilling because tools' `check.ps1` can report a pass over a tree edited during its run in the same way, which was not tested. |
| **16. A gate runner** | tools `check.ps1` (578); rf `run-gates.ps1` (300) and `ship-check.ps1` (2,508); tn `load-check.ps1` (54), which runs three tests before the game; modpack: the CI step list | Four shapes, no shared code. | The idea is; each list is local. | **Leave.** What each runs is the repository's; the parts worth sharing are rows 1, 2, 5 and 15. |
| **17. Launch the client on these mods, isolated** | rf: `scripts/dev-launch.ps1` (143, 2 project lines) | tn has no equivalent and has a hand-play ticket open (#27). tn's `port-probe.ps1` opens a window for three probes, in the harness's directories. | Nearly: the mods come from `Get-RepoMods`, as `pack-mods.ps1`'s did before it moved. | **Lift**, with the mod list as arguments, as the packer took them; then rf contracts and tn has the play loop for #27. |
| **18. Close a launched game before cleaning up** | rf: `factorio-lib.ps1` `Stop-LaunchedGame` (kill, wait until gone, then junctions, then directory, #467); tn: its own close and clean in `port-probe.ps1`, tested by `scripts/tests/probe-runner-cleanup.ps1` (#42, #61, #62) | Not compared line by line. Both exist because a killed game holds files and a junction left in `%TEMP%` is followed by a recursive delete (tn #61). | Yes. | **Lift** `Stop-LaunchedGame` into the harness library, reopening "the rest of `factorio-lib.ps1` stays" on the fact that tn needed it, and in the cluster of row 17. tn keeps its window lock unless the grilling finds rf needs one. |
| **19. Run an in-game probe to a PASS line** | tn: `scripts/port-probe.ps1` (303, 13 project lines) and its mod, on `--test-scenario` (new in 2.1.24) | rf's rigs are built differently: `Get-RigBuildLua`, `Start-RunReport` and a client per rig. No copy. | The runner is; the probes are tn's. | **Leave.** tn may be thrown away, and rf's rigs would have to move to `--test-scenario` to share it. Worth naming to rf as a measured 2.1.24 mechanism. |
| **20. Dump the data stage of these mods** | rf: `scripts/dump-data.ps1` (74, 2 project lines); tools: `get-dump.ps1`, `load-harness.ps1` | Overlapping jobs: rf's copies one dump of its own mods to a path; tools' caches dumps by key. | rf's: through `Get-RepoMods` only. | **Drop** rf's in favour of `get-dump.ps1` if rf's callers can take a cached dump; the callers were not read. |
| **21. Glossary words to avoid** | modpack: `scripts/glossary-check.ps1` (292) | No copy. tools' `GLOSSARY.md` has 12 `_Avoid_` lines and nothing reads them; rf and tn have no `GLOSSARY.md` with any. | The method is; `$LEFT`, seven words the modpack leaves to its reviewer, is the modpack's. | **Lift**, with `$LEFT` read from the glossary or a parameter, and **spread** to tools, the one other repository whose glossary has avoided words. |
| **22. Absolute words for a session to walk** | modpack: `scripts/absolute-words.ps1` (188, 0 project lines) | No copy. | Yes. | **Leave** until another repository's review asks a session to enumerate quantifiers; that is the agent-docs survey's question. |
| **23. Lines that name what a range changed** | modpack: `scripts/mentions.ps1` (492, 25 project lines) | Its pin-move half (breaking tools commits between two pins) repeats what tools' `breaking-lib.ps1` and `pin-measure.ps1` give. | Half: members, `base >=` floors and `factorio_version` are the modpack's. | **Leave**; in the grilling, whether its pin-move half should call `breaking-lib.ps1`. |
| **24. Reword one commit of an unpushed branch** | modpack: `scripts/reword-commit.ps1` (219, 0 project lines) | No copy. Every sibling's session lacks an interactive rebase. | Yes, git only. | **Lift.** It is generic, has a self-test, and the problem it solves is the harness's, not the modpack's. |
| **25. Review process scripts** | modpack `pr-body.ps1` (369); rf `tools/review-coverage.py` (145) and `tools/review-usage.py` (397); tools `revert-run.ps1` (337) | No copies; each serves its repository's review page. `pr-body.ps1` loads `Test-Body` from the shared body check. No sibling names `revert-run.ps1`. | Code: yes, 0 project lines each. Each encodes one repository's review steps. | **Leave**, pending the agent-docs survey: they move with a shared review process or not at all. A lift of rf's two would also be the first Python in tools, whose README says there is none. |
| **26. Check a setting reached a new session** | modpack: `scripts/probe-session.ps1` (299, 0 project lines) | No copy. | Yes. | **Leave**: one consumer; for the hooks survey to weigh. |
| **27. Session hooks kept under `scripts/` and `tools/`** | tools: six `refuse-*.ps1`; modpack: `ask-before-download.ps1` (202); rf: `tools/refuse-hanging-bash.py` (429) | rf's hook refuses, among other things, two backslashes in a row in a Bash command on Windows. | Mixed. | **Not ruled here**: the hooks survey's. Listed so the inventory is whole. |
| **28. Pin move measured with a forms file** | modpack: `scripts/pin-forms.psd1`, read by tools' `pin-measure.ps1` | rf names `pin-measure.ps1` in one file and has no forms file; tn has neither. | The file is each sibling's by design. | **Spread** to rf and tn when each next moves its pin, if Truls wants pin tickets measured there as the tools' issue-tracker page asks. |
| **29. Lua unit tests run in CI** | rf: `tests/harness.lua`, six suites, the `lua` job of `gates.yml` | No copy. tn's Lua has no pure modules under test. | The harness is (ADR 0005 there). | **Leave**: one consumer. |
| **30. Python tools' `--self-test` in CI** | rf: `gates.yml` job `tools` | None elsewhere. | n/a | **Leave.** |
| **31. Where a script's tests live** | tools and rf: a `-SelfTest` in each script; tn: separate files under `scripts/tests/` | A convention, not code. | n/a | **Leave**, and note for row 1 and 2's lifts that tn's two tests become `-SelfTest` cases when they move. |
| **32. Each repository's own checks** | modpack: `stage-pack`, `member-change-check`, `overlap-rows-check`, `player-page-check`; rf: the gates, probes, benches, art tools, `load-check.ps1`'s invariants, `name-check.ps1`, `ship-check.ps1` sections 1 to 4, 8, 10, 15, 18 and 19; tn: `freeze-time.ps1`, `recipe-category.ps1`, `shotgun-items.ps1`, `probe-runner-cleanup.ps1` | None. | No: each needs the repository's mods, packs or tickets. | **Leave.** |

## Rulings already held, not reopened unless a row names a new fact

From [`extraction-plan.md`](../extraction-plan.md):

- **Extracted and finished, no copy left**: `commit-check.ps1` (2026-09-21), `fetch-mods.ps1` and
  the load harness (2026-09-25), `pack-mods.ps1` (2026-09-28), the modpack's
  `markdown-check.ps1`, `get-dump.ps1` and `refuse-cd-into-mod-cache.ps1` (2026-10-11), five
  helpers of `factorio-lib.ps1` (2026-10-12), the tree viewer and `locale-check.ps1`
  (2026-10-14), and `Get-HeadingAnchor`, whose copy in rf's `ship-check.ps1` was removed
  (2026-10-15). This survey found no copy of any of them in a sibling.
- **`name-check.ps1` stays in rf for now** (2026-10-11, #103). Not reopened: tn has a prefix,
  `TN-`, but nothing in tn asks for a name check, so the "no second consumer" reason stands.
- **`factorio-lib.ps1` is split, not moved whole; the rest stays.** Rows 3 and 18 propose to
  reopen it for two functions, each on a named fact: tn needed the same function and wrote its
  own.
- **`load-check.ps1`: the harness moved, the invariants stay.** Untouched here (row 32).
- **Siblings consume the tools as a pinned submodule** (ADR 0001). Row 10 leans on it.
- **The packer's case rule, and the mod portal upload, which does not exist anywhere.** Nothing
  here bears on either.

## Clusters, for the grilling tickets

1. **PowerShell script lints**: rows 1, 2 and 5, and the spread of tools' `param-check.ps1` and
   `variable-case-check.ps1`. Generic, small, and each found by an incident. The cheapest
   cluster.
2. **Prose and Markdown rules**: rows 4, 6, 11, 12, 13 and 21. Most of it is in rf's
   `ship-check.ps1`; deciding it means reading sections 6, 7, 12 and 17 for what is rf's.
3. **CI**: rows 8, 9, 10, 30, and tn's lack of a workflow. One decision for tn (a workflow at
   all), then small ones.
4. **Running the game**: rows 3, 17, 18, 19 and 20, and row 7's locale check. Most rows here
   reopen "the rest of `factorio-lib.ps1` stays", each on a named fact.
5. **Review and session tooling**: rows 22 to 26 and 28. Waits on the agent-docs survey, since
   these scripts serve each repository's review page; row 24 can be ruled alone.
6. **Leave as they are**: rows 14 to 16, 27, 29, 31 and 32. For one ticket to confirm, or none.

## What could not be determined

- Whether tn's mods build asset paths by concatenation, which decides how much row 3 gains.
- How much of `ship-check.ps1` section 7's matcher is tuned to rf's prose (row 12).
- Whether rf's callers of `dump-data.ps1` can take `get-dump.ps1`'s cached dump (row 20).
- Whether tn's `port-probe.ps1` cleanup and rf's `Stop-LaunchedGame` do the same thing in the same
  order (row 18): they were read for intent, not compared.
- Whether a sibling *wires* each tools script it names: the counts above are names in tracked
  files.
