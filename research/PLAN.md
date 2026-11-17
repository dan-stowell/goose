# PLAN

Dan writes the campaign; the agent keeps the Milestones log and the Now line.

## Campaign 1 (2026-11-17): a memory-first Goose compiler in Goose, and pictures of why

Grow `selfhost/` toward the full language, put the ladder (CHARTER.md) under it, and make it fast by
saving bytes, with the demo command and the pictures page showing every gain.

## Oracle number (report at every milestone)

1. **Coverage:** positive fixtures passing with blessed output, error fixtures rejected correctly,
   `stdlib/` modules compiling, each out of its total; W1's fixed point holding (yes/no).
2. **Speed:** W1 and W2 source-to-running-program on the "ours" rung vs "stock optimized" and
   "stock fast", in seconds, min/median/max.

## Setup

- Build the C++ compiler from source (`cmake`; the VM may lack it: a pip venv works, as on
  2026-10-24) and the release binary as a cross-check. Note gcc and TinyCC versions.
- `selfhost/` is seeded from `test/goose_in_goose/` (done in the setup commit). The October attempt's
  branches (`selfhost-bootstrap`, `gap-float-text`, `gap-multi-return`, `gap-param-defaults`,
  `scoreboard-run`) are 266 commits stale; mine them for the gaps they found and their scoreboard
  script, don't merge them.
- Reference repos, read-only, under `/home/exedev/targets/`: `dan-stowell/simd-lang` (SHAPES.md) and
  `dan-stowell/paradigms` (ATTACKS.md, GRID.md), through the GitHub integration
  (`https://github.int.exe.xyz/dan-stowell/<repo>`).

## Milestones

M0. The ladder measured on this VM for W1, W2 and two W3 programs (every rung that runs today);
    `./research/demo` prints it, stage by stage, and runs the result; the way to see bytes move is
    settled (counters, simulation, or both) and the first picture is on port 8000, even if crude.
M1. The fixture scoreboard is committed and enforced (it never goes down); the largest clusters of
    missing features closed; W1's fixed point holds throughout.
M2. A memory-first pass over `selfhost/`: where its bytes go per stage (vs the C++ compiler), the
    first changes in layout or access order, each with a before/after picture. The C it emits shrinks.
M3. The downstream seconds: C that compiles faster, or a fast path that skips the C compiler, on the
    ladder for W1-W3.
M4. Positive fixtures pass; `stdlib/` compiles; W2 runs entirely through `selfhost/`.

Milestones log:

Now: M0 + M1 in parallel (updated 2026-11-17 02:25 UTC). Merged: demo, feat-stdlib (interim), feat-enums
(interim), scan-index. Boards run 40/776, reject 39/2036, stdlib 6/17; fixed point holds. Running: builders
`viz`, `feat-stdlib`, `feat-storage` (must rebase: conflicts in checker/emitter), `feat-enums`, `emit-dedup`;
codex on `feat-builtins` (/home/exedev/goose-builtins; its 0ec1d8ed claims check_length_* pass but they
cc-error on master: re-verify before merging). Merge rule: merge a branch only when it merges cleanly and
`python3 selfhost/scoreboard.py --enforce` passes on the merge; then `--update`. M0 closes when viz lands
(first picture on :8000): then do LOOP's milestone steps.
