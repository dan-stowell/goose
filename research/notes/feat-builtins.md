# feat-builtins — 2026-11-17

Implemented checker/emitter/runtime support for `check_length`, `range_index`,
`pop_n`, `move_from`, `index_of`, `bytes_of`, `free`, `alloc_index`, `alloc_ref`,
`alloc_slice`, `free_slice`, and `realloc_slice`. Read the builtin table,
`typecheck_builtins.h`, `codegen_builtins.h`, and the reference span allocator.
No edits to `src/` or `test/`.

Counts and ranges validate signed/unsigned inputs; custom messages retain source
locations. Moves use memmove and capture the destination before source evaluation.
Byte views reject pointer-containing images and temporary owners, preserve const
and grow-shrink restrictions, and participate in shrink checks, including merged
roots, loops, captured values, and container-held views. `index_of` requires an
exact array-element root; it is not a runtime search.

Slot pools retain elements after free, select freed slots in LIFO order, and
reset their bookkeeping when a local pool is constructed again. Fixed elements
are evaluated before claiming a slot, matching the reference. Pool metadata uses
independent data-stack arenas; it does not consume element storage or use malloc.
Slice pools use a sorted coalescing span vector: lowest fitting span first, then
free tail extension, then append. Reallocation grows in place where possible and
otherwise releases/coalesces before overlap-safe relocation. Defaults execute for
every new element, including nested fixed arrays and side-effecting field defaults.
The vector is an initial correctness implementation, not the reference's faster
span tree. No performance claim is made.

Also fixed loaded loop-slice provenance, reusable-pool shrink through merged
references, and dispatch of user overloads sharing builtin names. Master gained
bytes_of, pop_n, enums, generics, packed storage and emitter work during this run;
rebases required consolidating dispatch and resolving runtime additions. The final
rebase also integrated case dispatch and loop-control work; new builtin IDs are
now named constants in a separate range. Scalar iteration copies must not inherit
a grow-shrink reference restriction from the sequence they were read from.
A subsequent rebase added relative references, root storage and the accepted-error
ratchet. Slot allocation now builds self-relative aggregates in place and encodes
relative reference elements at their final slot; alloc_ref of a reference element
returns its referent. Move/reallocation reject self-relative relocation. Byte images
permit self-relative offsets but reject references measured from external pools.
Pool references retain their original capability across narrowing, parameters and
rebinding; slot/slice metadata cannot be interchanged. Shrink effects carry their
element type across calls, including shrinks of a root owner's array fields.

## Measured boards

| point | run | exact reject diagnostics | stdlib | W1 |
|---|---:|---:|---:|---|
| starting worktree | 23/776 | 4/2036 | 0/17 | fixed point |
| rebased master c7c4e0a8 committed board | 133/776 | 65/2036 | 8/17 | — |
| this branch | 150/776 | 71/2036 | 8/17 | fixed point |

Thus the raw +127 positives include concurrent master work; this branch adds 17
passing positives and 6 exact diagnostics over that master board. The accepted-error
ratchet also passes: 395 erroneous fixtures remain accepted versus master's 435,
with no newly accepted fixtures. The existing many-spans pool fixture,
bounds failures, message failures, and slot-reuse fixture now pass.

## Reproduction

The sandbox cannot write the reference compiler's normal ~/.goose build cache:

```sh
export GOOSE_HOME=/home/exedev/.cache/goose-builtins
python3 selfhost/scoreboard.py --goose /home/exedev/goose/build/goose --enforce
python3 selfhost/tests/check_builtins.py --goose /home/exedev/goose/build/goose
python3 selfhost/tests/check_slice_runtime.py --goose /home/exedev/goose/build/goose
```

The first command rebuilds both compiler stages, checks the C fixed point and
scores all boards. The second compares six successful programs against the
reference and checks negative programs with both compilers. The third extracts
the actual embedded C runtime, compares 500 seeded allocation/free/reallocation
operations against the reference, and tests ten boundary cases under UBSan.
All passed before the corresponding commits.

## Goose observations

Append-only compiler tables and integer IDs made checked synthetic default trees
straightforward. The lifetime checker caught a recursive emitter call retaining
a temporary formatted string; naming the saved destination before recursing fixed
it. Rebinding text first borrowed from static storage to text owned by the compiler
requires choosing the compiler-owned root at initialization. Struct initializer
field order is also checked by the selfhost, so stage-one success alone is not
sufficient. The fixed point and independent runtime comparisons caught distinct
errors, especially dispatch collisions during rebases and default evaluation order.

## Remaining work and limits

Threads and queues remain unimplemented: `thread_spawn`, contained workers,
`thread_wait`, `qput`, `qlimit`, `qget`, and `qpoll` require genuine asynchronous
execution, isolated global/data-stack state and typed FIFO message storage. They
were audited, but no synchronous spawn or no-op queue stubs were added.

Byte images currently require fixed-size elements and reject zero-size layouts
whose C placeholder bytes differ from the language image. Index recovery and pool
operations conservatively reject roots they cannot prove exact. Index recovery
handles slice-slot addresses and writable references read back from the unique
global owner of their element type. This leaves the
slice-pool model fixture blocked at index_of and branch-pool fixtures blocked by
merged pool provenance. Existing reference-rebinding and other compiler gaps also
prevent some fixtures from reaching these builtins. Byte-view last-use handling
is conservative across loops, captures and later same-name tokens.

## Publication

The requested worktree's Git metadata lives under /home/exedev/goose/.git and is
read-only in this sandbox. Changes were committed from a separate writable clone
at /home/exedev/.cache/goose-builtins-publish, with origin explicitly set to Dan's
fork. Only feat-builtins is pushed, after fetching and rebasing origin/master.
The requested worktree has the tested source changes but its local Git HEAD/index
cannot be advanced by this session; its diff therefore also shows rebased master
changes. The publication clone is the authoritative committed checkout.
