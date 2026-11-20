---
prefix: gft
max-line-length: 100
---

# Review panel

The agents that review this repository's pull requests, through the `review-panel` skill: each in a
Herdr app space `gft-<agent>`, working in its own worktree beside the checkout,
`grado-factorio-tools-panel/<agent>`, detached at `origin/main`. `panel.py up` starts what is not
running.

| Agent | Command | Clear |
|---|---|---|
| codex | `codex --no-daemon` | `/clear` |
| antigravity | `agy` | `/clear` |
| fable | `claude --model claude-fable-5-2` | `/clear` |

- **Agent**: the space's suffix and the answer file's name; `a-z`, `0-9`, `-` and `_`.
- **Command**: the bare command with its model; the app wraps it in `pwsh -NoExit -Command`.
  Codex needs `--no-daemon`, or its commands run outside hc.
- **Clear**: what `panel.py reset` sends to start a new conversation; empty means `/clear`. A clear
  keeps the program and its model: after editing a Command, run `panel.py up --restart`.
- **max-line-length**, in the frontmatter: 100, the limit the `refuse-pr-body.ps1` hook holds pull
  request bodies, issues and comments to (`.claude/settings.json`). A line `switch_ids.py` would
  change past it stops the switch, which names each such line, writes nothing and exits 1: rewrap
  or reword, and run it again. It never rewraps, and does not measure fenced code blocks, table
  rows or lines it leaves unchanged (#515).

Codex's sandbox starts `pwsh` 7 from the MSI install, `C:\Program Files\PowerShell\7`, and not
from the Microsoft Store's, which it cannot reach. On a machine with the Store copy alone, Codex's
shell is Windows PowerShell 5.1: a finding of its that hangs on how PowerShell behaves is then
confirmed by another reviewer's run or the session's own.
