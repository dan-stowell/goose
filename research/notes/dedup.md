# Duplicate specializations in the selfhost's C (2026-11-17, lead)

Observation: sh2.c for W1 is 3,661,811 bytes / 918 functions. With temporaries, labels, params,
locals (t/p/v/l + digits, labelN) and gg_frame_N alpha-renamed, and callees partitioned to a fixed
point (research/tools/c_dedup.py), only 152 distinct function bodies remain: 1,889,352 bytes
(52%) are copies. Cause: checker.goose (~line 750) keys a Specialization on each view/reference
argument's root, readonly and growshrink (and `held`), so `run_compilation(COMMAND_CHECK, x, "")`
vs `run_compilation(COMMAND_EMIT, x, arguments[2])` (literal root vs args root) instantiates the
whole compiler twice; small helpers get 178-198 copies. Provenance matters to the checker, not
to the C.

Experiment: `python3 research/tools/c_dedup.py sh2.c sh2d.c` keeps one representative per class:
1,588,497 bytes; gcc -O2 9.90/9.87/10.06 s -> 4.76/4.64/4.65 s; peak 353 MB -> 215 MB; the deduped
compiler emits byte-identical C for selfhost (cmp).
