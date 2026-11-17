Reading additional input from stdin...
OpenAI Codex v0.169.0
--------
workdir: /home/exedev/goose-w
model: gpt-6-astra
provider: exe-llm
approval: never
sandbox: read-only
reasoning effort: none
reasoning summaries: none
session id: 01a1e73c-982b-76b3-bb1d-123a090be0db
--------
user
You are reviewing Dan's Goose fork (current directory): a Goose compiler written in Goose under
selfhost/, built memory-first, with research notes under research/. Read research/CHARTER.md,
research/PLAN.md, research/STATUS.md, research/LADDER.md, research/FINDINGS.md and the tail of
research/JOURNAL.md. Do not edit anything.

Answer briefly and concretely, citing files and numbers:
1. Which claimed result can't be reproduced with ./research/demo, or isn't on the pictures page?
   Run the demo if you can.
2. Which correctness claim isn't actually checked: a fixed point not rebuilt, fixtures counted but
   outputs not compared, a program built but not run?
3. Which timing compares unlike things (warm against cold, a different input, a rung that skips
   work another rung does)?
4. Where is effort going into milliseconds on a stage that is a small part of the ladder, while the
   seconds sit elsewhere?
5. Which picture shows something other than what the caption claims (simulated vs measured,
   a different input, an old run)?
6. Quote any recent JOURNAL.md passage that declines or shrinks work because of time, usage or a
   session ending.
Skip praise.
codex
I’ll read the research claims, check them against the demo and pictures, and run the demo if the environment permits. I won’t edit files.
exec
/bin/bash -lc "pwd; rg --files -g 'AGENTS.md' -g 'CLAUDE.md' -g 'README*' -g 'research/**'" in /home/exedev/goose-w
 succeeded in 0ms:
/home/exedev/goose-w
selfhost/README.md
docs/site/README.md
samples/README.md
research/REVIEWS.md
research/tools/c_dedup.py
research/LOOP.md
research/viz/build.py
research/viz/page.html
research/viz/METHOD.md
research/viz/README.md
research/viz/index.html
research/viz/data/cpp_w1.json
research/viz/data/counters.json
research/viz/data/selfhost_w1.json
third_party/tinycc/README
third_party/tinycc/README.md
test/goose_in_goose/README.md
research/viz/trace/counters_json.py
research/viz/trace/run.sh
research/viz/trace/build.sh
research/viz/trace/reduce.py
research/viz/trace/bytemove.c
research/viz/trace/calib.c
research/viz/trace/counters.sh
research/viz/trace/stagemarks.py
research/IDEAS.md
research/.gitattributes
research/CHARTER.md
research/JOURNAL.md
research/STATUS.md
research/LADDER.md
research/FINDINGS.md
research/runs/20261117T013206Z-de28e5b6.json
research/runs/20261117T015013Z-98bae32d.json
research/runs/20261117T013206Z-de28e5b6.meta.json
research/runs/20261117T015013Z-98bae32d.meta.json
research/setup.sh
research/notes/brief-feature.md
research/notes/feat-storage.md
research/notes/tcc-rung.md
research/notes/dedup.md
research/notes/feat-enums.md
research/notes/emit-dedup.md
research/notes/brief-common.md
research/notes/briefs.md
research/demo
research/PLAN.md
tree-sitter/README.md
research/reviews/inbox/.keep
research/reviews/done/.keep
research/prompts/skeptic.md
bench/kostya/README.md
bench/kostya2/README.md
third_party/cute_spirv/README.md
third_party/subprocess/README.md
README.md
bench/plb2/README.md
bench/bddicken/README.md
bench/plb/README.md
vscode/README.md

exec
/bin/bash -lc 'cat research/CHARTER.md research/PLAN.md research/STATUS.md research/LADDER.md research/FINDINGS.md; tail -n 220 research/JOURNAL.md' in /home/exedev/goose-w
 succeeded in 0ms:
# CHARTER

Only Dan edits this file. Agents read it at the start of every session. The current campaign is in
`research/PLAN.md`; the procedure is in `research/LOOP.md`.

*Draft of 2026-11-17, written for Dan to edit.*

## North star

A Goose compiler written in Goose, built memory-first, that takes real Goose programs to running
programs fast, and a set of pictures that show **why** it is fast: bytes moving between the caches
and memory, stage by stage, before and after each change.

Two things are learned at once:

1. **Can a compiler be written in Goose's memory model and come out fast?** Data stacks freed at scope
   exit, narrow 32-bit links instead of pointers, data stored inline, threads that share no memory. On
   paper that model is the list of lessons from the Go work in `dan-stowell/simd-lang`'s SHAPES.md
   (arenas, compact ids, store the answer on the thing, partition then join). This project builds a
   real program with it, and where the language is missing something, that is a finding.
2. **Where does the time go when you save bytes instead of instructions?** The paradigms grid
   (`dan-stowell/paradigms`, 2026-11-16) found that every gap to tuned C was bytes moved: whole-array
   passes, copies between workers, rescans. Here that thesis gets tested on a whole compiler, and shown.

This is Dan's fork of `aardappel/goose`. Nothing goes upstream; see "Upstream" below.

## The ladder (the baseline, measured first and kept current)

What a person feels is **source to running program**. Every number reported sits on this ladder, for
the same input, on the same VM:

| rung | front end (Goose -> C) | back end (C -> executable) |
|---|---|---|
| stock optimized | the C++ compiler (`src/`, `goose build`) | gcc -O2 |
| stock fast | the C++ compiler (`goose file.goose`) | TinyCC, in process |
| self-hosted | `selfhost/` (the Goose-written compiler) | gcc -O2, then TinyCC |
| ours | `selfhost/`, memory-first | whatever wins: less C, C that compiles faster, or our own machine code |

First measurement (2026-11-17, on spawn: 2 cores, so only indicative; M0 re-measures on the run's VM),
input `test/goose_in_goose/main.goose` (3,321 lines, the compiler compiling itself):

- C++ front end: **0.21 s**, 49 MB peak, writes 1.33 MB of C.
- Goose-written front end (built from the same source): **0.39 s**, 34 MB peak, writes **3.66 MB** of C.
- `goose build` (front end + gcc -O2): **3.8 s** warm. gcc is about 95% of it.
- `goose file.goose` (front end + TinyCC): 0.23 s.
- gcc -O2 on the Goose-written compiler's 3.66 MB of C: **10.0 s**, against ~3.6 s on the C++
  compiler's 1.33 MB for the same program. 2.75x the bytes, 2.8x the C compiler's time: the bytes we
  emit are paid for again downstream. (The three-stage fixed point holds: stage 2 and stage 3 C are identical.)

So on today's inputs the front end is tiny ball and the seconds are in the C compiler. The campaign
must not spend itself shaving 0.2 s. Either the work grows (bigger programs, the whole test suite, a
self-hosted compiler that covers the language and is itself tens of thousands of lines), or the win
is downstream: emitting fewer bytes of C (2.75x more than the C++ compiler today is a byte cost paid
again by gcc), C that's cheaper to compile, or skipping the C compiler for a fast path (code
generation by shape, copy-and-patch: SHAPES.md's codegen section). Report wins in seconds on the
ladder, not in milliseconds of one stage.

## Workloads (inputs that produce something you can run and check)

1. **W1: the compiler compiling itself.** `selfhost/` builds `selfhost/` (three stages, C fixed point).
2. **W2: the test suite.** 3,065 `.goose` files in `test/` with blessed outputs (`test/run_tests.py`).
   Wall time of the whole suite through each rung is a felt number for anyone working on Goose.
3. **W3: real programs.** `stdlib/`, `samples/` (`31_mini_doom`, `30_mini_minecraft`, ...),
   `bench/`. Each one built and run, its output checked.
4. Bigger inputs as they appear: a fully self-hosted compiler; Goose programs worth porting. Synthetic
   inputs only as a scaling check, never as the headline.

Correctness first, always: a rung's time counts only when its outputs match (W1's fixed point, W2's
blessed outputs, W3's program output).

## Deliverables

1. **`selfhost/`**: the Goose-written compiler, growing until it does what `src/` does: positive
   fixtures run with blessed output, error fixtures rejected where their markers say, `stdlib/`
   compiles. Seeded from upstream's `test/goose_in_goose/` (which stays untouched, as upstream's own
   regression).
2. **`./research/demo`**: one command Dan can run on the VM. It builds a workload through each rung,
   stage by stage, printing as it goes: stage, time, bytes read and written, peak memory, and how the
   output was checked. Then it runs what it built. `--before <commit>` runs an older version alongside.
   Nothing counts as a result unless this command shows it.
3. **The pictures** (`research/viz/`), served by the VM on port 8000
   (`https://<vm>.exe.xyz:8000/`, private to Dan). The main deliverable alongside the compiler, not an
   afterthought. Be inventive; this probably doesn't exist yet. What Dan wants to see:
   - **bytes moving between L1, L2, L3 and memory** over the course of a compile, stage by stage: a
     flow whose width is bytes per second, say, or the address space as strips per data structure
     (source, tokens, tree, types, C text) that light up in the color of the level that served each
     access;
   - **before and after** for each change, side by side, so a hash-map lookup (scattered sparks into
     memory) visibly turns into a sweep (one bright line), and the reason a change is faster is seen
     before any number is read;
   - the ladder over time, commit by commit;
   - at the top, a plain TL;DR in numbers ("W2: 41 s -> 9 s; the C we emit is 2.6x smaller").
   Regenerate it at every milestone from real runs, never by hand.
4. **`research/FINDINGS.md`**, short: each change in SHAPES.md's style (before, observation, fix,
   number), plus what Goose made easy, forced, or couldn't express.

## How to see bytes move

Settle this in M0 and write down what works on the run's VM.

- Hardware counters first (`perf stat`: cache references and misses per level, if the VM exposes
  them). On spawn the PMU devices list has no `ibs_op`, so AMD's per-access load sampling is probably
  not available under KVM; check on the run's VM.
- When counters can't say where an access went, record it: an instrumentation tool (DynamoRIO's
  `drcachesim`, Valgrind's `cachegrind`/`lackey`, or `perf mem` if it works) gives every access, a
  cache model replays it, and the record drives the pictures. Slow, but exact and repeatable, and
  noise-free, which this shared VM needs.
- Counting by hand is fine too: bytes allocated per stage, passes over each array, bytes of C written.
  A count explains a time and doesn't drift.

## Measuring on a noisy machine

The VM shares its host with other VMs. Seconds-scale work is the point partly because it shrugs off
noise. Still: at least five interleaved runs for any comparison, report min / median / max, a
difference counts only when the ranges don't overlap; note `uptime` next to a measurement; never wait
for a quiet machine. Cache simulations and counts don't need repeats.

## Rules

- **`src/` is the reference, read freely.** No clean-room rule this time: studying how the C++
  compiler lays out its data is part of the work. Don't change `src/` except to add measurement
  hooks, and then on a separate commit that says so.
- **Upstream.** spawn merges `aardappel/goose` master into this fork's master every hour (a merge,
  never a force). Upstream moves fast (265 commits in three weeks) and may change the language under
  `selfhost/`; W2's fixtures and the fixed point will say so, and keeping up is part of the work. Never
  push, open PRs, or file issues on `aardappel/goose`.
- **Never stop to ask.** Pick the most ambitious step you can justify, write why in
  `research/JOURNAL.md`, and do it. Decisions that are Dan's go in `research/STATUS.md`; keep working.
- **Horizon.** This runs for days. Time left, usage left and "the next session" are never reasons to
  decline or shrink a step. The only valid reason is a measurement.
- **Calibrate on the record.** In bottom-up an agent took a C linker from nothing to matching the stock
  linker on the Go standard library in about an hour; the Goose compiler itself was written mostly by
  Fable from a human design. A language feature in `selfhost/` is hours, not days.
- **Commit and push often** with real messages; absolute numbers and `date -u` timestamps.

## Anti-goals

- Shaving milliseconds off a stage that is already a small part of the ladder.
- Reports that are only markdown: if a result can't be run with `./research/demo` or seen on the
  pictures page, it isn't finished.
- Benchmark-harness polish for its own sake.
- Declining or shrinking work because of time left, usage, or a session ending.
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
Now: M0 + M1 in parallel (updated 2026-11-17 02:25 UTC). Merged: demo, feat-stdlib (interim), feat-enums
(interim), scan-index. Boards run 40/776, reject 39/2036, stdlib 6/17; fixed point holds. Running: builders
`viz`, `feat-stdlib`, `feat-storage` (must rebase: conflicts in checker/emitter), `feat-enums`, `emit-dedup`;
codex on `feat-builtins` (/home/exedev/goose-builtins; its 0ec1d8ed claims check_length_* pass but they
cc-error on master: re-verify before merging). Merge rule: merge a branch only when it merges cleanly and
`python3 selfhost/scoreboard.py --enforce` passes on the merge; then `--update`. M0 closes when viz lands
(first picture on :8000): then do LOOP's milestone steps.
# STATUS (at most ten lines; updated at every milestone and whenever Dan is needed)

2026-11-17 01:55 UTC, M0 done. Oracle: run 63/776, reject 39/2036, stdlib 6/17, W1 fixed point yes.
Speed (W1, median): self-hosted 0.20 s front end + 7.28 s gcc; stock optimized 0.36 + 6.10 s; stock fast 0.97 s.
Moved: symbol index + overload chain (front end ~3x), emit-dedup (C 5.24 -> 1.91 MB, gcc 14.5 -> 6.3 s, one input).
Pictures: :8000 (bytes per data structure, per cache level). Next: M1 clusters (4 builders + codex), emit-lean,
before/after pictures, like-for-like W2.

## Decisions for Dan
- None.
# LADDER

Source to running program, per workload and rung (research/CHARTER.md). Written by `research/demo --ladder` from a real run; do not edit by hand.

- command: `research/demo --full --ladder`
- date: 2026-11-17 01:50 UTC, commit 98bae32d
- uptime: `01:50:13 up 42 min,  0 user,  load average: 3.46, 3.73, 3.78`
- W2: 771 positive fixtures (all); the wall rows are the felt numbers, the (sum) rows add each process's wall time.

What does not run on the self-hosted rung today:

- 19_vm: stdlib/std.goose:1155:13: error: argument count mismatch
- 21_raytrace: stdlib/vec.goose:60:44: error: numeric operands required
- 31_mini_doom: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer

W2 on self-hosted: 73/771 pass (0 skipped); the largest failure clusters (first error):

- 97: front end: error: argument count mismatch (e.g. `cycle_scratch_locals`)
- 84: front end: error: not implemented yet: relative and optional references (e.g. `decayed_references`)
- 71: front end: error: expected top-level declaration (e.g. `bulk_default_loops`)
- 39: front end: error: not implemented yet: custom formatting dispatch (e.g. `codegen_exec`)
- 24: front end: error: not implemented yet: variable-mode enums (e.g. `adt_adaptation`)
- 23: front end: error: expected identifier (e.g. `defer_exits`)
- 16: front end: error: not implemented yet: whole resizable assignment analysis (e.g. `assign_path_after`)
- 14: front end: error: not implemented yet: reference rebinding analysis (e.g. `compare_order`)
- 14: front end: error: global declarations require an initializer (e.g. `relative_declarations`)
- 11: run: stdout (e.g. `const_global_folding`)
- 11: front end: error: cannot find import gfx.goose (e.g. `gfx_compute`)
- 10: front end: error: expected ';', got 'in' (e.g. `index_call_cached_counts`)


### W1

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | front end (C++) | 0.320 | 0.363 | 0.416 | 5 | 287.61 KB | 2.19 MB | 72.9 MB | ok: - |
| - | stock optimized | C compiler (gcc -O2) | 5.822 | 6.096 | 6.611 | 5 | 2.19 MB | 451.99 KB | 292.8 MB | ok: - |
| - | stock optimized | run (compile selfhost) | 0.138 | 0.141 | 0.161 | 5 | 287.61 KB | 2.10 MB | 53.7 MB | ok: - |
| - | stock optimized | check | 0.002 | 0.003 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | stock fast | front end+TinyCC+run | 0.883 | 0.966 | 1.065 | 5 | 287.61 KB | 2.10 MB | 123.4 MB | ok: - |
| - | stock fast | check | 0.002 | 0.003 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | self-hosted | front end (sh2) | 0.177 | 0.201 | 0.230 | 5 | 287.61 KB | 2.10 MB | 55.4 MB | ok: - |
| - | self-hosted | C compiler (gcc -O2) | 6.818 | 7.283 | 7.603 | 5 | 2.10 MB | 446.22 KB | 309.7 MB | ok: - |
| - | self-hosted | run (compile selfhost) | 0.186 | 0.197 | 0.231 | 5 | 287.61 KB | 2.10 MB | 55.3 MB | ok: - |
| - | self-hosted | check | 0.003 | 0.005 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |

