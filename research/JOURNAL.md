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
- 2026-11-17 feat-enums: user format overloads (custom formatting dispatch), by value or reference, generic ones on struct/enum patterns; run 40->43.
- 2026-11-17 feat-enums: value-producing break for loop/block (joined like branches); run 43->44.
- 2026-11-17 feat-enums: case-function tag dispatch, variable-mode enums (E..), float text per 3.7; run 67->79.
- 2026-11-17 viz2: before/after pictures (aa0092db vs HEAD, own and same input), cc1 traced on both Cs, ladder over time, regen.sh; front end 0.32 -> 0.13 s on the same input, gcc -O2 10.4 -> 7.6 s.
- 2026-11-17 research/demo: self-hosted gcc -O0 and fast (TinyCC) rungs, W2/selfhost-pass like-for-like subset, rev on every record.
- 2026-11-17 LADDER.md and research/runs/20261117T015525Z-92b547b4.json: full run with --before 0aa09be4 (load avg ~15 during it).
- 2026-11-17 review triage (M0 skeptic): demo W2 checks expected stderr; stdlib board also emits+compiles a program importing each module.
- 2026-11-17 feat-storage: optionals (T?, T&?, null, .= rebinding, flow narrowing by if/while/guard/assert/&&/null tests with a persistent fact list), stack-overflow fault report; run 63 -> 72.
- 2026-11-17 feat-storage: root structs (one data-stack slot per nonfixed field, per-field provenance pseudo-symbols); run 72 -> 87, stdlib 6 -> 8.
- 2026-11-17 feat-storage: check_length, range_index, index_of; runtime flushes stdout before an abort; run 87 -> 98.
- 2026-11-17 feat-storage: globals with only a type start as their default; .= assigns in generic code; run 98 -> 101.
- 2026-11-17 feat-storage: relative references (self- and pool-relative, u8..u64), built in place when pushed, rendered from their slot; run 101 -> 110.
- 2026-11-17 feat-enums: checks with the features: break type fixed by the first break, implicit copies and dead roots out of match arms and breaks, zero-size variant/zero-length array fields and elements, negated literal range, pattern names (nested fn, type parameter); reject 39->61.
- 2026-11-17 scoreboard ratchet 2: error fixtures wrongly accepted may not grow (selfhost/scoreboard/accepted.txt, 435). Boards after storage+enums: run 133/776, reject 65/2036, stdlib 8/17.
- 2026-11-17 feat-storage: relative-link checks (pool and same-root targets, no copies of values holding self-relative links); reject 43 -> 53.
- 2026-11-17 selfhost defer: parsed (statement or block), checked where written without leaving, emitted at block end, return, break and continue (stdlib 6->7 with exception, reject 19->27, run 30->31)
- 2026-11-17 selfhost literal parameters (7.7) with whole-program literal verification, and .= as = in generic code; std.goose now checks once its two limited arrays and one block literal are patched out
- 2026-11-17 selfhost static function values (7.6): block literals (named params or it) and function names bind leftover generics; blocks are anonymous nested functions of the caller, their frames handed to the HOF as env parameters. std.goose now checks with only its two limited arrays patched (run 31->33)
- 2026-11-17 selfhost runtime gains std's externs (libm wrappers, bit ops, float bits, find_any/pair, shortest digits, os file/dir/stdin/env/time/random) and a loop tail no longer emits a void assignment; against std with its two limited arrays patched, 52 std-importing fixtures pass
- 2026-11-17 selfhost prints floats shortest for their type (mined from gap-float-text 3837407b), computes literal-like floats at the f32 they adapt to, and builds array literals viewed as slices in a temporary (run 33->42)
- 2026-11-17 selfhost tracks how exactly a constant is known (exact, joined range, or adapting with unknown value: 1 << k, ~c, literal params) and computes an adapting integer expression at the type it adapts to (run 42->43; 61 std fixtures pass against patched std)
- 2026-11-17 feat-stdlib rebased onto master (storage, enums, emit-dedup): std checks; stdlib 12/17, run 131/776, reject 49
- 2026-11-17 selfhost resolves names lexically for constant positions, values, calls and assignments (type parameters, nested functions, locals hide globals) and bounds a growing type's field-default cycle (reject 49->84, accepted 294->260)
