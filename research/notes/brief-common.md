Context (shared by all builders). Repo: /home/exedev/goose, Dan's fork of aardappel/goose (a systems
language that compiles to C). Read research/CHARTER.md (goal, ladder, deliverables) first; it is short.
Our work lives only in research/ and selfhost/; never edit src/ or test/ (upstream). Never push to
aardappel/goose; pushing to origin (this fork) is fine, branch as told below.

VM facts established 2026-11-17 (8 cores AMD EPYC 9554P under KVM, 31 GB, Ubuntu 24.04):
- C++ compiler built at /home/exedev/goose/build/goose (Release, all packages compiled in: gfx works
  headless with GOOSE_GFX_HEADLESS=1 via mesa lavapipe). Use that binary from your worktree (pass
  absolute path); do not rebuild build/ in the main checkout. gcc 13.3.0. No standalone tcc binary;
  TinyCC is in-process in `goose file.goose` (source of tinycc in third_party/tinycc if you need a CLI).
- perf at /usr/local/bin/perf (paranoid=2, user-space counts work: cycles, instructions,
  cache-references, cache-misses, L1-dcache-loads; LLC-* not supported; L1-dcache-load-misses reads 0).
  valgrind 3.22 installed (cachegrind, lackey). sudo works without password.
- Ladder rungs: stock optimized = `goose build x.goose -o out` (C++ front end + gcc -O2);
  stock fast = `goose x.goose` (C++ front end + TinyCC in process, runs it);
  self-hosted = build selfhost/ with `goose build selfhost/main.goose -o sh1`, then
  `sh1 -o sh2.c selfhost/main.goose; gcc -O2 sh2.c -o sh2 -lm` ; then `sh2 -o out.c x.goose` and gcc -O2.
  Fixed point: sh2 -o sh3.c selfhost/main.goose; cmp sh2.c sh3.c.
  Measured once: goose build selfhost -> 6.7 s; sh1 emitting sh2.c 0.48 s, 3.66 MB of C.
- W2 stock: `python3 test/run_tests.py` = 54 s wall (8 jobs), all pass. `--goose-in-goose-only` 24.5 s.
- W3 samples: samples/*.goose with samples/expected/<name>.out; args in samples/data/<name>.args,
  stdin in data/<name>.stdin; run with samples/ as cwd. 31_mini_doom needs GOOSE_GFX_HEADLESS=1 and
  args `--frames 30 --wad data/freedoom1-e1m1.wad`. samples/run_samples.py shows exactly how they run.
- Measuring: >=5 interleaved runs, min/median/max, note `uptime`. Cap anything data-dependent:
  `systemd-run --user --scope -p MemoryMax=8G timeout ...`. Delete only with literal paths.
- Commit often with real messages ending in the line
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Add one line per commit to research/JOURNAL.md
  (`- YYYY-MM-DD <what>`). When done, report in five lines or fewer; put details in a file you commit.
