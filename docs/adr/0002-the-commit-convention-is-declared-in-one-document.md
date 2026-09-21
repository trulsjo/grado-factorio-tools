# 2. The commit convention is declared in one document

Date: 2026-09-21

## Status

Accepted. Taken as part of
[Extract the commit check from realistic-fusion-refreshed](https://github.com/trulsjo/grado-factorio-tools/issues/1).

## Context

Extracting `commit-check.ps1` gives three repositories one *enforcing* check. It does not by itself
give them one *convention*. Each `CLAUDE.md` carried its own near-identical copy of the whole
commit-message section: the format block, the subject rules, a ten-row type table, the situational
emoji sentence, the body rule, breaking changes and a worked example.

Measured 2026-09-21 across all three repositories: the type tables are identical — ten types, same
emoji, same order. Only the `build` row's prose and the scope vocabulary differ, and scopes name a
repository's own parts, so those differ legitimately.

Removing the duplication from the code while leaving it in the prose would move the problem up one
layer rather than solve it, and prose drift is the harder kind because no gate reads it. The
evidence was already in hand: `commit-check.ps1` has accepted 🔀 since it was written, and none of
the three documents declared it. That discrepancy survived precisely because nothing compares the
script to the document it claims to enforce.

## Decision

The convention is declared once, in `docs/commit-convention.md` in this repository. Each consuming
repository's `CLAUDE.md` keeps only the four-line format block, its own scope vocabulary, and a
pointer here.

The script's `$TYPES` and `$SITUATIONAL` literals are **not** checked against that document, and
that is deliberate rather than an oversight.

## Considered options

**The script's literals as the single declaration**, with no table in any document. Purest — drift
would be impossible by construction. Rejected because a reader would have to parse PowerShell to
learn the convention, and `CLAUDE.md` is the first thing an agent reads.

**A self-test case that parses the canonical table and asserts it matches `$TYPES`.** This closes
the remaining drift with a gate instead of by deletion, and the table is regular GFM, so parsing it
is easy. Rejected — and this is the rejection most likely to be proposed again, which is why it is
written down. It would give `commit-check.ps1` a filesystem read beyond the message file it is
handed. That self-containment is the property that made this script the least entangled candidate
in `docs/extraction-plan.md`, the reason it was chosen to go first, and the thing the submodule
experiment is testing. Buying a drift gate with it would spend the experiment in order to protect
the experiment's own paperwork.

**Each `CLAUDE.md` keeps its full table.** The status quo: four homes for one rule. Rejected
because declaring 🔀 would then have meant the same edit in three files on the first day.

## Consequences

- Two homes remain — this document and the script's literals — so the drift is reduced rather than
  eliminated. It is now the only one, and it is named on the page itself under "What the check is
  blind to".
- A rule change is one edit here, plus one in the script when it changes what is enforced. A
  sibling picks it up when it bumps its submodule pin, which is the opt-in ADR 0001 wanted rather
  than a second mechanism.
- A clone that skipped `git submodule update --init` has an empty directory and cannot follow a
  relative pointer, so each sibling's pointer carries the GitHub URL beside the path.
- Worth revisiting the day a repository genuinely needs a different type table. Nothing supports
  one today, which is why per-repository configuration was dropped from issue #1 rather than built.
