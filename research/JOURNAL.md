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
- 2026-11-17 feat-storage: selfhost gets limited arrays (T[..k] fixed struct, T[..]) and packed variable-size storage (T[], T[uN], T[varint], variable struct fields, varint), pop_n.
- 2026-11-17 feat-storage rebased on master (enums, stdlib): run 40 -> 63, reject 39, stdlib 6; index_symbol added for two unindexed temporary-root pushes.
