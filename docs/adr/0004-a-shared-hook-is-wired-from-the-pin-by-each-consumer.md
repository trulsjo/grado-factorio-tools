# 4. A shared hook is wired from the pin, by each consumer

Date: 2026-11-06

## Status

Accepted. Ruled by Truls in
[How siblings wire a shared Claude Code hook](https://github.com/trulsjo/grado-factorio-tools/issues/315),
on the map [#309](https://github.com/trulsjo/grado-factorio-tools/issues/309). The evidence is
[`docs/research/claude-hooks.md`](../research/claude-hooks.md), *How each repository wires each hook
today*.

## Context

The session hooks here (`refuse-*.ps1`, and the hooks lifted beside them) guard every repository
a session works in, but a session reads its hooks only from the repository it runs in. Two facts
shape how a consumer can run one:

- **`settings.json` has no include.** Every consumer copies its hook lines into its own
  `.claude/settings.json`, so the copies can drift, and on 2026-11-06 they had. Four of the six
  published consumer forms lacked the branch below, and `refuse-pr-body.ps1`'s README form
  disagreed with its `.EXAMPLE`.
- **A script under `vendor/` cannot report its own absence.** It is missing whenever the
  submodule was never fetched, and so is every script that could guard it. Without a guard in
  the line itself, pwsh exits 64 and nothing reaches the agent
  ([grado-factorio-modpack#228](https://github.com/trulsjo/grado-factorio-modpack/issues/228)):
  the hook is off, and nobody is told.

## Decision

1. **Every consumer's hook line takes one form.** It calls the script at
   `$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/`, behind a `case` prefilter, so
   PowerShell starts only for a command the hook could refuse. When the script is missing, the
   line exits 0 with JSON carrying both a `systemMessage` and
   `hookSpecificOutput.additionalContext` that name the missing path. The command runs and the
   agent is told it was not checked. The matcher is `Bash|PowerShell` (Truls, 2026-10-12,
   recorded in `hook-matcher.ps1`).
2. **Each script's first `.EXAMPLE` is the one canonical consumer form.** The README links to it
   and does not repeat it, so there is one text to copy and to hold copies against.
3. **`-SelfTest -Settings <file>` finds a hook's wiring by its script name, never by its
   position**, so a consumer can place a shared hook anywhere in its file.
4. **Each consumer's CI runs `-SelfTest -Settings .claude/settings.json` for every shared hook it
   wires**, so a line that drifts from its `.EXAMPLE` fails there and not silently.
5. **Arguments that differ per repository stay on the consumer's own line.** A script's defaults
   are the common case, and its `.EXAMPLE` names each option. Which options a repository turns
   on is its own choice.
6. **Every consumer tracks `.claude/settings.json`** for its shared hooks, and keeps personal
   settings in the untracked `settings.local.json`. A hook wired only in an untracked file is
   wired on one machine only.

## Considered options

**A Claude Code plugin carrying the hooks.** It would end the copying. Rejected because a plugin
installs per machine, from a marketplace, at a version of its own. It would not follow each
consumer's submodule pin ([ADR 0001](0001-siblings-consume-this-repo-as-a-submodule.md)), so a
change here could alter a consumer's guards before that consumer opts in. It would also bring
back the "wired on one machine only" state that decision 6 removes.

**A wrapper script under `vendor/` that every line calls.** It would shorten each line. Rejected
because the wrapper is missing exactly when it is needed, which is the second fact above.

**Each consumer writing its own line freely.** It is what happened before, and it is how four of
six forms came to lack the missing-script branch.

## Consequences

- A change to a hook's consumer form is a change to its `.EXAMPLE`. Each consumer picks it up by
  moving its pin and copying the new line, and its CI self-test fails until it does.
- A consumer without CI has nowhere to hold its lines. `true-nukes-refreshed` gets a workflow for
  this among other reasons
  ([Rulings: CI workflows](https://github.com/trulsjo/grado-factorio-tools/issues/320)).
