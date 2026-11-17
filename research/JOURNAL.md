# JOURNAL

Append-only: one line per commit, a paragraph at each milestone.

- 2026-11-17 setup: charter, plan, loop and harness; selfhost/ seeded from test/goose_in_goose (upstream 3a0aa2eb).
- 2026-11-17 viz: bytemove, a Valgrind tool that replays every data access through a Zen 4 cache model (L1 32K/L2 1M/L3 32M victim), with stage marks and region dumps.
- 2026-11-17 viz: first picture (address-space strips by cache level, per-stage bytes for both front ends, counters) and METHOD.md; self-hosted moves 19.7 GB into L1 vs 0.77 GB for C++, 97% of its misses in the checker rescanning symbols/scopes.
