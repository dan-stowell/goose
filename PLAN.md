# Plan

## Goal

Grow a self-hosted Goose compiler, written in Goose, in `selfhost/`, until it
does what `src/` does. That means three things in order: it accepts and runs
the positive test fixtures with the blessed output, it rejects the error
fixtures where their markers say, and it compiles `stdlib/`. Progress is a
scoreboard of fixtures passed out of the total, and the pass count only ever
goes up. Replacing the C++ compiler comes after that and gets its own decision.

`selfhost/` is seeded from `test/goose_in_goose/`, which stays frozen as the
bootstrap regression it is today. Every change to `selfhost/` keeps its
three-stage C fixed point.

When `selfhost/` and `src/` disagree, `docs/goose_spec.md` decides. When the
spec is silent, what the real compiler does decides, and the docs get fixed to
say so.

## Ground rules

- **Clean room (on trial).** Whoever writes `selfhost/` code doesn't read
  `src/`: they work from `docs/`, `stdlib/`, the fixtures, and what
  `build/goose` does when run. Reviewers and verifiers may read `src/` to judge
  correctness. When the docs aren't enough to settle a behavior, the
  coordinator reads `src/` and writes the answer into the docs as its own
  commit, so workers stay clean and the spec improves.
  Drop the rule if it gets too slow: if over the first ~5 feature tasks more
  than one task in three stalls, or bounces back more than twice, on behavior
  the docs didn't cover, the coordinator records that under Decisions and
  lifts the rule.
- **Don't block on Dan.** Dan wants as much progress as possible without
  waiting on him. Where the spec is silent, follow the real compiler, record
  it under Decisions, and add it to Questions for Dan. Pushing to `origin`
  (dan-stowell/goose) and PRs there are fine without asking; pass
  `-R dan-stowell/goose` to `gh pr create`. Never push, open PRs or file
  issues on `upstream` (aardappel/goose). Real language changes (behavior
  `src/` doesn't already have) wait for him.
- **Tooling.** This machine has no system cmake. A pip-installed one lives
  in the session scratchpad venv; tell workers its path, or ask Dan to
  `brew install cmake`.

## Milestones

1. `selfhost/` exists and bootstraps in the suite. (done 2026-10-24)
2. Scoreboards for positive fixtures, error fixtures and stdlib, with a
   committed baseline the suite enforces.
3. Close gaps, largest cluster first, until the positive fixtures pass.
4. Error fixtures pass.
5. Stdlib compiles.

## Tasks

| task | worker | state | notes |
|------|--------|-------|-------|
| selfhost-seed | claude | done | Merged 2026-10-24. Codex review and verify clean |
| scoreboard-run | codex | round 2 | Verify passed, review found 1 blocker (`// runtime-define:` fixtures built without their `-D`) and 11 smaller fixes, incl. splitting out a generic board so the errors/stdlib boards reuse it. Codex fixing. Codex's sandbox has no network, so Claude reruns the full suite |
| scoreboard-errors | claude | todo | errors/ and errors_tc/: rejected on the marked line. Extends scoreboard-run's section; start after it merges |
| scoreboard-stdlib | codex | todo | `selfhost --check` per stdlib module. Extends scoreboard-run's section; start after it merges |
| gap-param-defaults | claude | in flight | Parameter defaults (§7.1). `std.goose:1077` `parse_int(.., base: i64 = 10)` blocks 142 fixtures at parse. Branched off scoreboard-run's first commit; rebase onto round 2 before merging |

Next gaps, from scoreboard-run's first rejection clusters (counts are first
errors only, so they hide what's behind the stdlib parse failure):
variable and limited array storage (64), relative and optional references
(53), custom formatting dispatch (29), enum type checking (27), nonfixed
struct fields (18), missing gfx/ui/physics imports (28).

## Decisions

- 2026-10-24: Self-hosted compiler lives in `selfhost/`, seeded from
  `test/goose_in_goose/`, which stays unchanged.
- 2026-10-24: Clean-room rule on trial (see Ground rules).

## Questions for Dan

None yet. Nothing here blocks work.
