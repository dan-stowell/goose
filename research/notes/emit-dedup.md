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
