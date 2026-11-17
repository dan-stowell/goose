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
