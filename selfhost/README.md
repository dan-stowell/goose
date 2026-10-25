# The self-hosted compiler

This is a Goose compiler written in Goose, being grown toward doing everything
the C++ compiler in `src/` does: first accepting and running the positive test
fixtures with their blessed output, then rejecting the error fixtures where
their markers say, then compiling `stdlib/`. `PLAN.md` has the goal
and the task list. `main.goose` imports the other thirteen modules.

It was seeded from [test/goose_in_goose/](../test/goose_in_goose/README.md),
which stays frozen as the bootstrap regression it was. This copy is the one
that changes. Like its seed it compiles a subset of Goose to C with a runtime
of its own, and its acceptance or rejection of a program is not yet the
language's expected behavior.

It is written clean-room: whoever writes code here works from `docs/`,
`stdlib/`, the fixtures and what `build/goose` does when run, without reading
`src/`. When the docs don't settle a behavior, that is reported rather than
guessed, and the answer goes into the docs.

The normal suite bootstraps it in a section of its own, through the same three
stages as goose_in_goose: the real compiler emits stage 1, each stage compiles
these sources into the next, and stage-2 and stage-3 C must be identical. To
run just that:

```sh
python3 test/run_tests.py --selfhost-only --exe build/goose --cc native
```

Every change here keeps that fixed point. The usual `--profile`, `--no-jit`
and `--nocgen` options apply, as described in
[docs/testing.md](../docs/testing.md). Generated C, executables and per-stage
logs go in `build/gen/<profile>/selfhost/O<level>/`.
