# Code review — this repository's rules

Conventions on top of the `/code-review` plugin, which is not this repository's to edit. What was
measured, and the past findings behind each rule, are in
[code-review-evidence.md](code-review-evidence.md).

## How a review is run

- **Once per change, on the pull request.** Skip the review step inside `/implement` or any other
  skill: open the pull request, then review it. Each session had run it twice over one diff.
- **Two lanes.** A bug scan, which runs `scripts/check.ps1` and, when the harness or `mod-info.ps1`
  changed, the harness's self-test; and a prose lane applying the rules below, which takes in the
  plugin's `CLAUDE.md` and code-comment lanes. Its history and earlier-pull-request-comments lanes
  are dropped: they came back empty in nearly every review.
- **The reviewing session scores each finding itself**, on the plugin's rubric, with no scoring
  agents. Up to 14 subagents a review had posted two comments across eight pull requests.

## What is reported

- **Report every finding that survived verification, whatever it scored.** Post to the pull
  request only what scores 80 or more. The rubric has no value between 75 and 100, so the filter
  drops findings that are verified and real.
- **A review that posts nothing still names each finding, its score, and whether it was
  verified.** A silent pass and a filtered pass must never look the same.
- **Do not re-score to get a finding posted.** Say it matters and let a human decide: an inflated
  score destroys the only signal the score carries.

## Review the prose, not only the code

A wrong sentence here has no gate to fail, and most defects found here were prose that was wrong
about a correct artefact. These bind the reviewer, not only the author.

- **Check every number in prose against the diff, and do the arithmetic.**
- **Treat a quantifier as an instruction to enumerate.** "All" and "none" are checked by walking
  the set, never by agreeing with the tone.
- **When a change supersedes a figure, grep for the old one**, and read every hit in
  `docs/extraction-plan.md`, `docs/adr/`, `CLAUDE.md`, `GLOSSARY.md` and these two pages. A
  correction that misses one place makes the survivor read as deliberate.
- **An old figure struck through beside what replaced it is not a defect; an unmarked one is.**
- **A measurement of a sibling repository is a measurement**: that checkout moves, so an undated
  one is a finding.
- **Check a claim about entanglement against the file, not the reference count**, which
  undercounts.
- **Flag a header or comment that lists what the code lists**: self-test cases, fixtures, a count
  of them, a list of refusals. Each went stale when the code changed; `-SelfTest` prints the cases.
