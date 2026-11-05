# Survey: git hooks across the mod repositories

Ticket #311, part of map #309. Read 2026-11-06 at each repository's `origin/main`:
`grado-factorio-tools` `e70669f`, `grado-factorio-modpack` `987e638`,
`realistic-fusion-refreshed` `9fd78b5`, `true-nukes-refreshed` `78486d2`. All three siblings pin
`vendor/grado-factorio-tools` at `36b34f7`; the tools repo is two commits past it (`04e03bd`,
`e70669f`), both edits to the example wrapper in the header of `scripts/follow-pin.ps1`. The
pinned copies were not surveyed as the siblings' own. The rulings below are proposals: Truls rules.

## Inventory

Every tracked file under `.githooks/`, from `git ls-files -s`. Code lines leave out comments and
blank lines. Every one is POSIX `sh`, and every one runs `pwsh -NoProfile -File`.

| Repo | Hook | Lines (code) | Mode | Runs |
|---|---|---|---|---|
| tools | `commit-msg` | 37 (11) | 100755 | `scripts/commit-check.ps1 -ScopeFile commit-scopes.txt` |
| tools | `pre-commit` | 52 (23) | 100755 | `scripts/markdown-check.ps1 -All -MaxLineLength $LIMIT`; `Invoke-StagedCommentCheck` from `scripts/comment-line-lib.ps1`; `$LIMIT` read from `$MARKDOWN_LINE_LIMIT` in `scripts/check.ps1` |
| tools | `pre-push` | 30 (11) | 100755 | `scripts/check.ps1 -SkipIfPassed`, after `unset $(git rev-parse --local-env-vars)` |
| modpack | `commit-msg` | 36 (12) | **100644** | vendor `commit-check.ps1`, then `scripts/member-change-check.ps1 -MessageFile` |
| modpack | `pre-commit` | 40 (17) | 100755 | vendor `markdown-check.ps1 -MaxLineLength 100` (staged); `scripts/overlap-rows-check.ps1`; `scripts/header-length-check.ps1`; `scripts/player-page-check.ps1` |
| modpack | `post-checkout` | 35 (17) | 100755 | vendor `follow-pin.ps1 post-checkout`, branch checkouts only |
| modpack | `post-merge` | 20 (16) | 100755 | vendor `follow-pin.ps1 post-merge` |
| modpack | `post-rewrite` | 23 (17) | 100755 | vendor `follow-pin.ps1 post-rewrite`, rebases only |
| rf | `commit-msg` | 33 (11) | 100755 | vendor `commit-check.ps1` |
| rf | `pre-commit` | 23 (11) | 100755 | vendor `markdown-check.ps1` (staged, no length limit) |
| tn | `commit-msg` | 32 (11) | 100755 | vendor `commit-check.ps1` |

**Installed** in every repository by `git config core.hooksPath .githooks`, once per clone; each
sibling adds `git submodule update --init` first, as its `CLAUDE.md` and each hook's header say.
Nothing installs either step or checks that it was taken. Since `core.hooksPath` sits in the
shared `.git/config`, one setting covers every worktree of a clone; only
`true-nukes-refreshed/CLAUDE.md` says so. The submodule is per worktree, which it also says.

