# REVIEWS

One line of triage per inbox item: accept / reject (why) / defer.
- 20261117T0201-codex-skeptic (M0): (1) ladder/pictures/tcc rung missing: accept, fixed by viz2 + demo2 (merged ec1088e5). (2a) stdlib board was check-only: accept, it now also emits C for a program importing the module and gcc-compiles it (still 6/17). (2b) marker locations unchecked: reject, run_tests.py matches message substrings only, same as here. (2c) demo W2 ignored expected stderr: accept, fixed. (3) unlike W2 comparisons: accept, demo2 adds the same-fixture-set rows. (4) ms vs s: accept, front-end work stopped after the two scans; seconds work is emit-dedup/emit-lean. (5) stale picture: accept, viz2 regenerated with before/after. (6) none.
