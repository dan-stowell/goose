Feature-builder rules (selfhost/, M1 of research/PLAN.md):
- selfhost/ is the Goose-written Goose compiler (~3.3k lines: lexer, parser, checker, generics,
  emitter, runtime). src/ (C++) is the reference implementation: read it freely to learn semantics
  and how the C++ compiler lowers each feature; docs/reference.md and docs/goose_spec.md are the
  rules. The C++ compiler's emitted C (`/home/exedev/goose/build/goose build x.goose` keeps C? see
  docs/command_line.md for writing the C: e.g. `goose build --emit-c` / `-o x.c`) shows a target lowering.
- The scoreboard: `python3 selfhost/scoreboard.py --goose /home/exedev/goose/build/goose` (16 s;
  bootstraps selfhost/, checks W1's fixed point, scores boards run/reject/stdlib, prints the largest
  failure clusters, writes build/scoreboard/*.tsv with each fixture's first failure reason).
  Every commit touching selfhost/ must keep the fixed point and never lose a pass:
  run with `--enforce` before each commit, and `--update` to record gains in selfhost/scoreboard/*.txt.
- Write the feature for real (semantics as src/ does them, including the checks), not a
  fixture-specific hack. Keep code in the compiler's existing style. Note anything Goose made easy,
  forced, or could not express while writing the compiler in research/notes/<your-branch>.md
  (it feeds FINDINGS.md).
- Commit small and often on your branch. Every ~hour and at the end: `git fetch origin &&
  git rebase origin/master` (resolve conflicts in selfhost/scoreboard/*.txt by rerunning
  --update), rerun --enforce, then `git push -f origin <branch>` (your own branch only). The lead
  merges into master. Don't edit research/ files other than your notes file and JOURNAL.md lines.
- Keep going through your cluster list until it is done or you are blocked by another cluster;
  then take the next biggest cluster that is in your area. Report in five lines: board numbers
  before/after, branch, what is blocked.
