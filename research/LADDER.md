# LADDER

Source to running program, per workload and rung (research/CHARTER.md). Written by `research/demo --ladder` from a real run; do not edit by hand.

- command: `research/demo --full --ladder`
- date: 2026-11-17 01:32 UTC, commit de28e5b6
- uptime: `01:32:06 up 24 min,  0 user,  load average: 5.06, 4.19, 2.43`
- W2: 771 positive fixtures (all); the wall rows are the felt numbers, the (sum) rows add each process's wall time.

What does not run on the self-hosted rung today:

- 19_vm: stdlib/std.goose:1348:34: error: expected ')', got '='
- 21_raytrace: stdlib/std.goose:1348:34: error: expected ')', got '='
- 31_mini_doom: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer

W2 on self-hosted: 30/771 pass (0 skipped); the largest failure clusters (first error):

- 169: front end: error: expected ')', got '=' (e.g. `call_location`)
- 84: front end: error: expected top-level declaration (e.g. `bulk_default_loops`)
- 62: front end: error: not implemented yet: variable and limited array storage (e.g. `append_constructed_results`)
- 56: front end: error: not implemented yet: relative and optional references (e.g. `fat_optional`)
- 31: front end: error: not implemented yet: custom formatting dispatch (e.g. `codegen_exec`)
- 30: front end: error: not implemented yet: enum type checking (e.g. `argument_captures`)
- 18: front end: error: not implemented yet: nonfixed struct fields (e.g. `discarded_resizable_bounds`)
- 16: front end: error: expected identifier (e.g. `match_constants`)
- 14: front end: error: global declarations require an initializer (e.g. `relative_declarations`)
- 13: front end: error: argument count mismatch (e.g. `funval_array_adaptation`)
- 11: front end: error: cannot find import gfx.goose (e.g. `gfx_compute`)
- 10: front end: error: expected ';', got 'in' (e.g. `index_call_cached_counts`)


### W1

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | front end (C++) | 0.173 | 0.198 | 0.225 | 5 | 183.68 KB | 1.33 MB | 48.2 MB | ok: - |
| - | stock optimized | C compiler (gcc -O2) | 3.451 | 3.576 | 4.204 | 5 | 1.33 MB | 311.61 KB | 182.9 MB | ok: - |
| - | stock optimized | run (compile selfhost) | 0.319 | 0.337 | 0.456 | 5 | 183.68 KB | 3.66 MB | 32.9 MB | ok: - |
| - | stock optimized | check | 0.005 | 0.008 | 0.009 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | stock fast | front end+TinyCC+run | 2.516 | 2.600 | 3.397 | 5 | 183.68 KB | 3.66 MB | 81.4 MB | ok: - |
| - | stock fast | check | 0.004 | 0.006 | 0.009 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | self-hosted | front end (sh2) | 0.300 | 0.319 | 0.382 | 5 | 183.68 KB | 3.66 MB | 34.5 MB | ok: - |
| - | self-hosted | C compiler (gcc -O2) | 9.504 | 9.984 | 10.913 | 5 | 3.66 MB | 571.72 KB | 344.8 MB | ok: - |
| - | self-hosted | run (compile selfhost) | 0.294 | 0.333 | 0.364 | 5 | 183.68 KB | 3.66 MB | 34.4 MB | ok: - |
| - | self-hosted | check | 0.004 | 0.008 | 0.009 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |

