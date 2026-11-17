# LADDER

Source to running program, per workload and rung (research/CHARTER.md). Written by `research/demo --ladder` from a real run; do not edit by hand.

- command: `research/demo --full --ladder`
- date: 2026-11-17 02:32 UTC, commit 8d3971d6
- uptime: `02:32:58 up  1:25,  0 user,  load average: 4.43, 5.75, 6.19`
- W2: 771 positive fixtures (all); the wall rows are the felt numbers, the (sum) rows add each process's wall time.
- W2/selfhost-pass: the 134 of them the self-hosted rung passes (and the JIT can run), through every rung: the like-for-like speed comparison while coverage grows.
- self-hosted rungs: sh2 (built by gcc -O2) writes the C; `self-hosted` compiles it with gcc -O2, `self-hosted gcc -O0` with gcc -O0, `self-hosted fast` with TinyCC (`tcc -c`, then a gcc link; research/notes/tcc-rung.md).

What does not run on the self-hosted rung today:

- 19_vm: stdlib/std.goose:1155:13: error: argument count mismatch
- 21_raytrace: stdlib/vec.goose:60:44: error: operator / cannot be applied to vec3<f32> and f32
- 31_mini_doom: samples/31_mini_doom.goose:1437:5: error: expected identifier


### W1

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | front end (C++) | 0.508 | 0.531 | 0.779 | 5 | 378.16 KB | 2.86 MB | 94.0 MB | ok: - |
| - | stock optimized | C compiler (gcc -O2) | 7.721 | 8.241 | 10.173 | 5 | 2.86 MB | 560.08 KB | 341.9 MB | ok: - |
| - | stock optimized | run (compile selfhost) | 0.218 | 0.246 | 0.293 | 5 | 378.16 KB | 1.73 MB | 63.8 MB | ok: - |
| - | stock optimized | check | 0.003 | 0.004 | 0.006 | 5 | 3.45 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | stock fast | front end+TinyCC+run | 1.523 | 1.615 | 1.665 | 5 | 378.16 KB | 1.73 MB | 161.1 MB | ok: - |
| - | stock fast | check | 0.002 | 0.004 | 0.005 | 5 | 3.45 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | self-hosted | front end (sh2) | 0.237 | 0.269 | 0.328 | 5 | 378.16 KB | 1.73 MB | 65.4 MB | ok: - |
| - | self-hosted | C compiler (gcc -O2) | 8.669 | 8.827 | 10.089 | 5 | 1.73 MB | 543.50 KB | 331.1 MB | ok: - |
| - | self-hosted | run (compile selfhost) | 0.251 | 0.270 | 0.298 | 5 | 378.16 KB | 1.73 MB | 65.3 MB | ok: - |
| - | self-hosted | check | 0.002 | 0.002 | 0.009 | 5 | 3.45 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
| - | self-hosted gcc -O0 | front end (sh2) | 0.257 | 0.279 | 0.290 | 5 | 378.16 KB | 1.73 MB | 65.4 MB | ok: - |
| - | self-hosted gcc -O0 | C compiler (gcc -O0) | 1.993 | 2.006 | 2.590 | 5 | 1.73 MB | 1.05 MB | 194.7 MB | ok: - |
| - | self-hosted gcc -O0 | run (compile selfhost) | 0.721 | 0.750 | 0.948 | 5 | 378.16 KB | 1.73 MB | 66.6 MB | ok: - |
| - | self-hosted gcc -O0 | check | 0.003 | 0.005 | 0.006 | 5 | 3.45 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
| - | self-hosted fast | front end (sh2) | 0.274 | 0.283 | 0.361 | 5 | 378.16 KB | 1.73 MB | 65.3 MB | ok: - |
| - | self-hosted fast | C compiler (tcc -c) | 0.039 | 0.052 | 0.056 | 5 | 1.73 MB | 1.80 MB | 26.7 MB | ok: - |
| - | self-hosted fast | link (gcc) | 0.035 | 0.042 | 0.057 | 5 | 1.80 MB | 1.27 MB | 26.7 MB | ok: - |
| - | self-hosted fast | run (compile selfhost) | 0.899 | 0.997 | 1.374 | 5 | 378.16 KB | 1.73 MB | 67.2 MB | ok: - |
| - | self-hosted fast | check | 0.002 | 0.003 | 0.005 | 5 | 3.45 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |

