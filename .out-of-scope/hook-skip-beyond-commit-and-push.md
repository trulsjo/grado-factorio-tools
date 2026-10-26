# Refusing a hook skip on rebase, cherry-pick, revert, am and merge

`refuse-git-hook-skip.ps1` judges `git commit` and `git push` only. It does not refuse
`--no-verify` or `-c core.hooksPath=` on the other subcommands that make commits. Truls ruled
this out on 2026-10-26, closing #260.

## What was asked

#260 asked the hook to judge `rebase`, `cherry-pick`, `merge`, `am` and `revert` by the same
rules as `commit`. It came from the retro of PRs #249 to #252 and #257: rebasing PR #252's branch,
the session ran `git -c core.hooksPath=/dev/null rebase main`, the hook let it through, and the
ticket read that as the replayed commits skipping `pre-commit` and `commit-msg`.

## Why it is out of scope

Those subcommands run neither hook to begin with, so the refusal would guard nothing. Measured on
2026-10-26 with git 2.37.3.windows.1, in a scratch repository whose `pre-commit` and `commit-msg`
each append their name to a log, each subcommand run with hooks on and with
`-c core.hooksPath=/dev/null`:

| Subcommand | Hooks on | Hooks off |
| --- | --- | --- |
| plain `git commit` (the control) | `pre-commit`, `commit-msg` | none |
| `rebase`, clean | none | none |
| `rebase` stopped on a conflict, resolved, `--continue` | none | none |
| `cherry-pick` | none | none |
| `revert --no-edit` | none | none |
| `am` | none | none |
| `merge --no-ff -m` | `commit-msg` | none |

So the rebase on PR #252 skipped nothing a plain rebase runs. What is left is a merge commit's
`commit-msg`, and a merge commit is rare here: `main` holds none of its 268 commits (read at
`f2ea96f`, 2026-10-26), since pull requests are rebase-merged. The hook's header already names
merge, am and rebase among what it cannot see, so it does not overstate its coverage.

Not measured: the hooks these subcommands run of their own (`pre-rebase`, `pre-merge-commit`,
`applypatch-msg`, `pre-applypatch`, `post-rewrite`). This repository's `.githooks/` holds only
`pre-commit`, `commit-msg` and `pre-push`; a hook added there for one of them reopens the
question.

## Prior requests

- #260: "Refuse a hook skip on rebase, cherry-pick, merge, am and revert"
