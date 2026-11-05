# Claude Code hooks and permissions across the mod repositories

Research for [#312](https://github.com/trulsjo/grado-factorio-tools/issues/312), part of the
wayfinder map [#309](https://github.com/trulsjo/grado-factorio-tools/issues/309). Read on
2026-11-06. The proposed rulings below are proposals; Truls rules (#309, *Notes*).

## What was read

Each repository's tracked files (`git -C <repo> ls-files`), at these commits:

| Repository | Commit | `vendor/grado-factorio-tools` pin |
|---|---|---|
| `grado-factorio-tools` | `e70669f` (`origin/main`) | none: it is the tools |
| `grado-factorio-modpack` | `987e638` | `36b34f7` |
| `realistic-fusion-refreshed` | `9fd78b5` | `36b34f7` |
| `true-nukes-refreshed` | `78486d2` | `36b34f7` |

`36b34f7` is 2 commits behind `e70669f`, and it already holds every hook script named below
(`git ls-tree 36b34f7 scripts/`), `refuse-git-discard.ps1` and `hook-matcher.ps1` included. So no
pin move stands between a sibling and any of these hooks.

Tracked Claude Code configuration, the whole of it:

| Repository | `.claude/settings.json` | `.mcp.json` | Hook scripts it calls |
|---|---|---|---|
| `grado-factorio-tools` | tracked | none | `scripts/refuse-git-hook-skip.ps1`, `refuse-python-heredoc.ps1`, `refuse-pr-body.ps1`, `refuse-backtick-substitution.ps1` |
| `grado-factorio-modpack` | tracked | none | `vendor/grado-factorio-tools/scripts/refuse-cd-into-mod-cache.ps1`, `scripts/ask-before-download.ps1` |
| `realistic-fusion-refreshed` | **git-ignored** (`.gitignore`: `.claude/*`) | git-ignored (`/.mcp.json`) | `tools/refuse-hanging-bash.py` is tracked; the settings that wire it are not |
| `true-nukes-refreshed` | **no `.claude/` directory** | none | none |

`realistic-fusion-refreshed`'s untracked `.claude/settings.json`, `.claude/config.json`,
`.claude/helpers/*` and `.mcp.json` were read on disk to say what the tracked tree lacks, and are
described, not ruled, below. `settings.local.json` files are personal and were not surveyed.
User-level config (`~/.claude-personal/settings.json`) is named where a repository practice
overlaps it, never ruled.

## How each repository wires each hook today

This is what #315 waits on. Every hook below is a `PreToolUse` `type: command` hook; the command is
run by `sh`, reads the tool call from stdin with `i=$(cat)`, and pipes it to the script.

| Repository | Hook | Matcher | Script path | `case` prefilter | Script missing | Arguments |
|---|---|---|---|---|---|---|
| tools | `refuse-git-hook-skip.ps1` | `Bash\|PowerShell` | own, `$CLAUDE_PROJECT_DIR/scripts/` | `*commit*\|*push*` | no branch (own tracked file) | none |
| tools | `refuse-python-heredoc.ps1` | same entry | own | `*py*'<<'*` | no branch | none |
| tools | `refuse-pr-body.ps1` | same entry | own | `*gh*pr*` | no branch | `-CiteSiblings -RequireSummaryVisual` |
| tools | `refuse-backtick-substitution.ps1` | same entry | own | `` *'`'* `` | no branch | none |
| modpack | `refuse-cd-into-mod-cache.ps1` | `Bash\|PowerShell` | vendor, `$CLAUDE_PROJECT_DIR/vendor/grado-factorio-tools/scripts/` | `*mod-cache*` | `[ -f "$h" ]`, else exit 0 with JSON: `systemMessage` and `hookSpecificOutput.additionalContext`, the same message, naming the vendor path | `-Root "$CLAUDE_PROJECT_DIR" -CacheName .mod-cache` |
| modpack | `ask-before-download.ps1` | same entry | own, `scripts/` | `*npm*\|*npx*\|*pip*\|*gem*\|*cargo*\|*winget*\|*choco*\|*scoop*\|*release*download*\|*.exe*\|*.msi*\|*.zip*\|*.tar.gz*\|*.tgz*` | no branch (own tracked file) | none |
| RF (untracked) | `refuse-hanging-bash.py` | `Bash` only | own, `$CLAUDE_PROJECT_DIR/tools/`, run by `python` | none: Python starts before every Bash call | no branch | none |
| TN | nothing | | | | | |

All entries in one repository share one matcher entry: the tools repository has one `PreToolUse`
entry with four hooks, the modpack one with two.

**Two hooks are documented for consumers but wired by none:** `refuse-git-discard.ps1` (README
*Keeping an agent session from discarding uncommitted work*; grado-factorio-modpack#366, open,
plans to wire it there) is not wired in the tools repository's own settings either.

**What the tools repository tells a consumer to write** (`README.md`, one fenced `"command"` per
hook, and each script's first `.EXAMPLE`), compared with what is wired. Each command was split at
`;` and before each `-Parameter`, and the pieces diffed with `git diff --no-index --numstat`:

| Hook | README consumer form vs what is wired | Has the missing-script branch in the README form |
|---|---|---|
| `refuse-git-hook-skip.ps1` | 1 piece differs from tools' own: the path (`vendor/...` for a consumer) | **no** |
| `refuse-python-heredoc.ps1` | 1 piece: the path | **no** |
| `refuse-pr-body.ps1` | 3 pieces against 2: the path, and the README passes `-CiteSiblings` alone where tools' own passes `-CiteSiblings -RequireSummaryVisual` | **no** |
| `refuse-backtick-substitution.ps1` | 1 piece: the path | **no** |
| `refuse-cd-into-mod-cache.ps1` | README and `.EXAMPLE` identical (603 chars); the modpack's (590 chars) differs in 4 pieces against 2: it adds `-CacheName .mod-cache` (the default), names the vendor path in its message, and builds the JSON with `printf '{...%s...}' "$m" "$m"` from one `m=` string where the README repeats the message as a literal | yes |
| `refuse-git-discard.ps1` | README and `.EXAMPLE` identical (599 chars); no wiring to compare | yes |

So the loud-when-missing guard that #115 introduced is in two of the six consumer forms the
tools repository publishes. A consumer that copies the other four as written gets the outcome
grado-factorio-modpack#228 measured for a missing script: pwsh exits 64 (measured 2026-10-08,
`refuse-cd-into-mod-cache.ps1`'s header) and, by #228's account (Claude Code 2.1.296), nothing of
it reached the agent.

**How each hook's self-test finds a consumer's wiring** (`-SelfTest -Settings <file>`), which
decides whether a shared fragment can be placed freely in a sibling's file:

- `refuse-git-hook-skip.ps1`, `refuse-python-heredoc.ps1`, `refuse-pr-body.ps1`,
  `refuse-backtick-substitution.ps1`: the first command of any `PreToolUse` entry that names the
  script (`Where-Object { @($_.hooks.command) -match $names }`). Position-free.
- `refuse-cd-into-mod-cache.ps1`: `hooks.PreToolUse[0]`, the first entry, and "its first
  PreToolUse hook" (`.PARAMETER Settings`). **Position-bound.**
- `refuse-git-discard.ps1`: has no `-Settings`; its `-SelfTest` runs the README form only.
- The modpack's `ask-before-download.ps1`: its self-test reads
  `hooks.PreToolUse[0].hooks[1].command` of its own settings. **Position-bound**, to second place.
- `realistic-fusion-refreshed`'s `refuse-hanging-bash.py --self-test` reads no settings.

Who runs those self-tests: the tools repository's `scripts/check.ps1` (`$SELF_TESTS`) runs every
`refuse-*.ps1` and `hook-matcher.ps1` against its own settings; the modpack's
`.github/workflows/check.yml` runs `ask-before-download.ps1 -SelfTest` and
`refuse-cd-into-mod-cache.ps1 -SelfTest -Settings .claude/settings.json`, and its
`scripts/pin-forms.psd1` records the cd hook's forms for a pin move;
`realistic-fusion-refreshed`'s `.github/workflows/gates.yml` and `scripts/run-gates.ps1` run
`refuse-hanging-bash.py --self-test`.

## The candidate table

| Practice | Lives in (repo: path) | Copies elsewhere, and how far they have drifted | Generic? | Proposed ruling, and why |
|---|---|---|---|---|
| Refuse a commit or push that skips git hooks | tools: `scripts/refuse-git-hook-skip.ps1` (256 lines), wired in `.claude/settings.json` | None. Every sibling has a `.githooks/commit-msg` it could skip (modpack also `pre-commit` and three post-hooks, RF `pre-commit`), and none wires this | Yes: names no repo | **Spread** to modpack, RF and TN, through the vendor path. The hook protects exactly the git hooks each already runs. Wait for #315's wiring form, since the README form has no missing-script branch |
| Refuse Python run from a heredoc | tools: `scripts/refuse-python-heredoc.ps1` (238 lines), wired | None as text. Overlaps RF's `refuse-hanging-bash.py` (which refuses `python -` fed nothing and a heredoc over 60 lines) and the user-level `~/.claude-personal/hooks/heredoc-backslash.py` (58 lines, refuses a heredoc body holding a backslash); TN's agent memory carries the same lesson as prose | Yes | **Spread** to modpack, RF and TN. The failure (halved backslashes, hangs) is a property of the Bash tool on Windows, not of a repo. Rule the overlap with RF's hook in the same cluster |
| Refuse a PR body the body check fails | tools: `scripts/refuse-pr-body.ps1` (281 lines), wired with `-CiteSiblings -RequireSummaryVisual` | None wired. The README's consumer form passes `-CiteSiblings` alone (3 pieces against 2, above). RF asks for the same chain by hand (`docs/agents/issue-tracker.md`, *Pull request body*: `pr-body-check.ps1 <file> &&`, no arguments); the modpack checks bodies in CI (`check.yml`) only. TN has no PR body convention, and its `issue-tracker.md` says "Use a heredoc for multi-line bodies", which this hook refuses for `--body` | Yes in code; **the arguments are per repo**, and wiring it imposes the `## Summary` / `## Evidence` / `## Merge Danger` template | **Spread** to modpack and RF, each with the arguments its CI passes to `pr-body-check.ps1`. **TN: no proposal**: wiring it there adopts a PR body convention TN has not taken, which is a separate decision for Truls |
| Refuse a Bash command that runs a backtick span | tools: `scripts/refuse-backtick-substitution.ps1` (323 lines), wired | None | Yes | **Spread** to modpack, RF and TN. Every repo's docs are written in Markdown code spans, the input that triggered #272 |
| Refuse a git command that discards uncommitted work | tools: `scripts/refuse-git-discard.ps1` (360 lines); README consumer form | **Wired nowhere, the tools repo included.** grado-factorio-modpack#366 (open) plans the modpack's wiring | Yes: #224 says "the risk is the same in every repository" | **Spread** to all four, the tools repo's own settings included. Its own reason covers every repo; that the tools repo, which wires its four other hooks, lacks it looks like an omission. One new fact for the cluster: it has no `-Settings`, so a consumer cannot prove its own wiring |
| Refuse a `cd` into the mod cache | tools: `scripts/refuse-cd-into-mod-cache.ps1` (318 lines), lifted from the modpack by #76; wired in the modpack | Modpack's wiring differs from the README form in 4 pieces against 2 (above); same behaviour, message differs. **RF also keeps caches at the root**, `.mod-cache/` and `.mod-cache-portal/` (`.gitignore`: `.mod-cache*/`), and is unguarded. TN and tools keep none on this machine | Yes, with `-Root` and `-CacheName`; but `-CacheName` takes one name, so RF needs two wirings or a change | **Spread** to RF once RF can track settings (row below). **Leave** TN and tools: neither has a cache. Its wiring is the modpack's, already ruled consumer-side in `extraction-plan.md` |
| Ask before downloading a program | modpack: `scripts/ask-before-download.ps1` (202 lines); rule in modpack `CLAUDE.md`, *Conventions* (#179) | None. No other repo's `CLAUDE.md` or docs states the rule | The refusal is generic; its allow-list is `mods.factorio.com`, and its self-test cases name `Grado_ABC`, `stage-pack.ps1`, `.mod-cache` and reads `hooks[1]` by position | **Lift**, proposed: the incident (#179, a subagent fetching linters) is not modpack-specific, and RF and TN run the same subagents. The self-test would need `-Settings` and a name-based lookup, as the tools hooks have. Second choice: leave, if Truls wants the rule only where it was ruled |
| Refuse a Bash command that would hang, a long heredoc, or a backslash pair | RF: `tools/refuse-hanging-bash.py` (429 lines, Python), wired only from RF's **untracked** settings (`CLAUDE.md` and `docs/agents/issue-tracker.md` say a fresh clone has no hook) | None as text. Overlaps `refuse-python-heredoc.ps1` (Python from a heredoc) and the user-level `heredoc-backslash.py` (backslashes). Bare `cat` waiting on the tool's stdin is caught by nothing else | Yes: nothing names `rf-` or RF's layout, except the log path `.claude/refused-bash.log` | **Lift**, proposed, as the one Bash-tool hang guard: its two hang shapes (#645) and the backslash halving (#682) hit any repo on this machine. To rule with it: Python in a PowerShell repo, the `Bash`-only matcher (`hook-matcher.ps1` records Truls's 2026-10-12 ruling that both shell tools be demanded; this hook guards a Bash-only failure), and which of the overlapping three keeps the backslash check |
| Prove a consumer's wiring in its CI | modpack: `.github/workflows/check.yml` runs `refuse-cd-into-mod-cache.ps1 -SelfTest -Settings .claude/settings.json`; tools: `scripts/check.ps1` against its own settings | Only the modpack runs a shared hook's self-test against its own settings | Yes | **Spread** with each hook spread: a wiring nothing runs drifts unseen, which is what #120 found. Depends on each hook having a position-free `-Settings` |
| Matcher reading for self-tests | tools: `scripts/hook-matcher.ps1` (130 lines) | None | Yes | **Leave** in tools: already shared, dot-sourced by the hooks' self-tests |
| Allow the `blocked_by` POST | tools and modpack: `.claude/settings.json` `permissions.allow`, two rules each | **Identical** in both files (2 lines, 0 differ): one rule per repo path, `grado-factorio-modpack` and `grado-factorio-tools`. RF and TN document the same POST in `docs/agents/issue-tracker.md` and allow nothing | Names each repo's path; RF and TN would need their own | **Spread** to RF and TN with their own repo paths, if Truls takes de036e0's ruling (grado-factorio-modpack#233: the wildcard's risk accepted) as covering them. TN's map work files blockers the same way |
| Plugins switched off per repo | modpack: `.claude/settings.json` `enabledPlugins` (oh-my-claudecode and ponytail off, #160) | None | No: a choice about this repo's sessions | **Leave**: ruled for the modpack's reasons. Named so the cluster does not copy it by accident with the hooks |
| Tracked `.claude/settings.json` at all | tools, modpack | RF ignores `.claude/*` (`.gitignore`, from `4676bf5`, whose comment says "If a project-scoped setting is ever worth sharing, negate it here rather than dropping this rule"); TN has no `.claude/` | Yes | **Spread** to RF (negate `.claude/settings.json` as the comment says) and TN (create it). Every other spread to these two depends on it. `extraction-plan.md` already records that RF "could not wire it from a tracked file as it stands" |
| RF's local tool config | RF, untracked: `.claude/settings.json` `footerLinksRegexes` and the four `graft` allow rules, `.mcp.json` (`graft` server), `.claude/config.json` (`blender-mcp`), `.claude/helpers/graft-*.cjs` | None | No: graft, graphify and Blender tooling of one machine (RF `CLAUDE.md`, *Code indexes*, #598: optional, git-ignored) | **Leave**, untracked. If RF's settings become tracked, these stay out of the tracked file |
| `.mcp.json` | none tracked anywhere | | | **Leave**: nothing to rule |

## Rulings `docs/extraction-plan.md` already holds for this kind

Listed as ruled, not reopened:

- **`refuse-cd-into-mod-cache.ps1` moved to this repository** (ruled by Truls 2026-10-08,
  #76, contracted by grado-factorio-modpack#184 on 2026-10-11): the script is here, parameterised
  by `-Root` and `-CacheName`; **the wiring stays with each consumer**, because the self-test
  reads the consumer's `.claude/settings.json`, which a submodule cannot supply.
- **The self-test's wiring half** takes a consumer's file as `-Settings`, and since #115 and
  #120 fails a wiring that does not tell the agent when the script is missing, or whose matcher
  does not start the hook for both shell tools.
- **`realistic-fusion-refreshed` "ignores `.claude/*` and could not wire it from a tracked file
  as it stands"**: recorded as a fact, not a ruling. The proposal above to un-ignore its settings
  is new, and the new fact that argues for it is that RF now has a hook of its own
  (`refuse-hanging-bash.py`, #645, after 2026-10-08) that a fresh clone does not get, and two
  mod caches the cd hook would guard.

No other row of `extraction-plan.md` touches Claude Code hooks or permissions. The four
`refuse-*` hooks written here (#118, #240, #259, #272) and `refuse-git-discard.ps1` (#224) were
written here, not extracted, so the plan has no row for them.

## Proposed clusters

1. **Shared hook wiring** (#315 already holds the question). The six `refuse-*` hooks, the CI
   self-test against a consumer's settings, and the two prerequisites: RF un-ignoring
   `.claude/settings.json` and TN creating one. Facts for it: four of the six published consumer
   forms lack the missing-script branch; two self-tests (`refuse-cd-into-mod-cache.ps1`,
   `ask-before-download.ps1`) find their wiring by position, so a shared fragment cannot be
   placed freely; `refuse-git-discard.ps1` has no `-Settings`; `refuse-pr-body.ps1` needs
   per-repo arguments and the README's form already disagrees with tools' own.
2. **Shell-tool input guards, and their overlap.** `refuse-python-heredoc.ps1`,
   `refuse-backtick-substitution.ps1`, RF's `refuse-hanging-bash.py` and the user-level
   `heredoc-backslash.py` guard four faces of one problem, the Bash tool's handling of
   heredocs, quotes and backslashes on Windows. To rule: lift RF's, in which language, and which
   one owns the backslash check.
3. **What a session may do unasked.** `ask-before-download.ps1` (lift or leave), the
   `blocked_by` allow rules (spread to RF and TN), and the modpack's plugin switch-off (leave).
   TN's adoption of `refuse-pr-body.ps1` falls here too, since it carries a PR body convention.

## What could not be determined

- What a session shows when a consumer's hook script is missing and the wiring has no guard was
  measured once, for one hook, by grado-factorio-modpack#228; not for the other four forms.
- Whether the tools repository leaving `refuse-git-discard.ps1` unwired was decided: neither
  #224's body nor the commits `18d64b3`, `ea1f8cc`, `f2ea96f` say.
- How RF's untracked settings came to wire `refuse-hanging-bash.py` on Truls's machine is
  recorded only in prose (`docs/agents/issue-tracker.md`: "registered on Truls's machine on
  2026-10-09"); another machine's state was not read.
- The README for `refuse-git-discard.ps1` says `git worktree add` is blocked by "a hook on the
  development machine". No such hook is in any of the four repositories or in
  `~/.claude-personal/settings.json`; it was not looked for further (a plugin's hook is likely).