Source to running program (W1, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| - | stock optimized | 8.492 | 8.994 | 11.208 |
| - | stock fast | 1.523 | 1.615 | 1.665 |
| - | self-hosted | 9.199 | 9.347 | 10.600 |
| - | self-hosted gcc -O0 | 3.011 | 3.035 | 3.795 |
| - | self-hosted fast | 1.273 | 1.356 | 1.848 |

### W3

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| vm | stock optimized | front end (C++) | 0.024 | 0.025 | 0.039 | 5 | 5.03 KB | 141.58 KB | 26.7 MB | ok: - |
| vm | stock optimized | C compiler (gcc -O2) | 0.122 | 0.136 | 0.175 | 5 | 141.58 KB | 84.30 KB | 33.3 MB | ok: - |
| vm | stock optimized | run | 0.001 | 0.001 | 0.003 | 5 | 4.10 KB | 512 B | 26.7 MB | ok: - |
| vm | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | stock fast | front end+TinyCC+run | 0.022 | 0.030 | 0.041 | 5 | 5.03 KB | 512 B | 26.7 MB | ok: - |
| vm | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | self-hosted | front end (sh2) | 0.005 | 0.005 | 0.005 | 1 | 5.03 KB | 0 B | 24.0 MB | FAIL: unsupported: stdlib/std.goose:1155:13: error: argument count mismatch |
| raytrace | stock optimized | front end (C++) | 0.027 | 0.033 | 0.042 | 5 | 5.46 KB | 162.87 KB | 26.7 MB | ok: - |
| raytrace | stock optimized | C compiler (gcc -O2) | 0.216 | 0.248 | 0.333 | 5 | 162.87 KB | 88.30 KB | 41.6 MB | ok: - |
| raytrace | stock optimized | run | 0.006 | 0.014 | 0.014 | 5 | 4.10 KB | 2.06 KB | 26.7 MB | ok: - |
| raytrace | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | stock fast | front end+TinyCC+run | 0.070 | 0.091 | 0.106 | 5 | 5.46 KB | 2.06 KB | 26.7 MB | ok: - |
| raytrace | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | self-hosted | front end (sh2) | 0.006 | 0.006 | 0.006 | 1 | 5.46 KB | 0 B | 24.0 MB | FAIL: unsupported: stdlib/vec.goose:60:44: error: operator / cannot be applied to vec3<f32> and f32 |
| mini_doom | stock optimized | front end (C++) | 0.101 | 0.107 | 0.117 | 5 | 69.61 KB | 962.91 KB | 28.5 MB | ok: - |
| mini_doom | stock optimized | C compiler (gcc -O2) | 1.946 | 1.991 | 2.775 | 5 | 962.91 KB | 3.99 MB | 108.6 MB | ok: - |
| mini_doom | stock optimized | run | 0.458 | 0.542 | 0.563 | 5 | 4.10 KB | 42 B | 235.2 MB | ok: - |
| mini_doom | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | stock fast | front end+TinyCC+run | 0.605 | 0.682 | 0.776 | 5 | 69.61 KB | 42 B | 254.7 MB | ok: - |
| mini_doom | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | self-hosted | front end (sh2) | 0.006 | 0.006 | 0.006 | 1 | 69.61 KB | 0 B | 24.0 MB | FAIL: unsupported: samples/31_mini_doom.goose:1437:5: error: expected identifier |

Source to running program (W3, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| vm | stock optimized | 0.147 | 0.171 | 0.200 |
| vm | stock fast | 0.022 | 0.030 | 0.041 |
| vm | self-hosted | does not run | | |
| raytrace | stock optimized | 0.272 | 0.285 | 0.374 |
| raytrace | stock fast | 0.070 | 0.091 | 0.106 |
| raytrace | self-hosted | does not run | | |
| mini_doom | stock optimized | 2.600 | 2.617 | 3.424 |
| mini_doom | stock fast | 0.605 | 0.682 | 0.776 |
| mini_doom | self-hosted | does not run | | |

### W2

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | goose build (sum) | 126.555 | 139.925 | 207.554 | 5 | 1.95 MB | 0 B | 115.3 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | run (sum) | 3.335 | 3.678 | 6.963 | 5 | 1.95 MB | 0 B | 115.3 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | wall, 771 fixtures -j8 | 16.770 | 18.530 | 27.498 | 5 | 1.95 MB | 0 B | 115.3 MB | ok: blessed output match: 771/771 pass |
| - | stock fast | goose x.goose (fe+tcc+run) (sum) | 16.291 | 18.056 | 40.483 | 5 | 1.95 MB | 0 B | 134.2 MB | ok: blessed output match: 733/733 pass |
| - | stock fast | wall, 771 fixtures -j8 | 2.384 | 2.609 | 5.698 | 5 | 1.95 MB | 0 B | 134.2 MB | ok: blessed output match: 733/733 pass |
| - | self-hosted | front end (sh2) (sum) | 2.765 | 3.050 | 7.468 | 5 | 1.95 MB | 0 B | 66.9 MB | FAIL: blessed output match: 134/771 pass |
| - | self-hosted | C compiler (gcc -O2) (sum) | 26.429 | 27.754 | 59.538 | 5 | 1.95 MB | 0 B | 66.9 MB | FAIL: blessed output match: 134/771 pass |
| - | self-hosted | run (sum) | 0.596 | 0.732 | 2.109 | 5 | 1.95 MB | 0 B | 66.9 MB | FAIL: blessed output match: 134/771 pass |
| - | self-hosted | wall, 771 fixtures -j8 | 3.943 | 4.130 | 9.041 | 5 | 1.95 MB | 0 B | 66.9 MB | FAIL: blessed output match: 134/771 pass |
| selfhost-pass | stock optimized | goose build (sum) | 14.167 | 15.362 | 31.996 | 5 | 187.05 KB | 0 B | 59.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | stock optimized | run (sum) | 0.191 | 0.203 | 0.589 | 5 | 187.05 KB | 0 B | 59.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | stock optimized | wall, 134 fixtures -j8 | 1.928 | 2.100 | 4.181 | 5 | 187.05 KB | 0 B | 59.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | stock fast | goose x.goose (fe+tcc+run) (sum) | 1.699 | 1.909 | 3.632 | 5 | 187.05 KB | 0 B | 26.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | stock fast | wall, 134 fixtures -j8 | 0.496 | 0.577 | 0.868 | 5 | 187.05 KB | 0 B | 26.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted | front end (sh2) (sum) | 0.535 | 0.548 | 1.254 | 5 | 187.05 KB | 0 B | 66.5 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted | C compiler (gcc -O2) (sum) | 19.957 | 20.916 | 38.630 | 5 | 187.05 KB | 0 B | 66.5 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted | run (sum) | 0.615 | 0.772 | 1.333 | 5 | 187.05 KB | 0 B | 66.5 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted | wall, 134 fixtures -j8 | 2.840 | 3.095 | 5.349 | 5 | 187.05 KB | 0 B | 66.5 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted gcc -O0 | front end (sh2) (sum) | 0.465 | 0.504 | 1.012 | 5 | 187.05 KB | 0 B | 54.3 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted gcc -O0 | C compiler (gcc -O0) (sum) | 18.853 | 20.205 | 30.032 | 5 | 187.05 KB | 0 B | 54.3 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted gcc -O0 | run (sum) | 4.363 | 4.805 | 6.173 | 5 | 187.05 KB | 0 B | 54.3 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted gcc -O0 | wall, 134 fixtures -j8 | 4.443 | 4.877 | 6.184 | 5 | 187.05 KB | 0 B | 54.3 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted fast | front end (sh2) (sum) | 0.546 | 0.604 | 0.757 | 5 | 187.05 KB | 0 B | 26.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted fast | C compiler (tcc -c) (sum) | 1.220 | 1.226 | 1.439 | 5 | 187.05 KB | 0 B | 26.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted fast | link (gcc) (sum) | 3.760 | 3.852 | 4.193 | 5 | 187.05 KB | 0 B | 26.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted fast | run (sum) | 4.127 | 4.309 | 4.714 | 5 | 187.05 KB | 0 B | 26.7 MB | ok: blessed output match: 134/134 pass |
| selfhost-pass | self-hosted fast | wall, 134 fixtures -j8 | 3.920 | 4.120 | 4.394 | 5 | 187.05 KB | 0 B | 26.7 MB | ok: blessed output match: 134/134 pass |
