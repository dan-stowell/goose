# emit-lean: C that is cheap to compile and fast without an optimizer (2026-11-17)

Goal (M3 groundwork): the selfhost's C leaned on gcc -O2 to remove a temporary per subexpression,
frame-struct traffic for every local, a `gg_view` call per array access and repeated header
loads. Through TinyCC that cost 6x (now) to 18x (tcc-rung.md) at run time.

## Method

`research/tools/emit_bench.sh OUT INPUT name=sh1 ...` writes each emitter's C for one fixed input
(here: master 8c1072de..c7c4e0a8's `selfhost/main.goose`, i.e. W1), checks that the gcc-built and
tcc-built compilers agree on their output, then reports bytes, and for each of gcc -O2, gcc -O0,
`tcc -c`, the tcc-built compiler running W1 (`run-tcc`) and the gcc -O2-built one (`run-gcc`):
user-space instruction counts (`perf stat -e instructions:u`, children included: deterministic on
this shared VM, so one run each) and RUNS interleaved wall times
(`research/tools/bench_summary.py` prints min/median/max). Each idea is one commit; the per-idea
table builds each commit's emitter and runs all of them on the same input.

Correctness for every step: W1 fixed point (sh2.c == sh3.c), `scoreboard.py --enforce`
(final: run 133/776, reject 65/2036, stdlib 8/17, accepted 435, the same as master), and
`research/tools/evaluation_order.goose` (operands changed by later calls, nested functions writing
the parent's locals, compound assignment with a call on the right, short-circuit side effects in
if/while), whose output must match stock `goose` (`12 1121 15 1020 16 5 8 11 false 10` /
`200 15011`).

## Per idea (instructions; each row is the commit applied on top of the previous)

| step | C bytes | gcc -O2 | gcc -O0 | tcc -c | run-tcc (W1) | run-gcc (W1) |
|---|---|---|---|---|---|---|
| master (c7c4e0a8) | 2,543,682 | 63.76G | 21.67G | 437M | 12.16G | 1.974G |
| 1 read arrays in place (7cdf7ab9) | 2,401,931 | 62.98G | 19.88G | 409M | 8.19G | 1.998G |
| 2 sample only when needed, inline index check (54623cab) | 2,042,125 | 60.81G | 17.41G | 365M | 6.33G | 2.004G |
| 3 locals as C locals (addfc54a) | 1,809,173 | 59.09G | 16.55G | 325M | 6.27G | 1.808G |
| 4 casts, literals, condition temp reuse (337d63e5) | 1,632,140 | 58.95G | 16.38G | 300M | 6.18G | 1.808G |
| 5 && / \|\| conditions as jumps (f65933bd) | 1,630,358 | 58.58G | 16.21G | 297M | 5.67G | 1.773G |
| total | -36% | -8% | -25% | -32% | -53% | -10% |

1. **Read arrays in place.** `c_view_parts` gives an array's data pointer and length as C
   lvalues (`(h).base`/`(h).len`, `(s).data`/`(s).len`, `(a).data`/count, `(a).e`/`(a).len`). Indexing, slicing,
   `.len` and `for` use them instead of `gg_view(...)`; in tcc that was a struct-returning call
   (15% of the tcc-built compiler's samples, twice per loop iteration in the hot linear scans).
   When the index (and slice bounds) are pure (`pure_expression`: names, literals, operators,
   members, indexing; no calls, blocks or assignments) and the array's own code cannot fail, the
   array is read after the bounds with no slice temporary at all.
2. **Sample an operand only when a later one can change it.** A binary operator's left operand,
   a call argument and a compound assignment's old value get a temporary only if a later operand
   is impure, or the operand's code itself can fail (`code_may_fail`: slices, `/`, `%`), so
   failures keep their order. Right operands, unary operands, `if` conditions and values that
   are already temporaries never get one. The bounds check is an inline
   `if ((uint64_t)i >= (uint64_t)n) gg_index_fail();` instead of a `gg_index` call.
3. **Locals as C locals.** A local stays in the frame struct only if a nested function of its
   owner exists (it is reached via `frame.parent`); otherwise it is a C variable and a parameter is
   used in place (no `frame.vN = pN` copy). Addresses of locals need no frame: a C local lives as
   long as the call. tcc gains little here (it keeps both on the stack); gcc -O2's build gains 10%.
4. **Casts and literals.** No numeric cast to the type a value already has; literals below 2^31
   are `((T)n)` rather than `((T)UINT64_C(n))`; a nested `&&`/`||` reuses its operand's
   temporary as its result.
5. **Conditions as jumps.** `if`/`while` conditions built from `&&`, `||` and `!` become
   `if (!(a)) goto L;` chains (`c_branch`), as the C++ compiler emits, instead of a bool
   temporary per operator.

Tried and dropped: making `gg_view`, `gg_ref`, `gg_index` and `gg_get_stack` macros. tcc's run
barely moved (1.12 vs 1.17 s) and gcc -O2/-O0 got slower (8.96 vs 7.47 s median -O2): the macro
text is reparsed at every use. Reading the parts at the source (step 1) got the tcc win without it.

## Wall times (5 interleaved runs, min / median / max)

Load average 3.5-6.2 (other builders running); the `max` column carries their noise.

| measurement | master | emit-lean |
|---|---|---|
| (a) bytes of C for W1 | 2,543,682 | 1,630,358 |
| (b) gcc -O2 | 8.77 / 9.13 / 21.78 s | 7.88 / 8.27 / 9.69 s |
| (d) gcc -O0 | 2.69 / 2.95 / 6.60 s | 1.76 / 1.93 / 2.83 s |
| tcc -c | 0.04 / 0.08 / 0.12 s | 0.03 / 0.03 / 0.09 s |
| (c) tcc-built stage 2, W1 | 1.60 / 2.49 / 3.43 s | 0.87 / 0.91 / 1.15 s |
| gcc -O2-built stage 2, W1 | 0.28 / 0.37 / 0.47 s | 0.23 / 0.25 / 0.42 s |

The gcc -O2 ranges overlap (the instruction count, -8%, is the reliable number); the others do not.

## Where it stands, and what is left

- The tcc-built compiler now runs W1 in 3.2x the instructions of the gcc -O2 build's instructions (was 6.2x).
  Its profile is the checker's linear scans (`check_shrink` over all symbols, copying each
  116-byte Symbol per iteration, as the C++ compiler's C does too).
- gcc -O2 no longer tracks bytes: our 1.63 MB costs it 58.6G instructions, the C++ compiler's
  2.19 MB of C for the same program 44.5G. Its time spreads over all passes (-ftime-report: no pass
  above 9%), so the remaining lever is fewer statements per Goose node, not fewer bytes.
- Next ideas: loop over arrays with a pointer cursor and hoist the header load out of the loop
  when the body does not write the array; bind `let x = a[i]` of a struct as a pointer when
  nothing in its scope writes the array; inline the small one-call helpers (`scope_contains`) as
  the C++ front end does.

## What Goose made easy, forced, or could not express

- Easy: the emitter's whole state is flat tables indexed by node and symbol, so "is this subtree
  pure", "does this function own a nested function" are a few lines each over `ctx.nodes` and
  `ctx.specializations`, with no new structures.
- Forced: a recursive helper must be declared `recursive fn` (§7.8), checked by call-cycle
  analysis; `short_circuit` calling itself was rejected until marked.
- The selfhost's own tables are reached through `ctx: Compiler&`, so even a scratch buffer can't be
  shrunk (see emit-dedup.md); here that made no difference.
