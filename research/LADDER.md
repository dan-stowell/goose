# LADDER

Source to running program, per workload and rung (research/CHARTER.md). Written by `research/demo --ladder` from a real run; do not edit by hand.

- command: `research/demo --full --ladder`
- date: 2026-11-17 01:27 UTC, commit 6d0b87a8
- uptime: `01:27:38 up 19 min,  0 user,  load average: 2.15, 1.67, 1.23`
- W2: 771 positive fixtures (all); the wall rows are the felt numbers, the (sum) rows add each process's wall time.

What does not run on the self-hosted rung today:

- 19_vm: stdlib/std.goose:1348:34: error: expected ')', got '='
- 21_raytrace: stdlib/std.goose:1348:34: error: expected ')', got '='
- 31_mini_doom: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer


### W1

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | front end (C++) | 0.172 | 0.193 | 0.204 | 5 | 183.68 KB | 1.33 MB | 48.4 MB | ok: - |
| - | stock optimized | C compiler (gcc -O2) | 3.450 | 3.495 | 3.585 | 5 | 1.33 MB | 311.61 KB | 182.9 MB | ok: - |
| - | stock optimized | run (compile selfhost) | 0.333 | 0.350 | 0.443 | 5 | 183.68 KB | 3.66 MB | 32.9 MB | ok: - |
| - | stock optimized | check | 0.008 | 0.009 | 0.012 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | stock fast | front end+TinyCC+run | 2.552 | 2.577 | 2.900 | 5 | 183.68 KB | 3.66 MB | 81.3 MB | ok: - |
| - | stock fast | check | 0.008 | 0.008 | 0.010 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | self-hosted | front end (sh2) | 0.301 | 0.319 | 0.370 | 5 | 183.68 KB | 3.66 MB | 34.4 MB | ok: - |
| - | self-hosted | C compiler (gcc -O2) | 9.634 | 9.763 | 10.054 | 5 | 3.66 MB | 571.72 KB | 344.5 MB | ok: - |
| - | self-hosted | run (compile selfhost) | 0.324 | 0.339 | 0.351 | 5 | 183.68 KB | 3.66 MB | 34.6 MB | ok: - |
| - | self-hosted | check | 0.005 | 0.008 | 0.009 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |

Source to running program (W1, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| - | stock optimized | 4.007 | 4.037 | 4.210 |
| - | stock fast | 2.552 | 2.577 | 2.900 |
| - | self-hosted | 10.278 | 10.415 | 10.720 |

### W3

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| vm | stock optimized | front end (C++) | 0.021 | 0.026 | 0.037 | 5 | 5.03 KB | 141.66 KB | 30.3 MB | ok: - |
| vm | stock optimized | C compiler (gcc -O2) | 0.113 | 0.137 | 0.153 | 5 | 141.66 KB | 84.30 KB | 33.3 MB | ok: - |
| vm | stock optimized | run | 0.001 | 0.002 | 0.002 | 5 | 4.10 KB | 512 B | 30.3 MB | ok: - |
| vm | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | stock fast | front end+TinyCC+run | 0.024 | 0.041 | 0.042 | 5 | 5.03 KB | 512 B | 30.3 MB | ok: - |
| vm | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | self-hosted | front end (sh2) | 0.008 | 0.008 | 0.008 | 1 | 5.03 KB | 0 B | 28.0 MB | FAIL: unsupported: stdlib/std.goose:1348:34: error: expected ')', got '=' |
| raytrace | stock optimized | front end (C++) | 0.020 | 0.031 | 0.042 | 5 | 5.46 KB | 162.95 KB | 30.3 MB | ok: - |
| raytrace | stock optimized | C compiler (gcc -O2) | 0.241 | 0.267 | 0.320 | 5 | 162.95 KB | 88.30 KB | 41.5 MB | ok: - |
| raytrace | stock optimized | run | 0.006 | 0.007 | 0.014 | 5 | 4.10 KB | 2.06 KB | 30.3 MB | ok: - |
| raytrace | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | stock fast | front end+TinyCC+run | 0.066 | 0.078 | 0.100 | 5 | 5.46 KB | 2.06 KB | 30.3 MB | ok: - |
| raytrace | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | self-hosted | front end (sh2) | 0.004 | 0.004 | 0.004 | 1 | 5.46 KB | 0 B | 28.0 MB | FAIL: unsupported: stdlib/std.goose:1348:34: error: expected ')', got '=' |
| mini_doom | stock optimized | front end (C++) | 0.094 | 0.099 | 0.122 | 5 | 69.61 KB | 962.99 KB | 30.3 MB | ok: - |
| mini_doom | stock optimized | C compiler (gcc -O2) | 1.928 | 2.074 | 2.170 | 5 | 962.99 KB | 3.99 MB | 108.6 MB | ok: - |
| mini_doom | stock optimized | run | 0.451 | 0.475 | 0.634 | 5 | 4.10 KB | 42 B | 238.7 MB | ok: - |
| mini_doom | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | stock fast | front end+TinyCC+run | 0.622 | 0.656 | 0.684 | 5 | 69.61 KB | 42 B | 252.1 MB | ok: - |
| mini_doom | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | self-hosted | front end (sh2) | 0.006 | 0.006 | 0.006 | 1 | 69.61 KB | 0 B | 28.0 MB | FAIL: unsupported: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer |

Source to running program (W3, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| vm | stock optimized | 0.152 | 0.160 | 0.187 |
| vm | stock fast | 0.024 | 0.041 | 0.042 |
| vm | self-hosted | does not run | | |
| raytrace | stock optimized | 0.294 | 0.304 | 0.357 |
| raytrace | stock fast | 0.066 | 0.078 | 0.100 |
| raytrace | self-hosted | does not run | | |
| mini_doom | stock optimized | 2.514 | 2.663 | 2.823 |
| mini_doom | stock fast | 0.622 | 0.656 | 0.684 |
| mini_doom | self-hosted | does not run | | |

### W2

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | goose build (sum) | 134.945 | 142.768 | 170.940 | 5 | 1.95 MB | 0 B | 121.8 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | run (sum) | 3.775 | 4.497 | 5.635 | 5 | 1.95 MB | 0 B | 121.8 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | wall, 771 fixtures -j8 | 17.885 | 18.851 | 22.516 | 5 | 1.95 MB | 0 B | 121.8 MB | ok: blessed output match: 771/771 pass |
| - | stock fast | goose x.goose (fe+tcc+run) (sum) | 15.972 | 17.499 | 19.252 | 5 | 1.95 MB | 0 B | 133.5 MB | ok: blessed output match: 733/733 pass |
| - | stock fast | wall, 771 fixtures -j8 | 2.292 | 2.558 | 2.826 | 5 | 1.95 MB | 0 B | 133.5 MB | ok: blessed output match: 733/733 pass |
| - | self-hosted | front end (sh2) (sum) | 2.001 | 2.542 | 3.024 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted | C compiler (gcc -O2) (sum) | 4.258 | 4.942 | 5.339 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted | run (sum) | 0.061 | 0.091 | 0.103 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted | wall, 771 fixtures -j8 | 1.042 | 1.238 | 1.377 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
