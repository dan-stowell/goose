# JOURNAL

Append-only: one line per commit, a paragraph at each milestone.

- 2026-11-17 setup: charter, plan, loop and harness; selfhost/ seeded from test/goose_in_goose (upstream 3a0aa2eb).
- 2026-11-17 M0 setup: VM is 8 cores EPYC 9554P/31 GB; research/setup.sh installs cmake, perf (6.8 tools), valgrind, SDL deps, lavapipe; C++ compiler built with all packages (mini_doom runs headless). W2 stock suite (run_tests.py, 8 jobs) 54.4 s wall, all pass; goose_in_goose bootstrap 24.5 s. Builders launched: demo (branch demo), bytes/viz (branch viz).
- 2026-11-17 selfhost/scoreboard.py: bootstrap + fixed point + three boards. Baseline: run 23/776, reject 3/2035 (1951 exit 1 but markers unmatched, 80 accepted), stdlib 0/17; fixed point yes; 16 s on 8 cores. Biggest cluster: stdlib/std.goose:1348 parameter defaults don't parse (168 run fixtures).
