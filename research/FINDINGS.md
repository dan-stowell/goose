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
