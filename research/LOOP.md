# LOOP: how a continuous run works

Read `research/CHARTER.md` first (the goal and the rules), then `research/PLAN.md` (the campaign). This
file is the procedure. A run has no deadline: `./overnight.sh` keeps sessions going until a `STOP`
file exists in the repo root, and starts a fresh session on PLAN.md whenever one ends. A session
ending is not an event. Never decline or shrink a step because of time, usage or the session ending.

The repo root is upstream Goose; everything of ours lives in `research/` and `selfhost/` (plus
`overnight.sh` and `.claude/`), so hourly merges from upstream don't collide with the run.

## Files (all under `research/` unless noted)

| file | who writes | what |
|---|---|---|
| `CHARTER.md` | Dan only | goal, rules, the ladder, deliverables |
| `PLAN.md` | Dan: the campaign; agent: Milestones log and the Now line | the campaign and its oracle number |
| `STATUS.md` | agent, at most ten lines | the oracle number, what moved, decisions for Dan |
| `JOURNAL.md` | agent, append-only | one line per commit; a paragraph at each milestone |
| `LADDER.md` | agent | the ladder table per workload, with the command that produced each row |
| `FINDINGS.md` | agent | each change: before, observation, fix, number; what Goose made easy / forced / impossible |
| `IDEAS.md` | agent | ideas, each with a kill test and status |
| `demo` | agent | the demo command (CHARTER.md, Deliverables) |
| `viz/` | agent | the pictures page and the scripts that regenerate it from runs |
| `reviews/inbox/`, `REVIEWS.md` | reviewers; agent triages | raw reviews; one line of triage each |
| `selfhost/` (root) | agent | the compiler |

## Working

Work the campaign continuously. There are no numbered iterations.

- Keep the Now line in PLAN.md exact: the next concrete step, ideally the command to run. A fresh
  session with no memory resumes from it.
- Commit and push every working step, with tests for what it touches, and one line in JOURNAL.md.
  Every commit that touches `selfhost/` keeps W1's three-stage fixed point and never lowers the
  fixture scoreboard.
- `git pull --rebase` before pushing. spawn merges upstream Goose into master hourly; if upstream
  broke `selfhost/` (a fixture or the fixed point fails right after a merge), fixing it is the next
  step, and JOURNAL.md says which upstream commit did it.
- Split the work into parts a test can check (a feature cluster, a stage of the demo, the viz
  pipeline) and hand independent parts to subagents in their own git worktrees, so they build in
  parallel.
- Run long measurements, suite runs and simulations as background scripts that report once.
- Triage `reviews/inbox/*` when something is there: one line each in `REVIEWS.md`, then move it to
  `reviews/done/`. Never wait for a reviewer.
- After any change that moves the ladder, regenerate the pictures page from the new runs.

## At each milestone (PLAN.md lists them)

1. Measure the oracle number; append the milestone to PLAN.md's log.
2. Bring `LADDER.md` up to date. Say plainly when a number got worse.
3. Write a JOURNAL.md paragraph that ends with: **"What did the oracle number do since the last
   milestone? If it stalled, what is the blocker, and what am I doing about it?"**
4. Regenerate the pictures page; put the TL;DR at its top.
5. Fire the background reviewer (below) on the milestone commit.
6. Overwrite `STATUS.md`.

If several hours pass without a milestone, do steps 1, 3, 4 and 6 anyway.

## Background reviewer (never block on it)

Run from a second clone (`/home/exedev/goose-w`, `git -C /home/exedev/goose-w pull` first) so it
doesn't fight over the build directory. It must not edit code. Output goes to `research/reviews/inbox/`.

    cd /home/exedev/goose-w && timeout 40m codex exec --sandbox read-only --model gpt-6-astra \
      -c model_provider=exe-llm -c 'model_providers.exe-llm.name="exe-llm"' \
      -c 'model_providers.exe-llm.base_url="https://llm.int.exe.xyz/v1"' \
      "$(cat research/prompts/skeptic.md)" </dev/null \
      > /home/exedev/goose/research/reviews/inbox/$(date +%Y%m%dT%H%M)-codex-skeptic.md 2>&1 &

A stalled or refused review gets one line in `REVIEWS.md` and is dropped. If a provider flags a
prompt, reword it around compile speed and correctness; don't retry it unchanged. A finding that work
is being avoided must be answered with a measurement or a commit, not "defer".

## Usage limits and models

Your 5-hour model limit is shared with Dan's other VMs. Codex runs on its own budget (`codex exec`,
configured as above, with `</dev/null`), so give it the work it does as well as you: fixture triage,
tests and adversarial Goose programs for a feature you've specified, running the suite and the
measurements, mechanical edits, re-reviews of a diff after a fix. Tell Codex the rules it needs
(commit style, no upstream pushes); it doesn't read these files.

- **The lead session**: direction, design, diagnosis that has stalled, the pictures' design.
- **Builders (`model: "opus"`, or the session's own model)**: a feature cluster in `selfhost/`, the
  demo, the viz pipeline, a memory-layout change. One per worktree.
- **Sonnet**: installs, reading (DynamoRIO and cachegrind docs, prior art on visualizing caches, Zig's
  data-oriented compiler design), and subagents that only search or summarize.

Within that, don't ration. If the model limit is reached the session goes idle; `overnight.sh`'s
watchdog types a "continue" a minute after the printed reset time. Commit often and nothing is lost.

## Fresh contexts

Most of a long session's usage is re-reading its own context. The repo is your memory, so a fresh
context loses nothing that matters. The Stop hook tells you when the context passes 250k tokens.
Then, at the next clean point:

1. Wait for your subagents to finish (a `/clear` kills them), or stop them and note in the Now line
   what each was doing and how to relaunch it.
2. Commit and push; make PLAN.md's Now line exact, the commands to run included.
3. `touch .claude/fresh` and end your turn.

The watchdog then types `/clear` and the start prompt, and you continue from the Now line. Also take
a fresh context after each milestone.

## VM safety

- Claude Code stops for a person on an `rm` it can't rule out as dangerous (a glob or a variable it
  can't trace, in a compound command), even in bypass mode, and nobody is watching. Delete with
  literal paths in a command of its own (`rm -rf -- out`, then `mkdir out`), or guard variables
  (`rm -rf -- "${D:?}/out"`).
- A runaway child can OOM-kill this whole session. Cap anything with data-dependent allocation:
  `systemd-run --user --scope -p MemoryMax=8G` (Goose reserves 2 GB of address space per data
  stack, so `prlimit --as` makes it fail at start), plus `timeout`.
- Big target projects: clone them under `/home/exedev/targets/`, not inside this repo.
- The pictures server: one process on port 8000, started in the background with `nohup` or a tmux
  window of its own, serving `research/viz/`. Restart it if it's gone; it's how Dan watches.

## Stopping

The Stop hook (`.claude/hooks/keep-going.sh`) lets a session end only when `STOP` exists. Then: bring
STATUS.md, the Now line and the pictures page up to date, commit, push.