Source to running program (W1, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| - | stock optimized | 4.011 | 4.111 | 4.833 |
| - | stock fast | 2.516 | 2.600 | 3.397 |
| - | self-hosted | 10.150 | 10.625 | 11.571 |

### W3

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| vm | stock optimized | front end (C++) | 0.028 | 0.033 | 0.038 | 5 | 5.03 KB | 141.66 KB | 30.2 MB | ok: - |
| vm | stock optimized | C compiler (gcc -O2) | 0.127 | 0.135 | 0.140 | 5 | 141.66 KB | 84.30 KB | 33.3 MB | ok: - |
| vm | stock optimized | run | 0.001 | 0.001 | 0.002 | 5 | 4.10 KB | 512 B | 30.2 MB | ok: - |
| vm | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | stock fast | front end+TinyCC+run | 0.021 | 0.025 | 0.043 | 5 | 5.03 KB | 512 B | 30.2 MB | ok: - |
| vm | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | self-hosted | front end (sh2) | 0.008 | 0.008 | 0.008 | 1 | 5.03 KB | 0 B | 28.1 MB | FAIL: unsupported: stdlib/std.goose:1348:34: error: expected ')', got '=' |
| raytrace | stock optimized | front end (C++) | 0.032 | 0.041 | 0.050 | 5 | 5.46 KB | 162.95 KB | 30.2 MB | ok: - |
| raytrace | stock optimized | C compiler (gcc -O2) | 0.208 | 0.270 | 0.306 | 5 | 162.95 KB | 88.30 KB | 41.5 MB | ok: - |
| raytrace | stock optimized | run | 0.005 | 0.008 | 0.015 | 5 | 4.10 KB | 2.06 KB | 30.2 MB | ok: - |
| raytrace | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | stock fast | front end+TinyCC+run | 0.079 | 0.087 | 0.104 | 5 | 5.46 KB | 2.06 KB | 30.2 MB | ok: - |
| raytrace | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | self-hosted | front end (sh2) | 0.005 | 0.005 | 0.005 | 1 | 5.46 KB | 0 B | 28.1 MB | FAIL: unsupported: stdlib/std.goose:1348:34: error: expected ')', got '=' |
| mini_doom | stock optimized | front end (C++) | 0.096 | 0.109 | 0.150 | 5 | 69.61 KB | 962.99 KB | 30.2 MB | ok: - |
| mini_doom | stock optimized | C compiler (gcc -O2) | 1.981 | 2.092 | 2.736 | 5 | 962.99 KB | 3.99 MB | 108.7 MB | ok: - |
| mini_doom | stock optimized | run | 0.456 | 0.501 | 0.618 | 5 | 4.10 KB | 42 B | 235.1 MB | ok: - |
| mini_doom | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | stock fast | front end+TinyCC+run | 0.596 | 0.680 | 0.738 | 5 | 69.61 KB | 42 B | 252.5 MB | ok: - |
| mini_doom | stock fast | check | 0.000 | 0.000 | 0.002 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | self-hosted | front end (sh2) | 0.004 | 0.004 | 0.004 | 1 | 69.61 KB | 0 B | 28.1 MB | FAIL: unsupported: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer |

Source to running program (W3, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| vm | stock optimized | 0.160 | 0.169 | 0.174 |
| vm | stock fast | 0.021 | 0.025 | 0.043 |
| vm | self-hosted | does not run | | |
| raytrace | stock optimized | 0.256 | 0.328 | 0.356 |
| raytrace | stock fast | 0.079 | 0.087 | 0.104 |
| raytrace | self-hosted | does not run | | |
| mini_doom | stock optimized | 2.584 | 2.681 | 3.504 |
| mini_doom | stock fast | 0.596 | 0.680 | 0.738 |
| mini_doom | self-hosted | does not run | | |

### W2

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | goose build (sum) | 146.297 | 170.537 | 230.624 | 5 | 1.95 MB | 0 B | 115.6 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | run (sum) | 4.467 | 5.243 | 7.192 | 5 | 1.95 MB | 0 B | 115.6 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | wall, 771 fixtures -j8 | 19.345 | 22.465 | 30.328 | 5 | 1.95 MB | 0 B | 115.6 MB | ok: blessed output match: 771/771 pass |
| - | stock fast | goose x.goose (fe+tcc+run) (sum) | 15.584 | 18.484 | 25.901 | 5 | 1.95 MB | 0 B | 136.0 MB | ok: blessed output match: 733/733 pass |
| - | stock fast | wall, 771 fixtures -j8 | 2.250 | 2.681 | 3.675 | 5 | 1.95 MB | 0 B | 136.0 MB | ok: blessed output match: 733/733 pass |
| - | self-hosted | front end (sh2) (sum) | 2.127 | 2.460 | 3.569 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted | C compiler (gcc -O2) (sum) | 4.136 | 4.517 | 5.213 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted | run (sum) | 0.059 | 0.077 | 0.128 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted | wall, 771 fixtures -j8 | 1.040 | 1.159 | 1.506 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
