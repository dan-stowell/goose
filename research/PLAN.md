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

- M0 (2026-11-17 01:50 UTC, commit 98bae32d): ladder measured on this VM (research/LADDER.md, `research/demo
  --full --ladder`); demo prints it stage by stage; bytes method settled (perf counters + a Valgrind cache-model
  tool, research/viz/METHOD.md); first picture live on :8000. Oracle: run 63/776, reject 39/2036, stdlib 6/17,
  fixed point yes. W1 (selfhost, now 288 KB of source) self-hosted: front end 0.20 s + gcc -O2 7.28 s (median)
  vs stock optimized 0.36 + 6.10 s, stock fast 0.97 s total. W2 stock optimized wall 27.0 s (771/771), stock
  fast 3.75 s (733/733); self-hosted 73/771.
Now: paused (2026-11-17 02:40 UTC): Dan stopped all Claude builders over Remote Control. Boards run 134/776,
reject 228/2036 (340 wrongly accepted), stdlib 8/17; fixed point holds. Unmerged on origin: feat-stdlib
2b5fcf6a (11 commits; earlier tip newly accepted 46 error fixtures, so enforce failed), feat-builtins
9922e626 (codex; re-verify check_length_*), emit-lean has nothing new. research/viz/regen.sh failed in
reduce: "ValueError: 'gs_os_read_file' is not in list" (stage-function list vs the grown selfhost); fix that
before regenerating. Resume: merge with research/tools/merge_branch.sh, then relaunch builders from
research/notes/briefs.md only when Dan says so.