**On a missing `pwsh` or submodule**, every hook prints a line to stderr saying what was NOT
checked and exits 0, the posture ADR 0001 requires (`docs/adr/0001-*.md`, "a missed step must be
loud"). The siblings' hooks add a second line naming `git submodule update --init`. The
follow-pin hooks exit 0 on every path, since a hook's status becomes the checkout's. Three
departures, none a breach:

- tools `pre-commit` also passes when `$MARKDOWN_LINE_LIMIT` cannot be read out of
  `scripts/check.ps1`, and says so.
- modpack `pre-commit` guards only the vendor path. Its three local checks are run unguarded,
  which is right: they are tracked in the same tree as the hook.
- modpack `commit-msg` runs `member-change-check.ps1` unguarded for the same reason.

**Backstops in CI**, for a clone that never opted in: tools runs `check.ps1` and the title check
(`.github/workflows/check.yml`); modpack runs the commit check over the range and the Markdown
check (`.github/workflows/check.yml`); rf runs `commit-check.ps1 -Range` and `ship-check.ps1`,
which holds every tracked `.md` to the Markdown check (`.github/workflows/gates.yml`).
**`true-nukes-refreshed` has no `.github/`**, so a clone of it that skips the two steps has its
messages checked by nothing.

## Drift, measured

`git diff --no-index --numstat`, whole file and then with comments and blank lines removed.

| Pair | Whole file (+/-) | Code only (+/-) | What differs in code |
|---|---|---|---|
| rf `commit-msg` vs tn `commit-msg` | +5 / -6 | identical | comments only; tn's header names rf's as its source |
| rf `commit-msg` vs modpack `commit-msg` | +6 / -3 | +4 / -3 | modpack chains `member-change-check.ps1`, and its messages name it |
| rf `commit-msg` vs tools `commit-msg` | +16 / -12 | +3 / -3 | tools resolves `scripts/` not `vendor/`, and passes `-ScopeFile` |
| rf `pre-commit` vs modpack `pre-commit` | +31 / -14 | +12 / -6 | modpack adds `-MaxLineLength 100` and three local checks |
| rf `pre-commit` vs tools `pre-commit` | +42 / -13 | +18 / -6 | tools reads the limit from `check.ps1`, runs `-All` and the comment-line check |
| `follow-pin.ps1` example (tools `e70669f`) vs modpack `post-checkout` | n/a | +13 / -9 | modpack adds `cd` to the root and spells out the two messages where the example has `say()`; same output, same exit |
| modpack `post-checkout` vs `post-merge` | +4 / -19 | +1 / -2 | the hook name and the guard line, as the example's header says |
| modpack `post-checkout` vs `post-rewrite` | +7 / -19 | +2 / -2 | the same |

So the copies that matter are the three sibling `commit-msg` wrappers, whose code is the same
eleven lines in rf and tn and that plus a chained check in modpack, and the follow-pin wrapper,
which exists once (modpack) and as the canonical example in the tools header, equivalent in
behaviour.

## Candidates

| Practice | Lives in (repo: path) | Copies elsewhere, and how far they have drifted | Generic? | Proposed ruling, and why |
|---|---|---|---|---|
| A `commit-msg` wrapper that guards `pwsh` and the vendor path, then runs the shared `commit-check.ps1` | rf: `.githooks/commit-msg` (the first; tn's names it as its source) | tn: code identical, 11 comment lines differ. modpack: +4/-3 code, for its chained check. tools: +3/-3 code, resolving its own `scripts/` | Yes. It names only `vendor/grado-factorio-tools` | **Leave** each wrapper in its sibling, **lift** its canonical text into the header of `scripts/commit-check.ps1` as an `.EXAMPLE`, as `follow-pin.ps1` holds its wrapper. The wrapper cannot live in the submodule: its whole job is to speak when the submodule is missing. A canonical example makes the drift measurable against one text instead of three |
| Missing `pwsh` or missing check: say what was NOT checked, exit 0 | every hook in all four | Uniform in posture; the wording varies per hook | Yes | **Already ruled** (ADR 0001). No action. Worth naming in the canonical example above, so a new hook inherits it |
| `pre-commit` running the shared `markdown-check.ps1` on staged Markdown | rf: `.githooks/pre-commit`; modpack: `.githooks/pre-commit` | rf vs modpack +12/-6 code; rf vs tools +18/-6. The limit differs: modpack 100, tools 100 read from `check.ps1`, rf none | Yes, the Markdown call. modpack's other three checks are its own | **Spread to tn**, with the guard rf's hook has. tn's `CLAUDE.md` records the Markdown check as staying out "for now (#8)" and wiring it in as Truls's call, so this is that call, not a reopening. Whether rf adopts `-MaxLineLength 100` is a separate question for rf |
| A comment-line limit on staged scripts, in `pre-commit` | tools: `Invoke-StagedCommentCheck`, `scripts/comment-line-lib.ps1` (66 lines), `scripts/*.ps1` only; modpack: `scripts/header-length-check.ps1` (255 lines), scripts, `.githooks/` and workflows | Two implementations of one rule, no shared code | Yes, both: neither names a mod | **Refer to the scripts survey**: the hooks only call them. If one lifts, the hook lines follow. Noted here because the duplication shows up in `pre-commit` |
| `pre-push` running the repository's gate with `-SkipIfPassed` | tools: `.githooks/pre-push` | None | The wiring is; `check.ps1` is tools' own | **Leave.** No sibling has a single offline gate of the same shape to run, and rf runs `ship-check.ps1` in CI instead. The `unset $(git rev-parse --local-env-vars)` line is a lesson worth keeping in whatever doc the example lands in, as a hook running git in a scratch repo needs it |
| post-checkout, post-merge and post-rewrite running the shared `follow-pin.ps1` | modpack: `.githooks/post-*` (#391) | The tools example: +13/-9 code, same behaviour. The three differ from each other by 1-2 code lines, as designed | Yes. Only the submodule path | **Spread to rf** (already ticketed: realistic-fusion-refreshed#790, open, `ready-for-agent`) **and to tn**, which has the same submodule and runs worktrees. modpack's copies can stay as they are: equivalent, and the example is canonical |
| A scope vocabulary the hook enforces (`-ScopeFile`) | tools: `commit-scopes.txt`, passed by `.githooks/commit-msg` | None. Each sibling lists its scopes in `CLAUDE.md` prose and its hook passes no `-ScopeFile`, so any scope passes | The mechanism is; each list is the repository's own (ADR 0002) | **Spread** a `commit-scopes.txt` to each sibling, its list moved out of `CLAUDE.md`. The prose has already drifted: four rf commits of 2026-10-31 and 2026-11-01 (`7081f76`, `4abbc01`, `4a29bf4`, `291633c`) use `research`, which rf's list does not hold. Which list each repository keeps is that repository's call |
| A second, repository-specific check chained in `commit-msg` | modpack: `scripts/member-change-check.ps1` (#375) | None | No: it reads pack members, `Grado_` | **Leave.** What counts as breaking is the consumer's own (ADR 0002) |
| Repository-specific `pre-commit` checks | modpack: `overlap-rows-check.ps1`, `player-page-check.ps1` | None | No: catalogue rows and pack pages | **Leave**, local by design |
| Hooks committed executable | all four; the follow-pin example says to (`git add --chmod=+x`) | modpack `.githooks/commit-msg` is mode **100644**, created so in `172848a` and never changed; every other hook is 100755 | Yes | **Fix in modpack** (`git add --chmod=+x .githooks/commit-msg`), a one-line ticket there. Off Windows git ignores a hook that is not executable, which is silent: the posture ADR 0001 forbids. On this machine `core.fileMode` is `false`, so nothing has shown it. Whether a check should hold every `.githooks/` file to 100755 is a question for the cluster |
| The two install steps, in prose | each repository's `CLAUDE.md`, and each hook's header | rf, modpack and tn say the same two lines in their own words | Yes | **Refer to the agent-docs survey** for the `CLAUDE.md` prose. No hook-side change |
| CI as the backstop for a clone that skipped the hooks | tools, modpack, rf: `.github/workflows/` | tn has none | Yes | **Refer to the scripts-and-checks survey.** Noted because tn's hooks are its only check |

## Rulings already held that touch hooks

Listed as ruled. None is reopened here: no new fact found argues against one.

- **ADR 0001** (2026-09-21): siblings consume the tools repo as a submodule at
  `vendor/grado-factorio-tools`; at most two setup steps per clone, and a missed step must be
  loud. Every hook's missing-submodule branch is this ruling.
- **ADR 0002**: the convention is declared once, in `docs/commit-convention.md`; the scope
  vocabulary and what counts as breaking stay with each consumer. The `-ScopeFile` row spreads
  the mechanism and leaves each list where ADR 0002 puts it.
- **`docs/extraction-plan.md`, *Extracted***: `commit-check.ps1` moved from rf on 2026-09-21 and
  both siblings' copies were deleted; their `commit-msg` hooks were rewired to the submodule.
  The wrappers left behind are the wiring, not a copy of the check.
- **`docs/extraction-plan.md`, *From the modpack***: `markdown-check.ps1` moved (#74), and
  grado-factorio-modpack#182 deleted the modpack's copy and rewired its `pre-commit` on
  2026-10-11.
- **`.out-of-scope/hook-skip-beyond-commit-and-push.md`**: the tools repo's `.githooks/` holds
  only `pre-commit`, `commit-msg` and `pre-push`, and a hook added there for another event
  reopens that ruling. Spreading the follow-pin hooks to siblings adds none to the tools repo, so
  it is untouched.
- **grado-factorio-modpack `docs/decisions.md`, #391** (2026-10-26): tracked hooks keep the
  submodule at the pin `HEAD` records, every path exits 0, and realistic-fusion-refreshed#790 is
  to wire the same there.
- **`true-nukes-refreshed/CLAUDE.md`, *Shared tooling*** (#8): the Markdown check stays out for
  now, and wiring it in is Truls's call.

## Clusters, for the grilling tickets

1. **The `commit-msg` wrapper and its vocabulary.** The canonical example in `commit-check.ps1`,
   the `-ScopeFile` spread, and the modpack mode fix. One grilling: what a sibling's
   `commit-msg` is made of, and what stays its own.
2. **What a sibling's `pre-commit` runs.** The Markdown check's spread to tn, rf's missing length
   limit, and the two comment-line implementations, decided with the scripts survey.
3. **The follow-pin hooks' spread** to rf (ticketed, #790) and tn. Small: probably a ruling
   without much grilling.
4. **Hook hygiene that nothing checks**: the executable bit, and whether anything should check
   that the two install steps were taken. May fold into cluster 1.

## What this survey could not determine

- Whether the 100644 `commit-msg` has ever been skipped in practice. On this Windows checkout
  git ignores the mode; whether any clone of the modpack has committed off Windows is not
  recorded anywhere read. Not run on Linux.
- Whether the four rf `research` commits were meant as a new scope or were a slip. The prose list
  says the one; the history says the other.
- Whether modpack `CLAUDE.md`'s sentence on `markdown-check.ps1 -Range origin/main...HEAD` is
  about CI or the hook: the hook passes no `-Range` and reads the staged files. Read as CI here.
