# IDEAS

Each idea: source, kill test, status.

| idea | source | kill test | status |
|---|---|---|---|
| Emit one C body per class of identical specializations | lead, research/notes/dedup.md | c_dedup.py on sh2.c reports ~0 dup bytes and gcc -O2 time falls >30% with W1 fixed point | building (emit-dedup); textual experiment: 9.9 s -> 4.65 s |
| Key specializations on what lowering needs; check provenance per call site without re-checking the body | lead | front-end check time share (count specializations checked, time --check) >25% of front end | open; after emit-dedup |
| Self-hosted rung through TinyCC: build a tcc CLI (or libtcc) from third_party/tinycc | charter ladder | tcc compiles sh2.c and the result passes the fixed point | open |
| Inline small functions in the emitter like the C++ compiler's -O2 (209 vs 918 functions for W1) | lead | gcc time per function: count functions vs gcc seconds on dedup output | open |
| Direct machine code for the fast path (copy-and-patch / codegen by shape, SHAPES.md) | charter | front end + tcc time on W2 is dominated by tcc, not the front end | open; M3 |
