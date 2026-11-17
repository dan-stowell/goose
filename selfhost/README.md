# selfhost: Goose compiler written in Goose

Seeded on 2026-11-17 from upstream's `test/goose_in_goose/` (at 3a0aa2eb), which stays as upstream's
own bootstrap regression. This copy grows toward the whole language, memory-first; see
`research/CHARTER.md` and `research/PLAN.md`.

`main.goose` imports the other modules. Build it with the C++ compiler, then let it build itself:

```sh
goose build selfhost/main.goose -o build/sh1          # stage 1, built by the C++ compiler
build/sh1 -o build/sh2.c selfhost/main.goose          # stage 1 compiles itself
gcc -O2 build/sh2.c -o build/sh2 -lm                 # stage 2 (its C runtime is embedded)
build/sh2 -o build/sh3.c selfhost/main.goose && cmp build/sh2.c build/sh3.c   # the fixed point
```