Source to running program (W1, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| - | stock optimized | 6.282 | 6.667 | 7.089 |
| - | stock fast | 0.883 | 0.966 | 1.065 |
| - | self-hosted | 7.181 | 7.726 | 8.004 |

### W3

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| vm | stock optimized | front end (C++) | 0.021 | 0.032 | 0.036 | 5 | 5.03 KB | 141.58 KB | 26.6 MB | ok: - |
| vm | stock optimized | C compiler (gcc -O2) | 0.118 | 0.139 | 0.152 | 5 | 141.58 KB | 84.30 KB | 33.4 MB | ok: - |
| vm | stock optimized | run | 0.001 | 0.002 | 0.002 | 5 | 4.10 KB | 512 B | 26.6 MB | ok: - |
| vm | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | stock fast | front end+TinyCC+run | 0.021 | 0.035 | 0.042 | 5 | 5.03 KB | 512 B | 26.6 MB | ok: - |
| vm | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | self-hosted | front end (sh2) | 0.008 | 0.008 | 0.008 | 1 | 5.03 KB | 0 B | 24.4 MB | FAIL: unsupported: stdlib/std.goose:1155:13: error: argument count mismatch |
| raytrace | stock optimized | front end (C++) | 0.032 | 0.040 | 0.047 | 5 | 5.46 KB | 162.87 KB | 26.6 MB | ok: - |
| raytrace | stock optimized | C compiler (gcc -O2) | 0.225 | 0.240 | 0.251 | 5 | 162.87 KB | 88.30 KB | 41.5 MB | ok: - |
| raytrace | stock optimized | run | 0.005 | 0.007 | 0.010 | 5 | 4.10 KB | 2.06 KB | 26.6 MB | ok: - |
| raytrace | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | stock fast | front end+TinyCC+run | 0.069 | 0.092 | 0.106 | 5 | 5.46 KB | 2.06 KB | 26.6 MB | ok: - |
| raytrace | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | self-hosted | front end (sh2) | 0.009 | 0.009 | 0.009 | 1 | 5.46 KB | 0 B | 24.4 MB | FAIL: unsupported: stdlib/vec.goose:60:44: error: numeric operands required |
| mini_doom | stock optimized | front end (C++) | 0.097 | 0.103 | 0.123 | 5 | 69.61 KB | 962.91 KB | 28.6 MB | ok: - |
| mini_doom | stock optimized | C compiler (gcc -O2) | 1.910 | 1.981 | 2.021 | 5 | 962.91 KB | 3.99 MB | 108.6 MB | ok: - |
| mini_doom | stock optimized | run | 0.475 | 0.517 | 0.603 | 5 | 4.10 KB | 42 B | 237.0 MB | ok: - |
| mini_doom | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | stock fast | front end+TinyCC+run | 0.590 | 0.673 | 0.787 | 5 | 69.61 KB | 42 B | 252.9 MB | ok: - |
| mini_doom | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | self-hosted | front end (sh2) | 0.002 | 0.002 | 0.002 | 1 | 69.61 KB | 0 B | 24.4 MB | FAIL: unsupported: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer |

Source to running program (W3, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| vm | stock optimized | 0.153 | 0.173 | 0.173 |
| vm | stock fast | 0.021 | 0.035 | 0.042 |
| vm | self-hosted | does not run | | |
| raytrace | stock optimized | 0.266 | 0.282 | 0.308 |
| raytrace | stock fast | 0.069 | 0.092 | 0.106 |
| raytrace | self-hosted | does not run | | |
| mini_doom | stock optimized | 2.558 | 2.600 | 2.729 |
| mini_doom | stock fast | 0.590 | 0.673 | 0.787 |
| mini_doom | self-hosted | does not run | | |

### W2

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | goose build (sum) | 150.044 | 204.378 | 309.226 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | run (sum) | 4.475 | 6.027 | 9.797 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | wall, 771 fixtures -j8 | 19.738 | 27.021 | 40.607 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
| - | stock fast | goose x.goose (fe+tcc+run) (sum) | 18.818 | 26.847 | 32.062 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
| - | stock fast | wall, 771 fixtures -j8 | 2.679 | 3.753 | 4.545 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
| - | self-hosted | front end (sh2) (sum) | 3.535 | 4.913 | 5.752 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | C compiler (gcc -O2) (sum) | 14.039 | 19.923 | 25.450 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | run (sum) | 0.941 | 1.386 | 1.586 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | wall, 771 fixtures -j8 | 2.541 | 3.519 | 4.376 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
# FINDINGS

Each change: before, observation, fix, number (the style of simd-lang SHAPES.md). Then what Goose made easy, forced, or could not express.

## 1. Two linear scans were 63% of the self-hosted front end (2026-11-17)
**Before.** W1 front end (stage 2 emitting C for selfhost/) 0.30-0.33 s. perf: 42% in find_symbol, which scanned
every symbol backwards for each name lookup, and 21% in reaches_function, which scanned every checked call for
each specialization a DFS visited, once per call. **Observation.** Both answer a question whose answer depends
only on data that is fixed when it is asked: symbols are never removed or renamed; the call graph is complete
when the recursive-cycle test runs. **Fix.** A (scope, name) hash with chains through a parallel array
(newest first, so the latest declaration still wins); and the call graph laid out once as offsets + targets with
one Tarjan pass storing each specialization's component on it ("store the answer on the thing"; "partition,
then join"). **Number.** 0.11-0.14 s over 7 interleaved runs (load ~5), every fixture's outcome identical.
**Goose.** Forced: neither helper may shrink a ctx array (a `resize(0)` or a `pop` makes every caller "may shrink
ctx", which the checker then rejects at call sites that write through ctx after the call, §5.1), so the
table grows in place and the Tarjan stack keeps its own top index. Easy: parallel arrays of i64 are the natural
data shape.

## 2. Overload resolution scanned every symbol twice per overloaded call (2026-11-17)
**Before.** After finding 1, W1 front end 0.13-0.18 s, 1,019 M user instructions; perf: 22% in overload_member,
called for every symbol by resolve_overload. **Fix.** Overloads share the (scope, name) bucket of finding 1's
hash: walk that chain only. **Number.** 0.09-0.14 s (7 interleaved runs, load 9.4: the ranges touch at 0.14, so
the count is the proof): 647 M instructions (-37%); outcomes identical. **Goose.** Forced: a local list of
candidates is rejected (§7.8: a non-fixed-size local may not be in scope across a call into its own recursive
cycle), so the loop walks the chain directly, which needed the order-independence argument written in the code.

## 3. Half the C was the same functions again (2026-11-17)
**Before.** Specializations are keyed on each view argument's provenance (root, readonly, held), which the
checker needs and the C doesn't: W1's C held each function about twice, small helpers up to 198 times
(research/notes/dedup.md). **Fix (emit-dedup).** Names numbered per function; references to other functions
and frames marked in the text; classes refined to a fixed point; one body written per class
(research/notes/emit-dedup.md). **Number (lead's re-check, same input: emit-dedup's selfhost source,
compiled by the emitter before and after).** C 5,236,874 -> 1,906,276 bytes; gcc -O2 14.17/14.48/15.01 ->
6.10/6.29/6.57 s (5 interleaved, load 2-4); peak 425 -> 284 MB; both compilers emit identical C for it.
SHAPES.md killed this idea for Go at 8% duplicate code; here it was 52-64%.
**Goose.** Forced: the scratch buffer can't shrink while ctx holds slices into other arrays, so it stays
as big as all functions' text.
# JOURNAL

Append-only: one line per commit, a paragraph at each milestone.

- 2026-11-17 setup: charter, plan, loop and harness; selfhost/ seeded from test/goose_in_goose (upstream 3a0aa2eb).
- 2026-11-17 M0 setup: VM is 8 cores EPYC 9554P/31 GB; research/setup.sh installs cmake, perf (6.8 tools), valgrind, SDL deps, lavapipe; C++ compiler built with all packages (mini_doom runs headless). W2 stock suite (run_tests.py, 8 jobs) 54.4 s wall, all pass; goose_in_goose bootstrap 24.5 s. Builders launched: demo (branch demo), bytes/viz (branch viz).
- 2026-11-17 selfhost/scoreboard.py: bootstrap + fixed point + three boards. Baseline: run 23/776, reject 3/2035 (1951 exit 1 but markers unmatched, 80 accepted), stdlib 0/17; fixed point yes; 16 s on 8 cores. Biggest cluster: stdlib/std.goose:1348 parameter defaults don't parse (168 run fixtures).
- 2026-11-17 tcc rung: tcc compiles sh2.c in 0.07 s and holds the fixed point, but the tcc-built compiler runs W1 18x slower (5.9 s vs 0.32 s); research/notes/tcc-rung.md.
- 2026-11-17 scan-index: find_symbol hashed by (scope, name), recursive-cycle test by SCC over a CSR call graph: W1 front end 0.30-0.33 -> 0.11-0.14 s; outcomes identical; selfhost/tests/ joins the reject board (4/2036).
- 2026-11-17 overloads walk their (scope, name) chain: W1 front end 1,019 M -> 647 M instructions, 0.13-0.18 -> 0.09-0.14 s; outcomes identical.
- 2026-11-17 selfhost --check accepts a module that declares no main, as a library (stdlib 0 -> 2/17)
- 2026-11-17 selfhost parameter defaults, mined from the October gap-param-defaults branch (run 23->24, reject 3->7)
- 2026-11-17 selfhost fixed multiple results and multi-target receivers, mined from gap-multi-return (run 24->26)
- 2026-11-17 selfhost function modifiers (simd, inline, checkfree, export), adapting named constants and float lets, int-to-float, as! float, loops without break as bottom (stdlib 2->6/17, reject 7->14)
- 2026-11-17 selfhost constant folding and joined constant branches, constness-generic parameters, struct literal '..', bytes_of, src_file/src_line, unreached view params rooted globally, field-default cycles and the 16-deep instantiation bound, Goose-spelled types in diagnostics (run 26->30, reject 14->18)
- 2026-11-17 research/demo: the ladder for W1, W2 (sampled or --full), W3, stage by stage, with --before and a JSON record per run.
- 2026-11-17 LADDER.md and research/runs/20261117T013206Z-de28e5b6.json from a full demo run (W1 4.1/2.6/10.6 s; W2 22.5/2.7 s stock, self-hosted 30/771).
- 2026-11-17 feat-enums: fixed-mode enums, variant types/constructors/constants, match over enums and integers (coverage, overlap, binders), results generic over constness, instantiation chain limit.
- 2026-11-17 selfhost shift compound assignments take any integer count; unreached view params rooted without a held bound; index the symbols project_result pushes (tried name-based liveness at shrinks: unsound, it lost 31 rejections, reverted)
- 2026-11-17 emit-dedup: the selfhost emitter numbers names per function, writes refs as markers and partitions specializations to a fixed point; W1 sh2.c 1104 -> 195 functions, 4.51 MB -> 1.73 MB, 0 duplicate bytes; gcc -O2 11.82/12.63/13.36 s -> 5.54/5.74/6.30 s (load 4-7); front end -2.8% instructions; fixed point holds, scoreboard --enforce passes. research/notes/emit-dedup.md.
- 2026-11-17 feat-storage: selfhost gets limited arrays (T[..k] fixed struct, T[..]) and packed variable-size storage (T[], T[uN], T[varint], variable struct fields, varint), pop_n.
- 2026-11-17 feat-storage rebased on master (enums, stdlib): run 40 -> 63, reject 39, stdlib 6; index_symbol added for two unindexed temporary-root pushes.
- 2026-11-17 viz: bytemove, a Valgrind tool that replays every data access through a Zen 4 cache model (L1 32K/L2 1M/L3 32M victim), with stage marks and region dumps.
- 2026-11-17 viz: first picture (address-space strips by cache level, per-stage bytes for both front ends, counters) and METHOD.md; self-hosted moves 19.7 GB into L1 vs 0.77 GB for C++, 97% of its misses in the checker rescanning symbols/scopes.
- 2026-11-17 merged emit-dedup, feat-storage, viz; lead re-check of emit-dedup on one input: 5.24 -> 1.91 MB of C, gcc -O2 14.2-15.0 -> 6.1-6.6 s. Boards run 63/776, reject 39/2036, stdlib 6/17.

**M0 (2026-11-17 01:50 UTC).** The ladder runs on this VM for W1, W2 and three W3 samples, and `research/demo`
prints it stage by stage. Bytes are seen two ways: perf's Zen 4 fill counters for totals, and a Valgrind tool
with a model of this CPU's caches for per-access attribution (50x slowdown; matches cachegrind's L1 misses to
0.03%); the first picture shows the self-hosted front end pulling 25x the C++ front end's bytes into L1, 97% of
it the checker re-reading symbol and scope tables. Before M0 closed, three byte-saving changes landed:
the symbol hash index and the overload chain walk (front end 0.30-0.33 -> 0.09-0.14 s on the old W1) and
emit-dedup (one input: 5.24 -> 1.91 MB of C, gcc -O2 14.2-15.0 -> 6.1-6.6 s). The self-hosted compiler's C for
W1 is now smaller than the C++ compiler's (2.10 vs 2.19 MB), but gcc still takes longer on it (7.28 vs 6.10 s):
its C is harder to compile per byte (emit-lean is on that). **What did the oracle number do since the last
milestone?** This is the first: run 23 -> 63/776, reject 3 -> 39/2036, stdlib 0 -> 6/17, fixed point held
throughout. Self-hosted W1 is still 1.2x stock optimized, and W2 can't be compared until more fixtures pass;
demo2 is adding a like-for-like W2 row (the fixtures the selfhost passes, through every rung).

exec
/bin/bash -lc 'cat README.md research/viz/README.md research/viz/METHOD.md; cat research/demo' in /home/exedev/goose-w
 succeeded in 0ms:
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/logo_white_fg_trans_bg_mini.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/logo/logo_black_fg_white_bg_mini.png">
  <img alt="The Goose programming language" src="docs/logo/logo_black_fg_white_bg_mini.png">
</picture>

# The Goose Programming Language

A memory-safe systems language with no heap allocator, garbage collector, or
lifetime annotations. In this repository's benchmarks, Goose runs faster than
C++ and Rust while using less memory.

[Tutorial](docs/tutorial.md) · [Reference](docs/reference.md) ·
[Specification](docs/goose_spec.md) · [Command line](docs/command_line.md) ·
[Packages](docs/packages.md) ·
[Samples](samples/README.md) · [Benchmarks](bench/results.md) ·
[Standard library](docs/stdlib.md)

Goose has syntax familiar to C and Rust programmers, but **there is no heap**.
Every dynamic value lives inline on data stacks managed by the compiler.
Growth advances a pointer, and memory is freed when its scope ends. The
language's type and lifetime rules make this memory model safe to use.

[![Discord Chat](https://img.shields.io/badge/chat-discord-blue)](https://discord.gg/397eZdbnsR)
[![Twitter Follow](https://img.shields.io/twitter/follow/wvo.svg?style=social)](https://twitter.com/wvo)

## Why Goose

* **Faster than C++ and than safe Rust, while memory safe.** Over sixteen
  benchmarks Goose runs at 3.3x the speed of idiomatic C++, 1.16x hand-optimized
  C++ and 1.12x the best safe Rust, and uses 1.9x, 1.3x and 1.2x less memory
  ([results](bench/results.md)). These gains
  come from Goose's data layouts and memory model.
* **No allocator, no GC, no reference counting, no destructors.** Memory is a
  handful of data stacks that the compiler assigns statically. Freeing a
  structure with a million elements takes a single store, no matter how
  deeply it is nested.
* **Growth preserves references.** A reference into a growing array stays valid for as
  long as the array does. In the corresponding benchmarks, Goose keeps typed
  references where C++ must call `reserve` and safe Rust uses `u32` indices.
* **Memory safe with zero annotations.** There is no lifetime syntax, there
  are no aliasing or exclusivity rules, and there is no `unsafe`. The compiler
  infers what every reference is rooted at and rejects references that could
  outlive their owners.
* **Nested data stays inline.** A string, an array of strings, a record with
  variable-size fields and an array of those records are each stored as one
  contiguous block that contains no pointers. A example record that takes 160 bytes
  and one allocation in C++ takes 29 bytes and no allocations in Goose.
* **Variable sized Enums.** Variable-mode ADTs store each value at
  the size of its own variant rather than that of the largest variant. On the
  benchmark that exercises this, they use 4x less memory than a Rust `enum`
  and run at 2x its speed.
* **Links narrower than pointers.** A relative reference stores a typed, checked
  link as a 1, 2 or 4-byte offset. Structures built from them are position
  independent, so a data structure can be written to a file as is. Saving
  it is a single write, and loading it is a single read followed by a
  verification pass that rejects malformed or hostile data.
* **Everything is built in place, guaranteed.** A value is constructed at its
  final destination through any depth of calls. `items.push(parse(line))`
  writes the parsed record directly into the array, and returning a growable
  array by value does not copy it.
* **Returns across multiple calls.** `return err from load` returns from a
  function any number of frames up the call stack. It is checked statically,
  and needs no unwinder, no `Result` type and no `?` on every call.
* **Threads with no shared memory.** A worker is compiled as a separate program
  with its own memory, and flat values are passed between threads through
  typed queues with a `memcpy`. Data races, locks, atomics and memory
  orderings do not exist in the language.
* **Generics and higher-order functions with no overhead.** An untyped
  parameter is generic. Function values are compile-time entities, so
  `xs.filter() { it > 0 }` compiles to what the handwrittend loop would looks like and builds its
  result directly in its destination.
* **Compiles to C and can call C.** Goose compiles to one C file, so it runs wherever
  a C compiler does and calls C directly through `extern fn`. The bundled
  TinyCC backend compiles and runs a program in-process, with no build step.

The [tutorial](docs/tutorial.md) walks through all of this by example, the
[reference](docs/reference.md) covers the whole language topic by topic,
the [specification](docs/goose_spec.md) has the exact rules, and the
[benchmarks](bench/results.md) have the numbers, including the cases where
Goose loses.

## Features

This section focuses on what distinguishes Goose. The [tutorial](docs/tutorial.md)
explains these features in more detail, and the [samples](samples/README.md)
show them in thirty-one complete programs.

### One memory model: data stacks freed at scope exit

A program has the native call stack, static data and N data stacks, where the
compiler works out N. A data stack is a large address-space reservation with a
bump pointer, and there is no other memory. At most one resizable value is
live per stack and it is always on top, so growth never moves anything and
never checks a capacity. All of this is proved at compile time; the runtime
tracks only the bump pointers.

```goose
for round in 3 {
    var scratch: u8[>..] = [];                        // grow-only: growth is a pointer bump
    for i in 100000 { scratch.push((i % 256) as! u8); }
    print("round ", round, ": ", scratch.len, " bytes");
}                                                     // the free: one store to the stack top
```

### Memory never moves, so references survive growth

```goose
struct Item { id: i32, weight: f32 }

var items: Item[>..] = [];
let first .= items.push(Item { 1, 0.5 });             // a reference to element 0
for i: i32 in 2..1000001 { items.push(Item { i, 0.0 }); }
first.weight = 99.5;                                  // still valid, a million pushes later
```

`push` returns a reference to the new element, so a program can link elements
while building the array. A `vector<T>` or `Vec<T>` may reallocate and cannot
provide this guarantee. Stable references account for several benchmark gains.

### Safe references, no annotations

Every reference and slice has a static *root*: the variable that bounds its
target's lifetime. A reference must not outlive the variable that owns its
target or access that target through an incompatible type. The compiler infers
roots and specializes functions for them, so no annotations are needed. There
are no aliasing or exclusivity rules. When a lifetime check fails, the error
names the reference's root and its destination:

```goose
fn longest(a: u8[:], b: u8[:]) -> u8[:] { if a.len >= b.len { a } else { b } }

var outer: u8[>..] = [];
var w = outer[..];
{
    var inner: u8[>..] = [];
    format(inner, "inner text");
    w = longest(outer, inner);     // error: storing a reference rooted at inner,
}                                  //        which does not outlive the destination (§9.2)
```

A slice `T[:]` lets a function accept a range from any array kind without
copying its elements. For example, `split` returns slices into its input, and
a dictionary keyed by `u8[:]` stores views of strings rather than copies.

### Nested data stays inline

There is no single array type. Instead there is a family of array types that
differ only in how their size can change. Every member is laid out as
`[metadata][elements...]`, inline and packed, never as a pointer to a separate
block of elements:

| Type | What it is |
|---|---|
| `T[k]` | fixed size, known at compile time |
| `T[]`, `T[varint]` | sized at construction, frozen after; a fixed or variable-width length |
| `T[..k]`, `T[..]` | capacity inline; grows and shrinks within it |
| `T[>..]` | **grow-only**: the most commonly used kind; references into it stay valid |
| `T[>..<]` | **grow-shrink**: stacks, queues, heaps |

Strings are `u8` arrays: `u8[>..]` is a builder, `u8[]` a finished string
stored inline in whatever holds it, `u8[..16]` a small string inside a struct,
`u8[:]` a view. A struct may contain variable-size parts, which are stored
inline in declaration order, so a record is a sequence of bytes with no
indirection in it:

```goose
struct Item  { sku: u8[varint], qty: varint, cents: varint }
struct Order { id: varint, customer: u8[varint], items: Item[varint] }

var book: Order[>..] = [];
book.push(Order { id: 1001, customer: "alice",
                  items: [Item { sku: "SKU-441", qty: 2, cents: 1999 },
                          Item { sku: "SKU-7", qty: 1, cents: 500 }] });
```

That order is **29 bytes and 0 allocations**. As C++ `std::string` +
`std::vector<Item>` it is 160 bytes and 1 allocation, and as Rust `String` +
`Vec<Item>` it is 153 bytes and 4 allocations. An entire order book is a single
array, so reading it streams through the cache. The trade-off is that an array
of variable-size elements is sequential: you can iterate it but not index it
(unless you keep a second array of references into it as an index).

### Enums in two sizes

Algebraic data types are the only form of dynamic polymorphism; there is no
inheritance and there are no vtables. Every ADT can be stored in two ways,
chosen at the point of use. Fixed mode (`Shape`) stores a tag plus room for
the largest payload, so values can be indexed and overwritten. Variable mode
(`Shape..`) gives each value exactly the size of its variant. An array of
such values becomes sequential and a value never changes variant, but in
exchange you may take references *into* a payload:

```goose
enum Shape { Circle { r: f64 }, Rect { w: f64, h: f64 }, Dot }

var packed: Shape..[>..] = [];                 // 9, 17 and 1 bytes, not 17 each
packed.push(Shape.Circle { r: 1.0 });
packed.push(Shape.Rect { w: 2.0, h: 3.0 });
packed.push(Shape.Dot);
for s in packed {
    match s { Rect &r => { r.w += 1.0; }, _ => {} }   // edits the payload in place, inside the array
}
```

*Case functions* provide another way to dispatch on a variant: define one
overload per variant. Calls dispatch on the tag through a jump table, and the
compiler checks that the overloads cover every variant:

```goose
fn area(s: Shape.Circle) -> f64 { 3.14159 * s.r * s.r }
fn area(s: Shape.Rect) -> f64   { s.w * s.h }
fn area(s: Shape.Dot) -> f64    { 0.0 }

for s in packed { print(s, " area ", area(s)); }
```

### Links narrower than pointers

A `T&` is a machine address: it takes eight bytes and never dangles. A
*relative reference* is the same link stored as a narrow offset. A `T&<u32>`
is measured from the field itself to a target in the same array, so the
structure is position independent. A `T&<u32 in pool>` is measured from the
base of a named pool, so other arrays can link into the pool. `T&<u32>?` uses
offset 0 as null. Here is a binary search tree in one grow-only array, with
12-byte nodes:

```goose
struct Node { key: i32, left: Node&<u32>?, right: Node&<u32>? }   // 12 bytes, links included

fn insert(pool: Node[>..]&, key: i32) {
    if pool.len == 0 { pool.push(Node { key: key }); return; }
    var cur .= pool[0];                             // .= binds a reference; = would copy the node
    loop {
        if key == cur.key { return; }
        let next = if key < cur.key { cur.left } else { cur.right };
        if next { cur .= next; continue; }          // narrowed by `if`: next is a Node&
        if key < cur.key { cur.left .= pool.push(Node { key: key }); }
        else             { cur.right .= pool.push(Node { key: key }); }
        return;
    }
}
```

References are transparent (there is no `*` or `->`). `.=` binds or retargets
a reference, and `Node?` is a nullable reference that `if`, `guard` and
`assert` narrow. The insert is one push and one store, and the push cannot
invalidate `cur`. When lifetimes are not nested, the standard library's
[`slot_pool<T>`](docs/stdlib.md#slot_pool) pairs a grow-only `items` array
with a freelist. `alloc_ref` reuses a free slot or
pushes a new one, and `free` returns a slot to the pool. Since a slot's memory
is never actually freed, a stale slot reads a *different value of the correct
type* rather than corrupting memory.

[`slice_pool<T>`](docs/stdlib.md#slice_pool) provides contiguous runs with
allocation, free and resize operations. The language features `reusable` and
`reusable[]` are **deprecated** in favor of these pool types. They remain
available for existing code and the [remaining migration gaps](docs/design/root_structs.md#separate-follow-up-reusable-pools-in-the-stdlib);
removal is a later step.

### Saving and loading data as bytes

```goose
var image: u8[>..] = tree.to_bytes();           // a framed byte image of the whole array
var loaded, ok = from_bytes<Node[>..]>(image);  // verified before it becomes a value
image[image.len - 3] = 200;                     // tamper with a link ...
var bad, bok = from_bytes<Node[>..]>(image);    // ... and it is false and an empty array
```

The tree's links are self-relative, so the tree means the same thing wherever
it is stored. Saving it writes its bytes and loading it reads them back, with
no serializer, no schema and no pointer fixups. `from_bytes` checks the
framing, every tag, every length and every link before the bytes become a
value, so a corrupt or hostile file makes it return `false`, never a wild
reference.

### In-place construction

The copy-free construction guarantee
([spec §4.3](docs/goose_spec.md#43-the-in-place-construction-guarantee)) says a
constructed value is always built at its final location, which is passed down
through calls. A function returning a grow-only array by value writes its
elements directly into the caller's variable, or into a field of the record
being built inside another array, so out-parameters are rarely needed.

```goose
words.push(str("word", i));                    // formatted straight into the new element
let evens = xs.filter() { it % 2 == 0 };       // built straight into `evens`: no temporary
book.push(Order { id: 1001, customer: "alice", items: parse_items("SKU-441:2:1999;SKU-7:1:500") });
```

### Returning errors across calls

```goose
struct User { name: u8[..16], age: i32 }

fn load(text: u8[:]) -> User[>..], u8[] {
    var users: User[>..] = [];
    each_split(text, '\n') { users.push(parse_user(it)); };
    return users, "";
}

fn parse_user(line: u8[:]) -> User {              // returns a User: no Result, no error parameter
    let comma = find(line, ",");
    guard comma >= 0 else { return [], str("expected name,age: ", line) from load; }
    let age, ok = parse_int(line[comma + 1..]);
    guard ok else { return [], str("bad age: ", line) from load; }
    let name = trim(line[..comma]);
    return User { name: name, age: age as i32 };
}
```

`return E from f` returns `E` as the result of the innermost active call of
`f`, however many frames up that call is. Every function in between keeps its
plain signature. The construct is checked statically: every call of
`parse_user` must lie inside a `load` call, so nothing can go uncaught at
runtime. It is implemented as a hidden discriminant checked in each frame
rather than as an unwinder, and the message is built directly where `load`'s
caller wants it. The parsers in the samples use it for every syntax error.

### Generics and function blocks

```goose
fn twice(x) { x + x }                              // an untyped parameter is a generic one

fn each_pair<T, F>(xs: T[:]) {                     // F is a function value: a compile-time entity
    for i in 0..xs.len - 1 { F(xs[i], xs[i + 1]); }
}

fn first_gap(xs: i64[:]) -> i64 {
    each_pair(xs) { a, b => if b - a > 1 { return a; } };   // returns from first_gap, not each_pair
    return -1;
}

let evens = xs.filter() { it % 2 == 0 };
let total = fold(xs, 0) { acc, x => acc + x };
sort(xs) { a, b => a > b };
```

Everything is monomorphized. Type arguments are inferred from argument types;
type parameters that do not appear in those types can be supplied explicitly.
Function values are passed as generic parameters. Every call of a function
value is direct and can be inlined, function values cannot escape, and there
are no closure objects or function pointers, so a higher-order function
compiles to exactly the loop it looks like. A block may `return` from its
lexically enclosing function, and nested functions can use the enclosing
function's locals.

### Threads with no shared memory

```goose
thread_fn worker() {                                // a separate program with its own memory
    loop {
        let job = qget<Job>();                      // blocks on the typed queue for Job
        guard job.n >= 0 else { break; }            // -1 means stop
        qput(Result { n: job.n, digits: count_digits(job.n) });
    }
}

for i in n { ids.push(thread_spawn(worker)); }
```

There is no shared mutable memory. A `thread_fn` and everything it calls is
compiled as its own program with its own data stacks and its own copies of the
globals. Values are passed between threads through typed queues, one per
type, and must be *flat*, with no references at any depth. Passing them is
cheap because a flat Goose value is contiguous: a job or a result can carry
real data, such as pixels, and passing it is a single `memcpy`.

A failed check or `abort` in a worker started with `thread_spawn_contained`
ends only that worker. Its message goes to whoever waits for it, not to
stderr, so a supervisor can log it and start another:

```goose
var why: u8[>..] = [];
while !thread_wait(thread_spawn_contained(serve, attempt), why) {
    log(why);                                       // "assert failed (serve.goose:12)"
    why.clear();
    attempt++;
}
```

The first `thread_wait(id, msg)` for a worker takes the message; a caller
that doesn't ask for it loses it.

### Compiling to and calling C

```goose
extern fn hypot(x: f64, y: f64) -> f64;             // straight from libm
extern fn crc32_bytes(s: const u8[:]) -> u32;       // a slice crosses as { data, len }
extern fn stats_of(xs: i32[:], out: Stats&);        // a struct filled through a pointer
```

An `extern fn` binds a Goose signature to a C symbol. The `math` and `os`
modules use this interface. Only types with supported C representations may
cross the boundary; unsupported signatures are rejected at the declaration.
The compiler emits one C file for the whole program. The bundled TinyCC
backend can compile and run that C inside the Goose compiler's process.

### Where the speed comes from

Much of the speed comes from the memory model: no heap allocation or
per-object teardown, contiguous data, narrow links, and enums sized for the
variant they contain. Every index is bounds-checked, and the compiler removes
checks it can prove unnecessary. An `assert` on a slice length often lets the
compiler remove the remaining checks in a kernel, so that the kernel can be
vectorized. `--bce-lines` reports the checks that remain. `checkfree fn`
rejects a kernel if any bounds check remains in it; index types let graph
edges keep the validation done while the graph was built.
Benchmark measurements use whole-process wall-clock time, including teardown.

| Geometric mean over 16 benchmarks | vs idiomatic C++ | vs hand-optimized C++ | vs best safe Rust |
|---|---:|---:|---:|
| speed, MSVC backend | 3.51x | 1.24x | 1.13x |
| speed, clang backend | 3.54x | 1.26x | 1.19x |
| peak memory | 1.95x less | 1.32x less | 1.25x less |

The [summary](bench/summary.md) explains the gains and losses;
[results.md](bench/results.md) has every measurement, and
[design.md](bench/design.md) explains what the suite tests.

### Limitations

* You have to think about where data lives: who owns it, and how long its
  scope lasts. Usually the owner is the function that builds the data, which
  needs no extra work; when it is not, use a `slot_pool` or `slice_pool`.
* Recursive functions cannot keep growable data across a recursive call.
  Scratch data must end before the call, and data that outlives the call is
  passed in as a pool.
* Arrays of variable-size elements can be iterated but not indexed (unless
  you keep an index of references beside them). A fixed-mode enum cannot be
  pointed into, and a variable-mode one cannot be overwritten. You make this
  choice per container.
* There are no escaping closures, no function pointers and no dynamic
  dispatch beyond ADT tags, and only whole-program compilation is supported.
* A slot that was returned to a pool but is still referenced
  reads whatever its next owner put there. That is a logic bug, but never
  memory corruption.

[Tutorial §18](docs/tutorial.md#18-limitations) is the full list.

## Install a release

Prebuilt compilers for Windows (x64), Linux (x64) and macOS (Apple silicon
and Intel) are on the [releases page](https://github.com/aardappel/goose/releases),
with the graphics, audio, ui and physics packages compiled in. Unpack one
anywhere and put its directory on PATH: the compiler finds the standard
library, TinyCC's runtime and the packages beside itself, and keeps what it
builds under `~/.goose` (`GOOSE_HOME`). The archive also holds these docs, the
samples and the VS Code extension.

Each release also has `SHA256SUMS`, the SHA-256 of every archive. In the
directory an archive was downloaded to, `sha256sum -c --ignore-missing
SHA256SUMS` checks it (on macOS, `shasum -a 256` in place of `sha256sum`); on
Windows, `Get-FileHash` prints the hash to compare with the archive's line.

Running a program in-process (`goose file.goose`) needs nothing else on
Windows. On Linux it needs the C library's headers (`libc6-dev`, or
`glibc-devel`); on macOS, the SDK of the Xcode command line tools
(`xcode-select --install`). `goose build` also needs a C compiler: Visual
Studio 2022 or later, or clang, on Windows; gcc or clang elsewhere. The Linux
compiler needs glibc 2.35 or later (Ubuntu 22.04, Debian 12), and the macOS
compiler needs macOS 13.3 or later. macOS keeps a downloaded archive's files
from running until `xattr -dr com.apple.quarantine` is run on the unpacked
directory.

On macOS, a recent release is also on Homebrew: `brew install goose-lang`.

## Build and run

You need CMake 3.27 or later, a C++20 compiler (MSVC, clang or gcc) and Python
3 for the test and sample runners. TinyCC, which the in-process backend is
built from, is part of the tree. The graphics, audio, ui and physics
modules are packages in repositories of their own
([goose_gfx](https://github.com/aardappel/goose_gfx) and
[goose_physics](https://github.com/aardappel/goose_physics);
`docs/design/packages.md`). `-DGOOSE_BUILTIN_LIBS=all` fetches them with git
at configure time, at the pinned tags, and compiles them into the compiler,
so programs that use them run with nothing else installed. Without that
option the compiler is built on its own, and the first time a program
imports one of these packages, the package is built into `~/.goose`, which
needs git, cmake and a C compiler.

```bash
git clone https://github.com/aardappel/goose
cd goose
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGOOSE_BUILTIN_LIBS=all
cmake --build build --config Release
```

`GOOSE_BUILTIN_LIBS` can also name some of the packages (`physics`, or
`gfx`, which includes `audio` and `ui` too). On
Linux, SDL needs the X11 or Wayland development packages
([`third_party/SDL/docs/README-linux.md`](https://github.com/libsdl-org/SDL/blob/main/docs/README-linux.md));
without them the build leaves the `gfx` module out and says what to install.

The runner scripts prefer `build/Release`, then `build/RelWithDebInfo`, then
`build`, then `build/Debug`. Pass `--exe` to select a specific compiler; use an
explicit Debug executable when testing with compiler assertions enabled.
The compiler is `build/goose` (`build/Release/goose.exe` with the Visual Studio
generator), and it finds the standard library in the source tree it was built
from. On Windows 10 version 1903 and later, its embedded manifest selects a
UTF-8 process code page so compiler paths do not depend on the system locale.
Earlier Windows versions retain their legacy code page. Generated native
executables retain their own process settings.

Run a program directly from source, in-process, with no C compiler and no
build step (`goose run` is the explicit form of the same command):

```bash
build/goose samples/01_tour.goose
```

Or build an executable, which is written beside the source. The compiler
finds a C compiler on the machine (`goose toolchain` shows which one) and
links the generated C with the runtime and any native modules the program
uses, including graphics. Programs that use threads must be built this way,
since TinyCC cannot place thread-local storage.

```bash
build/goose build samples/01_tour.goose && samples/01_tour
build/goose build samples/27_gfx_cube.goose && samples/27_gfx_cube
```

`goose check` only typechecks. `--debug` turns on the overflow, range and
tag checks, each of which names its source line when it fails, and
`--bce-lines` reports the bounds checks that remain on each line. Every
resizable value lives on a data stack of 2 GB of reserved address space,
committed as it is used, and `--stack-reserve 16G` changes that size.
[The command line](docs/command_line.md) describes every command and
option, including how to write the C for a build system or a C host of your
own (`goose -o tour.c tour.goose`).

A program with C of its own lists that C in a sidecar file beside the
source, `foo.build` beside `foo.goose`: `c_sources = ["impl.c"];`. Both
forms build that C, so an `extern fn` can call it either way. A program uses
a library by writing `import name from "source";` in its root file. The
source is a directory (`"./lib"`), or a git repository at a tag or commit
(`"owner/repo@v1"` on GitHub, `"host/owner/repo@ref"`), which is fetched
into `~/.goose` and built there once per C compiler
([packages](docs/packages.md)).

A program using `audio` plays procedural mono/stereo PCM through SDL3 without
opening a graphics window. See the [audio reference](docs/stdlib.md#audio).

The test suite and the samples run on Windows, macOS and Linux:

```bash
python test/run_tests.py
python samples/run_samples.py
```

For editing, the [VS Code extension](vscode/README.md) gives syntax
highlighting, the compiler's language server (`goose lsp`: errors as you
type, hover, go to definition, completion, rename, symbols) and one-key runs
through the JIT:

```bash
code --install-extension vscode/goose-language.vsix
```

Other editors can run `goose lsp` themselves; [editors](docs/editors.md)
has the configuration for Neovim, Helix and Emacs.

## Documentation

* [Documentation index](docs/index.md): the map of everything below, and
  the root of the documentation site built from these files
  ([how](docs/site/README.md)).
* [Tutorial](docs/tutorial.md): the friendly introduction, by example. Read
  this first.
* [Language reference](docs/reference.md): every feature, topic by topic,
  with a compiling example for each. It covers the whole language and is
  written to be read.
* [Language specification](docs/goose_spec.md): the exact rules, when you want
  to know why something did not compile.
* [Samples](samples/README.md): thirty-one complete programs in reading
  order, from a tour of the language to a JSON parser, a threaded Mandelbrot, a
  file tree built from two pools, a spinning cube on the GPU, thousands of
  boxes raining into a heap and a to-do list in windows of widgets.
* [Standard library](docs/stdlib.md): fourteen modules, all written in readable
  Goose under `stdlib/`. They include `gfx` for graphics on SDL3's GPU API ([how
  it is built](https://github.com/aardappel/goose_gfx/blob/main/docs/gfx.md))
  and `physics` for rigid body physics on Box3D ([how it is
  built](https://github.com/aardappel/goose_physics/blob/main/docs/physics.md)).
  The `ui` module provides fonts, [text rendering and game
  HUDs](docs/stdlib.md#text-rendering-and-game-huds). It also provides windows
  and widgets on Nuklear, drawn through gfx ([how it is
  built](https://github.com/aardappel/goose_gfx/blob/main/docs/ui.md)).
* [The command line](docs/command_line.md): every command and option of
  `goose`, from running and building to writing the C yourself, the
  formatter and the language server.
* [Building programs and using packages](docs/packages.md): libraries from
  git repositories or directories, a program's own C, and how to make a
  package of your own.
* [Benchmarks](bench/summary.md): the numbers, with the
  [full results](bench/results.md) and the [design](bench/design.md) behind them.
* [Implementation notes](docs/implementation.md): how the compiler works, pass
  by pass, and [how it is tested](docs/testing.md).

## Status

Goose is new. What exists today is a whole-program compiler of about thirty
thousand lines of C++, the specification, the standard library, the samples,
and a test suite that CI runs on Windows, macOS and Linux with an extra
sanitizer job. These are deliberately out of scope for now: moves for
resizable values, more than one resizable per struct, labeled `break`,
namespace privacy, and more OS/library access. Open items are tracked in the
[specification's Appendix B](docs/goose_spec.md#appendix-b-todo--open-items).

## License

Goose is licensed under the [Apache License, Version 2.0](LICENSE).

## Authors

**Wouter van Oortmerssen**: Language Design, Compiler Design, Coding standards.
[home](https://strlen.com/) page, [twitter](https://x.com/wvo).

**Claude Fable**: Compiler implementation, Benchmarking, Sample & Doc writing.

## History & Use of AI

This repo was produced almost entirely with AI, from a human language design.
I had designed Goose several years ago, and had started to implement it,
but running a game startup (which is built on another programming language of mine,
[Lobster](https://strlen.com/lobster/)) there was no time to finish it.
Which was sad, because I knew Goose could do things other languages can't,
and it should exist.

I had not expected AI to help with this until Fable came out. I thought it
might be capable enough to do a good job.
I made it essentially clone the style and structure of my other recent compiler
(Lobster), which is why if you look at the code, it looks rather similar to that.
My initial design had left lots of things unspecified, and lots of back and forth
with Fable made me decide on all of those, and it is now a better language for it.

It is also an experiment in using AI to implement a new language, rather than
reproduce an existing one.

You may wonder why I had it work in C++, if clearly I could have used any
language, like Rust, or my own Lobster, or.. Goose itself (that may still happen).
With Fable, it was my observation that it is almost equally capable in any
language, and the strong guardrails of Rust or other languages are not as pressing
as they once were.
Since the compiler emits C, you likely already need to have a C/C++ compiler around,
so sticking inside one ecosystem would seem to simplify deployment and adoption.
I've also integrated libtcc and who knows what other C libraries in the future.
And, like I said, to have the compiler code mimic my existing Lobster compiler seemed
fun, at least I can read it like it is my own.
# viz

The pictures page (research/CHARTER.md, Deliverables 3), served on port 8000. Generated from real runs by the scripts here; never edited by hand.

- `index.html`: the page, built by `build.py` from `page.html`, `data/*.json` and `../runs/*.json`.
- `METHOD.md`: how bytes are seen moving on this VM, with the evidence.
- `trace/`: the bytemove Valgrind tool, stage marking, reduction, counters; `trace/run.sh` regenerates everything.
- Served by `python3 -m http.server 8000 --directory /home/exedev/goose/research/viz` (log: /tmp/viz-server.log).
# How bytes are seen moving on this VM (settled in M0, 2026-11-17)

VM: AMD EPYC 9554P (Zen 4) under KVM, 8 vCPUs, L1D 32 KB 8-way, L2 1 MB 8-way per core,
L3 32 MB (one CCD visible), 64-byte lines. Workload W1: each front end compiling `selfhost/`
(13 modules, 3,321 lines) to C.

## The method

1. **Counters for real totals** (`trace/counters.sh`, `data/counters.json`). Five interleaved runs
   per front end and per cumulative mode (`--parse`, `--check`, `-o out.c`); a stage is the
   difference between modes. Three groups of at most six events each, so nothing is multiplexed.
2. **A simulation for per-access attribution** (`trace/bytemove.c`, a Valgrind tool of our own).
   Every load and store goes through a model of this CPU's caches: L1D 32 KB 8-way, L2 1 MB 8-way
   inclusive of L1, L3 32 MB 16-way filled by L2 victims (exclusive), 64-byte lines, LRU, write-allocate,
   dirty write-backs counted, **no hardware prefetcher**. For each access it records the level that
   served it. It tags stages by function entry (`--marks`, sticky or by call extent through the stack
   pointer), counts exactly per (stage, 64 KB chunk, level, read/write), writes a pseudo-randomly
   sampled trace (one access in 64) for the pictures, logs every mmap/munmap/brk with the file name,
   and dumps the self-hosted runtime's data-stack table (`gg_stacks`) at each stage change.
3. **Regions** (`trace/reduce.py`). Self-hosted compiler: every table in `run_compilation`
   (selfhost/context.goose) is a resizable on a data stack of its own; `gg_stacks[frame.base + k]`
   holds table k in declaration order. The base is found as the stack whose top equals the size of the
   C written (that is `c_final`, k = 11) in the dump taken entering `write`; the other 23 follow, and
   any other data stack is "temporaries". The machine stack comes from the stack-pointer range the tool
   saw. C++ compiler: machine stacks, heap (brk and anonymous mmaps, glibc arenas), image (file-backed
   mappings and the .bss right after them). The C++ heap is not split by data structure yet (that needs
   malloc call-site tagging; a later step).
4. **Stages.** Self-hosted: `trace/stagemarks.py` finds lex, parse, load_program,
   register_declarations, check_program, generate_c in the emitted C by shape (all functions are
   `gg_function_N`), and marks them `noinline` in a copy (`sh2m`) built `-O2 -g -no-pie`; the copy
   writes byte-identical C. lex and parse are extents (lex runs inside parse for each import), the
   rest sticky. C++: `ParseProgram`, `ResolveTypeNames` (check), `Optimizer`/`BCE::RunAll`
   (optimize), `CodeGen::CodeGen` (emit), `WriteFileMakingDirs` (write), all sticky.

`trace/run.sh` does all of it from source and rebuilds `index.html` (about 2 minutes).

## Evidence

**PMU.** `/sys/bus/event_source/devices` has `cpu` but no `ibs_op`/`ibs_fetch`: IBS is absent under
this KVM, so no per-access hardware sampling. `perf mem record` fails: "memory events not supported".
`perf list` knows the Zen 4 events and they count (user space, paranoid=2):
`ls_dmnd_fills_from_sys.{local_l2, local_ccx, dram_io_near}` are non-zero; `near_cache`, `far_cache`,
`dram_io_far` read 0 (single socket, as expected); `l2_pf_hit_l2.all` reads 0 (prefetch events seem
not to be passed through). `LLC-*` unsupported, `L1-dcache-load-misses` reads 0, so the generic
aliases are useless here: use the raw AMD names.

**Simulation vs cachegrind vs counters**, self-hosted front end on W1 (same binary, sh2m):

| | bytemove | cachegrind (`--cache-sim=yes`, D1 32K/8, LL 32M/16) | perf, median of 5 (sh2) |
|---|---|---|---|
| instructions | 3.866 G | 3.864 G | 3.84 G |
| data accesses | 1.070 G | 1.065 G D refs | 0.95 G loads + 0.13 G stores dispatched |
| L1 misses | 307.3 M | 307.4 M | 279.9 M demand fills from L2 + 2.8 M from L3 + 0.17 M from DRAM; 367 M fills of any kind |
| served by memory | 0.52 M | 0.515 M LLd misses | 0.17 M demand from DRAM |

The model agrees with cachegrind's L1 to 0.03%. Against the hardware, the simulation's L1 misses
are within 10% of the demand fills; the gap is what the L1 prefetchers bring in ahead of demand
(the "any" fills, 367 M, include them). For the C++ front end: simulated 8.75 M L2 + 2.49 M L3 + 0.84 M
memory; measured 9.1 M demand fills from L2, 1.0 M from L3, 0.6 M from DRAM. Level by level the
simulation overstates L3 and memory for C++ (no prefetcher) but the totals and the ranking hold: 307 M vs 12 M L1 misses simulated, 283 M vs 10.7 M measured (26x and 25x).

Calibration (`trace/calib.c`, random 8-byte reads, 4 M of them): working set 16 KB -> 100% L1;
512 KB -> 94% L2; 8 MB -> 91% L3; 256 MB -> memory for every miss. The model behaves.

**Cost.**

| | native | under bytemove | slowdown | raw trace | committed |
|---|---|---|---|---|---|
| self-hosted, W1 | 0.31-0.34 s | 17.8 s | ~55x | 134 MB samples + 54 KB exact | 1.0 MB JSON |
| C++, W1 | 0.21-0.22 s | 9.3 s | ~43x | 70 MB samples | 0.55 MB JSON |
| cachegrind, self-hosted | | 14.5 s | ~45x | | totals only |
| lackey `--trace-mem=yes`, self-hosted `--parse` only (57 M instr) | 0.016 s | 91 s | ~5,700x | see below | |

Lackey prints a text line per access and per instruction: extrapolated to the full compile (3.9 G
instructions) that is about 100 minutes and tens of GB of text before any cache model runs, so
"lackey piped into a model" was rejected in favour of the model inside the tool.

**DynamoRIO.** github.com is reachable from the VM (HTTP 200 on the releases page), so drcachesim
could be downloaded, but it is not needed: Ubuntu's valgrind package ships the headers and the static
core libraries (`/usr/lib/x86_64-linux-gnu/valgrind/libcoregrind-amd64-linux.a`, `libvex-...a`), so an
out-of-tree tool builds in a second (`trace/build.sh`), and its model is exactly ours. Revisit
drcachesim only if we need prefetcher models or a 10x faster trace.

## Caveats

- No hardware prefetcher in the model: a sequential sweep shows as one L2 (or memory) line per 64 bytes
  where the hardware would have most of them in L1 already. Sweeps still look like sweeps (thin bright
  lines), and the counters keep us honest about totals.
- The traced self-hosted binary is `sh2m`: the same C with six functions marked `noinline` and
  built `-no-pie`; its instruction count is within 0.7% of sh2's.
- Time on the x axis is data accesses, not seconds; seconds per stage come from the counters.
- An access spanning two lines is counted once, at the farther level.
#!/usr/bin/env python3
"""research/demo: the ladder (research/CHARTER.md), measured stage by stage.

Builds each workload through each rung that runs today, printing one line per
stage as it goes (rung, stage, wall time, bytes in and out, peak RSS, how the
output was checked), runs what it built and checks it, then prints
min/median/max per stage. Every measurement is also written to
research/runs/<UTC timestamp>-<shortsha>.json (a list of records
{workload, rung, stage, run, seconds, bytes_in, bytes_out, peak_rss_kb, check,
ok}, plus `item` where a workload has several programs).

Workloads:
  W1  selfhost/ compiling itself (stock optimized, stock fast, self-hosted;
      checked by the C fixed point)
  W2  positive fixtures with blessed output (every 10th by default, --full for
      all); stock rungs timed, self-hosted rung counted
  W3  samples 19_vm, 21_raytrace, 31_mini_doom (headless), checked against
      samples/expected/

Usage:
  research/demo                 everything, 5 interleaved runs
  research/demo --quick         everything, 1 run
  research/demo --only W1,W3    some workloads
  research/demo --before REV    also build REV's selfhost/ and run it alongside
  research/demo --full          W2 over every positive fixture
  research/demo --ladder        also rewrite research/LADDER.md from this run

Build products go to build/demo/. The C++ compiler is $GOOSE (default
/home/exedev/goose/build/goose, else build/goose in this tree).
"""

import argparse
import datetime
import json
import os
import platform
import re
import shlex
import shutil
import statistics
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
B = ROOT / "build" / "demo"
SAMPLES = ["19_vm", "21_raytrace", "31_mini_doom"]
W2_EXCLUDED_DIRS = ("errors", "errors_tc", "goose_in_goose", "lsp", "packages")
TIMEOUT = 900


def find_goose():
    for p in (os.environ.get("GOOSE"), "/home/exedev/goose/build/goose", ROOT / "build" / "goose"):
        if p and Path(p).is_file() and os.access(p, os.X_OK):
            return str(p)
    sys.exit("demo: no goose compiler (set GOOSE=path)")


GOOSE = find_goose()
CC = shutil.which("gcc") or shutil.which("cc")


# --- measuring one process --------------------------------------------------

class Result:
    __slots__ = ("code", "seconds", "rss_kb", "out", "err")


def measure(argv, cwd=None, stdin=None, out=None, timeout=TIMEOUT):
    """Run argv; wall time, peak RSS (os.wait4's ru_maxrss), exit code; its
    stdout goes to `out` (a path) or is captured, its stderr is captured."""
    B.mkdir(parents=True, exist_ok=True)
    errf = open(B / f".stderr-{threading.get_ident()}", "w+b")
    outf = open(out, "wb") if out else open(B / f".stdout-{threading.get_ident()}", "w+b")
    inf = open(stdin, "rb") if stdin else subprocess.DEVNULL
    try:
        t0 = time.perf_counter()
        p = subprocess.Popen([str(a) for a in argv], cwd=cwd, stdin=inf, stdout=outf, stderr=errf)
        timer = threading.Timer(timeout, p.kill)
        timer.start()
        _, status, ru = os.wait4(p.pid, 0)
        r = Result()
        r.seconds = time.perf_counter() - t0
        timer.cancel()
        p.returncode = r.code = os.waitstatus_to_exitcode(status)
        r.rss_kb = ru.ru_maxrss
        errf.seek(0)
        r.err = errf.read().decode("utf-8", "replace")
        if out:
            r.out = None
        else:
            outf.seek(0)
            r.out = outf.read().decode("utf-8", "replace")
        return r
    finally:
        errf.close()
        outf.close()
        if stdin:
            inf.close()


def size(p):
    try:
        return Path(p).stat().st_size
    except OSError:
        return 0


def tree_bytes(d):
    return sum(size(f) for f in Path(d).glob("*.goose"))


def normalized(text):
    return text.replace("\r\n", "\n").rstrip("\n")


def first_error(r):
    for line in (r.err + (r.out or "")).splitlines():
        if line.strip():
            return line.strip().replace(str(ROOT) + "/", "")[:160]
    return f"exit {r.code}"


def human(n):
    if n is None:
        return "-"
    for unit, scale in (("GB", 1e9), ("MB", 1e6), ("KB", 1e3)):
        if n >= scale:
            return f"{n / scale:.2f} {unit}"
    return f"{n} B"


# --- the record -------------------------------------------------------------

RECORDS = []
W2_FAILURES = {}   # rung -> (passed, ran, fixtures, [(first failure, [fixtures])])
PRINT_LOCK = threading.Lock()


def record(workload, rung, stage, run, seconds, bytes_in, bytes_out, rss_kb, check, ok,
           item=None, quiet=False):
    rec = {"workload": workload, "rung": rung, "stage": stage, "run": run,
           "seconds": round(seconds, 6) if seconds is not None else None,
           "bytes_in": bytes_in, "bytes_out": bytes_out, "peak_rss_kb": rss_kb,
           "check": check, "ok": ok}
    if item:
        rec["item"] = item
    RECORDS.append(rec)
    if not quiet:
        what = f"{workload}{'/' + item if item else ''}"
        secs = f"{seconds:8.3f} s" if seconds is not None else "       - s"
        rss = f"{rss_kb / 1024:7.1f} MB" if rss_kb else "        -"
        line = (f"{what:<16} {rung:<26} {stage:<26} run {run}  {secs}  in {human(bytes_in):>9}"
                f"  out {human(bytes_out):>9}  rss {rss}  {'ok  ' if ok else 'FAIL'} {check}")
        with PRINT_LOCK:
            print(line, flush=True)
    return rec


def step(workload, rung, stage, run, argv, bytes_in, out_path=None, check="-", item=None,
         cwd=None, stdin=None, bytes_out=None):
    """Measure one stage, print and record it; returns the Result (ok = exit 0)."""
    r = measure(argv, cwd=cwd or ROOT, stdin=stdin)   # out_path is the product, sized
    if bytes_out is None:
        bytes_out = size(out_path) if out_path else len((r.out or "").encode())
    ok = r.code == 0
    record(workload, rung, stage, run, r.seconds, bytes_in, bytes_out, r.rss_kb,
           check if ok else f"exit {r.code}: {first_error(r)}", ok, item)
    return r


def check_cmp(workload, rung, run, a, b, what, item=None):
    t0 = time.perf_counter()
    ok = Path(a).exists() and Path(b).exists() and Path(a).read_bytes() == Path(b).read_bytes()
    record(workload, rung, "check", run, time.perf_counter() - t0, size(a) + size(b), 0, None,
           f"fixed point cmp: {what}" + ("" if ok else " DIFFER"), ok, item)
    return ok


def check_out(workload, rung, run, got, want_path, item=None):
    t0 = time.perf_counter()
    want = normalized(Path(want_path).read_text(encoding="utf-8", errors="replace"))
    ok = got is not None and normalized(got) == want
    record(workload, rung, "check", run, time.perf_counter() - t0, len(want.encode()), 0, None,
           f"blessed output match: {Path(want_path).relative_to(ROOT)}" + ("" if ok else " MISMATCH"),
           ok, item)
    return ok


# --- the C compiler command `goose build` would run -------------------------

def build_cc_command(src, exe, extra=(), cwd=None):
    """`goose build --dry-run`'s commands: builds the runtime object if it is
    missing and returns the program's own C compile, as an argv whose C file
    is the first .c argument (to be replaced by ours)."""
    r = measure([GOOSE, "build", "-O2", *extra, "-o", exe, "--dry-run", src], cwd=cwd or ROOT)
    if r.code != 0:
        return None, first_error(r)
    lines = [l for l in r.out.splitlines() if l.strip()]
    for l in lines[:-1]:
        argv = shlex.split(l)
        target = argv[argv.index("-o") + 1] if "-o" in argv else None
        if target and not Path(target).exists():
            # The runtime object (or a package's) is built once per GOOSE_HOME:
            # one real build makes it, outside any measurement.
            measure([GOOSE, "build", "-O2", *extra, "-o", exe, src], cwd=cwd or ROOT)
            break
    argv = shlex.split(lines[-1])
    ci = next(i for i, a in enumerate(argv) if a.endswith(".c"))
    return (argv, ci), None


def cc_argv(cmd, cfile, exe):
    argv, ci = cmd
    argv = list(argv)
    argv[ci] = str(cfile)
    argv[argv.index("-o") + 1] = str(exe)
    return argv


# --- trees: the selfhost/ under test, now and --before ----------------------

class Tree:
    def __init__(self, label, root, src):
        self.label = label          # "" for now, "@sha" for --before
        self.root = Path(root)      # the cwd its compilers run in (stdlib/ is found there)
        self.src = Path(src)        # the directory with main.goose
        self.dir = B / ("now" if not label else "before-" + label[1:])
        self.dir.mkdir(parents=True, exist_ok=True)
        self.sh2 = self.dir / "sh2"
        self.ref = self.dir / "sh3.c"
        self.ok = False

    def rung(self, name):
        return name + self.label


def bootstrap(tree):
    """sh1 = goose build selfhost; sh1 -> sh2.c; gcc -> sh2; sh2 -> sh3.c;
    sh2.c == sh3.c. Recorded as run 0."""
    d, main = tree.dir, tree.src / "main.goose"
    nbytes = tree_bytes(tree.src)
    rung = tree.rung("bootstrap")
    print(f"-- bootstrap {tree.src} --", flush=True)
    cmd, err = build_cc_command(main, d / "sh1", cwd=tree.root)
    if not cmd:
        record("W1", rung, "goose build --dry-run", 0, None, nbytes, 0, None, err, False)
        return False
    steps = [
        ("sh1: C++ front end", [GOOSE, "-O2", "-o", d / "sh1.c", main], d / "sh1.c", nbytes),
        ("sh1: C compiler", cc_argv(cmd, d / "sh1.c", d / "sh1"), d / "sh1", None),
        ("sh2.c: sh1 front end", [d / "sh1", "-o", d / "sh2.c", main], d / "sh2.c", nbytes),
        ("sh2: gcc -O2", [CC, "-O2", d / "sh2.c", "-o", d / "sh2", "-lm"], d / "sh2", None),
        ("sh3.c: sh2 front end", [d / "sh2", "-o", d / "sh3.c", main], d / "sh3.c", nbytes),
    ]
    prev = None
    for stage, argv, out, nin in steps:
        r = measure(argv, cwd=tree.root)
        nin = nin if nin is not None else size(prev)
        record("W1", rung, stage, 0, r.seconds, nin, size(out), r.rss_kb,
               "-" if r.code == 0 else f"exit {r.code}: {first_error(r)}", r.code == 0)
        if r.code != 0:
            return False
        prev = out
    tree.ok = check_cmp("W1", rung, 0, d / "sh2.c", d / "sh3.c", "sh2.c == sh3.c")
    tree.cc = cmd
    return tree.ok


# --- W1 ----------------------------------------------------------------------

def w1(tree, run, rungs):
    d, main, nbytes = tree.dir, tree.src / "main.goose", tree_bytes(tree.src)
    for rung in rungs:
        name = tree.rung(rung)
        if rung == "stock optimized":
            c, exe, outc = d / "so.c", d / "so", d / "so.out.c"
            if step("W1", name, "front end (C++)", run, [GOOSE, "-O2", "-o", c, main], nbytes, c,
                    cwd=tree.root).code:
                continue
            if step("W1", name, "C compiler (gcc -O2)", run, cc_argv(tree.cc, c, exe), size(c), exe,
                    cwd=tree.root).code:
                continue
            if step("W1", name, "run (compile selfhost)", run, [exe, "-o", outc, main], nbytes, outc,
                    cwd=tree.root).code:
                continue
            check_cmp("W1", name, run, outc, tree.ref, "its C == sh3.c")
        elif rung == "stock fast":
            outc = d / "sf.out.c"
            if step("W1", name, "front end+TinyCC+run", run,
                    [GOOSE, "-O2", main, "--", "-o", outc, main], nbytes, outc, cwd=tree.root,
                    bytes_out=None).code:
                continue
            check_cmp("W1", name, run, outc, tree.ref, "its C == sh3.c")
        elif rung == "self-hosted":
            c, exe, outc = d / "sh.c", d / "sh", d / "sh.out.c"
            if step("W1", name, "front end (sh2)", run, [tree.sh2, "-o", c, main], nbytes, c,
                    cwd=tree.root).code:
                continue
            if step("W1", name, "C compiler (gcc -O2)", run, [CC, "-O2", c, "-o", exe, "-lm"],
                    size(c), exe, cwd=tree.root).code:
                continue
            if step("W1", name, "run (compile selfhost)", run, [exe, "-o", outc, main], nbytes, outc,
                    cwd=tree.root).code:
                continue
            check_cmp("W1", name, run, outc, c, "stage n C == stage n+1 C")


# --- W3 ----------------------------------------------------------------------

class Sample:
    def __init__(self, stem):
        self.stem = stem
        self.name = re.sub(r"^\d+_", "", stem)
        self.src = ROOT / "samples" / f"{stem}.goose"
        argf = ROOT / "samples" / "data" / f"{self.name}.args"
        self.args = argf.read_text().split() if argf.exists() else []
        stdin = ROOT / "samples" / "data" / f"{self.name}.stdin"
        self.stdin = stdin if stdin.exists() else None
        h = ROOT / "samples" / f"{self.name}.h"
        self.extra = ["--include", str(h)] if h.exists() else []
        self.expected = ROOT / "samples" / "expected" / f"{self.name}.out"
        self.nbytes = size(self.src)
        self.cc, self.ccerr = build_cc_command(self.src, B / "w3" / self.name, self.extra)
        self.unsupported = {}   # tree label -> first error line


def w3(sample, tree, run, rungs):
    d = B / "w3"
    d.mkdir(parents=True, exist_ok=True)
    cwd = ROOT / "samples"
    it = sample.name
    for rung in rungs:
        name = tree.rung(rung)
        if rung == "stock optimized":
            c, exe = d / f"{it}.so.c", d / f"{it}.so"
            if step("W3", name, "front end (C++)", run,
                    [GOOSE, "-O2", *sample.extra, "-o", c, sample.src], sample.nbytes, c, item=it).code:
                continue
            if not sample.cc:
                record("W3", name, "C compiler (gcc -O2)", run, None, size(c), 0, None,
                       f"no build command: {sample.ccerr}", False, it)
                continue
            if step("W3", name, "C compiler (gcc -O2)", run, cc_argv(sample.cc, c, exe), size(c), exe,
                    item=it).code:
                continue
            r = step("W3", name, "run", run, [exe, *sample.args], size(sample.stdin or ""),
                     item=it, cwd=cwd, stdin=sample.stdin)
            if r.code == 0:
                check_out("W3", name, run, r.out, sample.expected, it)
        elif rung == "stock fast":
            r = step("W3", name, "front end+TinyCC+run", run,
                     [GOOSE, "-O2", *sample.extra, sample.src, "--", *sample.args], sample.nbytes,
                     item=it, cwd=cwd, stdin=sample.stdin)
            if r.code == 0:
                check_out("W3", name, run, r.out, sample.expected, it)
        elif rung == "self-hosted":
            if not tree.ok:
                continue
            c, exe = d / f"{it}.sh{tree.label}.c", d / f"{it}.sh{tree.label}"
            if tree.label in sample.unsupported:
                continue   # said once, in run 1
            r = measure([tree.sh2, "-o", c, sample.src], cwd=tree.root)
            if r.code != 0:
                sample.unsupported[tree.label] = first_error(r)
                record("W3", name, "front end (sh2)", run, r.seconds, sample.nbytes, 0, r.rss_kb,
                       f"unsupported: {first_error(r)}", False, it)
                continue
            record("W3", name, "front end (sh2)", run, r.seconds, sample.nbytes, size(c), r.rss_kb,
                   "-", True, it)
            if step("W3", name, "C compiler (gcc -O2)", run, [CC, "-O2", c, "-o", exe, "-lm"],
                    size(c), exe, item=it).code:
                continue
            r = step("W3", name, "run", run, [exe, *sample.args], size(sample.stdin or ""), item=it,
                     cwd=cwd, stdin=sample.stdin)
            if r.code == 0:
                check_out("W3", name, run, r.out, sample.expected, it)


# --- W2 ----------------------------------------------------------------------

def fixtures(full):
    t = ROOT / "test"
    fs = []
    for f in sorted(t.glob("*/*.goose")):
        if f.parent.name in W2_EXCLUDED_DIRS or f.name == "lexer_tokens.goose":
            continue
        if not (t / "expected" / f"{f.stem}.out").exists() or f.with_suffix(".build").exists():
            continue
        line = f.open(encoding="utf-8", errors="replace").readline()
        if "parse-only" in line:
            continue
        defines = re.findall(r"^// runtime-define: (\w+=\w+)$", line)
        fs.append((f, ["-D" + d for d in defines], "no-jit" in line))
    return fs if full else fs[::10]


def fixture_ok(f, r):
    """Exit status as the suite wants it (an .aborts fixture must fail) and
    stdout equal to the blessed output."""
    e = ROOT / "test" / "expected"
    aborts = (e / f"{f.stem}.aborts").exists()
    if (r.code == 0) == aborts:
        return False, f"exit {r.code}"
    want = normalized((e / f"{f.stem}.out").read_text(encoding="utf-8", errors="replace"))
    return normalized(r.out) == want, "stdout"


def w2_one(rung, f, defines, nojit, tree, d):
    """One fixture through one rung: (stage seconds dict, peak rss, outcome)."""
    exe, c = d / f.stem, d / f"{f.stem}.c"
    secs, rss = {}, 0
    if rung == "stock optimized":
        r = measure([GOOSE, "build", "-O2", *defines, "-o", exe, f])
        secs["goose build"], rss = r.seconds, r.rss_kb
        if r.code:
            return secs, rss, "build failed"
    elif rung == "stock fast":
        if nojit:
            return secs, rss, "skip (no-jit)"
        r = measure([GOOSE, "-O2", *defines, f])
        secs["goose x.goose (fe+tcc+run)"], rss = r.seconds, r.rss_kb
        if r.code and "JIT mode does not support" in r.err:
            return secs, rss, "skip (JIT does not support it)"
        ok, why = fixture_ok(f, r)
        return secs, rss, "pass" if ok else f"run: {why}"
    else:
        r = measure([tree.sh2, "-o", c, f], cwd=tree.root)
        secs["front end (sh2)"], rss = r.seconds, r.rss_kb
        if r.code:
            return secs, rss, "front end: " + re.sub(r"^\S+:\d+:\d+: ", "", first_error(r))[:70]
        r = measure([CC, "-O2", *defines, c, "-o", exe, "-lm", "-pthread"])
        secs["C compiler (gcc -O2)"], rss = r.seconds, max(rss, r.rss_kb)
        if r.code:
            return secs, rss, "C compiler failed"
    r = measure([exe])
    secs["run"], rss = r.seconds, max(rss, r.rss_kb)
    ok, why = fixture_ok(f, r)
    return secs, rss, "pass" if ok else f"run: {why}"


def w2(fs, tree, run, rungs, jobs, show_failures):
    nbytes = sum(size(f) for f, _, _ in fs)
    for rung in rungs:
        name = tree.rung(rung)
        d = B / "w2" / re.sub(r"\W+", "_", name)
        d.mkdir(parents=True, exist_ok=True)
        t0 = time.perf_counter()
        with ThreadPoolExecutor(jobs) as pool:
            res = list(pool.map(lambda x: w2_one(rung, *x, tree, d), fs))
        wall = time.perf_counter() - t0
        outcomes = [o for _, _, o in res]
        ran = [o for o in outcomes if not o.startswith("skip")]
        passed = outcomes.count("pass")
        rss = max((r for _, r, _ in res), default=0)
        stages = {}
        for s, _, _ in res:
            for k, v in s.items():
                stages[k] = stages.get(k, 0) + v
        check = f"blessed output match: {passed}/{len(ran)} pass"
        for k, v in stages.items():
            record("W2", name, f"{k} (sum)", run, v, nbytes, 0, rss, check, passed == len(ran))
        record("W2", name, f"wall, {len(fs)} fixtures -j{jobs}", run, wall, nbytes, 0, rss, check,
               passed == len(ran))
        if show_failures:
            clusters = {}
            for (f, _, _), o in zip(fs, outcomes):
                if o != "pass" and not o.startswith("skip"):
                    clusters.setdefault(o, []).append(f.stem)
            top = sorted(clusters.items(), key=lambda kv: -len(kv[1]))[:12]
            for o, names in top:
                print(f"    {len(names):4}  {o}  (e.g. {names[0]})")
            W2_FAILURES[name] = (passed, len(ran), len(fs), top)


# --- the summary --------------------------------------------------------------

def summary_rows():
    groups = {}
    for r in RECORDS:
        if r["run"] == 0 or r["seconds"] is None:
            continue
        key = (r["workload"], r.get("item", ""), r["rung"], r["stage"])
        groups.setdefault(key, []).append(r)
    rows = []
    for key, rs in groups.items():
        secs = sorted(r["seconds"] for r in rs)
        last = rs[-1]
        rows.append((*key, secs[0], statistics.median(secs), secs[-1], len(secs),
                     last["bytes_in"], last["bytes_out"], max(r["peak_rss_kb"] or 0 for r in rs),
                     all(r["ok"] for r in rs), last["check"]))
    # Source to running program: the stages before check, summed per run.
    # A run counts only when every one of its stages, the check included, is ok;
    # a rung with no such run is listed as not running.
    totals, bad = {}, set()
    for r in RECORDS:
        if r["run"] == 0 or r["workload"] == "W2":
            continue
        key = (r["workload"], r.get("item", ""), r["rung"])
        totals.setdefault(key, {}).setdefault(r["run"], 0.0)
        if not r["ok"] or r["seconds"] is None:
            bad.add((key, r["run"]))
        elif r["stage"] != "check":
            totals[key][r["run"]] += r["seconds"]
    for (key, run) in bad:
        totals[key].pop(run, None)
    return rows, totals


def markdown_tables(rows, totals):
    out = []
    for wl in ("W1", "W3", "W2"):
        wrows = [r for r in rows if r[0] == wl]
        if not wrows:
            continue
        out.append(f"\n### {wl}\n")
        out.append("| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out "
                   "| peak RSS | check |")
        out.append("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|")
        for (w, item, rung, stage, mn, md, mx, n, bi, bo, rss, ok, check) in wrows:
            out.append(f"| {item or '-'} | {rung} | {stage} | {mn:.3f} | {md:.3f} | {mx:.3f} | {n} "
                       f"| {human(bi)} | {human(bo)} | {rss / 1024:.1f} MB | "
                       f"{'ok' if ok else 'FAIL'}: {check} |")
        tots = [(k, v) for k, v in totals.items() if k[0] == wl]
        if tots:
            out.append(f"\nSource to running program ({wl}, stages before the check, summed per run):\n")
            out.append("| item | rung | min s | median s | max s |")
            out.append("|---|---|---:|---:|---:|")
            for (w, item, rung), per in tots:
                v = sorted(per.values())
                if not v:
                    out.append(f"| {item or '-'} | {rung} | does not run | | |")
                    continue
                out.append(f"| {item or '-'} | {rung} | {v[0]:.3f} | {statistics.median(v):.3f} "
                           f"| {v[-1]:.3f} |")
    return "\n".join(out)


def print_summary(rows, totals):
    print("\n== summary: min / median / max seconds ==", flush=True)
    for (w, item, rung, stage, mn, md, mx, n, bi, bo, rss, ok, check) in rows:
        what = f"{w}{'/' + item if item else ''}"
        print(f"{what:<16} {rung:<26} {stage:<34} {mn:8.3f} {md:8.3f} {mx:8.3f}  n={n}  "
              f"{'ok  ' if ok else 'FAIL'} {check}")
    print("\n== source to running program (sum of stages before check) ==")
    for (w, item, rung), per in totals.items():
        v = sorted(per.values())
        what = f"{w}{'/' + item if item else ''}"
        if not v:
            print(f"{what:<16} {rung:<26} does not run (see its FAIL line)")
            continue
        print(f"{what:<16} {rung:<26} {v[0]:8.3f} {statistics.median(v):8.3f} {v[-1]:8.3f}")


# --- main ---------------------------------------------------------------------

def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


def make_before(rev):
    sha = git("rev-parse", "--short", rev)
    wt = Path(f"/tmp/goose-demo-before-{sha}")
    if wt.exists():
        subprocess.run(["git", "worktree", "remove", "--force", f"/tmp/goose-demo-before-{sha}"],
                       cwd=ROOT)
    git("worktree", "add", "--detach", str(wt), sha)
    src = wt / "selfhost"
    if not (src / "main.goose").exists():
        src = wt / "test" / "goose_in_goose"   # before selfhost/ was seeded from it
    return Tree("@" + sha, wt, src), sha


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--runs", type=int, default=None, help="interleaved runs (default 5)")
    ap.add_argument("--quick", action="store_true", help="one run")
    ap.add_argument("--only", default="W1,W3,W2", help="workloads, comma separated")
    ap.add_argument("--full", action="store_true", help="W2 over every positive fixture")
    ap.add_argument("--w2-runs", type=int, default=None,
                    help="runs of W2 (default: --runs)")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 1, help="W2 parallelism")
    ap.add_argument("--before", help="also build this commit's selfhost/ and run it alongside")
    ap.add_argument("--ladder", action="store_true", help="rewrite research/LADDER.md from this run")
    ap.add_argument("--no-record", action="store_true", help="write no research/runs/ JSON")
    args = ap.parse_args()

    # Cap the whole tree of processes at 8 GB, once, by re-running under a
    # systemd scope: no per-process wrapper to distort times or RSS.
    if not os.environ.get("GOOSE_DEMO_SCOPED") and shutil.which("systemd-run"):
        env = dict(os.environ, GOOSE_DEMO_SCOPED="1")
        try:
            os.execvpe("systemd-run", ["systemd-run", "--user", "--scope", "--quiet",
                                       "-p", "MemoryMax=8G", sys.executable, os.path.abspath(sys.argv[0]), *sys.argv[1:]], env)
        except OSError:
            pass

    runs = 1 if args.quick else (args.runs or 5)
    w2runs = args.w2_runs or runs
    only = {w.strip().upper() for w in args.only.split(",")}
    os.environ["GOOSE_GFX_HEADLESS"] = "1"
    os.environ["GOOSE_HOME"] = str(B / "goose-home")
    B.mkdir(parents=True, exist_ok=True)

    sha = git("rev-parse", "--short", "HEAD")
    dirty = bool(git("status", "--porcelain", "--", "selfhost", "research/demo"))
    started = datetime.datetime.now(datetime.timezone.utc)
    up = subprocess.run(["uptime"], capture_output=True, text=True).stdout.strip()
    cmdline = "research/demo " + " ".join(shlex.quote(a) for a in sys.argv[1:])
    print(f"demo {cmdline}\n  commit {sha}{' (dirty)' if dirty else ''}, "
          f"{started:%Y-%m-%d %H:%M:%S} UTC, {platform.node()}, {os.cpu_count()} cpus")
    print(f"  uptime: {up}")
    print(f"  goose {GOOSE}; cc {CC}; runs {runs} (W2 {w2runs}), W2 jobs {args.jobs}", flush=True)

    trees = [Tree("", ROOT, ROOT / "selfhost")]
    before_wt = None
    try:
        if args.before:
            t, bsha = make_before(args.before)
            trees.append(t)
            before_wt = bsha
        for t in trees:
            bootstrap(t)
            if not t.ok:
                print(f"  bootstrap of {t.src} failed: its rungs are skipped", flush=True)

        samples = [Sample(s) for s in SAMPLES] if "W3" in only else []
        fs = fixtures(args.full) if "W2" in only else []

        for run in range(1, runs + 1):
            print(f"\n== run {run}/{runs} ==", flush=True)
            if "W1" in only:
                for t in trees:
                    if t.ok:
                        w1(t, run, ["stock optimized", "stock fast", "self-hosted"])
            for s in samples:
                for i, t in enumerate(trees):
                    w3(s, t, run, ["stock optimized", "stock fast", "self-hosted"] if i == 0
                       else ["self-hosted"])
            if fs and run <= w2runs:
                print(f"-- W2: {len(fs)} positive fixtures{' (every 10th)' if not args.full else ''}"
                      f", -j{args.jobs} --", flush=True)
                for i, t in enumerate(trees):
                    rungs = (["stock optimized", "stock fast"] if i == 0 else []) + \
                            (["self-hosted"] if t.ok else [])
                    w2(fs, t, run, rungs, args.jobs, show_failures=(run == 1))
    finally:
        if before_wt:
            subprocess.run(["git", "worktree", "remove", "--force",
                            f"/tmp/goose-demo-before-{before_wt}"], cwd=ROOT)

    rows, totals = summary_rows()
    print_summary(rows, totals)
    unsupported = [f"{s.stem}{lbl and ' (' + lbl + ')'}: {e}" for s in samples
                   for lbl, e in s.unsupported.items()]
    if unsupported:
        print("\nself-hosted rung, unsupported:")
        for u in unsupported:
            print("  " + u)

    stamp = started.strftime("%Y%m%dT%H%M%SZ")
    if not args.no_record:
        out = ROOT / "research" / "runs" / f"{stamp}-{sha}.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(RECORDS, indent=1) + "\n")
        meta = {"command": cmdline, "commit": sha, "dirty": dirty, "utc": started.isoformat(),
                "uptime": up, "host": platform.node(), "cpus": os.cpu_count(), "goose": GOOSE,
                "cc": CC, "runs": runs, "w2_runs": w2runs, "w2_fixtures": len(fs),
                "w2_full": args.full, "before": args.before}
        out.with_suffix(".meta.json").write_text(json.dumps(meta, indent=1) + "\n")
        print(f"\nrecord: {out.relative_to(ROOT)}")
    if args.ladder:
        write_ladder(rows, totals, cmdline, up, started, sha, unsupported, len(fs), args.full)


def write_ladder(rows, totals, cmdline, up, started, sha, unsupported, nfix, full):
    text = ["# LADDER", "",
            "Source to running program, per workload and rung (research/CHARTER.md). Written by "
            "`research/demo --ladder` from a real run; do not edit by hand.", "",
            f"- command: `{cmdline}`",
            f"- date: {started:%Y-%m-%d %H:%M} UTC, commit {sha}",
            f"- uptime: `{up}`",
            f"- W2: {nfix} positive fixtures{' (all)' if full else ' (every 10th)'}; "
            "the wall rows are the felt numbers, the (sum) rows add each process's wall time.",
            ""]
    if unsupported:
        text.append("What does not run on the self-hosted rung today:\n")
        text += [f"- {u}" for u in unsupported]
        text.append("")
    for rung, (passed, ran, n, top) in W2_FAILURES.items():
        if passed == ran:
            continue
        text.append(f"W2 on {rung}: {passed}/{ran} pass ({n - ran} skipped); the largest failure "
                    "clusters (first error):\n")
        text += [f"- {len(names)}: {o} (e.g. `{names[0]}`)" for o, names in top]
        text.append("")
    text.append(markdown_tables(rows, totals))
    (ROOT / "research" / "LADDER.md").write_text("\n".join(text) + "\n")
    print("wrote research/LADDER.md")


if __name__ == "__main__":
    main()

exec
/bin/bash -lc 'nl -ba research/FINDINGS.md; tail -n 160 research/JOURNAL.md; cat research/viz/METHOD.md research/viz/README.md' in /home/exedev/goose-w
 succeeded in 0ms:
     1	# FINDINGS
     2	
     3	Each change: before, observation, fix, number (the style of simd-lang SHAPES.md). Then what Goose made easy, forced, or could not express.
     4	
     5	## 1. Two linear scans were 63% of the self-hosted front end (2026-11-17)
     6	**Before.** W1 front end (stage 2 emitting C for selfhost/) 0.30-0.33 s. perf: 42% in find_symbol, which scanned
     7	every symbol backwards for each name lookup, and 21% in reaches_function, which scanned every checked call for
     8	each specialization a DFS visited, once per call. **Observation.** Both answer a question whose answer depends
     9	only on data that is fixed when it is asked: symbols are never removed or renamed; the call graph is complete
    10	when the recursive-cycle test runs. **Fix.** A (scope, name) hash with chains through a parallel array
    11	(newest first, so the latest declaration still wins); and the call graph laid out once as offsets + targets with
    12	one Tarjan pass storing each specialization's component on it ("store the answer on the thing"; "partition,
    13	then join"). **Number.** 0.11-0.14 s over 7 interleaved runs (load ~5), every fixture's outcome identical.
    14	**Goose.** Forced: neither helper may shrink a ctx array (a `resize(0)` or a `pop` makes every caller "may shrink
    15	ctx", which the checker then rejects at call sites that write through ctx after the call, §5.1), so the
    16	table grows in place and the Tarjan stack keeps its own top index. Easy: parallel arrays of i64 are the natural
    17	data shape.
    18	
    19	## 2. Overload resolution scanned every symbol twice per overloaded call (2026-11-17)
    20	**Before.** After finding 1, W1 front end 0.13-0.18 s, 1,019 M user instructions; perf: 22% in overload_member,
    21	called for every symbol by resolve_overload. **Fix.** Overloads share the (scope, name) bucket of finding 1's
    22	hash: walk that chain only. **Number.** 0.09-0.14 s (7 interleaved runs, load 9.4: the ranges touch at 0.14, so
    23	the count is the proof): 647 M instructions (-37%); outcomes identical. **Goose.** Forced: a local list of
    24	candidates is rejected (§7.8: a non-fixed-size local may not be in scope across a call into its own recursive
    25	cycle), so the loop walks the chain directly, which needed the order-independence argument written in the code.
    26	
    27	## 3. Half the C was the same functions again (2026-11-17)
    28	**Before.** Specializations are keyed on each view argument's provenance (root, readonly, held), which the
    29	checker needs and the C doesn't: W1's C held each function about twice, small helpers up to 198 times
    30	(research/notes/dedup.md). **Fix (emit-dedup).** Names numbered per function; references to other functions
    31	and frames marked in the text; classes refined to a fixed point; one body written per class
    32	(research/notes/emit-dedup.md). **Number (lead's re-check, same input: emit-dedup's selfhost source,
    33	compiled by the emitter before and after).** C 5,236,874 -> 1,906,276 bytes; gcc -O2 14.17/14.48/15.01 ->
    34	6.10/6.29/6.57 s (5 interleaved, load 2-4); peak 425 -> 284 MB; both compilers emit identical C for it.
    35	SHAPES.md killed this idea for Go at 8% duplicate code; here it was 52-64%.
    36	**Goose.** Forced: the scratch buffer can't shrink while ctx holds slices into other arrays, so it stays
    37	as big as all functions' text.
# JOURNAL

Append-only: one line per commit, a paragraph at each milestone.

- 2026-11-17 setup: charter, plan, loop and harness; selfhost/ seeded from test/goose_in_goose (upstream 3a0aa2eb).
- 2026-11-17 M0 setup: VM is 8 cores EPYC 9554P/31 GB; research/setup.sh installs cmake, perf (6.8 tools), valgrind, SDL deps, lavapipe; C++ compiler built with all packages (mini_doom runs headless). W2 stock suite (run_tests.py, 8 jobs) 54.4 s wall, all pass; goose_in_goose bootstrap 24.5 s. Builders launched: demo (branch demo), bytes/viz (branch viz).
- 2026-11-17 selfhost/scoreboard.py: bootstrap + fixed point + three boards. Baseline: run 23/776, reject 3/2035 (1951 exit 1 but markers unmatched, 80 accepted), stdlib 0/17; fixed point yes; 16 s on 8 cores. Biggest cluster: stdlib/std.goose:1348 parameter defaults don't parse (168 run fixtures).
- 2026-11-17 tcc rung: tcc compiles sh2.c in 0.07 s and holds the fixed point, but the tcc-built compiler runs W1 18x slower (5.9 s vs 0.32 s); research/notes/tcc-rung.md.
- 2026-11-17 scan-index: find_symbol hashed by (scope, name), recursive-cycle test by SCC over a CSR call graph: W1 front end 0.30-0.33 -> 0.11-0.14 s; outcomes identical; selfhost/tests/ joins the reject board (4/2036).
- 2026-11-17 overloads walk their (scope, name) chain: W1 front end 1,019 M -> 647 M instructions, 0.13-0.18 -> 0.09-0.14 s; outcomes identical.
- 2026-11-17 selfhost --check accepts a module that declares no main, as a library (stdlib 0 -> 2/17)
- 2026-11-17 selfhost parameter defaults, mined from the October gap-param-defaults branch (run 23->24, reject 3->7)
- 2026-11-17 selfhost fixed multiple results and multi-target receivers, mined from gap-multi-return (run 24->26)
- 2026-11-17 selfhost function modifiers (simd, inline, checkfree, export), adapting named constants and float lets, int-to-float, as! float, loops without break as bottom (stdlib 2->6/17, reject 7->14)
- 2026-11-17 selfhost constant folding and joined constant branches, constness-generic parameters, struct literal '..', bytes_of, src_file/src_line, unreached view params rooted globally, field-default cycles and the 16-deep instantiation bound, Goose-spelled types in diagnostics (run 26->30, reject 14->18)
- 2026-11-17 research/demo: the ladder for W1, W2 (sampled or --full), W3, stage by stage, with --before and a JSON record per run.
- 2026-11-17 LADDER.md and research/runs/20261117T013206Z-de28e5b6.json from a full demo run (W1 4.1/2.6/10.6 s; W2 22.5/2.7 s stock, self-hosted 30/771).
- 2026-11-17 feat-enums: fixed-mode enums, variant types/constructors/constants, match over enums and integers (coverage, overlap, binders), results generic over constness, instantiation chain limit.
- 2026-11-17 selfhost shift compound assignments take any integer count; unreached view params rooted without a held bound; index the symbols project_result pushes (tried name-based liveness at shrinks: unsound, it lost 31 rejections, reverted)
- 2026-11-17 emit-dedup: the selfhost emitter numbers names per function, writes refs as markers and partitions specializations to a fixed point; W1 sh2.c 1104 -> 195 functions, 4.51 MB -> 1.73 MB, 0 duplicate bytes; gcc -O2 11.82/12.63/13.36 s -> 5.54/5.74/6.30 s (load 4-7); front end -2.8% instructions; fixed point holds, scoreboard --enforce passes. research/notes/emit-dedup.md.
- 2026-11-17 feat-storage: selfhost gets limited arrays (T[..k] fixed struct, T[..]) and packed variable-size storage (T[], T[uN], T[varint], variable struct fields, varint), pop_n.
- 2026-11-17 feat-storage rebased on master (enums, stdlib): run 40 -> 63, reject 39, stdlib 6; index_symbol added for two unindexed temporary-root pushes.
- 2026-11-17 viz: bytemove, a Valgrind tool that replays every data access through a Zen 4 cache model (L1 32K/L2 1M/L3 32M victim), with stage marks and region dumps.
- 2026-11-17 viz: first picture (address-space strips by cache level, per-stage bytes for both front ends, counters) and METHOD.md; self-hosted moves 19.7 GB into L1 vs 0.77 GB for C++, 97% of its misses in the checker rescanning symbols/scopes.
- 2026-11-17 merged emit-dedup, feat-storage, viz; lead re-check of emit-dedup on one input: 5.24 -> 1.91 MB of C, gcc -O2 14.2-15.0 -> 6.1-6.6 s. Boards run 63/776, reject 39/2036, stdlib 6/17.

**M0 (2026-11-17 01:50 UTC).** The ladder runs on this VM for W1, W2 and three W3 samples, and `research/demo`
prints it stage by stage. Bytes are seen two ways: perf's Zen 4 fill counters for totals, and a Valgrind tool
with a model of this CPU's caches for per-access attribution (50x slowdown; matches cachegrind's L1 misses to
0.03%); the first picture shows the self-hosted front end pulling 25x the C++ front end's bytes into L1, 97% of
it the checker re-reading symbol and scope tables. Before M0 closed, three byte-saving changes landed:
the symbol hash index and the overload chain walk (front end 0.30-0.33 -> 0.09-0.14 s on the old W1) and
emit-dedup (one input: 5.24 -> 1.91 MB of C, gcc -O2 14.2-15.0 -> 6.1-6.6 s). The self-hosted compiler's C for
W1 is now smaller than the C++ compiler's (2.10 vs 2.19 MB), but gcc still takes longer on it (7.28 vs 6.10 s):
its C is harder to compile per byte (emit-lean is on that). **What did the oracle number do since the last
milestone?** This is the first: run 23 -> 63/776, reject 3 -> 39/2036, stdlib 0 -> 6/17, fixed point held
throughout. Self-hosted W1 is still 1.2x stock optimized, and W2 can't be compared until more fixtures pass;
demo2 is adding a like-for-like W2 row (the fixtures the selfhost passes, through every rung).
# How bytes are seen moving on this VM (settled in M0, 2026-11-17)

VM: AMD EPYC 9554P (Zen 4) under KVM, 8 vCPUs, L1D 32 KB 8-way, L2 1 MB 8-way per core,
L3 32 MB (one CCD visible), 64-byte lines. Workload W1: each front end compiling `selfhost/`
(13 modules, 3,321 lines) to C.

## The method

1. **Counters for real totals** (`trace/counters.sh`, `data/counters.json`). Five interleaved runs
   per front end and per cumulative mode (`--parse`, `--check`, `-o out.c`); a stage is the
   difference between modes. Three groups of at most six events each, so nothing is multiplexed.
2. **A simulation for per-access attribution** (`trace/bytemove.c`, a Valgrind tool of our own).
   Every load and store goes through a model of this CPU's caches: L1D 32 KB 8-way, L2 1 MB 8-way
   inclusive of L1, L3 32 MB 16-way filled by L2 victims (exclusive), 64-byte lines, LRU, write-allocate,
   dirty write-backs counted, **no hardware prefetcher**. For each access it records the level that
   served it. It tags stages by function entry (`--marks`, sticky or by call extent through the stack
   pointer), counts exactly per (stage, 64 KB chunk, level, read/write), writes a pseudo-randomly
   sampled trace (one access in 64) for the pictures, logs every mmap/munmap/brk with the file name,
   and dumps the self-hosted runtime's data-stack table (`gg_stacks`) at each stage change.
3. **Regions** (`trace/reduce.py`). Self-hosted compiler: every table in `run_compilation`
   (selfhost/context.goose) is a resizable on a data stack of its own; `gg_stacks[frame.base + k]`
   holds table k in declaration order. The base is found as the stack whose top equals the size of the
   C written (that is `c_final`, k = 11) in the dump taken entering `write`; the other 23 follow, and
   any other data stack is "temporaries". The machine stack comes from the stack-pointer range the tool
   saw. C++ compiler: machine stacks, heap (brk and anonymous mmaps, glibc arenas), image (file-backed
   mappings and the .bss right after them). The C++ heap is not split by data structure yet (that needs
   malloc call-site tagging; a later step).
4. **Stages.** Self-hosted: `trace/stagemarks.py` finds lex, parse, load_program,
   register_declarations, check_program, generate_c in the emitted C by shape (all functions are
   `gg_function_N`), and marks them `noinline` in a copy (`sh2m`) built `-O2 -g -no-pie`; the copy
   writes byte-identical C. lex and parse are extents (lex runs inside parse for each import), the
   rest sticky. C++: `ParseProgram`, `ResolveTypeNames` (check), `Optimizer`/`BCE::RunAll`
   (optimize), `CodeGen::CodeGen` (emit), `WriteFileMakingDirs` (write), all sticky.

`trace/run.sh` does all of it from source and rebuilds `index.html` (about 2 minutes).

## Evidence

**PMU.** `/sys/bus/event_source/devices` has `cpu` but no `ibs_op`/`ibs_fetch`: IBS is absent under
this KVM, so no per-access hardware sampling. `perf mem record` fails: "memory events not supported".
`perf list` knows the Zen 4 events and they count (user space, paranoid=2):
`ls_dmnd_fills_from_sys.{local_l2, local_ccx, dram_io_near}` are non-zero; `near_cache`, `far_cache`,
`dram_io_far` read 0 (single socket, as expected); `l2_pf_hit_l2.all` reads 0 (prefetch events seem
not to be passed through). `LLC-*` unsupported, `L1-dcache-load-misses` reads 0, so the generic
aliases are useless here: use the raw AMD names.

**Simulation vs cachegrind vs counters**, self-hosted front end on W1 (same binary, sh2m):

| | bytemove | cachegrind (`--cache-sim=yes`, D1 32K/8, LL 32M/16) | perf, median of 5 (sh2) |
|---|---|---|---|
| instructions | 3.866 G | 3.864 G | 3.84 G |
| data accesses | 1.070 G | 1.065 G D refs | 0.95 G loads + 0.13 G stores dispatched |
| L1 misses | 307.3 M | 307.4 M | 279.9 M demand fills from L2 + 2.8 M from L3 + 0.17 M from DRAM; 367 M fills of any kind |
| served by memory | 0.52 M | 0.515 M LLd misses | 0.17 M demand from DRAM |

The model agrees with cachegrind's L1 to 0.03%. Against the hardware, the simulation's L1 misses
are within 10% of the demand fills; the gap is what the L1 prefetchers bring in ahead of demand
(the "any" fills, 367 M, include them). For the C++ front end: simulated 8.75 M L2 + 2.49 M L3 + 0.84 M
memory; measured 9.1 M demand fills from L2, 1.0 M from L3, 0.6 M from DRAM. Level by level the
simulation overstates L3 and memory for C++ (no prefetcher) but the totals and the ranking hold: 307 M vs 12 M L1 misses simulated, 283 M vs 10.7 M measured (26x and 25x).

Calibration (`trace/calib.c`, random 8-byte reads, 4 M of them): working set 16 KB -> 100% L1;
512 KB -> 94% L2; 8 MB -> 91% L3; 256 MB -> memory for every miss. The model behaves.

**Cost.**

| | native | under bytemove | slowdown | raw trace | committed |
|---|---|---|---|---|---|
| self-hosted, W1 | 0.31-0.34 s | 17.8 s | ~55x | 134 MB samples + 54 KB exact | 1.0 MB JSON |
| C++, W1 | 0.21-0.22 s | 9.3 s | ~43x | 70 MB samples | 0.55 MB JSON |
| cachegrind, self-hosted | | 14.5 s | ~45x | | totals only |
| lackey `--trace-mem=yes`, self-hosted `--parse` only (57 M instr) | 0.016 s | 91 s | ~5,700x | see below | |

Lackey prints a text line per access and per instruction: extrapolated to the full compile (3.9 G
instructions) that is about 100 minutes and tens of GB of text before any cache model runs, so
"lackey piped into a model" was rejected in favour of the model inside the tool.

**DynamoRIO.** github.com is reachable from the VM (HTTP 200 on the releases page), so drcachesim
could be downloaded, but it is not needed: Ubuntu's valgrind package ships the headers and the static
core libraries (`/usr/lib/x86_64-linux-gnu/valgrind/libcoregrind-amd64-linux.a`, `libvex-...a`), so an
out-of-tree tool builds in a second (`trace/build.sh`), and its model is exactly ours. Revisit
drcachesim only if we need prefetcher models or a 10x faster trace.

## Caveats

- No hardware prefetcher in the model: a sequential sweep shows as one L2 (or memory) line per 64 bytes
  where the hardware would have most of them in L1 already. Sweeps still look like sweeps (thin bright
  lines), and the counters keep us honest about totals.
- The traced self-hosted binary is `sh2m`: the same C with six functions marked `noinline` and
  built `-no-pie`; its instruction count is within 0.7% of sh2's.
- Time on the x axis is data accesses, not seconds; seconds per stage come from the counters.
- An access spanning two lines is counted once, at the farther level.
# viz

The pictures page (research/CHARTER.md, Deliverables 3), served on port 8000. Generated from real runs by the scripts here; never edited by hand.

- `index.html`: the page, built by `build.py` from `page.html`, `data/*.json` and `../runs/*.json`.
- `METHOD.md`: how bytes are seen moving on this VM, with the evidence.
- `trace/`: the bytemove Valgrind tool, stage marking, reduction, counters; `trace/run.sh` regenerates everything.
- Served by `python3 -m http.server 8000 --directory /home/exedev/goose/research/viz` (log: /tmp/viz-server.log).

exec
/bin/bash -lc "rg -n 'caption|simulat|measur|W1|ladder|dedup|index|fetch|json|2026|input' research/viz/page.html research/viz/build.py research/viz/index.html; sed -n '1,270p' research/demo" in /home/exedev/goose-w
 succeeded in 0ms:
research/viz/page.html:43:  padding: 8px 10px; font-size: 12px; line-height: 1.45; color: var(--text); display: none; z-index: 10; max-width: 320px;
research/viz/page.html:54:<h1>Bytes moving through the caches: Goose front ends compiling W1</h1>
research/viz/page.html:60:  <h3>The ladder</h3>
research/viz/page.html:61:  <div id="ladder" class="scroll"></div>
research/viz/page.html:67:the cache level that served them in the simulation, and brighter where there are more of them.</p>
research/viz/page.html:76:<p>Bytes brought into L1 from each level (64 bytes per line filled), per stage, for both front ends on the same input.
research/viz/page.html:79:<div id="measured" class="card scroll"></div>
research/viz/page.html:85:<h2>How this was measured</h2>
research/viz/page.html:88:(L1 32 KB 8-way, L2 1 MB 8-way, L3 32 MB 16-way victim cache, 64-byte lines, LRU, no prefetcher) and records which level served it.
research/viz/page.html:89:The simulation agrees with cachegrind on L1 misses to within 0.1% and with the counters to within the prefetchers' share.
research/viz/page.html:109:  `Built ${META.built} from commit ${META.commit}. W1: selfhost/main.goose and its 13 modules, 3,321 lines. Generated by research/viz/build.py from real runs.`;
research/viz/page.html:113:// ---------------------------------------------------------------- TL;DR + ladder
research/viz/page.html:126:  tl.push(`<li>Compiling W1 to C, the self-hosted front end brings <b>${fmtB(gm)}</b> into L1 from the levels below; the C++ front end brings <b>${fmtB(cm)}</b> (<b>${(gm / cm).toFixed(0)}x</b> less), for ${fmt(T.goose.c_bytes_out)}B and ${fmt(T.cpp.c_bytes_out)}B of C out.</li>`);
research/viz/page.html:139:if (!LADDER.length) tl.push('<li class="placeholder">The ladder (source to running program, per rung) appears here once research/runs/*.json exist.</li>');
research/viz/page.html:142:  document.getElementById('ladder').innerHTML = '<table><tr><th>workload</th><th>rung</th><th>stage</th><th>runs</th><th>min s</th><th>median s</th><th>max s</th><th>bytes out</th><th>peak RSS</th><th>check</th></tr>' +
research/viz/page.html:144:} else document.getElementById('ladder').innerHTML = '<p class="placeholder">No ladder runs yet (research/runs/*.json).</p>';
research/viz/page.html:203:      if (x1 - x0 > g.measureText(label).width + 8) { g.fillStyle = '#c3c2b7'; g.fillText(label, x0 + 5, 14); }
research/viz/page.html:221:      const lab = fmt(acc * i / ticks, 0); const w = g.measureText(lab).width; g.fillText(lab, Math.min(x - w / 2, W - w - 2), y + 6); }
research/viz/page.html:247:// ---------------------------------------------------------------- stage bars (simulation)
research/viz/page.html:280:    const names = { sh2: 'self-hosted (sh2), measured', cpp: 'C++ (build/goose), measured' };
research/viz/page.html:282:    stackedBars(document.getElementById('measured'), 'Measured with perf: demand fills into L1 per stage (median of 5 runs)',
research/viz/page.html:286:      `Each stage is the difference between cumulative runs (--parse, --check, -o out.c). L3 here is any fill from this CCX's L3; hardware prefetchers bring in lines the simulation counts as demand misses. Load average during the runs: ${(COUNTERS.uptime || []).map(u => u.split('load average:')[1]).join(' → ')}.`);
research/viz/build.py:2:"""Build research/viz/index.html from the committed data.
research/viz/build.py:5:  data/selfhost_w1.json, data/cpp_w1.json  bytemove traces reduced by trace/reduce.py
research/viz/build.py:6:  data/counters.json                       hardware counters, trace/counters.sh
research/viz/build.py:7:  ../runs/*.json                           the ladder (another builder writes these):
research/viz/build.py:13:import glob, json, os, statistics, subprocess, datetime
research/viz/build.py:18:    return json.load(open(p)) if os.path.exists(p) else None
research/viz/build.py:20:traces = [t for t in (load('data/selfhost_w1.json'), load('data/cpp_w1.json')) if t]
research/viz/build.py:21:counters = load('data/counters.json')
research/viz/build.py:23:for p in sorted(glob.glob(os.path.join(here, '..', 'runs', '*.json'))):
research/viz/build.py:25:        d = json.load(open(p))
research/viz/build.py:30:# ladder: per workload, rung, stage -> min/median/max over runs
research/viz/build.py:31:ladder = {}
research/viz/build.py:34:    ladder.setdefault(k, []).append(r)
research/viz/build.py:35:ladder_rows = []
research/viz/build.py:36:for (w, rung, st), rs in sorted(ladder.items(), key=lambda kv: tuple(str(x) for x in kv[0])):
research/viz/build.py:38:    ladder_rows.append({'workload': w, 'rung': rung, 'stage': st, 'n': len(rs),
research/viz/build.py:50:    json.dumps(traces, separators=(',', ':')), json.dumps(counters, separators=(',', ':')),
research/viz/build.py:51:    json.dumps(ladder_rows, separators=(',', ':')), json.dumps(meta)))
research/viz/build.py:52:open(os.path.join(here, 'index.html'), 'w').write(html)
research/viz/build.py:53:print('wrote index.html: %d bytes, %d traces, %d ladder rows' % (len(html), len(traces), len(ladder_rows)))
research/viz/index.html:43:  padding: 8px 10px; font-size: 12px; line-height: 1.45; color: var(--text); display: none; z-index: 10; max-width: 320px;
research/viz/index.html:54:<h1>Bytes moving through the caches: Goose front ends compiling W1</h1>
research/viz/index.html:60:  <h3>The ladder</h3>
research/viz/index.html:61:  <div id="ladder" class="scroll"></div>
research/viz/index.html:67:the cache level that served them in the simulation, and brighter where there are more of them.</p>
research/viz/index.html:76:<p>Bytes brought into L1 from each level (64 bytes per line filled), per stage, for both front ends on the same input.
research/viz/index.html:79:<div id="measured" class="card scroll"></div>
research/viz/index.html:85:<h2>How this was measured</h2>
research/viz/index.html:88:(L1 32 KB 8-way, L2 1 MB 8-way, L3 32 MB 16-way victim cache, 64-byte lines, LRU, no prefetcher) and records which level served it.
research/viz/index.html:89:The simulation agrees with cachegrind on L1 misses to within 0.1% and with the counters to within the prefetchers' share.
research/viz/index.html:97:const META = {"built": "2026-11-17 01:41 UTC", "commit": "5e5d79c5"};
research/viz/index.html:112:  `Built ${META.built} from commit ${META.commit}. W1: selfhost/main.goose and its 13 modules, 3,321 lines. Generated by research/viz/build.py from real runs.`;
research/viz/index.html:116:// ---------------------------------------------------------------- TL;DR + ladder
research/viz/index.html:129:  tl.push(`<li>Compiling W1 to C, the self-hosted front end brings <b>${fmtB(gm)}</b> into L1 from the levels below; the C++ front end brings <b>${fmtB(cm)}</b> (<b>${(gm / cm).toFixed(0)}x</b> less), for ${fmt(T.goose.c_bytes_out)}B and ${fmt(T.cpp.c_bytes_out)}B of C out.</li>`);
research/viz/index.html:142:if (!LADDER.length) tl.push('<li class="placeholder">The ladder (source to running program, per rung) appears here once research/runs/*.json exist.</li>');
research/viz/index.html:145:  document.getElementById('ladder').innerHTML = '<table><tr><th>workload</th><th>rung</th><th>stage</th><th>runs</th><th>min s</th><th>median s</th><th>max s</th><th>bytes out</th><th>peak RSS</th><th>check</th></tr>' +
research/viz/index.html:147:} else document.getElementById('ladder').innerHTML = '<p class="placeholder">No ladder runs yet (research/runs/*.json).</p>';
research/viz/index.html:206:      if (x1 - x0 > g.measureText(label).width + 8) { g.fillStyle = '#c3c2b7'; g.fillText(label, x0 + 5, 14); }
research/viz/index.html:224:      const lab = fmt(acc * i / ticks, 0); const w = g.measureText(lab).width; g.fillText(lab, Math.min(x - w / 2, W - w - 2), y + 6); }
research/viz/index.html:250:// ---------------------------------------------------------------- stage bars (simulation)
research/viz/index.html:283:    const names = { sh2: 'self-hosted (sh2), measured', cpp: 'C++ (build/goose), measured' };
research/viz/index.html:285:    stackedBars(document.getElementById('measured'), 'Measured with perf: demand fills into L1 per stage (median of 5 runs)',
research/viz/index.html:289:      `Each stage is the difference between cumulative runs (--parse, --check, -o out.c). L3 here is any fill from this CCX's L3; hardware prefetchers bring in lines the simulation counts as demand misses. Load average during the runs: ${(COUNTERS.uptime || []).map(u => u.split('load average:')[1]).join(' → ')}.`);
#!/usr/bin/env python3
"""research/demo: the ladder (research/CHARTER.md), measured stage by stage.

Builds each workload through each rung that runs today, printing one line per
stage as it goes (rung, stage, wall time, bytes in and out, peak RSS, how the
output was checked), runs what it built and checks it, then prints
min/median/max per stage. Every measurement is also written to
research/runs/<UTC timestamp>-<shortsha>.json (a list of records
{workload, rung, stage, run, seconds, bytes_in, bytes_out, peak_rss_kb, check,
ok}, plus `item` where a workload has several programs).

Workloads:
  W1  selfhost/ compiling itself (stock optimized, stock fast, self-hosted;
      checked by the C fixed point)
  W2  positive fixtures with blessed output (every 10th by default, --full for
      all); stock rungs timed, self-hosted rung counted
  W3  samples 19_vm, 21_raytrace, 31_mini_doom (headless), checked against
      samples/expected/

Usage:
  research/demo                 everything, 5 interleaved runs
  research/demo --quick         everything, 1 run
  research/demo --only W1,W3    some workloads
  research/demo --before REV    also build REV's selfhost/ and run it alongside
  research/demo --full          W2 over every positive fixture
  research/demo --ladder        also rewrite research/LADDER.md from this run

Build products go to build/demo/. The C++ compiler is $GOOSE (default
/home/exedev/goose/build/goose, else build/goose in this tree).
"""

import argparse
import datetime
import json
import os
import platform
import re
import shlex
import shutil
import statistics
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
B = ROOT / "build" / "demo"
SAMPLES = ["19_vm", "21_raytrace", "31_mini_doom"]
W2_EXCLUDED_DIRS = ("errors", "errors_tc", "goose_in_goose", "lsp", "packages")
TIMEOUT = 900


def find_goose():
    for p in (os.environ.get("GOOSE"), "/home/exedev/goose/build/goose", ROOT / "build" / "goose"):
        if p and Path(p).is_file() and os.access(p, os.X_OK):
            return str(p)
    sys.exit("demo: no goose compiler (set GOOSE=path)")


GOOSE = find_goose()
CC = shutil.which("gcc") or shutil.which("cc")


# --- measuring one process --------------------------------------------------

class Result:
    __slots__ = ("code", "seconds", "rss_kb", "out", "err")


def measure(argv, cwd=None, stdin=None, out=None, timeout=TIMEOUT):
    """Run argv; wall time, peak RSS (os.wait4's ru_maxrss), exit code; its
    stdout goes to `out` (a path) or is captured, its stderr is captured."""
    B.mkdir(parents=True, exist_ok=True)
    errf = open(B / f".stderr-{threading.get_ident()}", "w+b")
    outf = open(out, "wb") if out else open(B / f".stdout-{threading.get_ident()}", "w+b")
    inf = open(stdin, "rb") if stdin else subprocess.DEVNULL
    try:
        t0 = time.perf_counter()
        p = subprocess.Popen([str(a) for a in argv], cwd=cwd, stdin=inf, stdout=outf, stderr=errf)
        timer = threading.Timer(timeout, p.kill)
        timer.start()
        _, status, ru = os.wait4(p.pid, 0)
        r = Result()
        r.seconds = time.perf_counter() - t0
        timer.cancel()
        p.returncode = r.code = os.waitstatus_to_exitcode(status)
        r.rss_kb = ru.ru_maxrss
        errf.seek(0)
        r.err = errf.read().decode("utf-8", "replace")
        if out:
            r.out = None
        else:
            outf.seek(0)
            r.out = outf.read().decode("utf-8", "replace")
        return r
    finally:
        errf.close()
        outf.close()
        if stdin:
            inf.close()


def size(p):
    try:
        return Path(p).stat().st_size
    except OSError:
        return 0


def tree_bytes(d):
    return sum(size(f) for f in Path(d).glob("*.goose"))


def normalized(text):
    return text.replace("\r\n", "\n").rstrip("\n")


def first_error(r):
    for line in (r.err + (r.out or "")).splitlines():
        if line.strip():
            return line.strip().replace(str(ROOT) + "/", "")[:160]
    return f"exit {r.code}"


def human(n):
    if n is None:
        return "-"
    for unit, scale in (("GB", 1e9), ("MB", 1e6), ("KB", 1e3)):
        if n >= scale:
            return f"{n / scale:.2f} {unit}"
    return f"{n} B"


# --- the record -------------------------------------------------------------

RECORDS = []
W2_FAILURES = {}   # rung -> (passed, ran, fixtures, [(first failure, [fixtures])])
PRINT_LOCK = threading.Lock()


def record(workload, rung, stage, run, seconds, bytes_in, bytes_out, rss_kb, check, ok,
           item=None, quiet=False):
    rec = {"workload": workload, "rung": rung, "stage": stage, "run": run,
           "seconds": round(seconds, 6) if seconds is not None else None,
           "bytes_in": bytes_in, "bytes_out": bytes_out, "peak_rss_kb": rss_kb,
           "check": check, "ok": ok}
    if item:
        rec["item"] = item
    RECORDS.append(rec)
    if not quiet:
        what = f"{workload}{'/' + item if item else ''}"
        secs = f"{seconds:8.3f} s" if seconds is not None else "       - s"
        rss = f"{rss_kb / 1024:7.1f} MB" if rss_kb else "        -"
        line = (f"{what:<16} {rung:<26} {stage:<26} run {run}  {secs}  in {human(bytes_in):>9}"
                f"  out {human(bytes_out):>9}  rss {rss}  {'ok  ' if ok else 'FAIL'} {check}")
        with PRINT_LOCK:
            print(line, flush=True)
    return rec


def step(workload, rung, stage, run, argv, bytes_in, out_path=None, check="-", item=None,
         cwd=None, stdin=None, bytes_out=None):
    """Measure one stage, print and record it; returns the Result (ok = exit 0)."""
    r = measure(argv, cwd=cwd or ROOT, stdin=stdin)   # out_path is the product, sized
    if bytes_out is None:
        bytes_out = size(out_path) if out_path else len((r.out or "").encode())
    ok = r.code == 0
    record(workload, rung, stage, run, r.seconds, bytes_in, bytes_out, r.rss_kb,
           check if ok else f"exit {r.code}: {first_error(r)}", ok, item)
    return r


def check_cmp(workload, rung, run, a, b, what, item=None):
    t0 = time.perf_counter()
    ok = Path(a).exists() and Path(b).exists() and Path(a).read_bytes() == Path(b).read_bytes()
    record(workload, rung, "check", run, time.perf_counter() - t0, size(a) + size(b), 0, None,
           f"fixed point cmp: {what}" + ("" if ok else " DIFFER"), ok, item)
    return ok


def check_out(workload, rung, run, got, want_path, item=None):
    t0 = time.perf_counter()
    want = normalized(Path(want_path).read_text(encoding="utf-8", errors="replace"))
    ok = got is not None and normalized(got) == want
    record(workload, rung, "check", run, time.perf_counter() - t0, len(want.encode()), 0, None,
           f"blessed output match: {Path(want_path).relative_to(ROOT)}" + ("" if ok else " MISMATCH"),
           ok, item)
    return ok


# --- the C compiler command `goose build` would run -------------------------

def build_cc_command(src, exe, extra=(), cwd=None):
    """`goose build --dry-run`'s commands: builds the runtime object if it is
    missing and returns the program's own C compile, as an argv whose C file
    is the first .c argument (to be replaced by ours)."""
    r = measure([GOOSE, "build", "-O2", *extra, "-o", exe, "--dry-run", src], cwd=cwd or ROOT)
    if r.code != 0:
        return None, first_error(r)
    lines = [l for l in r.out.splitlines() if l.strip()]
    for l in lines[:-1]:
        argv = shlex.split(l)
        target = argv[argv.index("-o") + 1] if "-o" in argv else None
        if target and not Path(target).exists():
            # The runtime object (or a package's) is built once per GOOSE_HOME:
            # one real build makes it, outside any measurement.
            measure([GOOSE, "build", "-O2", *extra, "-o", exe, src], cwd=cwd or ROOT)
            break
    argv = shlex.split(lines[-1])
    ci = next(i for i, a in enumerate(argv) if a.endswith(".c"))
    return (argv, ci), None


def cc_argv(cmd, cfile, exe):
    argv, ci = cmd
    argv = list(argv)
    argv[ci] = str(cfile)
    argv[argv.index("-o") + 1] = str(exe)
    return argv


# --- trees: the selfhost/ under test, now and --before ----------------------

class Tree:
    def __init__(self, label, root, src):
        self.label = label          # "" for now, "@sha" for --before
        self.root = Path(root)      # the cwd its compilers run in (stdlib/ is found there)
        self.src = Path(src)        # the directory with main.goose
        self.dir = B / ("now" if not label else "before-" + label[1:])
        self.dir.mkdir(parents=True, exist_ok=True)
        self.sh2 = self.dir / "sh2"
        self.ref = self.dir / "sh3.c"
        self.ok = False

    def rung(self, name):
        return name + self.label


def bootstrap(tree):
    """sh1 = goose build selfhost; sh1 -> sh2.c; gcc -> sh2; sh2 -> sh3.c;
    sh2.c == sh3.c. Recorded as run 0."""
    d, main = tree.dir, tree.src / "main.goose"
    nbytes = tree_bytes(tree.src)
    rung = tree.rung("bootstrap")
    print(f"-- bootstrap {tree.src} --", flush=True)
    cmd, err = build_cc_command(main, d / "sh1", cwd=tree.root)
    if not cmd:
        record("W1", rung, "goose build --dry-run", 0, None, nbytes, 0, None, err, False)
        return False
    steps = [
        ("sh1: C++ front end", [GOOSE, "-O2", "-o", d / "sh1.c", main], d / "sh1.c", nbytes),
        ("sh1: C compiler", cc_argv(cmd, d / "sh1.c", d / "sh1"), d / "sh1", None),
        ("sh2.c: sh1 front end", [d / "sh1", "-o", d / "sh2.c", main], d / "sh2.c", nbytes),
        ("sh2: gcc -O2", [CC, "-O2", d / "sh2.c", "-o", d / "sh2", "-lm"], d / "sh2", None),
        ("sh3.c: sh2 front end", [d / "sh2", "-o", d / "sh3.c", main], d / "sh3.c", nbytes),
    ]
    prev = None
    for stage, argv, out, nin in steps:
        r = measure(argv, cwd=tree.root)
        nin = nin if nin is not None else size(prev)
        record("W1", rung, stage, 0, r.seconds, nin, size(out), r.rss_kb,
               "-" if r.code == 0 else f"exit {r.code}: {first_error(r)}", r.code == 0)
        if r.code != 0:
            return False
        prev = out
    tree.ok = check_cmp("W1", rung, 0, d / "sh2.c", d / "sh3.c", "sh2.c == sh3.c")
    tree.cc = cmd
    return tree.ok

exec
/bin/bash -lc "rg -n 'fixed|bootstrap|stdlib|check|output|reject|marker' selfhost/scoreboard.py; cat research/viz/build.py; cat research/notes/tcc-rung.md; cat research/notes/emit-dedup.md; nl -ba research/JOURNAL.md; git rev-parse --short HEAD" in /home/exedev/goose-w
 succeeded in 0ms:
4:Builds selfhost/ (stage 1 with the C++ compiler, stage 2 with stage 1 and gcc -O2), checks W1's
5:fixed point (stage 2 and stage 3 C identical), then scores the stage-2 compiler on:
9:          exit status and stdout match the blessed output (and expected/<name>.aborts/.stderr).
10:  reject  error fixtures (test/errors/, test/errors_tc/): pass when the compiler exits 1 and every
11:          `// error:` marker occurs in its `file:line:col: error:` lines; `rejected` counts exit 1.
12:  stdlib  stdlib/*.goose: pass when `--check` accepts the module.
14:Writes selfhost/scoreboard/<board>.txt (the passing names, sorted) unless --check-only, and
16:--enforce, exits nonzero when a name in a committed board no longer passes or the fixed point
40:        p = subprocess.run([str(a) for a in argv], capture_output=True, timeout=timeout, cwd=cwd,
58:def bootstrap(goose, work):
75:    fixed = (work / "sh2.c").read_bytes() == (work / "sh3.c").read_bytes()
76:    return work / "sh2", fixed, time.time() - t0
111:        status = "reject" if code == 1 else "crash"
126:        markers = [m.strip() for m in sf.read_text().splitlines() if m.strip()]
127:        if any(m not in err for m in markers):
128:            return name, "mismatch", "stderr markers"
134:def score_reject(sh, f, work):
136:    markers = re.findall(r"^// error: (.+)$", f.read_text(encoding="utf-8"), re.MULTILINE)
137:    code, out, err = run([sh, "--check", rel], timeout=60, cwd=ROOT)
142:    missing = [m for m in markers if m not in diags]
143:    if not markers or missing:
144:        return key, "rejected", first_line(diags)
148:def score_stdlib(sh, f, work):
149:    code, out, err = run([sh, "--check", f.relative_to(ROOT)], timeout=60, cwd=ROOT)
152:    return f.stem, ("reject" if code == 1 else "crash"), re.sub(r"^\S+:\d+:\d+: ", "", first_line(err))
156:             "reject": (error_fixtures, score_reject),
157:             "stdlib": (lambda: sorted((ROOT / "stdlib").glob("*.goose")), score_stdlib)}
163:    ap.add_argument("--sh", help="score this stage-2 compiler instead of bootstrapping")
174:        sh, fixed, secs = Path(args.sh).resolve(), None, 0.0
176:        sh, fixed, secs = bootstrap(args.goose, work)
177:        print(f"bootstrap: {secs:.1f} s; W1 fixed point (stage 2 C == stage 3 C): {'yes' if fixed else 'NO'}")
178:    failed = fixed is False
179:    for board in args.only or ["run", "reject", "stdlib"]:
#!/usr/bin/env python3
"""Build research/viz/index.html from the committed data.

Inputs (all real runs, never edited by hand):
  data/selfhost_w1.json, data/cpp_w1.json  bytemove traces reduced by trace/reduce.py
  data/counters.json                       hardware counters, trace/counters.sh
  ../runs/*.json                           the ladder (another builder writes these):
                                           [{workload, rung, stage, run, seconds, bytes_in,
                                             bytes_out, peak_rss_kb, check, ok}]
The page is one self-contained file: the data is inlined, no network needed.
usage: python3 research/viz/build.py
"""
import glob, json, os, statistics, subprocess, datetime

here = os.path.dirname(os.path.abspath(__file__))
def load(p):
    p = os.path.join(here, p)
    return json.load(open(p)) if os.path.exists(p) else None

traces = [t for t in (load('data/selfhost_w1.json'), load('data/cpp_w1.json')) if t]
counters = load('data/counters.json')
runs = []
for p in sorted(glob.glob(os.path.join(here, '..', 'runs', '*.json'))):
    try:
        d = json.load(open(p))
        runs += d if isinstance(d, list) else [d]
    except Exception as e:
        print('skipping', p, e)

# ladder: per workload, rung, stage -> min/median/max over runs
ladder = {}
for r in runs:
    k = (r.get('workload'), r.get('rung'), r.get('stage'))
    ladder.setdefault(k, []).append(r)
ladder_rows = []
for (w, rung, st), rs in sorted(ladder.items(), key=lambda kv: tuple(str(x) for x in kv[0])):
    secs = [float(r.get('seconds') or 0) for r in rs]
    ladder_rows.append({'workload': w, 'rung': rung, 'stage': st, 'n': len(rs),
                        'min': min(secs), 'median': statistics.median(secs), 'max': max(secs),
                        'bytes_out': rs[-1].get('bytes_out'), 'peak_rss_kb': rs[-1].get('peak_rss_kb'),
                        'check': rs[-1].get('check'), 'ok': all(r.get('ok') for r in rs)})
try:
    commit = subprocess.check_output(['git', '-C', here, 'rev-parse', '--short', 'HEAD'], text=True).strip()
except Exception:
    commit = '?'
meta = {'built': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC'), 'commit': commit}

html = open(os.path.join(here, 'page.html')).read()
html = html.replace('/*DATA*/', 'const TRACES = %s;\nconst COUNTERS = %s;\nconst LADDER = %s;\nconst META = %s;' % (
    json.dumps(traces, separators=(',', ':')), json.dumps(counters, separators=(',', ':')),
    json.dumps(ladder_rows, separators=(',', ':')), json.dumps(meta)))
open(os.path.join(here, 'index.html'), 'w').write(html)
print('wrote index.html: %d bytes, %d traces, %d ladder rows' % (len(html), len(traces), len(ladder_rows)))
# Self-hosted rung through TinyCC (2026-11-17, lead)

build/tcc/tcc (built by cmake/libtcc.cmake) works as a CLI with
`tcc -B build/tcclib -I/usr/include/x86_64-linux-gnu -I/usr/include -c x.c` and a gcc link
(`gcc -Wl,--no-eh-frame-hdr -z noexecstack x.o build/tcclib/libtcc1.a -lm`; tcc's own link can't find crt1.o
because the build's CONFIG_TCC_LIBPATHS is {B} only).

- tcc -c sh2.c (3.66 MB): 0.06-0.07 s, 12 MB peak; deduped sh2d.c (1.59 MB): 0.02-0.04 s.
- The tcc-built stage 2 holds the fixed point (identical C), but runs W1 in 5.86-5.91 s against
  0.32-0.34 s for the gcc -O2 build: 18x. The emitted C leans on gcc to remove its temporaries,
  frame-struct traffic and gg_view/gg_index helper calls. Implication for M3: on the fast path
  the C we emit must be good C before any optimizer sees it (or we emit machine code ourselves).
# emit-dedup: one C body per class of identical specializations (2026-11-17)

Implements the finding in `dedup.md`. Before: the checker keys a specialization on each view
argument's provenance, so W1 instantiates most of the compiler twice (and small helpers ~190 times),
and the emitter wrote every copy. After: the emitter writes each distinct function once.

## What changed (selfhost/emitter.goose, selfhost/context.goose)

1. **Names are per function.** Temporaries and labels restart at 0 in each function
   (`c_temporary`, `c_label` reset in `emit_function`). Locals and parameters are `v<k>` / `p<k>` where
   `k` is the symbol's index among its owner's kind-2 symbols (`local_names`, computed once in
   `prepare_emission`). A nested function reaching `frame.parent->v<k>` uses the owner's numbering,
   so it is consistent by construction. Globals keep `gg_globals.v<symbol>` (shared, not cloned).
   `prepare_emission` also links each function's locals (`first_local`/`next_local`), which replaces
   `c_frames`' scan of every symbol for every specialization (it was O(specs x symbols)).
2. **References are markers.** `gg_function_<id>` and `struct gg_frame_<id>` are written as the
   prefix, byte 1, the decimal id, byte 2 (`emit_ref`). Each specialization's frame struct +
   prototype and its definition go to the `c_specs` arena with boundaries in `c_spec_start` /
   `c_spec_split`; the gg_program body is one more chunk.
   Why in-band markers rather than (offset, spec) arrays: the body is generated into `c_output` while
   its temporaries go to `c_declarations`, and the two are reordered when copied into the arena, so
   recorded offsets would need fixing up per copy. Markers travel with the bytes. One linear pass
   (`compact_refs`) then rewrites every marker in place to the single byte 1 and appends its target to
   a flat `refs: i64[>..]` with `ref_start` per chunk; after that, text comparison is plain slice `==`.
3. **Partition refinement to a fixed point** (`write_specializations`). Start: classes of exact text
   equality with markers blanked (FNV-1a hash into an open-addressing table, confirmed by slice
   compare, so a hash collision cannot merge two functions). Each round: key = (own class, class of
   each ref in order), hashed into the same table and confirmed by comparing the class sequences;
   only flat i64/u64 arrays, O(total refs) per round, no strings. It only ever splits classes, so
   the round where the class count stops changing is the fixed point; recursive cycles stay merged
   because they start merged.
4. **Write one representative per class** (its lowest spec id): frame structs and prototypes, then
   definitions, then gg_program, each marker spelled as its target's representative id. Prototypes
   and frame structs are deduplicated too, which is why the file is smaller than `c_dedup.py`'s
   (which only drops definitions and prototypes, keeping every frame struct).

   Multiple results (merged from master during the rebase) add two more names: the
   `gg_results_<spec>` record type is a reference (marker, also from `c_declarations` via
   `declare_ref`), and a call's `gg_multi_<node>` record becomes `gg_multi_<k>`, `k` its order in
   the function (`c_multis`, cleared per function), since node ids differ between clones.

## Proof (numbers on the branch rebased onto origin/master 1e420132)

- (a) `research/tools/c_dedup.py` on the new sh2.c: `195 functions, 195 distinct; duplicate body
  bytes 0 of file 1728050`. The master emitter on the same source: `1104 functions, 195 distinct;
  duplicate body bytes 2423264 of file 4639437`, so the emitter finds exactly the classes the tool
  finds. (Master's own sh2.c, of master's source, is 4,510,907 bytes.)
- (b) W1 fixed point: sh1 (C++-built) -> sh2.c; gcc -O2 -> sh2; sh2 -> sh3.c; `cmp sh2.c sh3.c`
  identical. No marker byte (0x01) survives in the output. A small program with a multiple-result
  function, a nested function writing its parent's local, and two provenances per call
  (literal vs `u8[>..]`) prints the same as `goose x.goose` and has 4 functions instead of 7.
- (c) `python3 selfhost/scoreboard.py --goose build/goose --enforce` exits 0: fixed point yes,
  run 30/776, reject 19/2036, stdlib 6/17 (master's boards; no pass lost).
- (d) gcc -O2 on sh2.c, 5 interleaved runs, load average 4-7 (other builders running):

  | sh2.c | bytes | min | median | max | peak RSS |
  |---|---|---|---|---|---|
  | master emitter (master source) | 4,510,907 | 11.82 s | 12.63 s | 13.36 s | 375 MB |
  | dedup emitter (this branch) | 1,728,050 | 5.54 s | 5.74 s | 6.30 s | 262 MB |

  Front end (`sh2 -o x.c selfhost/main.goose`, same source for both, 5 interleaved runs): master
  0.13/0.16/0.18 s, new 0.12/0.17/0.19 s (min/median/max): the ranges overlap. Noise-free count,
  `perf stat -e instructions:u`: master 969,508,560, new 942,457,484 (-2.8%): the dedup pass costs
  less than the O(specs x symbols) frame scan it replaced. Peak RSS 45.4 MB both.
  (Before the rebase, against b6c14259: 3.66 MB -> 1.44 MB, gcc 9.73/11.56/12.92 s ->
  5.12/5.31/6.48 s, front end 4.002G -> 4.000G instructions.)

Commands: `goose build selfhost/main.goose -o sh1; ./sh1 -o sh2.c selfhost/main.goose;` then
`for i in 1..5; for v in master new: /usr/bin/time gcc -O2 $v/sh2.c -o x -lm` and the same loop over
`$v/sh2 -o fe.c selfhost/main.goose`.

## What Goose made easy, forced, or could not express

- **Could not shrink the scratch buffers.** The plan was to truncate `c_output` / `c_declarations`
  after each function (memory-first: scratch stays one function big). `ctx.c_output.resize(mark)`
  on a grow-only `u8[>..]&` is rejected ("cannot resize ctx while ctx is still used: what it refers
  to may hold a reference or slice into it", §5.1) because `ctx` holds other slices; making the
  field `u8[>..<]` is rejected at every place a slice from `ctx` is stored (§5.2), since the checker
  cannot tell which of ctx's arrays a stored slice points into. The provenance is per root (`ctx`),
  not per field. So the scratch stays append-only (3.6 MB, as before) and `c_specs` adds a second
  copy before the 1.4 MB output; fixing it needs either per-field provenance or splitting the
  scratch out of `Compiler`.
- `ctx.c_final.append(str(n))` inside a loop hit the selfhost's "not implemented yet: constructed
  append result analysis"; `format(ctx.c_final, n)` works.
- Easy: flat arrays indexed by spec id made the partition a few dozen lines; slice `==` on `u8`
  gave a memcmp-style confirm for free; wrapping `u64` multiply made FNV-1a a one-liner.
- The real fix is upstream of the emitter: the checker's specialization key includes provenance
  that the C does not depend on. Deduping at emission keeps the checker's precision and costs no
  front-end time; checking fewer specializations would also save checker time (W1: 1104 specs
  checked, 195 distinct).
     1	# JOURNAL
     2	
     3	Append-only: one line per commit, a paragraph at each milestone.
     4	
     5	- 2026-11-17 setup: charter, plan, loop and harness; selfhost/ seeded from test/goose_in_goose (upstream 3a0aa2eb).
     6	- 2026-11-17 M0 setup: VM is 8 cores EPYC 9554P/31 GB; research/setup.sh installs cmake, perf (6.8 tools), valgrind, SDL deps, lavapipe; C++ compiler built with all packages (mini_doom runs headless). W2 stock suite (run_tests.py, 8 jobs) 54.4 s wall, all pass; goose_in_goose bootstrap 24.5 s. Builders launched: demo (branch demo), bytes/viz (branch viz).
     7	- 2026-11-17 selfhost/scoreboard.py: bootstrap + fixed point + three boards. Baseline: run 23/776, reject 3/2035 (1951 exit 1 but markers unmatched, 80 accepted), stdlib 0/17; fixed point yes; 16 s on 8 cores. Biggest cluster: stdlib/std.goose:1348 parameter defaults don't parse (168 run fixtures).
     8	- 2026-11-17 tcc rung: tcc compiles sh2.c in 0.07 s and holds the fixed point, but the tcc-built compiler runs W1 18x slower (5.9 s vs 0.32 s); research/notes/tcc-rung.md.
     9	- 2026-11-17 scan-index: find_symbol hashed by (scope, name), recursive-cycle test by SCC over a CSR call graph: W1 front end 0.30-0.33 -> 0.11-0.14 s; outcomes identical; selfhost/tests/ joins the reject board (4/2036).
    10	- 2026-11-17 overloads walk their (scope, name) chain: W1 front end 1,019 M -> 647 M instructions, 0.13-0.18 -> 0.09-0.14 s; outcomes identical.
    11	- 2026-11-17 selfhost --check accepts a module that declares no main, as a library (stdlib 0 -> 2/17)
    12	- 2026-11-17 selfhost parameter defaults, mined from the October gap-param-defaults branch (run 23->24, reject 3->7)
    13	- 2026-11-17 selfhost fixed multiple results and multi-target receivers, mined from gap-multi-return (run 24->26)
    14	- 2026-11-17 selfhost function modifiers (simd, inline, checkfree, export), adapting named constants and float lets, int-to-float, as! float, loops without break as bottom (stdlib 2->6/17, reject 7->14)
    15	- 2026-11-17 selfhost constant folding and joined constant branches, constness-generic parameters, struct literal '..', bytes_of, src_file/src_line, unreached view params rooted globally, field-default cycles and the 16-deep instantiation bound, Goose-spelled types in diagnostics (run 26->30, reject 14->18)
    16	- 2026-11-17 research/demo: the ladder for W1, W2 (sampled or --full), W3, stage by stage, with --before and a JSON record per run.
    17	- 2026-11-17 LADDER.md and research/runs/20261117T013206Z-de28e5b6.json from a full demo run (W1 4.1/2.6/10.6 s; W2 22.5/2.7 s stock, self-hosted 30/771).
    18	- 2026-11-17 feat-enums: fixed-mode enums, variant types/constructors/constants, match over enums and integers (coverage, overlap, binders), results generic over constness, instantiation chain limit.
    19	- 2026-11-17 selfhost shift compound assignments take any integer count; unreached view params rooted without a held bound; index the symbols project_result pushes (tried name-based liveness at shrinks: unsound, it lost 31 rejections, reverted)
    20	- 2026-11-17 emit-dedup: the selfhost emitter numbers names per function, writes refs as markers and partitions specializations to a fixed point; W1 sh2.c 1104 -> 195 functions, 4.51 MB -> 1.73 MB, 0 duplicate bytes; gcc -O2 11.82/12.63/13.36 s -> 5.54/5.74/6.30 s (load 4-7); front end -2.8% instructions; fixed point holds, scoreboard --enforce passes. research/notes/emit-dedup.md.
    21	- 2026-11-17 feat-storage: selfhost gets limited arrays (T[..k] fixed struct, T[..]) and packed variable-size storage (T[], T[uN], T[varint], variable struct fields, varint), pop_n.
    22	- 2026-11-17 feat-storage rebased on master (enums, stdlib): run 40 -> 63, reject 39, stdlib 6; index_symbol added for two unindexed temporary-root pushes.
    23	- 2026-11-17 viz: bytemove, a Valgrind tool that replays every data access through a Zen 4 cache model (L1 32K/L2 1M/L3 32M victim), with stage marks and region dumps.
    24	- 2026-11-17 viz: first picture (address-space strips by cache level, per-stage bytes for both front ends, counters) and METHOD.md; self-hosted moves 19.7 GB into L1 vs 0.77 GB for C++, 97% of its misses in the checker rescanning symbols/scopes.
    25	- 2026-11-17 merged emit-dedup, feat-storage, viz; lead re-check of emit-dedup on one input: 5.24 -> 1.91 MB of C, gcc -O2 14.2-15.0 -> 6.1-6.6 s. Boards run 63/776, reject 39/2036, stdlib 6/17.
    26	
    27	**M0 (2026-11-17 01:50 UTC).** The ladder runs on this VM for W1, W2 and three W3 samples, and `research/demo`
    28	prints it stage by stage. Bytes are seen two ways: perf's Zen 4 fill counters for totals, and a Valgrind tool
    29	with a model of this CPU's caches for per-access attribution (50x slowdown; matches cachegrind's L1 misses to
    30	0.03%); the first picture shows the self-hosted front end pulling 25x the C++ front end's bytes into L1, 97% of
    31	it the checker re-reading symbol and scope tables. Before M0 closed, three byte-saving changes landed:
    32	the symbol hash index and the overload chain walk (front end 0.30-0.33 -> 0.09-0.14 s on the old W1) and
    33	emit-dedup (one input: 5.24 -> 1.91 MB of C, gcc -O2 14.2-15.0 -> 6.1-6.6 s). The self-hosted compiler's C for
    34	W1 is now smaller than the C++ compiler's (2.10 vs 2.19 MB), but gcc still takes longer on it (7.28 vs 6.10 s):
    35	its C is harder to compile per byte (emit-lean is on that). **What did the oracle number do since the last
    36	milestone?** This is the first: run 23 -> 63/776, reject 3 -> 39/2036, stdlib 0 -> 6/17, fixed point held
    37	throughout. Self-hosted W1 is still 1.2x stock optimized, and W2 can't be compared until more fixtures pass;
    38	demo2 is adding a like-for-like W2 row (the fixtures the selfhost passes, through every rung).
fdac3dfc

codex
The demo failed before compiling: its systemd wrapper cannot connect to the user bus. The files show a stale pictures page and comparisons using different inputs or fixture sets; I’m checking the correctness checks to distinguish missing validation from checks that are actually implemented.
exec
/bin/bash -lc "sed -n '58,155p' selfhost/scoreboard.py; nl -ba research/viz/trace/run.sh | head -n 100; nl -ba research/LADDER.md | tail -n 25; rg -n 'library|has_main|main_function|check_program|--check' selfhost/main.goose selfhost/checker.goose; nl -ba research/notes/emit-dedup.md | sed -n '43,65p'; sed -n '54,94p' research/viz/page.html" in /home/exedev/goose-w
 succeeded in 0ms:
def bootstrap(goose, work):
    """Stage 1 by the C++ compiler, stage 2 by stage 1 + gcc -O2, stage 3 C by stage 2."""
    work.mkdir(parents=True, exist_ok=True)
    main = ROOT / "selfhost" / "main.goose"
    t0 = time.time()
    code, out, err = run([goose, "build", main, "-o", work / "sh1"], timeout=600)
    if code:
        sys.exit(f"stage 1 build failed:\n{out}{err}")
    for stage, exe in ((2, "sh1"), (3, "sh2")):
        code, out, err = run([work / exe, "-o", work / f"sh{stage}.c", main], timeout=600)
        if code:
            sys.exit(f"stage {stage} emission failed:\n{out}{err}")
        if stage == 2:
            code, out, err = run(["gcc", "-O2", "-w", work / "sh2.c", "-o", work / "sh2", "-lm", "-lpthread"],
                                 timeout=600)
            if code:
                sys.exit(f"stage 2 gcc failed:\n{err}")
    fixed = (work / "sh2.c").read_bytes() == (work / "sh3.c").read_bytes()
    return work / "sh2", fixed, time.time() - t0


def positive_fixtures():
    tests = [f for f in sorted(TEST.glob("*/*.goose"))
             if f.parent.name not in SKIP_DIRS and f.name != "lexer_tokens.goose"]
    out = []
    for f in tests:
        if not (TEST / "expected" / f"{f.stem}.out").exists():
            continue
        if re.search(r"^// error: ", f.read_text(encoding="utf-8"), re.MULTILINE):
            continue
        out.append(f)
    return out


def error_fixtures():
    own = [f for f in sorted((ROOT / "selfhost" / "tests").glob("*.goose"))
           if re.search(r"^// error: ", f.read_text(encoding="utf-8"), re.MULTILINE)]
    return sorted((TEST / "errors").glob("*.goose")) + sorted((TEST / "errors_tc").glob("*.goose")) + own


def score_run(sh, f, work):
    name = f.stem
    rel = f.relative_to(ROOT)
    if f.parent.name in NATIVE or f.with_suffix(".build").exists():
        return name, "unsupported", "native module or sidecar"
    d = work / "run" / f.parent.name
    d.mkdir(parents=True, exist_ok=True)
    c, exe = d / f"{name}.c", d / name
    code, out, err = run([sh, "-o", c, rel], timeout=60, cwd=ROOT)
    if code == -999:
        return name, "crash", "selfhost timeout"
    if code:
        reason = first_line(err) or first_line(out)
        status = "reject" if code == 1 else "crash"
        return name, status, re.sub(r"^\S+:\d+:\d+: ", "", reason)
    code, out, err = run(["gcc", "-O2", "-w", c, "-o", exe, "-lm", "-lpthread"], timeout=120)
    if code:
        return name, "cc-error", first_line(re.sub(r"^.*?: ", "", err, flags=re.M))
    exp = TEST / "expected"
    args = (exp / f"{name}.args").read_text().split() if (exp / f"{name}.args").exists() else []
    code, out, err = run([exe, *args], timeout=30, cwd=ROOT)
    aborts = (exp / f"{name}.aborts").exists()
    if code == -999:
        return name, "mismatch", "run timeout"
    if aborts != (code != 0):
        return name, "mismatch", f"exit {code}: {first_line(err)}"
    sf = exp / f"{name}.stderr"
    if sf.exists():
        markers = [m.strip() for m in sf.read_text().splitlines() if m.strip()]
        if any(m not in err for m in markers):
            return name, "mismatch", "stderr markers"
    if joined(out) != joined((exp / f"{name}.out").read_text(encoding="utf-8", errors="replace")):
        return name, "mismatch", "stdout differs"
    return name, "pass", ""


def score_reject(sh, f, work):
    rel = f.relative_to(ROOT)
    markers = re.findall(r"^// error: (.+)$", f.read_text(encoding="utf-8"), re.MULTILINE)
    code, out, err = run([sh, "--check", rel], timeout=60, cwd=ROOT)
    key = f"{f.parent.name}/{f.stem}"
    if code != 1:
        return key, ("crash" if code not in (0, 1) else "accepted"), f"exit {code}: {first_line(err)}"
    diags = "\n".join(m[1] for m in (re.match(r"^\S.*:\d+(?::\d+)?: error: (.*)$", l) for l in err.splitlines()) if m)
    missing = [m for m in markers if m not in diags]
    if not markers or missing:
        return key, "rejected", first_line(diags)
    return key, "pass", ""


def score_stdlib(sh, f, work):
    code, out, err = run([sh, "--check", f.relative_to(ROOT)], timeout=60, cwd=ROOT)
    if code == 0:
        return f.stem, "pass", ""
    return f.stem, ("reject" if code == 1 else "crash"), re.sub(r"^\S+:\d+:\d+: ", "", first_line(err))


BOARD_FNS = {"run": (positive_fixtures, score_run),
     1	#!/bin/sh
     2	# The whole pictures pipeline for W1, from source: build the bytemove tool,
     3	# build the self-hosted compiler (sh1, then sh2 from its own C), make a
     4	# stage-marked copy of sh2, trace both front ends compiling selfhost/,
     5	# count with perf, reduce to research/viz/data/*.json, build index.html.
     6	# Usage (repo root): research/viz/trace/run.sh [WORKDIR]   (default /tmp/bytemove-w1)
     7	# Needs: valgrind 3.22 (headers + static libs, Ubuntu's package has them), gcc, perf.
     8	set -e
     9	root=$(pwd)
    10	goose=${GOOSE:-/home/exedev/goose/build/goose}
    11	w=${1:-/tmp/bytemove-w1}
    12	viz=$root/research/viz
    13	mkdir -p "$w"
    14	"$viz/trace/build.sh" "$w/vglib" >/dev/null
    15	
    16	"$goose" build selfhost/main.goose -o "$w/sh1" >/dev/null
    17	"$w/sh1" -o "$w/sh2.c" selfhost/main.goose
    18	gcc -O2 "$w/sh2.c" -o "$w/sh2" -lm
    19	marks=$(python3 "$viz/trace/stagemarks.py" "$w/sh2.c" "$w/sh2m.c")
    20	gcc -O2 -g -no-pie "$w/sh2m.c" -o "$w/sh2m" -lm
    21	stacks=$(nm "$w/sh2m" | awk '/ gg_stacks$/ {print $1}')
    22	
    23	rm -rf "$w/tsh" "$w/tcpp"; mkdir -p "$w/tsh" "$w/tcpp"
    24	t0=$(date +%s.%N)
    25	VALGRIND_LIB=$w/vglib valgrind -q --tool=bytemove --out="$w/tsh" --sample=64 --marks="$marks" \
    26	  --dump="$stacks:196608" "$w/sh2m" -o "$w/tsh/out.c" selfhost/main.goose
    27	t1=$(date +%s.%N)
    28	cmp "$w/tsh/out.c" "$w/sh2.c"     # the traced run wrote the same C (the fixed point)
    29	VALGRIND_LIB=$w/vglib valgrind -q --tool=bytemove --out="$w/tcpp" --sample=64 \
    30	  --marks='goose::ParseProgram=parse:s,goose::ResolveTypeNames=check:s,goose::Optimizer::Optimizer=optimize:s,goose::BCE::RunAll=optimize:s,goose::CodeGen::CodeGen=emit:s,goose::WriteFileMakingDirs=write:s' \
    31	  "$goose" -o "$w/tcpp/out.c" selfhost/main.goose
    32	t2=$(date +%s.%N)
    33	"$goose" -o "$w/cpp.c" selfhost/main.goose
    34	cmp "$w/tcpp/out.c" "$w/cpp.c"
    35	echo "traced: self-hosted $(echo "$t1 - $t0" | bc) s, C++ $(echo "$t2 - $t1" | bc) s"
    36	
    37	python3 "$viz/trace/reduce.py" goose "$w/tsh" "$w/tsh/out.c" "Self-hosted front end (sh2, built from its own C)" "$viz/data/selfhost_w1.json"
    38	python3 "$viz/trace/reduce.py" cpp "$w/tcpp" "$w/tcpp/out.c" "C++ front end (build/goose -o out.c)" "$viz/data/cpp_w1.json"
    39	"$viz/trace/counters.sh" "$w/sh2" "$goose" "$w/ctr"
    40	python3 "$viz/trace/counters_json.py" "$w/ctr/counters.csv" "$w/ctr/uptime.txt" "$viz/data/counters.json"
    41	python3 "$viz/build.py"
    83	| item | rung | min s | median s | max s |
    84	|---|---|---:|---:|---:|
    85	| vm | stock optimized | 0.153 | 0.173 | 0.173 |
    86	| vm | stock fast | 0.021 | 0.035 | 0.042 |
    87	| vm | self-hosted | does not run | | |
    88	| raytrace | stock optimized | 0.266 | 0.282 | 0.308 |
    89	| raytrace | stock fast | 0.069 | 0.092 | 0.106 |
    90	| raytrace | self-hosted | does not run | | |
    91	| mini_doom | stock optimized | 2.558 | 2.600 | 2.729 |
    92	| mini_doom | stock fast | 0.590 | 0.673 | 0.787 |
    93	| mini_doom | self-hosted | does not run | | |
    94	
    95	### W2
    96	
    97	| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
    98	|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
    99	| - | stock optimized | goose build (sum) | 150.044 | 204.378 | 309.226 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
   100	| - | stock optimized | run (sum) | 4.475 | 6.027 | 9.797 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
   101	| - | stock optimized | wall, 771 fixtures -j8 | 19.738 | 27.021 | 40.607 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
   102	| - | stock fast | goose x.goose (fe+tcc+run) (sum) | 18.818 | 26.847 | 32.062 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
   103	| - | stock fast | wall, 771 fixtures -j8 | 2.679 | 3.753 | 4.545 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
   104	| - | self-hosted | front end (sh2) (sum) | 3.535 | 4.913 | 5.752 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
   105	| - | self-hosted | C compiler (gcc -O2) (sum) | 14.039 | 19.923 | 25.450 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
   106	| - | self-hosted | run (sum) | 0.941 | 1.386 | 1.586 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
   107	| - | self-hosted | wall, 771 fixtures -j8 | 2.541 | 3.519 | 4.376 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
selfhost/checker.goose:1478:// A checked file that declares no main in any namespace is a library: its
selfhost/checker.goose:1480:fn check_program(ctx: Compiler&, library: bool) {
selfhost/checker.goose:1488:    if main_symbol < 0 && !(library && !declares_main) { write_stderr("error: no root-file main function\n"); exit(1); }
selfhost/checker.goose:1563:    // The stack only grows (a pop would make check_program shrink ctx, §5.1).
selfhost/main.goose:25:        check_program(ctx, false); generate_c(ctx);
selfhost/main.goose:31:        check_program(ctx, true);
    43	
    44	- (a) `research/tools/c_dedup.py` on the new sh2.c: `195 functions, 195 distinct; duplicate body
    45	  bytes 0 of file 1728050`. The master emitter on the same source: `1104 functions, 195 distinct;
    46	  duplicate body bytes 2423264 of file 4639437`, so the emitter finds exactly the classes the tool
    47	  finds. (Master's own sh2.c, of master's source, is 4,510,907 bytes.)
    48	- (b) W1 fixed point: sh1 (C++-built) -> sh2.c; gcc -O2 -> sh2; sh2 -> sh3.c; `cmp sh2.c sh3.c`
    49	  identical. No marker byte (0x01) survives in the output. A small program with a multiple-result
    50	  function, a nested function writing its parent's local, and two provenances per call
    51	  (literal vs `u8[>..]`) prints the same as `goose x.goose` and has 4 functions instead of 7.
    52	- (c) `python3 selfhost/scoreboard.py --goose build/goose --enforce` exits 0: fixed point yes,
    53	  run 30/776, reject 19/2036, stdlib 6/17 (master's boards; no pass lost).
    54	- (d) gcc -O2 on sh2.c, 5 interleaved runs, load average 4-7 (other builders running):
    55	
    56	  | sh2.c | bytes | min | median | max | peak RSS |
    57	  |---|---|---|---|---|---|
    58	  | master emitter (master source) | 4,510,907 | 11.82 s | 12.63 s | 13.36 s | 375 MB |
    59	  | dedup emitter (this branch) | 1,728,050 | 5.54 s | 5.74 s | 6.30 s | 262 MB |
    60	
    61	  Front end (`sh2 -o x.c selfhost/main.goose`, same source for both, 5 interleaved runs): master
    62	  0.13/0.16/0.18 s, new 0.12/0.17/0.19 s (min/median/max): the ranges overlap. Noise-free count,
    63	  `perf stat -e instructions:u`: master 969,508,560, new 942,457,484 (-2.8%): the dedup pass costs
    64	  less than the O(specs x symbols) frame scan it replaced. Peak RSS 45.4 MB both.
    65	  (Before the rebase, against b6c14259: 3.66 MB -> 1.44 MB, gcc 9.73/11.56/12.92 s ->
<h1>Bytes moving through the caches: Goose front ends compiling W1</h1>
<div class="sub" id="meta"></div>

<div class="card">
  <h3 style="margin-top:0">TL;DR</h3>
  <ul class="tldr" id="tldr"></ul>
  <h3>The ladder</h3>
  <div id="ladder" class="scroll"></div>
</div>

<h2>The address space over a compile</h2>
<p>Each strip is one data structure of the self-hosted compiler (each Goose table lives on a data stack of its own),
drawn as the bytes it actually used, stacked top to bottom; time runs left to right. Every pixel is a group of memory accesses, colored by
the cache level that served them in the simulation, and brighter where there are more of them.</p>
<div class="controls">
  <div class="legend" id="legend"></div>
  <span style="flex:1"></span>
  <div class="seg" id="mode"><button data-m="all" class="on">every access</button><button data-m="miss">misses only (L2, L3, memory)</button></div>
</div>
<div id="strips"></div>

<h2>Bytes moved per stage</h2>
<p>Bytes brought into L1 from each level (64 bytes per line filled), per stage, for both front ends on the same input.
The bars share one scale. Bold numbers on the left are L1 hits, which move nothing.</p>
<div id="stagebars" class="card scroll"></div>
<div id="measured" class="card scroll"></div>

<h2>Where the self-hosted compiler's bytes go</h2>
<p>Every access of the whole compile, by data structure (exact counts, not sampled).</p>
<div id="regions" class="card scroll"></div>

<h2>How this was measured</h2>
<p>Hardware counters (perf, AMD Zen 4 <code>ls_dmnd_fills_from_sys.*</code>, 5 runs) give real totals; a Valgrind tool,
<code>research/viz/trace/bytemove.c</code>, replays every load and store through a model of this CPU's caches
(L1 32 KB 8-way, L2 1 MB 8-way, L3 32 MB 16-way victim cache, 64-byte lines, LRU, no prefetcher) and records which level served it.
The simulation agrees with cachegrind on L1 misses to within 0.1% and with the counters to within the prefetchers' share.
Details and evidence: <code>research/viz/METHOD.md</code>. Regenerate: <code>research/viz/trace/run.sh</code>.</p>
</main>
<div id="tip"></div>
<script>
/*DATA*/

exec
/bin/bash -lc "python3 - <<'PY'
import json,re,pathlib
for n in ['selfhost_w1','cpp_w1','counters']:
 d=json.loads(pathlib.Path('research/viz/data/'+n+'.json').read_text()); print(n, list(d)); print({k:v for k,v in d.items() if k not in ['regions','samples','bins','stages','runs'] and len(str(v))<1800})
s=pathlib.Path('research/viz/index.html').read_text(); d=json.loads(re.search(r'const LADDER = (.*);',s).group(1)); print('embedded W1', [r for r in d if r['workload']=='W1' and r['rung']=='self-hosted']); print('embedded W3', [r for r in d if r['workload']=='W3' and r['stage']=='C compiler (gcc -O2)'])
print('source lines',sum(len(f.read_text().splitlines()) for f in pathlib.Path('selfhost').glob('*.goose')))
PY" in /home/exedev/goose-w
 succeeded in 0ms:
selfhost_w1 ['name', 'kind', 'xbins', 'ybins', 'sample_rate', 'samples', 'accesses', 'instructions', 'c_bytes_out', 'stage_segments', 'stage_totals', 'regions']
{'name': 'Self-hosted front end (sh2, built from its own C)', 'kind': 'goose', 'xbins': 720, 'ybins': 72, 'sample_rate': 64, 'accesses': 1069916367, 'instructions': 3866363984, 'c_bytes_out': 3661811, 'stage_totals': {'start': {'acc': [46320, 226, 0, 1387], 'reads': [33058, 202, 0, 1054], 'writes': [13262, 24, 0, 333], 'wb_mem': 0}, 'lex': {'acc': [10268812, 2673, 54, 47349], 'reads': [6141135, 2603, 54, 6], 'writes': [4127677, 70, 0, 47343], 'wb_mem': 0}, 'parse': {'acc': [12449366, 5540, 49828, 75016], 'reads': [8449857, 4007, 49735, 243], 'writes': [3999509, 1533, 93, 74773], 'wb_mem': 0}, 'check': {'acc': [596566136, 296806017, 429529, 206192], 'reads': [522102230, 295797870, 360315, 242], 'writes': [74463906, 1008147, 69214, 205950], 'wb_mem': 0}, 'emit': {'acc': [143278863, 9148976, 346670, 185109], 'reads': [95367449, 8288883, 217856, 664], 'writes': [47911414, 860093, 128814, 184445], 'wb_mem': 16925}, 'write': {'acc': [2063, 20, 146, 75], 'reads': [1223, 4, 127, 10], 'writes': [840, 16, 19, 65], 'wb_mem': 1}}}
cpp_w1 ['name', 'kind', 'xbins', 'ybins', 'sample_rate', 'samples', 'accesses', 'instructions', 'c_bytes_out', 'stage_segments', 'stage_totals', 'regions']
{'name': 'C++ front end (build/goose -o out.c)', 'kind': 'cpp', 'xbins': 720, 'ybins': 72, 'sample_rate': 64, 'accesses': 559308707, 'instructions': 1158579885, 'c_bytes_out': 1328942, 'stage_segments': [['start', 0.0, 0.0017202328835626806, 33], ['parse', 0.0017202328835626806, 0.031017391444621508, 2649579], ['check', 0.031017391444621508, 0.5966360500450938, 51698347], ['optimize', 0.5966360500450938, 0.792229137399769, 640213349], ['emit', 0.792229137399769, 0.9755853007724687, 900384058], ['write', 0.9755853007724687, 0.9767500846902363, 1127361699], ['start', 0.9767500846902363, 1.0, 1128936630]], 'stage_totals': {'start': {'acc': [13415502, 132992, 294335, 130652], 'reads': [8922655, 131338, 291664, 125685], 'writes': [4492847, 1654, 2671, 4967], 'wb_mem': 104730}, 'parse': {'acc': [16172352, 134378, 3295, 95844], 'reads': [9733788, 120734, 3014, 212], 'writes': [6438564, 13644, 281, 95632], 'wb_mem': 0}, 'check': {'acc': [309031307, 6025962, 788753, 509771], 'reads': [179221103, 4259532, 579061, 7513], 'writes': [129810204, 1766430, 209692, 502258], 'wb_mem': 86331}, 'optimize': {'acc': [107164367, 1363677, 887927, 23858], 'reads': [71357672, 1165912, 861677, 11931], 'writes': [35806695, 197765, 26250, 11927], 'wb_mem': 23235}, 'emit': {'acc': [100827805, 1075738, 503201, 80178], 'reads': [61333405, 824361, 431944, 6064], 'writes': [39494400, 251377, 71257, 74114], 'wb_mem': 72701}, 'write': {'acc': [616617, 19920, 10194, 82], 'reads': [386929, 19821, 9523, 79], 'writes': [229688, 99, 671, 3], 'wb_mem': 4348}}}
counters ['uptime', 'modes', 'stages']
{'uptime': ['01:40:14 up 32 min,  0 user,  load average: 5.31, 5.45, 3.94', ' 01:40:31 up 32 min,  0 user,  load average: 4.66, 5.30, 3.91']}
embedded W1 []
embedded W3 []
source lines 5041

exec
/bin/bash -lc "sed -n '1476,1535p' selfhost/checker.goose; rg -n '"'^const LADDER'"' research/viz/index.html; nl -ba research/demo | sed -n '387,411p'; nl -ba research/LADDER.md | sed -n '35,58p'; cat README.md | head -n 35" in /home/exedev/goose-w
 succeeded in 0ms:
    return id;
}
// A checked file that declares no main in any namespace is a library: its
// declarations are checked without an entry point, as `goose check` does.
fn check_program(ctx: Compiler&, library: bool) {
    for n in ctx.declarations { if ctx.nodes[n].tag == N_FUNCTION && ctx.tokens[ctx.nodes[n].token].text == "format" { error_at(ctx, ctx.nodes[n].token, "not implemented yet: custom formatting dispatch"); } }
    initialization_order(ctx, 0);
    for n in ctx.global_order { check_binding(ctx, n, 0); }
    var main_symbol = -1;
    for s, i in ctx.symbols { if s.scope == 0 && s.kind == 3 && s.ns < 0 && ctx.tokens[s.token].text == "main" { main_symbol = i; } }
    var declares_main = false;
    for n in ctx.declarations { if ctx.nodes[n].tag == N_FUNCTION && ctx.tokens[ctx.nodes[n].token].file == 0 && ctx.tokens[ctx.nodes[n].token].text == "main" { declares_main = true; } }
    if main_symbol < 0 && !(library && !declares_main) { write_stderr("error: no root-file main function\n"); exit(1); }
    if main_symbol >= 0 { check_function(ctx, main_symbol, -1, 0); }
    // Fully annotated, non-generic top-level bodies are checked even unused.
    // Generic and nested declarations remain demand-driven.
    let original_symbols = ctx.symbols.len;
    for i in original_symbols {
        let s = ctx.symbols[i];
        if s.scope != 0 { continue; }
        if s.kind == 1 {
            let d = ctx.nodes[s.decl];
            if d.tag == N_ALIAS { resolve_type(ctx, d.a, 0); }
            else if d.tag == N_STRUCT && ctx.nodes[d.a].first < 0 { struct_type(ctx, s.decl, 0); }
        }
        if s.kind == 3 && ctx.nodes[s.decl].first < 0 && ctx.nodes[s.decl].flags & 2 == 0 {
            var typed = true;
            var e = ctx.nodes[ctx.nodes[s.decl].a].first;
            while e >= 0 { if ctx.nodes[ctx.edges[e].value].a < 0 { typed = false; } e = ctx.edges[e].next; }
            if typed { check_function(ctx, i, -1, 0); }
        }
    }
    // Replay after bodies have closed, including recursive back edges whose
    // eventual shrink effects were not known on the first traversal.
    var changed = true;
    while changed {
        let before = ctx.effect_revision;
        for call in ctx.checked_calls {
            ctx.checking_function = ctx.scopes[call.scope].function;
            var effect = ctx.specializations[call.callee].shrinks;
            while effect >= 0 {
                let shrink = ctx.shrinks[ctx.edges[effect].value];
                if !shrink.balanced && !ctx.nodes[call.node].standalone { error_at(ctx, ctx.nodes[call.node].token, "not implemented yet: call that shrinks within a larger expression"); }
                check_shrink(ctx, shrink.root, element_type(ctx, ctx.symbols[shrink.root].ty), call.scope, ctx.nodes[call.node].token, shrink.balanced, true);
                effect = ctx.edges[effect].next;
            }
        }
        changed = ctx.effect_revision != before;
    }
    ctx.checking_function = -1;
    call_cycles(ctx);
    for call in ctx.checked_calls {
        let caller = ctx.scopes[call.scope].function;
        if caller >= 0 && ctx.specializations[call.callee].cycle == ctx.specializations[caller].cycle {
            for local in ctx.symbols {
                if local.kind == 2 && local.ty >= 0 && ctx.scopes[local.scope].function == caller && ctx.types[local.ty].size_class > 0 && scope_contains(ctx, local.scope, call.scope) { error_at(ctx, ctx.nodes[call.node].token, "call into a recursive cycle while nonfixed local is in scope"); }
            }
        }
    }
}
96:const LADDER = [];
   387	    fs = []
   388	    for f in sorted(t.glob("*/*.goose")):
   389	        if f.parent.name in W2_EXCLUDED_DIRS or f.name == "lexer_tokens.goose":
   390	            continue
   391	        if not (t / "expected" / f"{f.stem}.out").exists() or f.with_suffix(".build").exists():
   392	            continue
   393	        line = f.open(encoding="utf-8", errors="replace").readline()
   394	        if "parse-only" in line:
   395	            continue
   396	        defines = re.findall(r"^// runtime-define: (\w+=\w+)$", line)
   397	        fs.append((f, ["-D" + d for d in defines], "no-jit" in line))
   398	    return fs if full else fs[::10]
   399	
   400	
   401	def fixture_ok(f, r):
   402	    """Exit status as the suite wants it (an .aborts fixture must fail) and
   403	    stdout equal to the blessed output."""
   404	    e = ROOT / "test" / "expected"
   405	    aborts = (e / f"{f.stem}.aborts").exists()
   406	    if (r.code == 0) == aborts:
   407	        return False, f"exit {r.code}"
   408	    want = normalized((e / f"{f.stem}.out").read_text(encoding="utf-8", errors="replace"))
   409	    return normalized(r.out) == want, "stdout"
   410	
   411	
    35	|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
    36	| - | stock optimized | front end (C++) | 0.320 | 0.363 | 0.416 | 5 | 287.61 KB | 2.19 MB | 72.9 MB | ok: - |
    37	| - | stock optimized | C compiler (gcc -O2) | 5.822 | 6.096 | 6.611 | 5 | 2.19 MB | 451.99 KB | 292.8 MB | ok: - |
    38	| - | stock optimized | run (compile selfhost) | 0.138 | 0.141 | 0.161 | 5 | 287.61 KB | 2.10 MB | 53.7 MB | ok: - |
    39	| - | stock optimized | check | 0.002 | 0.003 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
    40	| - | stock fast | front end+TinyCC+run | 0.883 | 0.966 | 1.065 | 5 | 287.61 KB | 2.10 MB | 123.4 MB | ok: - |
    41	| - | stock fast | check | 0.002 | 0.003 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
    42	| - | self-hosted | front end (sh2) | 0.177 | 0.201 | 0.230 | 5 | 287.61 KB | 2.10 MB | 55.4 MB | ok: - |
    43	| - | self-hosted | C compiler (gcc -O2) | 6.818 | 7.283 | 7.603 | 5 | 2.10 MB | 446.22 KB | 309.7 MB | ok: - |
    44	| - | self-hosted | run (compile selfhost) | 0.186 | 0.197 | 0.231 | 5 | 287.61 KB | 2.10 MB | 55.3 MB | ok: - |
    45	| - | self-hosted | check | 0.003 | 0.005 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
    46	
    47	Source to running program (W1, stages before the check, summed per run):
    48	
    49	| item | rung | min s | median s | max s |
    50	|---|---|---:|---:|---:|
    51	| - | stock optimized | 6.282 | 6.667 | 7.089 |
    52	| - | stock fast | 0.883 | 0.966 | 1.065 |
    53	| - | self-hosted | 7.181 | 7.726 | 8.004 |
    54	
    55	### W3
    56	
    57	| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
    58	|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/logo_white_fg_trans_bg_mini.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/logo/logo_black_fg_white_bg_mini.png">
  <img alt="The Goose programming language" src="docs/logo/logo_black_fg_white_bg_mini.png">
</picture>

# The Goose Programming Language

A memory-safe systems language with no heap allocator, garbage collector, or
lifetime annotations. In this repository's benchmarks, Goose runs faster than
C++ and Rust while using less memory.

[Tutorial](docs/tutorial.md) · [Reference](docs/reference.md) ·
[Specification](docs/goose_spec.md) · [Command line](docs/command_line.md) ·
[Packages](docs/packages.md) ·
[Samples](samples/README.md) · [Benchmarks](bench/results.md) ·
[Standard library](docs/stdlib.md)

Goose has syntax familiar to C and Rust programmers, but **there is no heap**.
Every dynamic value lives inline on data stacks managed by the compiler.
Growth advances a pointer, and memory is freed when its scope ends. The
language's type and lifetime rules make this memory model safe to use.

[![Discord Chat](https://img.shields.io/badge/chat-discord-blue)](https://discord.gg/397eZdbnsR)
[![Twitter Follow](https://img.shields.io/twitter/follow/wvo.svg?style=social)](https://twitter.com/wvo)

## Why Goose

* **Faster than C++ and than safe Rust, while memory safe.** Over sixteen
  benchmarks Goose runs at 3.3x the speed of idiomatic C++, 1.16x hand-optimized
  C++ and 1.12x the best safe Rust, and uses 1.9x, 1.3x and 1.2x less memory
  ([results](bench/results.md)). These gains
  come from Goose's data layouts and memory model.
* **No allocator, no GC, no reference counting, no destructors.** Memory is a
  handful of data stacks that the compiler assigns statically. Freeing a

codex
Attempted `./research/demo --quick --no-record`; it exited 1: **“Failed to connect to bus: Operation not permitted.”** No files edited; findings below are from code and committed records.

1. **Results missing from the pictures/demo:** the committed pictures page contains **`const LADDER = [];`**, despite two recorded ladder runs ([index.html:96](/home/exedev/goose-w/research/viz/index.html:96)). No before/after pictures show the three FINDINGS improvements. The self-hosted TinyCC result—**0.07 s compilation, 5.9 s execution, 18× slower**—is documented but absent from the demo’s rungs ([notes](/home/exedev/goose-w/research/notes/tcc-rung.md:8)).

2. **Correctness gaps:** “stdlib **6/17 compiling**” means only `--check` succeeds; no C compilation or execution is tested ([scoreboard.py:148](/home/exedev/goose-w/selfhost/scoreboard.py:148)). Error-marker matching discards diagnostic locations, so it does not establish rejection **where** markers require ([scoreboard.py:134](/home/exedev/goose-w/selfhost/scoreboard.py:134)). Demo W2 checks stdout and exit status but omits expected stderr ([demo:401](/home/exedev/goose-w/research/demo:401)). The normal bootstrap *does* rebuild and compare the C fixed point; positive fixtures *are* run and their outputs compared.

3. **Unlike timing comparisons:** W2’s **27.021 s optimized versus 3.753 s fast** covers **771 versus 733** passing fixtures; self-hosted **3.519 s** completes only **73/771** ([LADDER:99](/home/exedev/goose-w/research/LADDER.md:99)). The original dedup **12.63 → 5.74 s** comparison uses master source versus branch source ([notes:58](/home/exedev/goose-w/research/notes/emit-dedup.md:58)); FINDINGS subsequently records a same-input recheck, **14.48 → 6.29 s**.

4. **Milliseconds versus seconds:** symbol indexing and overload-chain work targets **0.30–0.33 → 0.09–0.14 s** ([JOURNAL:32](/home/exedev/goose-w/research/JOURNAL.md:32)). On the published current ladder, the front end is **0.201/7.726 s ≈ 2.6%**; gcc consumes **7.283 s ≈ 94%** ([LADDER:42](/home/exedev/goose-w/research/LADDER.md:42)). Dedup addresses those downstream seconds.

5. **Stale picture:** the page identifies **3,321 source lines**, built **01:41 at `5e5d79c5`**; this checkout has **5,041 lines** ([index.html:97](/home/exedev/goose-w/research/viz/index.html:97)). Its trace emits **3,661,811 bytes** of self-hosted C ([data](/home/exedev/goose-w/research/viz/data/selfhost_w1.json)), versus the later ladder’s **2.10 MB**. Thus the **25× / 97% checker** picture describes an older compiler, not the post-change result. Simulation is explicitly labeled; however, “time runs left to right” actually means **data-access count**, not seconds ([METHOD](/home/exedev/goose-w/research/viz/METHOD.md)).

6. **No qualifying JOURNAL passage found.** The entire journal is 38 lines; none declines or shrinks work because of time, usage, or session ending. Its postponement says **“W2 can't be compared until more fixtures pass”** ([JOURNAL:37](/home/exedev/goose-w/research/JOURNAL.md:37)), which is a correctness limitation.
tokens used
44,213
Attempted `./research/demo --quick --no-record`; it exited 1: **“Failed to connect to bus: Operation not permitted.”** No files edited; findings below are from code and committed records.

1. **Results missing from the pictures/demo:** the committed pictures page contains **`const LADDER = [];`**, despite two recorded ladder runs ([index.html:96](/home/exedev/goose-w/research/viz/index.html:96)). No before/after pictures show the three FINDINGS improvements. The self-hosted TinyCC result—**0.07 s compilation, 5.9 s execution, 18× slower**—is documented but absent from the demo’s rungs ([notes](/home/exedev/goose-w/research/notes/tcc-rung.md:8)).

2. **Correctness gaps:** “stdlib **6/17 compiling**” means only `--check` succeeds; no C compilation or execution is tested ([scoreboard.py:148](/home/exedev/goose-w/selfhost/scoreboard.py:148)). Error-marker matching discards diagnostic locations, so it does not establish rejection **where** markers require ([scoreboard.py:134](/home/exedev/goose-w/selfhost/scoreboard.py:134)). Demo W2 checks stdout and exit status but omits expected stderr ([demo:401](/home/exedev/goose-w/research/demo:401)). The normal bootstrap *does* rebuild and compare the C fixed point; positive fixtures *are* run and their outputs compared.

3. **Unlike timing comparisons:** W2’s **27.021 s optimized versus 3.753 s fast** covers **771 versus 733** passing fixtures; self-hosted **3.519 s** completes only **73/771** ([LADDER:99](/home/exedev/goose-w/research/LADDER.md:99)). The original dedup **12.63 → 5.74 s** comparison uses master source versus branch source ([notes:58](/home/exedev/goose-w/research/notes/emit-dedup.md:58)); FINDINGS subsequently records a same-input recheck, **14.48 → 6.29 s**.

4. **Milliseconds versus seconds:** symbol indexing and overload-chain work targets **0.30–0.33 → 0.09–0.14 s** ([JOURNAL:32](/home/exedev/goose-w/research/JOURNAL.md:32)). On the published current ladder, the front end is **0.201/7.726 s ≈ 2.6%**; gcc consumes **7.283 s ≈ 94%** ([LADDER:42](/home/exedev/goose-w/research/LADDER.md:42)). Dedup addresses those downstream seconds.

5. **Stale picture:** the page identifies **3,321 source lines**, built **01:41 at `5e5d79c5`**; this checkout has **5,041 lines** ([index.html:97](/home/exedev/goose-w/research/viz/index.html:97)). Its trace emits **3,661,811 bytes** of self-hosted C ([data](/home/exedev/goose-w/research/viz/data/selfhost_w1.json)), versus the later ladder’s **2.10 MB**. Thus the **25× / 97% checker** picture describes an older compiler, not the post-change result. Simulation is explicitly labeled; however, “time runs left to right” actually means **data-access count**, not seconds ([METHOD](/home/exedev/goose-w/research/viz/METHOD.md)).

6. **No qualifying JOURNAL passage found.** The entire journal is 38 lines; none declines or shrinks work because of time, usage, or session ending. Its postponement says **“W2 can't be compared until more fixtures pass”** ([JOURNAL:37](/home/exedev/goose-w/research/JOURNAL.md:37)), which is a correctness limitation.
