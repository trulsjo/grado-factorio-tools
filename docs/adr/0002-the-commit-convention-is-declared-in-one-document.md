# 2. The commit convention is declared in one document

Date: 2026-09-21

## Status

Accepted. Taken as part of
[Extract the commit check from realistic-fusion-refreshed](https://github.com/trulsjo/grado-factorio-tools/issues/1).

## Context

Extracting `commit-check.ps1` will give three repositories one *enforcing* check, once the siblings
are repointed. It does not by itself give them one *convention*. Each `CLAUDE.md` carried its own
near-identical copy of the whole commit-message section: the format block, the subject rules, a
ten-row type table, the situational emoji sentence, the body rule, breaking changes and a worked
example.

Measured 2026-09-21 across all three repositories. **The type tables are identical** — ten types,
same emoji, same order — and that is the measurement this decision rests on. The sections around
them are not identical, and an earlier draft of this ADR said they were: they differ in the scope
vocabulary, the `build` row's prose, the body rule, the worked example, and — the one that matters
— **the breaking-change rule**. `realistic-fusion-refreshed` defines it as save compatibility and
a mod's public interface; `grado-factorio-modpack` as a dependency change an existing save cannot
survive, naming its pack chain; this repository as a consuming repository's interface.

Those last are not drift. They are three repositories being correct about three different domains,
and this repository's own rule is that **one mod's domain does not live here**. A decision that
centralised them would delete a save-compatibility rule that its own owner calls the one that
"breaks silently and players find out, not the build".

Removing the duplication from the code while leaving it in the prose would move the problem up one
layer rather than solve it, and prose drift is the harder kind because no gate reads it. The
evidence was already in hand: `commit-check.ps1` has accepted 🔀 since it was written, and none of
the three documents declared it. That discrepancy survived precisely because nothing compares the
script to the document it claims to enforce.

## Decision

The convention is declared once, in `docs/commit-convention.md` in this repository. Each consuming
repository's `CLAUDE.md` keeps the format block, a pointer here, and the two things that are its
own domain rather than shared mechanics: **its scope vocabulary**, and **what counts as a breaking
change**. The `!` and the `BREAKING CHANGE:` footer are mechanism and are shared; what triggers
them is domain knowledge and stays local.

The script's `$TYPES` and `$SITUATIONAL` literals are **not** checked against that document, and
that is deliberate rather than an oversight.

## Considered options

**The script's literals as the single declaration**, with no table in any document. Purest — drift
would be impossible by construction. Rejected because a reader would have to parse PowerShell to
learn the convention, and `CLAUDE.md` is the first thing an agent reads.

**A self-test case that parses the canonical table and asserts it matches `$TYPES`.** This closes
the remaining drift with a gate instead of by deletion, and the table is regular GFM, so parsing it
is easy. Rejected — and this is the rejection most likely to be proposed again, which is why it is
written down, and why the reason has to be the real one.

An earlier draft of this ADR said the read would break the script's self-containment because it
would touch the filesystem beyond the message file. **That reason was too strong and does not
survive checking.** `-Range` already shells out to `git rev-list` and `git log`, and the read would
resolve inside the submodule, so it would touch neither the network nor the consuming repository —
the two constraints ADR 0001 actually set.

The reason that does hold is narrower. The script today "assumes no directory layout beyond the
file it is handed" — one of the three properties measured when it was chosen as the least entangled
candidate in `docs/extraction-plan.md`. Locating a sibling document means assuming where the script
sits relative to it, and that is the first layout assumption in a file whose whole selling point is
having none. The drift it would close is one page against one hashtable, checked by eye in seconds;
the property it would spend is the one the extraction was chosen to test.

**Each `CLAUDE.md` keeps its full table.** The status quo: four homes for one rule. Rejected
because declaring 🔀 would then have meant the same edit in three files on the first day.

## Consequences

- **Three homes remain, not two.** This document, the script's `$TYPES`/`$SITUATIONAL` literals,
  and the script's own header, which restates several rules in prose and still names `CLAUDE.md`
  as where they live. All three are named on the page itself under "What the check is blind to".
  The header is [issue #10](https://github.com/trulsjo/grado-factorio-tools/issues/10), deferred
  because editing the script would end the byte-identical transfer this extraction rests on.
- **The `build` row's per-repository wording is lost**, deliberately. `realistic-fusion-refreshed`
  said "mod zip, `info.json`", the modpack said "the common one here"; the shared row says
  "packaging, dependencies". This is a real if small cost of centralising, accepted rather than
  overlooked. If it bites, a one-line local gloss is the cheap answer.
- **Neither sibling points here yet.** Both still carry the full table; they are repointed in #9
  and #4. Until then this ADR describes an intended end state, not the tree.
- A rule change is one edit here, plus one in the script when it changes what is enforced. A
  sibling picks it up when it bumps its submodule pin, which is the opt-in ADR 0001 wanted rather
  than a second mechanism.
- A clone that skipped `git submodule update --init` has an empty directory and cannot follow a
  relative pointer, so each sibling's pointer carries the GitHub URL beside the path.
- Worth revisiting the day a repository genuinely needs a different type table. Nothing supports
  one today, which is why per-repository configuration was dropped from issue #1 rather than built.
