# 3. Shared agent docs are linked from the pin, never imported

Date: 2026-11-06

## Status

Accepted. Ruled by Truls in
[*How siblings consume a shared agent doc*](https://github.com/trulsjo/grado-factorio-tools/issues/314),
on the map [#309](https://github.com/trulsjo/grado-factorio-tools/issues/309), and recorded with
the first doc lift,
[#335](https://github.com/trulsjo/grado-factorio-tools/issues/335).

## Context

The agent docs of the four mod repositories, this one and its three siblings, had grown apart
around shared rules: the four `docs/agents/issue-tracker.md` pages keep the setup template's core,
and any two share 14% to 32% of the rest (`docs/research/agent-docs.md`). The map ruled which
rules are lifted here. That left how a sibling reads a page that lives here. Three forms were on
the table:

- **A GitHub URL** to this repository. Always the latest version; follows no pin; needs the
  network.
- **A path into `vendor/grado-factorio-tools/docs/`.** Pinned, so a page changes for a sibling
  only when it moves its pin, and readable offline. Empty until `git submodule update --init`.
- **A stub page** in each sibling that names the shared page and keeps only that repository's own
  parts, the shape the *Commit messages* sections of each `CLAUDE.md` take, by #314's account, under
  [ADR 0002](0002-the-commit-convention-is-declared-in-one-document.md).

A further constraint: the `mattpocock-skills` read some pages at a fixed path, such as
`docs/agents/issue-tracker.md`, and re-running `/setup-matt-pocock-skills` rewrites those pages
in place.

## Decision

1. **The link form is ADR 0002's.** A sibling's doc links the shared page at its
   `vendor/grado-factorio-tools/docs/...` path, and gives the GitHub URL beside it with a note that
   `main` may be ahead of the pin. The `vendor/` path is the pinned version, the one whose scripts
   that sibling runs; the URL serves a reader on the web and a clone that never ran
   `git submodule update --init`. Neither is used alone: a `vendor/` link alone leaves an
   uninitialised clone with nothing to follow, and a URL alone can describe a newer convention
   than the pinned scripts enforce.
2. **No `@` imports.** A shared page is linked, and the sibling says when to load it ("read X
   before filing an issue"), as every `docs/agents/` page already is. A rule that applies in
   every session keeps a one-line form in the sibling's own `CLAUDE.md`, beside the link.
3. **This repository's `CLAUDE.md` carries a guard sentence**: a reader who reached the file
   through `vendor/` in another repository follows that repository's `CLAUDE.md`, not this one.
   Claude Code's memory docs say a subdirectory's `CLAUDE.md` loads when a file under it is read;
   that was not measured here. If it loads, the sentence keeps a sibling session from taking
   these rules as its own; if not, it costs one line.
4. **A page a skill expects at a fixed path becomes a stub page**: a file at that path, holding
   the repository's own parts and a link to the shared page in the form of point 1, whose first
   line warns that re-running `/setup-matt-pocock-skills` rewrites it in place and drops the
   link. Which parts are shared and which stay is ruled page by page.
5. **Pages only, not skills.** Whether Claude Code discovers a skill under
   `vendor/grado-factorio-tools/.claude/skills/` was not measured, and no ruling proposes a shared
   skill. A later ruling that wants one files a ticket to measure discovery first.

**This repository's own stubs link a shared page by a relative link alone**, as
`../tracker-conventions.md` (Truls, 2026-11-06, on
[#335](https://github.com/trulsjo/grado-factorio-tools/issues/335#issuecomment-6697411296)): here
the page and the stub are always at one commit, so there is no pin to follow and no uninitialised
clone.

## Considered options

**A `vendor/` link alone** and **a URL alone** are rejected under point 1, each for the reader it
leaves without the page.

**`@` imports in each sibling's `CLAUDE.md`.** Rejected under point 2, whose ruling gives no
reason beyond that every `docs/agents/` page is already linked and loaded when a task needs it.

**Lifting the setup template's own pages**, `triage-labels.md` and `domain.md`. Rejected in
[*Rulings: the setup skill's template pages*](https://github.com/trulsjo/grado-factorio-tools/issues/324):
their source is the plugin's template, a stub of them saves nothing, and re-running setup turns a
stub back into a copy.

## Consequences

- **A shared page changes for a sibling when it moves its pin**, the opt-in
  [ADR 0001](0001-siblings-consume-this-repo-as-a-submodule.md) wanted, and the web reader sees
  `main`, which may be ahead.
- **A gate can pass a `vendor/` link.** The shared Markdown check asks the working tree about a
  link into a submodule and reads no anchors there; the modpack's and realistic-fusion's CI check
  out with `submodules: true`, and the modpack carried such links in four agent docs, by #314's
  account of 2026-11-06, which names no commit.
- **Re-running `/setup-matt-pocock-skills` undoes a stub** without warning beyond its first line:
  the link is restored from git.
- The first doc lift is `docs/tracker-conventions.md`. The siblings' stubs come with their own
  tickets: trulsjo/grado-factorio-modpack#417, trulsjo/realistic-fusion-refreshed#864 and
  trulsjo/true-nukes-refreshed#74.
