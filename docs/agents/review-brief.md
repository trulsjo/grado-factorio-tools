# The brief for a review's agents

The words a review's session hands each lane, written once so that every lane is briefed alike
(#140). How a review is run is in [code-review.md](code-review.md), and the prose rules in
[code-review-prose.md](code-review-prose.md). This page carries two of `code-review.md`'s rules to
the lane, what the bug scan does not load and when the check is not run again, and adds none of
its own: a rule is changed there. The session fills the
blanks, written `<like this>`, with what is particular to the change, and sends the rest as it
stands. A lane that runs both reviews is sent both *Reads first* lines.

---

You are the `<bug scan | prose lane | both>` of the review of pull request `#<number>`,
`<title>`, at `<full SHA>`, in `C:\src\factorio\grado-factorio-tools`. The change:
`<what it does, and the tickets it closes>`.

**Reads first.** `CLAUDE.md`, `docs/agents/code-review.md`, and the tickets the change closes,
with `gh issue view <number> --comments`.

- The bug scan: the diff, `git diff origin/main...<full SHA>`, and each file it touches, whole.
  It does not load `docs/agents/code-review-prose.md`.
- The prose lane: `docs/agents/code-review-prose.md`, then the diff, the commit messages
  (`git log origin/main..<full SHA>`) and the pull request body (`gh pr view <number>`).

**The check.** `<CI's run <id> passed on this commit: name it and do not run the check again |
CI has not passed on this commit: run pwsh -File scripts/check.ps1 and report what it printed>`.

**The self-tests CI does not run.** `<each, as pwsh -File scripts/<script> -SelfTest, or "none">`.
Run each and report its last line.

**Read-only.** Edit no file, commit nothing, push nothing, and post nothing to GitHub: the
session acts on the findings and posts the review.

**Each finding** is reported as:

- **Place:** file and line, or the commit by subject, or the pull request body.
- **Text:** the words or code in question, quoted.
- **Failure:** what goes wrong, for whom, with the run or read that shows it.
- **Right:** what would be right.
- **Score:** a suggested score, 0 to 100, on the plugin's rubric.

**Nothing found** is said plainly, as "Nothing found", with what was read and run.

`<anything particular to this change: a claim to check, a sibling to open, a case to run>`
