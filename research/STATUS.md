# STATUS (at most ten lines; updated at every milestone and whenever Dan is needed)

2026-11-17 02:45 UTC, stopped (STOP). M0 done; M1 in progress. Boards: run 134/776, reject 228/2036, stdlib 8/17,
340 error fixtures wrongly accepted (ratcheted); W1 fixed point yes.
Moved (same-input re-checks): front end 0.30 -> 0.10 s (symbol index); C 5.24 -> 1.91 MB, gcc -O2 14.5 -> 6.3 s
(emit-dedup); C 2.67 -> 1.71 MB, gcc -O0 3.05 -> 2.08 s, tcc-built W1 1.9 -> 1.1 s (emit-lean). Ladder: research/LADDER.md.
Unmerged: feat-stdlib (~198/776 but 46 newly accepted errors), feat-builtins (codex, unverified). viz regen.sh broken.

## Decisions for Dan
- Restart the builders? (All stopped by you 02:40; briefs in research/notes/briefs.md.) Codex may still be running (`pkill -f "codex exec --sandbox workspace-write"`).
