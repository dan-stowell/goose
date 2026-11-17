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
| lackey `--trace-mem=yes`, self-hosted `--parse` only (57 M instr) | 0.02 s | 91 s | ~5,000x | 1.17 GB of text | |

Lackey prints a text line per access and per instruction: extrapolated to the full compile (3.9 G
instructions) that is about 100 minutes and about 80 GB of text before any cache model runs, so
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
