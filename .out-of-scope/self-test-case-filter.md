# Running one self-test case for a revert

A script's `-SelfTest` runs all its cases. It takes no filter that runs one case by its title, and
`revert-run.ps1` judges each revert by the whole self-test. Truls ruled a filter out on 2026-11-17,
closing #507.

## What was asked

#507, from the retro of PR #499, asked for a `-Case <title>` filter on the self-test runners, which
a revert list would pass through an entry's `Args`, so that a revert aimed at one case runs only
that case. In PR #499's session the session's own revert runs took 274, 342, 419 and 1226 s, by
the seconds each command printed, while the question each answered needed one case.

## Why it is out of scope

- The cost is wall time, not a wrong result.
- A revert narrowed to one case can pass where another case of the same self-test would have failed
  it, so the narrowed run says less than the whole one: the judgement `revert-run.ps1` gives would
  weaken.
- The filter would be added to every script's self-test runner, a change across the repository for
  the time it saves.

A request that answers the second point, a narrowed run that cannot pass where the whole would
fail, reopens the question.
