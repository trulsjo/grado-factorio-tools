# 1. Sibling repositories consume this one as a git submodule

Date: 2026-09-21

## Status

Accepted. Resolves
[Decide how the sibling repos consume this repo](https://github.com/trulsjo/grado-factorio-tools/issues/2).

## Context

A tool that moves here leaves nothing behind, so the repository it came from has to reach it
somehow. Nothing in the three repositories does that today: there is no submodule anywhere, no
PowerShell module manifest, and no CI in any of them. The first extraction cannot be done without
answering this, and the answer binds every extraction after it — which is why it is recorded rather
than settled in passing.

The decision was taken against five constraints, established before the options were scored:

- **One developer.** One commit author across the history, all by the owner, no forks, no CI. The
  figure of 135 pull requests, quoted here and elsewhere without its subject, is
  `realistic-fusion-refreshed` alone; across the three repositories it is 144 (135, 6 and 3,
  recounted 2026-09-21). The constraint is unaffected — one author either way — but the number was
  being read as a total. Designing for contributors who have not arrived would mean paying ceremony forever.
- **No action at a distance.** Editing a tool here must not change a sibling's behaviour until that
  sibling opts in. Deliberate version skew is not wanted; a half-finished edit silently becoming
  another repository's gate is.
- **Two setup steps per clone at most, and a missed step must be loud.** One already exists:
  `git config core.hooksPath .githooks`. A mechanism whose omission makes a gate silently pass
  everything is indistinguishable from a clean repository and is unacceptable.
- **No network fetch to run a local hook.**
- **Wiring fits in one sitting.**

The side-by-side checkout of all three repositories on one machine is treated as an accident of this
machine, not a guarantee, so resolving a sibling directory by convention was not admissible as the
primary mechanism.

## Decision

Sibling repositories consume this one as a **git submodule**, pinned to a commit each sibling bumps
deliberately.

**Mounted at `vendor/grado-factorio-tools`** — decided 2026-09-21 alongside the first extraction,
and recorded here because the mount path is the other half of this decision: it is where every
`.gitmodules` entry and every relative pointer in a sibling resolves. `vendor/` says *not ours,
your edit is lost on the next bump* to a human and to an agent without needing a README, where
`tools/` would sit beside `scripts/` and read as a second place to put your own.

## Considered options

**Vendored copy with a drift gate** — rejected twice over. Its drift gate has to reach the canonical
copy to know it has drifted, which breaks the no-network constraint for something that runs on every
commit. More seriously, a vendored copy in a sibling *is a copy left behind*, and this repository's
first rule is that copying is not extracting. Choosing it would have repealed the rule this
repository exists to enforce, as a side effect of the first extraction. Git subtree is the same
objection with a merge history attached.

**Published PowerShell module** — rejected on the one-sitting constraint. There is no manifest, no
gallery account and no publishing precedent in any of the three repositories, and it would impose a
release process per edit on 393 lines maintained by one person.

## Consequences

- The pinned pointer is not overhead. It *is* the "a sibling opts in before its gate changes"
  property, obtained for free rather than built.
- A sibling gains a `.gitmodules` entry, and updating a tool there becomes a deliberate commit.
- A clone that skips `git submodule update --init` gets an empty directory, so the tool cannot be
  resolved, so the hook reports that nothing was checked and lets the commit through. That is the
  loud-but-non-blocking posture the hooks already take when PowerShell is absent, and it is what
  makes the second setup step safe to require.
- Nothing here is built for a sibling-directory fallback. It was judged defensible as a convenience
  and unnecessary once the submodule resolves.
- The audience assumption is load-bearing and worth revisiting the day a second author appears. It
  is cheap to revisit: the submodule works for a contributor too, it only asks them for one more
  command.
