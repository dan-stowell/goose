# LADDER

Source to running program, per workload and rung (research/CHARTER.md). Written by `research/demo --ladder` from a real run; do not edit by hand.

- command: `research/demo --full --ladder`
- date: 2026-11-17 01:50 UTC, commit 98bae32d
- uptime: `01:50:13 up 42 min,  0 user,  load average: 3.46, 3.73, 3.78`
- W2: 771 positive fixtures (all); the wall rows are the felt numbers, the (sum) rows add each process's wall time.

What does not run on the self-hosted rung today:

- 19_vm: stdlib/std.goose:1155:13: error: argument count mismatch
- 21_raytrace: stdlib/vec.goose:60:44: error: numeric operands required
- 31_mini_doom: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer

W2 on self-hosted: 73/771 pass (0 skipped); the largest failure clusters (first error):

- 97: front end: error: argument count mismatch (e.g. `cycle_scratch_locals`)
- 84: front end: error: not implemented yet: relative and optional references (e.g. `decayed_references`)
- 71: front end: error: expected top-level declaration (e.g. `bulk_default_loops`)
- 39: front end: error: not implemented yet: custom formatting dispatch (e.g. `codegen_exec`)
- 24: front end: error: not implemented yet: variable-mode enums (e.g. `adt_adaptation`)
- 23: front end: error: expected identifier (e.g. `defer_exits`)
- 16: front end: error: not implemented yet: whole resizable assignment analysis (e.g. `assign_path_after`)
- 14: front end: error: not implemented yet: reference rebinding analysis (e.g. `compare_order`)
- 14: front end: error: global declarations require an initializer (e.g. `relative_declarations`)
- 11: run: stdout (e.g. `const_global_folding`)
- 11: front end: error: cannot find import gfx.goose (e.g. `gfx_compute`)
- 10: front end: error: expected ';', got 'in' (e.g. `index_call_cached_counts`)


### W1

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | front end (C++) | 0.320 | 0.363 | 0.416 | 5 | 287.61 KB | 2.19 MB | 72.9 MB | ok: - |
| - | stock optimized | C compiler (gcc -O2) | 5.822 | 6.096 | 6.611 | 5 | 2.19 MB | 451.99 KB | 292.8 MB | ok: - |
| - | stock optimized | run (compile selfhost) | 0.138 | 0.141 | 0.161 | 5 | 287.61 KB | 2.10 MB | 53.7 MB | ok: - |
| - | stock optimized | check | 0.002 | 0.003 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | stock fast | front end+TinyCC+run | 0.883 | 0.966 | 1.065 | 5 | 287.61 KB | 2.10 MB | 123.4 MB | ok: - |
| - | stock fast | check | 0.002 | 0.003 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | self-hosted | front end (sh2) | 0.177 | 0.201 | 0.230 | 5 | 287.61 KB | 2.10 MB | 55.4 MB | ok: - |
| - | self-hosted | C compiler (gcc -O2) | 6.818 | 7.283 | 7.603 | 5 | 2.10 MB | 446.22 KB | 309.7 MB | ok: - |
| - | self-hosted | run (compile selfhost) | 0.186 | 0.197 | 0.231 | 5 | 287.61 KB | 2.10 MB | 55.3 MB | ok: - |
| - | self-hosted | check | 0.003 | 0.005 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |

