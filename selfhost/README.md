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

The full suite also scores stage 2 against the positive execution fixtures,
building its C at the profile's lowest cgen setting (native `-O0` for baseline)
and checking their usual output and expected aborts. Fixtures requiring
`goose build` for sidecar C, packages or native modules are `unsupported`.
Run just the scoreboard and its bootstrap with
`python3 test/run_tests.py --selfhost-score-only --exe build/goose --cc native`.
Each fixture has a 30-second emit/build/run budget, and every result and its
first diagnostic go in `build/gen/<profile>/selfhost/scoreboard/run.tsv`.
The sorted passing names in `scoreboard/run.txt` are the ground the suite
holds: regressions fail, while newly passing fixtures are reported. Add them
with `--bless-selfhost`; it refuses to drop any baseline entry that fails or
disappears. Reports and baselines are separate for each board;
`--bless-selfhost` applies to every board and refuses regressions per board.
If stage 2 fails to bootstrap, the previous report is preserved.
