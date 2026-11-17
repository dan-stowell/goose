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

## 4. The C leaned on gcc for everything (2026-11-17, emit-lean)
**Before.** Every subexpression in a temporary, every local in the frame struct, every index through a
gg_view helper call: TinyCC compiled it in 0.07 s but the result ran W1 18x slower than gcc -O2's.
**Fix.** Five emitter changes (research/notes/emit-lean.md): read array data/length in place; a temporary only
when a later operand could change the value, bounds checked inline; locals as C locals unless a nested function
reaches them; no redundant casts; && / || in conditions as jumps. **Number (lead's re-check, same input: current
selfhost source through the emitter before and after; 5 interleaved runs, load 5-6).** C 2,673,873 -> 1,712,616
bytes; tcc-built stage 2 on W1 1.73/1.92/2.02 s (one 5.4 s outlier) -> 0.92/1.11/1.26 s; gcc -O0 2.61/3.05/3.06
-> 1.94/2.08/2.12 s; gcc -O2 ranges overlap (builder's counters: 63.8 G -> 58.6 G instructions). The C++
compiler's 2.19 MB for the same program costs gcc 44.5 G instructions: per byte our C is still harder.
**Goose.** Forced: views can't be kept in containers inside a recursive cycle, so emission keeps arena offsets.