Source to running program (W1, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| - | stock optimized | 6.282 | 6.667 | 7.089 |
| - | stock fast | 0.883 | 0.966 | 1.065 |
| - | self-hosted | 7.181 | 7.726 | 8.004 |

### W3

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| vm | stock optimized | front end (C++) | 0.021 | 0.032 | 0.036 | 5 | 5.03 KB | 141.58 KB | 26.6 MB | ok: - |
| vm | stock optimized | C compiler (gcc -O2) | 0.118 | 0.139 | 0.152 | 5 | 141.58 KB | 84.30 KB | 33.4 MB | ok: - |
| vm | stock optimized | run | 0.001 | 0.002 | 0.002 | 5 | 4.10 KB | 512 B | 26.6 MB | ok: - |
| vm | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | stock fast | front end+TinyCC+run | 0.021 | 0.035 | 0.042 | 5 | 5.03 KB | 512 B | 26.6 MB | ok: - |
| vm | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | self-hosted | front end (sh2) | 0.008 | 0.008 | 0.008 | 1 | 5.03 KB | 0 B | 24.4 MB | FAIL: unsupported: stdlib/std.goose:1155:13: error: argument count mismatch |
| raytrace | stock optimized | front end (C++) | 0.032 | 0.040 | 0.047 | 5 | 5.46 KB | 162.87 KB | 26.6 MB | ok: - |
| raytrace | stock optimized | C compiler (gcc -O2) | 0.225 | 0.240 | 0.251 | 5 | 162.87 KB | 88.30 KB | 41.5 MB | ok: - |
| raytrace | stock optimized | run | 0.005 | 0.007 | 0.010 | 5 | 4.10 KB | 2.06 KB | 26.6 MB | ok: - |
| raytrace | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | stock fast | front end+TinyCC+run | 0.069 | 0.092 | 0.106 | 5 | 5.46 KB | 2.06 KB | 26.6 MB | ok: - |
| raytrace | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | self-hosted | front end (sh2) | 0.009 | 0.009 | 0.009 | 1 | 5.46 KB | 0 B | 24.4 MB | FAIL: unsupported: stdlib/vec.goose:60:44: error: numeric operands required |
| mini_doom | stock optimized | front end (C++) | 0.097 | 0.103 | 0.123 | 5 | 69.61 KB | 962.91 KB | 28.6 MB | ok: - |
| mini_doom | stock optimized | C compiler (gcc -O2) | 1.910 | 1.981 | 2.021 | 5 | 962.91 KB | 3.99 MB | 108.6 MB | ok: - |
| mini_doom | stock optimized | run | 0.475 | 0.517 | 0.603 | 5 | 4.10 KB | 42 B | 237.0 MB | ok: - |
| mini_doom | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | stock fast | front end+TinyCC+run | 0.590 | 0.673 | 0.787 | 5 | 69.61 KB | 42 B | 252.9 MB | ok: - |
| mini_doom | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | self-hosted | front end (sh2) | 0.002 | 0.002 | 0.002 | 1 | 69.61 KB | 0 B | 24.4 MB | FAIL: unsupported: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer |

Source to running program (W3, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| vm | stock optimized | 0.153 | 0.173 | 0.173 |
| vm | stock fast | 0.021 | 0.035 | 0.042 |
| vm | self-hosted | does not run | | |
| raytrace | stock optimized | 0.266 | 0.282 | 0.308 |
| raytrace | stock fast | 0.069 | 0.092 | 0.106 |
| raytrace | self-hosted | does not run | | |
| mini_doom | stock optimized | 2.558 | 2.600 | 2.729 |
| mini_doom | stock fast | 0.590 | 0.673 | 0.787 |
| mini_doom | self-hosted | does not run | | |

### W2

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | goose build (sum) | 150.044 | 204.378 | 309.226 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | run (sum) | 4.475 | 6.027 | 9.797 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | wall, 771 fixtures -j8 | 19.738 | 27.021 | 40.607 | 5 | 1.95 MB | 0 B | 116.1 MB | ok: blessed output match: 771/771 pass |
| - | stock fast | goose x.goose (fe+tcc+run) (sum) | 18.818 | 26.847 | 32.062 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
| - | stock fast | wall, 771 fixtures -j8 | 2.679 | 3.753 | 4.545 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
| - | self-hosted | front end (sh2) (sum) | 3.535 | 4.913 | 5.752 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | C compiler (gcc -O2) (sum) | 14.039 | 19.923 | 25.450 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | run (sum) | 0.941 | 1.386 | 1.586 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | wall, 771 fixtures -j8 | 2.541 | 3.519 | 4.376 | 5 | 1.95 MB | 0 B | 52.8 MB | FAIL: blessed output match: 73/771 pass |
