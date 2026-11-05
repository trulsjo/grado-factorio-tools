# Survey: agent docs across the mod repositories

Research for [#313](https://github.com/trulsjo/grado-factorio-tools/issues/313), part of the map
[#309](https://github.com/trulsjo/grado-factorio-tools/issues/309). It asks which agent docs each
of the four repositories has, which of them duplicate one another, and what ruling each candidate
deserves: **lift**, **spread**, **leave** or **drop**, as the map defines them. Every ruling below
is a proposal with its reason. Truls rules.

## What was read, and how drift was measured

Tracked files only (`git -C <repo> ls-files`), read on 2026-11-06 at these commits, each the tip
of `origin/main`:

| Repository | Commit | Tools pin (`vendor/grado-factorio-tools`) |
|---|---|---|
| grado-factorio-tools | `e70669f` | — |
| grado-factorio-modpack | `987e638` | `36b34f7` |
| realistic-fusion-refreshed | `9fd78b5` | `36b34f7` |
| true-nukes-refreshed | `78486d2` | `36b34f7` |

All three siblings pin the same commit, two commits behind this repository's `main`; those two
change `scripts/follow-pin.ps1` and one other file, and no agent doc
(`git diff --stat 36b34f7 origin/main`). The pinned copy is not surveyed as a sibling's own.
Untracked skills (realistic-fusion-refreshed's `.claude/skills/graft`, `graphify` and `wiki`, which
its `.gitignore` excludes) and every `CLAUDE.local.md` are left out.

Drift is given two ways:

- **Lines**: `git diff --no-index --numstat <a> <b>`, as `+added -removed`. This counts rewrapping
  and punctuation as drift.
- **Words**: both texts unwrapped into paragraphs, whitespace collapsed and ` — ` read as `: `,
  then the words in common counted with Python's `difflib.SequenceMatcher`, given as
  `shared/longer`. This separates a rewrap from a change of content. The script was a scratch
  file of this session, not committed; the method is all of it.

A *section* of a `CLAUDE.md` is the text under one `##` heading, outside fences.

## Inventory

| Repository | `CLAUDE.md` (lines / bytes) | `docs/agents/` | Skills | Other |
|---|---|---|---|---|
| grado-factorio-tools | 76 / 4,034 | `triage-labels`, `domain`, `issue-tracker`, `code-review`, `code-review-prose`, `code-review-evidence`, `review-brief` | none | `GLOSSARY.md`, `docs/adr/` (2), `docs/claim-grades.md`, `docs/commit-convention.md` |
| grado-factorio-modpack | 290 / 16,585 | `triage-labels`, `domain`, `issue-tracker`, `code-review`, `code-review-why`, `pre-pr-review-brief` | `.claude/skills/mod-portal` | `GLOSSARY.md`, `docs/adr/` (2) |
| realistic-fusion-refreshed | 367 / 23,935 | `triage-labels`, `domain`, `issue-tracker`, `code-review`, `code-review-evidence`, `code-review-history`, `plugin-pass`, `review-figures`, `shipping`, `state-detail`, `upstream-material` | `.claude/skills/plugin-pass`, `pre-pr-review`, `render-machine` | `GLOSSARY.md`, `docs/adr/` (43), `scripts/CLAUDE.md` |
| true-nukes-refreshed | 231 / 13,277 | `triage-labels`, `domain`, `issue-tracker`, `checks` | `.agents/skills/domain-docs`, `issue-tracker`, `triage-labels` (Antigravity) | `AGENTS.md` (one line), no `GLOSSARY.md`, no `docs/adr/` |

Bytes are of `git show HEAD:CLAUDE.md | wc -c`. No repository has a nested `CLAUDE.md` other than
realistic-fusion-refreshed's `scripts/CLAUDE.md`, and none has `.claude/rules/`.

**Where the three common pages came from.** `triage-labels.md`, `domain.md` and
`issue-tracker.md` are the output of the `setup-matt-pocock-skills` skill: its templates are in
the plugin cache, `mattpocock-skills/1.3.1/skills/engineering/setup-matt-pocock-skills/`
(`triage-labels.md`, `domain.md`, `issue-tracker-github.md`). The same skill writes the
`## Agent skills` block of each `CLAUDE.md`. Against those templates:

| Page | tools | modpack | realistic-fusion | true-nukes |
|---|---|---|---|---|
| `triage-labels.md` | lines +4 -2, words 135/135 | lines +7 -2, words 135/163 | identical | identical |
| `domain.md` | lines +14 -6, words 266/266 | lines +20 -10, words 262/274 | lines +4 -4, words 265/266 | identical |
| `issue-tracker.md` | template words kept 527 of 553; page 3,630 words | 516; 2,346 | 521; 1,597 | 495; 784 |

So the first two are the template in all four: the tools copy is rewrapped to 100 columns,
realistic-fusion's keeps the template's em-dashes, the modpack's adds a dated note on when its
labels were created (28 words) and replaces the template's example tree with its own files
(`Grado_*/info.json`, two of its ADRs). The third keeps the template's core in all four and has
grown apart around it: pairwise, the four pages share 14% to 32% of the longer one's words.

## Candidates

| Practice | Lives in (repo: path) | Copies elsewhere, and how far they have drifted | Generic? | Proposed ruling, and why |
|---|---|---|---|---|
| **Triage label map** | all four: `docs/agents/triage-labels.md` | Four copies of the template. Pairwise: tools/rf/tn 135/135 words (tools rewrapped, +2 -4 lines); modpack adds 28 words of dated history (+3 lines). All four trackers use the five canonical labels unchanged. | Yes. | **Lift.** One page here, which is already this repository's own copy. Four copies of a page whose right-hand column is the same in all four is the case the map's Notes name. The modpack's dated note is history, and goes to its evidence page or is dropped. |
| **Domain docs page** | all four: `docs/agents/domain.md` | Template in all four. tools 266/266 words (rewrapped, +14 -6); rf 265/266 (dashes, +4 -4); tn identical to template; modpack 262/274, its example tree names its own files. | Yes, except the modpack's example tree. | **Lift.** As above. The example tree is an illustration; the modpack's swap of it for its own files is the one local thing, and the template's tree serves. |
| **Issue-tracker page, template core**: create, read, list, comment, label, close; PRs as a triage surface; publish and fetch; wayfinding operations | all four: `docs/agents/issue-tracker.md` | Template words kept: 527, 516, 521 and 495 of 553. Each repository edited the wayfinding *Blocking* bullet in its own way (row *Blocked-by* below). | Yes, but the modpack's commands spell `repos/trulsjo/grado-factorio-modpack`. | **Lift** the core into one page; each sibling keeps a page of its own additions, or a pointer, as #314 decides. `mattpocock-skills:code-review` names `docs/agents/issue-tracker.md` by path (`SKILL.md`, *Process*), so a sibling keeps a file at that path whatever else moves. |
| **Read an issue with `--json`, not `--comments`** | tools, modpack, rf: `docs/agents/issue-tracker.md` (*Read an issue*) | tn has the `--json` command and not the reason. Each of the three records its own finding of the same failure: tools 2026-10-14 (#148), modpack 2026-10-06, rf 2026-10-06 (gh 2.102.0). tn's `CLAUDE.md` *Issue tracker* and rf's both point readers at the command. | Yes. | **Lift**, with the one finding and the three dates as its evidence. Three records of one gh behaviour is the duplication a canonical page removes. |
| **Multi-line bodies through `--body-file`, written with the Write tool, never a heredoc** | tools, modpack, rf: `docs/agents/issue-tracker.md` (*Create an issue*) | tn's page keeps the template's "Use a heredoc for multi-line bodies", which tools and rf found failing under the Bash tool (tools PR #81, 2026-10-08; rf from 2026-10-06), and which the modpack's own hook refuses for some bodies (PR #186). rf's bullet is about 600 words of history, its hook `tools/refuse-hanging-bash.py` among it. tn's rule sits in a user-level memory only (`bash-heredoc-backslashes`), not ruled here. | Yes. rf's hook history is rf's. | **Lift** the rule, so tn stops carrying the instruction the other three disproved. rf's history moves to its evidence page or stays, its call. |
| **Search the open issues before filing** | tn (*Create an issue*: right before each create, `--search`); modpack (*Before filing*: here and in `grado-factorio-tools`, `--limit 200`); rf (*When a skill says "publish"*: by concept, not wording) | Three wordings of one rule, each with its own reason; no shared sentence. | Yes; which other trackers to search is local (the modpack names this one). | **Lift** the rule with the three reasons; each repository names its extra trackers beside its pointer. |
| **Blocked-by: native dependency edges plus a `## Blocked by` section** | tn (*Set blocked by*, and in wayfinding); modpack (*Add a blocker*; *A ticket that waits carries no `ready-for-agent`*); rf (*Blocking between issues*); tools (*Blocking*, wayfinding, 26 lines) | All four rewrote the template's *Blocking* bullet: tn and tools keep the body section always, modpack drops `ready-for-agent` while blocked, rf sets edges as tickets are created. The modpack's bullet also carries its `Bash(...)` permission rule for the POST. | Yes, apart from the modpack's permission rule, which is `.claude/settings.json` material. | **Lift** the mechanism (edge, section, readback); the permission rule stays with the modpack, for the Claude-hooks survey. Whether *no `ready-for-agent` while blocked* applies everywhere is Truls's. |
| **Before closing, list what hangs off the issue; close a duplicate with `--duplicate-of`** | tn (*Close*); modpack (*Close a duplicate*) | One copy each. | Yes. | **Lift** both into the shared page, or **leave** if Truls holds the shared page to what two or more repositories do now. |
| **A ticket's evidence**: a figure carries its command; a statement is read from source or marked as an account; a quantifier carries its search; a command that printed nothing is run again on an input that prints | tools (*A figure*, *What a ticket states*, *A command that printed nothing*); modpack (*What a ticket or a ruling comment states*, *A figure a triage or a grill makes*, *A quantifier in a ticket*); rf (`docs/agents/code-review.md`, the paragraph on a ticket's evidence, #637, #657) | Same rules, three wordings, each illustrated by its own incident. tn has none. They overlap `docs/claim-grades.md`, already lifted, whose grades say the same of a claim in a document. | Yes. | **Lift**, beside or into `docs/claim-grades.md`, which already holds the grades these rules apply to tickets. Incidents stay as each repository's evidence. |
| **A criterion names the self-test case that fails on revert** | tools: `docs/agents/issue-tracker.md` | None. | No: about this repository's `-SelfTest` convention. | **Leave.** |
| **A criterion that a setting took effect names a newly started process** | modpack: `docs/agents/issue-tracker.md` | None. | Yes for any repository that tests Claude Code settings, but tied to `scripts/probe-session.ps1`, the modpack's. | **Leave** until a second repository has such a ticket; then it travels with the probe script (scripts survey). |
| **Pull request body**: the `pr` skill's three headings and four markers, one bare `Closes #N` line per ticket, a branch commit named by role or subject and not by hash, `pr-body-check.ps1` run before the create, joined with `&&` | tools: `docs/agents/issue-tracker.md` (*Branches, pull requests and follow-up tickets*); modpack: same page (*Pull request body*, *A commit of the branch is named by its role*, *A closing keyword*); rf: same page (*Pull request body*), and `.claude/skills/pre-pr-review` | Three statements of the rules one shared script enforces (`scripts/pr-body-check.ps1`, here). The commit rule differs: modpack names a commit by role, rf by its subject in quotes, tools cites the pull request. Each adds its own section (modpack and rf the pre-PR review's, tools `-CiteSiblings`). tn has no pull request rules. | The rules the check enforces, yes; each repository's added sections, no. | **Lift** what `pr-body-check.ps1` enforces into one page beside it, on ADR 0002's pattern: the check and the page that declares what it checks, here; each repository's additions stay local. The commit-naming difference is Truls's to settle or keep. |
| **Work starts on a `ready-for-agent` ticket, on a branch per ticket** | tools: `CLAUDE.md` *Agent skills* and `docs/agents/issue-tracker.md` | tn's `CLAUDE.md` *State* says "one branch per ticket"; the modpack's *Conventions* says a batch of tickets lands as one pull request (#151). | The first half yes, the second is each repository's workflow. | **Leave.** The branching rules differ by choice; converging them is Truls's. |
| **The bar for a follow-up ticket** (Truls, 2026-10-06) | tools: `docs/agents/issue-tracker.md` | None. | Yes. | **Leave**, as a ruling made for this repository; spreading it is Truls's. |
| **Code review: the threshold sorts the comment, not the report; do not re-score** | tools: `docs/agents/code-review.md` (*What is reported*); modpack: `docs/agents/code-review.md` (*The threshold gates the comment*); rf: `docs/agents/code-review.md` (*The verdict sorts the comment*) | Whole pages share 1% to 8% of words: three wordings of one rule. "Do not re-score" is in all three. tn has no review page. | Yes. | **Lift** the rule; each review procedure stays local (next row). |
| **Code review: review the prose, not only the code** | tools: `docs/agents/code-review-prose.md`; modpack and rf: `docs/agents/code-review.md` (*Review the prose*) | Shared checks in all three: check every number and do the arithmetic; treat a quantifier as an instruction to enumerate. The rest is each repository's: sibling citations here, the catalogue in the modpack, ADRs and figures in rf. tools holds its page under 2,000 bytes (`scripts/check.ps1`, `$PAGE_LIMITS`). | The shared checks, yes. | **Lift** the shared checks into one page; each repository keeps its own list beside the pointer. |
| **Code review: when and how a review runs** | tools: one review on the pull request, two lanes (`code-review.md`, `review-brief.md`); modpack: a pre-PR review, plugin pass on request (`code-review.md`, `pre-pr-review-brief.md`); rf: a pre-PR review and a plugin pass (`code-review.md`, `plugin-pass.md`, skills `pre-pr-review`, `plugin-pass`) | Different procedures, not drift. tn uses the user-level `review-panel` skill (not ruled). | No: each is fitted to its gates. | **Leave.** Converging review procedures is a decision, not a deduplication. |
| **Rules page short, evidence on its own page** | tools `code-review-evidence.md`; modpack `code-review-why.md`; rf `code-review-evidence.md`, `code-review-history.md`, `review-figures.md`, `state-detail.md` | The same split, made separately three times. | The pattern yes, the contents no. | **Leave** the pages; the pattern goes into the row *Live rule only* below. |
| **`## Agent skills` block in `CLAUDE.md`** | all four | The setup skill's block, expanded in each: tools 61 words, modpack 106, tn 99, rf 452 (its review triggers). Pairwise 4% to 33% shared. The consuming skills find the pages through it: `triage` and `to-tickets` say the mapping and tracker "should have been provided to you". | The skeleton yes, the contents no. | **Leave** the block in each `CLAUDE.md`, pointing wherever the lifted pages land. It is how the skills are given the pages, so it is the consumption point #314 designs. |
| **The rule that matters most: big decisions are Truls's, settle none as a side effect** | all four: `CLAUDE.md` (tools *The decisions that are Truls's*) | The closing clause ("no 'I picked X to get started' … choosing between them is not") recurs in modpack, rf and tn at 0.69 to 0.75 similarity; the list of decisions is each repository's. | The clause yes, the list no. | **Leave.** It is the one rule each `CLAUDE.md` puts first; behind a link it would load only when followed. An `@` import would keep it loaded (see *Consuming a shared page*), if Truls wants one wording. |
| **Factorio specifics: three stages, API docs per version, pin a build** | modpack, rf, tn: `CLAUDE.md` *Factorio specifics*; tools: `CLAUDE.md` *Factorio facts to check, not remember* | modpack/rf/tn share 56% to 61% of words; three bullets nearly identical (0.88 to 0.90), the fourth each repository's own (the 1.1 → 2.0 break, the ancestors). tools' variant shares 14% to 20%. | The three bullets yes; the fourth no. | **Lift** the three bullets into one page; each `CLAUDE.md` keeps its own bullet and a pointer, or imports the page. |
| **Mod portal facts**: the `/full` endpoint, no key to read, any `2.x`, a missing mod may live under another name | tools: `CLAUDE.md` *Factorio facts*; modpack: `CLAUDE.md` *Checking the mod portal* and `.claude/skills/mod-portal/SKILL.md` | Two of the facts are in both `CLAUDE.md`s (0.90 on `factorio_version`), the SpaceMod example in both. The skill adds the endpoints and the sweep counts (read 2026-10-01). | Yes. | **Lift**, as a page or a skill here. Whether a skill under `vendor/` is discovered was not determined (below), so the form waits on #314. |
| **Default branch, commit email per repo, `CLAUDE.local.md` never committed** | all four: `CLAUDE.md` *Conventions* (tools *Working here*) | 0.66 to 0.81 similarity. Not the same fact everywhere: tn keeps `CLAUDE.local.md` out by `.git/info/exclude`, the others by `.gitignore`. | Yes, in form. | **Leave.** One line each, a pointer costs as much as the line, and the `CLAUDE.local.md` line differs in fact. |
| **Cite our own code by symbol, never by line number** | tools: `CLAUDE.md` *Working here* (one line); rf: `CLAUDE.md` *Conventions* (with what `ship-check.ps1` section 7 gates, ADR 0032); tn: `CLAUDE.md` *Conventions* | tn's is rf's shortened. The modpack has no code. | The rule yes; rf's gate no. | **Lift** the rule; rf keeps its gate's description and ADR 0032. |
| **Commit messages section** | modpack, rf, tn: `CLAUDE.md` *Commit messages*; tools: its own | Ruled by ADR 0002 (below). modpack/rf share 287 of 649 words: the format block, the pointer, the "three things" sentence and the hook opt-in. tn's section is 176 words and points at the convention by its GitHub URL only, with no `vendor/` path. | Ruled. | **Ruled: leave as ADR 0002 says.** New fact, not a reopening: tn's pointer is the inverse of ADR 0002's consequence ("each sibling's pointer carries the GitHub URL beside the path"). A tn-local fix. The hook opt-in prose belongs to the git-hooks survey. |
| **Live rule only: `CLAUDE.md` loads every turn, so history and detail go elsewhere** | modpack: `CLAUDE.md` *Conventions* (*This file states the live rule only*); rf: `docs/agents/state-detail.md` (#591); tools: `$PAGE_LIMITS` in `scripts/check.ps1` (#69), `CLAUDE.md` under 4,100 bytes | Three forms of one practice. Sizes: 4,034 / 16,585 / 23,935 / 13,277 bytes; 76 / 290 / 367 / 231 lines, where Claude Code's memory page says to "target under 200 lines per CLAUDE.md file". | Yes; the limits are each repository's. | **Lift** the rule into a shared page on writing agent docs. A size gate in a sibling is the scripts survey's, and the limit is each repository's. |
| **Upstream material and licensing** | rf: `CLAUDE.md` *Upstream material*, `docs/agents/upstream-material.md`; tn: `CLAUDE.md` *Upstream material* | 7% shared. | No. | **Leave.** Domain. |
| **State, checks, chains, code indexes, shared tooling** | modpack *State*, *The chain*; rf *State*, *Code indexes*; tn *State*, *Checks*, *Shared tooling*, `docs/agents/checks.md`; rf `docs/agents/shipping.md` | None. | No. | **Leave.** |
| **Nested `CLAUDE.md` for gate internals** | rf: `scripts/CLAUDE.md` | None. | No (`rf-` gates). | **Leave.** |
| **Rendered art skill** | rf: `.claude/skills/render-machine` | None. | No. | **Leave.** |
| **Antigravity entry points**: `AGENTS.md` as `@[CLAUDE.md](CLAUDE.md)`, and `.agents/skills/*` wrappers that link to `docs/agents/*` | tn: `AGENTS.md`, `.agents/skills/{domain-docs,issue-tracker,triage-labels}` (`3e84fa4`, 2026-11-02) | None. The wrappers hold no rules, only links. | Yes. | **Leave** in tn. Spreading depends on whether another repository runs Antigravity, which is Truls's. If the pages are lifted, the wrappers' links change with them. |
| **Glossary** | tools, modpack, rf: `GLOSSARY.md` | Domain terms. Overlaps: tools *Pin move* and modpack *Pin*; tools *Line* and modpack *Declared line*. The modpack's *Measured*, *Read from source* and *Inferred* are already stubs that link to `vendor/grado-factorio-tools/docs/claim-grades.md`. | No, but for the two overlapping terms. | **Leave.** The two overlaps could become stubs that link here, as the claim grades are; Truls's. |

## Rulings already held that touch agent docs

Listed as ruled. Not reopened unless the named fact argues for it.

- **ADR 0002**: the commit convention is declared once, in `docs/commit-convention.md`. Each
  sibling's `CLAUDE.md` keeps the format block, a pointer that carries the GitHub URL beside the
  path, its scope vocabulary and its breaking-change rule. New fact: true-nukes-refreshed's
  pointer has the URL and not the path. That is a local fix, not a reopening.
- **ADR 0001**: siblings consume this repository as a pinned submodule; a sibling picks up a
  change when it moves its pin. A lifted page reaches a sibling the same way.
- **`docs/claim-grades.md`** (Truls, 2026-10-16, #159): the grades are defined once here; a
  repository that adopts them states its own scope beside its link; this repository does not apply
  them to its own docs. It is the one agent doc lifted so far, taken from the modpack at `39dfb8c`.
  New fact: `docs/extraction-plan.md` holds no row for it (`grep -c claim-grades` gives 0), though
  the map says every lift is a row there.
- **`docs/extraction-plan.md`**, *Risks*: copying is not extracting; whatever moves leaves nothing
  behind. The map's Notes say the same of docs: one canonical page here, linked, not copied.
- **`docs/extraction-plan.md`**, *From the modpack*: a hook's wiring in `.claude/settings.json`
  stays with each consumer. It touches the modpack's permission rule in the *Blocked-by* row, which
  stays local for that reason.
- **`CLAUDE.md` here**: "if a script needs to know `rf-`, it stays where it is", used for the
  *Generic?* column; and `$PAGE_LIMITS` (#69) caps this repository's `CLAUDE.md` and two review
  pages, and no sibling's.

`docs/extraction-plan.md` holds no other ruling on agent docs: it names no page under
`docs/agents/`.

## Consuming a shared page: what the repositories do now

For #314. Read from the four repositories at the commits above, by a `git grep -o` for
`github.com/trulsjo/grado-factorio-tools` and for `vendor/grado-factorio-tools`, each followed by
its path, over `CLAUDE.md`, `AGENTS.md`, `docs/agents/`, the skills, `scripts/CLAUDE.md` and
`GLOSSARY.md`.

1. **A `vendor/` link and the GitHub URL beside it**, warning that `main` may be ahead of the pin:
   the commit convention, in the modpack's and realistic-fusion's `CLAUDE.md`. This is ADR 0002's
   form.
2. **A `vendor/` link alone**: `claim-grades.md` from realistic-fusion's
   `docs/agents/code-review.md` and from the modpack's `code-review.md`, `pre-pr-review-brief.md`
   and `GLOSSARY.md`. A clone without `git submodule update --init` follows nothing.
3. **The GitHub URL alone**: the commit convention, in true-nukes' `CLAUDE.md`.
4. **A stub entry that defines nothing and links to the definition**: the modpack's
   `GLOSSARY.md` entries for the three claim grades.
5. **Script paths under `vendor/.../scripts/`**: 13 lines in the modpack's agent docs, 9 in
   realistic-fusion's, none in true-nukes'. Not doc consumption, but a page's commands will name
   such paths.
6. **An include for another agent**: true-nukes' `AGENTS.md` is `@[CLAUDE.md](CLAUDE.md)`, and its
   `.agents/skills/*` are wrappers that link to `docs/agents/*`.

No repository uses Claude Code's `@path` import in a `CLAUDE.md`.

What Claude Code's documentation says bears on the choice (*How Claude remembers your project*,
<https://code.claude.com/docs/en/memory>, read 2026-11-06; read from documentation, not measured
here):

- "CLAUDE.md files can import additional files using `@path/to/import` syntax", resolved
  "relative to the file containing the import", to "a maximum depth of four hops". An import is
  external, and asks for approval once per project, only "when its path resolves outside your
  working directory". `vendor/grado-factorio-tools/...` is inside a sibling's working directory.
  An imported page loads every session, as `CLAUDE.md` does, and counts against its size.
- `CLAUDE.md` files "in subdirectories under your current working directory" load "once Claude
  reads, writes, or edits another file in that subdirectory".
  `vendor/grado-factorio-tools/CLAUDE.md` exists at the pin, so a sibling session that reads a
  page or script under `vendor/` would load this repository's own `CLAUDE.md`, with
  its rules for working *here*. Whether an `@` import counts as such a read was not determined.
- With a `CLAUDE.md` present, `AGENTS.md` is not read, so true-nukes' `AGENTS.md` changes nothing
  for Claude Code.
- The setup skill writes the pages to `docs/agents/` and the pointers into the `## Agent skills`
  block; `mattpocock-skills:code-review` names `docs/agents/issue-tracker.md` by path and tells the
  user to run the setup skill when it is missing. Re-running `/setup-matt-pocock-skills` rewrites
  the pages "in-place" (its `SKILL.md`), so a sibling page reduced to a pointer could be overwritten
  by the template.

## Clusters, as candidates for the grilling tickets

1. **The setup skill's pages and pointers**: *Triage label map*, *Domain docs page*, the
   issue-tracker page's template core, the `## Agent skills` block, tn's Antigravity wrappers.
   Near-identical copies of a third-party template; the question is one canonical page against
   the fixed paths the skills expect.
2. **Tracker and ticket conventions**: reading with `--json`, bodies by file, searching before
   filing, blocked-by, closing, a ticket's evidence (with `claim-grades.md`). Same rules in
   different words, each backed by its own incidents.
3. **Pull request bodies**: the rules `pr-body-check.ps1` enforces, and the commit-naming
   difference.
4. **Code review rules**: the threshold rule and the prose checks are shared; the procedures are
   not, and stay out unless Truls wants them converged.
5. **The shared parts of each `CLAUDE.md`**: Factorio specifics, mod portal facts, citing by
   symbol, live rule only and size, the rule that matters most, and tn's commit-convention
   pointer.
6. **The consumption mechanism**, across all five: link styles, `@` imports, the vendored
   `CLAUDE.md` loading on demand, skills in a submodule. This is #314's, and clusters 1 to 5 wait
   on it, as the map's *Order of the lifts* already guesses.

## What could not be determined

- **Whether Claude Code discovers a skill under `vendor/grado-factorio-tools/.claude/skills/`.**
  The memory page does not say, and nothing was run. It decides whether *Mod portal facts* can be
  lifted as a skill.
- **Whether an `@` import of a file under `vendor/` makes the vendored `CLAUDE.md` load.** Not
  measured.
- **Why true-nukes' issue-tracker page still says "Use a heredoc"**: its history was not read
  past the inventory. The page is the template's line, unchanged.
- **How the gates of each sibling would treat a page reduced to a pointer**: the Markdown checks
  read links to tracked files, and a `vendor/` path is a submodule path. Not run, since this survey
  runs no check in a sibling.
