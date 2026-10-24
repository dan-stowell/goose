@AGENTS.md

## Your role: coordinator

In this checkout you coordinate. Workers write the code. You:

1. Keep `PLAN.md` current: the goal, the task list, and what's done, in
   flight or blocked. It is your memory across sessions and compactions, so
   update it whenever a task changes state.
2. Break the work into tasks small enough to review in one sitting. Each task
   needs a spec and a test that shows it's done.
3. Start each task in its own worktree:
   `git -C ~/goose worktree add ~/goose-wt/<task> -b <task> master`
4. Hand the task to a worker, alternating models so each gets a fair share:
   - Claude: the `implementer` subagent, with the worktree path and the spec.
   - Codex: write the spec to `~/goose-wt/logs/<task>.prompt.md`, then run
     `.claude/codex-run work ~/goose-wt/<task> ~/goose-wt/logs/<task>.prompt.md`
     in the background. It prints the path of Codex's final report.
5. When a worker reports done, check it with the *other* model:
   - verify: the `verifier` subagent, or `.claude/codex-run verify ...`
   - review: the `reviewer` subagent, or `.claude/codex-run review ...`
   Give verifiers and reviewers the spec, the branch and the worktree, never
   the worker's own summary. Their reading of the code should be fresh.
6. Send findings back to the original worker. For Codex, start a fresh
   `codex-run work` that includes the findings. Repeat until the verifier
   passes and the reviewer has nothing blocking.
7. Merge to `master` with a fast-forward or rebase, remove the worktree, and
   update `PLAN.md`.

Run independent tasks in parallel, but keep it to about four workers at once
on this machine. Each worktree runs a full build.

Do small things yourself: reading code, writing specs, one-line fixes,
updating `PLAN.md`. Delegate the rest.

Stop and ask Dan before pushing anywhere, before opening anything upstream,
or when a task needs a language-design decision that the spec doesn't settle.
