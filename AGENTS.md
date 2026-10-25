# Agent guide

Read by every agent on this repo: Claude Code (through CLAUDE.md) and Codex.

## The repo

Goose is a memory-safe systems language with no heap; this is its compiler.
`goose` is C++20 (`src/`, one translation unit of headers under `main.cpp`)
and compiles Goose to one C file, built by the native C compiler or run
in-process through the vendored TinyCC (`--jit`).

- `docs/goose_spec.md`: the exact language rules. `docs/reference.md`,
  `docs/tutorial.md`: the language by topic and by example.
  `docs/implementation.md`: how the C++ compiler is built. `docs/design/`:
  design notes. `docs/testing.md`: the test suite, in full.
- `stdlib/`: the standard library, in Goose.
- `test/`: fixtures by category plus `run_tests.py`. `test/expected/` holds
  blessed outputs.
- `test/goose_in_goose/`: a compiler for a subset of Goose written in Goose
  (~3.3k lines, 14 modules). It bootstraps itself to a C fixed point. It was
  written from the docs and black-box behavior without reading `src/`.
- `samples/`, `bench/`: complete programs and benchmarks.

`origin` is Dan's fork. `upstream` is aardappel/goose.

## Building and testing

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug          # once per checkout
cmake --build build -j 14
python3 test/run_tests.py --exe build/goose --profile baseline --cc native --require-clang
```

Faster loops while working:

```sh
python3 test/run_tests.py --exe build/goose --cc native --goose-in-goose-only   # just the bootstrap
build/goose --check some.goose                                                    # typecheck one file
build/goose --jit some.goose                                                      # run one file in-process
```

The bootstrap writes its stages and logs to
`build/gen/<profile>/goose_in_goose/O<level>/`. Run the full suite before
calling a task done. It takes about as long as the -O0 bootstrap chain does.

## Working rules

- One task per branch, and one git worktree per branch under `~/goose-wt/<task>`.
  Don't work in `~/goose` itself; that checkout belongs to the coordinator.
- Small commits, each building and passing what it touches. Write commit
  messages in the repo's style (see `git log`): one plain sentence saying
  what changed.
- Add a test with every behavior change. A new behavior gets a fixture with
  its output blessed in `test/expected/`. A new rejection gets a fixture with
  `// error:` markers.
- Never weaken, delete or re-bless a test so that it passes. If a test is
  wrong, say so in your report and leave it to the coordinator.
- Match the surrounding code and comments. Comments in this repo explain why,
  in full sentences.
- Finish with a short report: what you changed, what you ran and its result
  (paste the summary lines), and anything you weren't sure about.

## The self-hosted compiler

`selfhost/` is a Goose compiler written in Goose, grown toward doing what
`src/` does (see `PLAN.md`). It is clean-room: when you write `selfhost/`
code, don't read `src/`. Work from `docs/`, `stdlib/`, the fixtures and what
`build/goose` does when you run it. If the docs don't settle a behavior, say
so in your report rather than guessing. Reviewers and verifiers may read
`src/`. `test/goose_in_goose/` stays frozen; don't change it.
