# LADDER

Source to running program, per workload and rung (research/CHARTER.md). Written by `research/demo --ladder` from a real run; do not edit by hand.

- command: `research/demo --full --ladder --before 0aa09be4`
- date: 2026-11-17 01:55 UTC, commit 92b547b4
- uptime: `01:55:25 up 47 min,  0 user,  load average: 15.27, 9.33, 5.97`
- W2: 771 positive fixtures (all); the wall rows are the felt numbers, the (sum) rows add each process's wall time.
- W2/selfhost-pass: the 73 of them the self-hosted rung passes (and the JIT can run), through every rung: the like-for-like speed comparison while coverage grows.
- self-hosted rungs: sh2 (built by gcc -O2) writes the C; `self-hosted` compiles it with gcc -O2, `self-hosted gcc -O0` with gcc -O0, `self-hosted fast` with TinyCC (`tcc -c`, then a gcc link; research/notes/tcc-rung.md).

What does not run on the self-hosted rung today:

- 19_vm: stdlib/std.goose:1155:13: error: argument count mismatch
- 19_vm (@0aa09be4): stdlib/std.goose:1348:34: error: expected ')', got '='
- 21_raytrace: stdlib/vec.goose:60:44: error: numeric operands required
- 21_raytrace (@0aa09be4): stdlib/std.goose:1348:34: error: expected ')', got '='
- 31_mini_doom: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer
- 31_mini_doom (@0aa09be4): samples/31_mini_doom.goose:134:1: error: global declarations require an initializer

W2 on self-hosted@0aa09be4: 30/73 pass (0 skipped); the largest failure clusters (first error):

- 20: front end: error: not implemented yet: variable and limited array storage (e.g. `append_destination_storage`)
- 8: front end: error: not implemented yet: enum type checking (e.g. `cnames`)
- 3: front end: error: unknown function 'bytes_of' (e.g. `byteview_provenance`)
- 2: front end: error: expected ')', got '=' (e.g. `call_location`)
- 2: front end: error: not implemented yet: expression tag 29 (e.g. `integer_match_extremes`)
- 2: front end: error: incompatible types (type 3 kind 6 width 16 -> 2 kind 6 width 16 (e.g. `short_circuit_temporaries`)
- 1: front end: error: not implemented yet: nonfixed struct fields (e.g. `print_variable_size_elements`)
- 1: front end: error: not implemented yet: multiple bindings (e.g. `return_root_merge`)
- 1: front end: goose runtime error: array index out of bounds (e.g. `bce_function_state`)
- 1: front end: error: not implemented yet: multiple return values (e.g. `inline_nested_calls`)
- 1: front end: error: unknown function 'pop_n' (e.g. `pop_n_past_end`)
- 1: front end: error: expected identifier (e.g. `match_overlaps`)

W2 on self-hosted gcc -O0@0aa09be4: 30/73 pass (0 skipped); the largest failure clusters (first error):

- 20: front end: error: not implemented yet: variable and limited array storage (e.g. `append_destination_storage`)
- 8: front end: error: not implemented yet: enum type checking (e.g. `cnames`)
- 3: front end: error: unknown function 'bytes_of' (e.g. `byteview_provenance`)
- 2: front end: error: expected ')', got '=' (e.g. `call_location`)
- 2: front end: error: not implemented yet: expression tag 29 (e.g. `integer_match_extremes`)
- 2: front end: error: incompatible types (type 3 kind 6 width 16 -> 2 kind 6 width 16 (e.g. `short_circuit_temporaries`)
- 1: front end: error: not implemented yet: nonfixed struct fields (e.g. `print_variable_size_elements`)
- 1: front end: error: not implemented yet: multiple bindings (e.g. `return_root_merge`)
- 1: front end: goose runtime error: array index out of bounds (e.g. `bce_function_state`)
- 1: front end: error: not implemented yet: multiple return values (e.g. `inline_nested_calls`)
- 1: front end: error: unknown function 'pop_n' (e.g. `pop_n_past_end`)
- 1: front end: error: expected identifier (e.g. `match_overlaps`)

W2 on self-hosted fast@0aa09be4: 30/73 pass (0 skipped); the largest failure clusters (first error):

- 20: front end: error: not implemented yet: variable and limited array storage (e.g. `append_destination_storage`)
- 8: front end: error: not implemented yet: enum type checking (e.g. `cnames`)
- 3: front end: error: unknown function 'bytes_of' (e.g. `byteview_provenance`)
- 2: front end: error: expected ')', got '=' (e.g. `call_location`)
- 2: front end: error: not implemented yet: expression tag 29 (e.g. `integer_match_extremes`)
- 2: front end: error: incompatible types (type 3 kind 6 width 16 -> 2 kind 6 width 16 (e.g. `short_circuit_temporaries`)
- 1: front end: error: not implemented yet: nonfixed struct fields (e.g. `print_variable_size_elements`)
- 1: front end: error: not implemented yet: multiple bindings (e.g. `return_root_merge`)
- 1: front end: goose runtime error: array index out of bounds (e.g. `bce_function_state`)
- 1: front end: error: not implemented yet: multiple return values (e.g. `inline_nested_calls`)
- 1: front end: error: unknown function 'pop_n' (e.g. `pop_n_past_end`)
- 1: front end: error: expected identifier (e.g. `match_overlaps`)


### W1

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | front end (C++) | 0.328 | 0.365 | 0.511 | 5 | 287.61 KB | 2.19 MB | 73.0 MB | ok: - |
| - | stock optimized | C compiler (gcc -O2) | 5.772 | 6.101 | 6.556 | 5 | 2.19 MB | 451.99 KB | 292.7 MB | ok: - |
| - | stock optimized | run (compile selfhost) | 0.140 | 0.150 | 0.159 | 5 | 287.61 KB | 2.10 MB | 53.7 MB | ok: - |
| - | stock optimized | check | 0.002 | 0.003 | 0.005 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | stock fast | front end+TinyCC+run | 0.926 | 0.962 | 1.108 | 5 | 287.61 KB | 2.10 MB | 123.6 MB | ok: - |
| - | stock fast | check | 0.001 | 0.001 | 0.003 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | self-hosted | front end (sh2) | 0.189 | 0.207 | 0.217 | 5 | 287.61 KB | 2.10 MB | 55.3 MB | ok: - |
| - | self-hosted | C compiler (gcc -O2) | 6.861 | 7.548 | 8.684 | 5 | 2.10 MB | 446.22 KB | 309.8 MB | ok: - |
| - | self-hosted | run (compile selfhost) | 0.182 | 0.203 | 0.215 | 5 | 287.61 KB | 2.10 MB | 55.4 MB | ok: - |
| - | self-hosted | check | 0.001 | 0.001 | 0.002 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
| - | self-hosted gcc -O0 | front end (sh2) | 0.177 | 0.206 | 0.241 | 5 | 287.61 KB | 2.10 MB | 55.3 MB | ok: - |
| - | self-hosted gcc -O0 | C compiler (gcc -O0) | 1.949 | 2.064 | 2.397 | 5 | 2.10 MB | 1.17 MB | 196.3 MB | ok: - |
| - | self-hosted gcc -O0 | run (compile selfhost) | 1.011 | 1.086 | 1.341 | 5 | 287.61 KB | 2.10 MB | 57.8 MB | ok: - |
| - | self-hosted gcc -O0 | check | 0.001 | 0.001 | 0.002 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
| - | self-hosted fast | front end (sh2) | 0.202 | 0.209 | 0.253 | 5 | 287.61 KB | 2.10 MB | 55.3 MB | ok: - |
| - | self-hosted fast | C compiler (tcc -c) | 0.043 | 0.052 | 0.060 | 5 | 2.10 MB | 1.83 MB | 31.0 MB | ok: - |
| - | self-hosted fast | link (gcc) | 0.031 | 0.036 | 0.043 | 5 | 1.83 MB | 1.36 MB | 31.0 MB | ok: - |
| - | self-hosted fast | run (compile selfhost) | 1.067 | 1.156 | 1.391 | 5 | 287.61 KB | 2.10 MB | 58.5 MB | ok: - |
| - | self-hosted fast | check | 0.001 | 0.001 | 0.001 | 5 | 4.20 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
| - | stock optimized@0aa09be4 | front end (C++) | 0.189 | 0.192 | 0.206 | 5 | 183.68 KB | 1.33 MB | 48.3 MB | ok: - |
| - | stock optimized@0aa09be4 | C compiler (gcc -O2) | 3.534 | 3.612 | 5.184 | 5 | 1.33 MB | 311.61 KB | 182.9 MB | ok: - |
| - | stock optimized@0aa09be4 | run (compile selfhost) | 0.318 | 0.345 | 0.411 | 5 | 183.68 KB | 3.66 MB | 33.0 MB | ok: - |
| - | stock optimized@0aa09be4 | check | 0.003 | 0.004 | 0.006 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | stock fast@0aa09be4 | front end+TinyCC+run | 2.553 | 2.654 | 2.918 | 5 | 183.68 KB | 3.66 MB | 81.2 MB | ok: - |
| - | stock fast@0aa09be4 | check | 0.004 | 0.004 | 0.008 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: its C == sh3.c |
| - | self-hosted@0aa09be4 | front end (sh2) | 0.303 | 0.325 | 0.472 | 5 | 183.68 KB | 3.66 MB | 34.5 MB | ok: - |
| - | self-hosted@0aa09be4 | C compiler (gcc -O2) | 9.639 | 10.762 | 12.029 | 5 | 3.66 MB | 571.73 KB | 344.5 MB | ok: - |
| - | self-hosted@0aa09be4 | run (compile selfhost) | 0.303 | 0.321 | 0.506 | 5 | 183.68 KB | 3.66 MB | 34.5 MB | ok: - |
| - | self-hosted@0aa09be4 | check | 0.005 | 0.006 | 0.008 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
| - | self-hosted gcc -O0@0aa09be4 | front end (sh2) | 0.301 | 0.390 | 0.472 | 5 | 183.68 KB | 3.66 MB | 34.5 MB | ok: - |
| - | self-hosted gcc -O0@0aa09be4 | C compiler (gcc -O0) | 3.156 | 3.431 | 3.793 | 5 | 3.66 MB | 1.80 MB | 313.4 MB | ok: - |
| - | self-hosted gcc -O0@0aa09be4 | run (compile selfhost) | 4.920 | 5.178 | 5.861 | 5 | 183.68 KB | 3.66 MB | 36.1 MB | ok: - |
| - | self-hosted gcc -O0@0aa09be4 | check | 0.004 | 0.008 | 0.009 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |
| - | self-hosted fast@0aa09be4 | front end (sh2) | 0.302 | 0.312 | 0.353 | 5 | 183.68 KB | 3.66 MB | 34.6 MB | ok: - |
| - | self-hosted fast@0aa09be4 | C compiler (tcc -c) | 0.061 | 0.067 | 0.085 | 5 | 3.66 MB | 2.80 MB | 31.2 MB | ok: - |
| - | self-hosted fast@0aa09be4 | link (gcc) | 0.031 | 0.041 | 0.067 | 5 | 2.80 MB | 2.08 MB | 31.2 MB | ok: - |
| - | self-hosted fast@0aa09be4 | run (compile selfhost) | 5.808 | 6.490 | 6.980 | 5 | 183.68 KB | 3.66 MB | 36.6 MB | ok: - |
| - | self-hosted fast@0aa09be4 | check | 0.004 | 0.004 | 0.008 | 5 | 7.32 MB | 0 B | 0.0 MB | ok: fixed point cmp: stage n C == stage n+1 C |

Source to running program (W1, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| - | stock optimized | 6.257 | 6.625 | 7.216 |
| - | stock fast | 0.926 | 0.962 | 1.108 |
| - | self-hosted | 7.274 | 7.936 | 9.101 |
| - | self-hosted gcc -O0 | 3.170 | 3.254 | 3.962 |
| - | self-hosted fast | 1.359 | 1.456 | 1.728 |
| - | stock optimized@0aa09be4 | 4.069 | 4.131 | 5.797 |
| - | stock fast@0aa09be4 | 2.553 | 2.654 | 2.918 |
| - | self-hosted@0aa09be4 | 10.283 | 11.586 | 12.860 |
| - | self-hosted gcc -O0@0aa09be4 | 8.513 | 9.198 | 9.593 |
| - | self-hosted fast@0aa09be4 | 6.226 | 6.919 | 7.439 |

### W3

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| vm | stock optimized | front end (C++) | 0.017 | 0.025 | 0.036 | 5 | 5.03 KB | 141.66 KB | 31.2 MB | ok: - |
| vm | stock optimized | C compiler (gcc -O2) | 0.111 | 0.132 | 0.141 | 5 | 141.66 KB | 84.30 KB | 33.4 MB | ok: - |
| vm | stock optimized | run | 0.001 | 0.001 | 0.001 | 5 | 4.10 KB | 512 B | 31.2 MB | ok: - |
| vm | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | stock fast | front end+TinyCC+run | 0.019 | 0.027 | 0.039 | 5 | 5.03 KB | 512 B | 31.2 MB | ok: - |
| vm | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 511 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/vm.out |
| vm | self-hosted | front end (sh2) | 0.006 | 0.006 | 0.006 | 1 | 5.03 KB | 0 B | 28.3 MB | FAIL: unsupported: stdlib/std.goose:1155:13: error: argument count mismatch |
| vm | self-hosted@0aa09be4 | front end (sh2) | 0.004 | 0.004 | 0.004 | 1 | 5.03 KB | 0 B | 28.3 MB | FAIL: unsupported: stdlib/std.goose:1348:34: error: expected ')', got '=' |
| raytrace | stock optimized | front end (C++) | 0.020 | 0.029 | 0.037 | 5 | 5.46 KB | 162.95 KB | 31.2 MB | ok: - |
| raytrace | stock optimized | C compiler (gcc -O2) | 0.203 | 0.236 | 0.289 | 5 | 162.95 KB | 88.30 KB | 41.5 MB | ok: - |
| raytrace | stock optimized | run | 0.005 | 0.006 | 0.015 | 5 | 4.10 KB | 2.06 KB | 31.2 MB | ok: - |
| raytrace | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | stock fast | front end+TinyCC+run | 0.075 | 0.084 | 0.104 | 5 | 5.46 KB | 2.06 KB | 31.2 MB | ok: - |
| raytrace | stock fast | check | 0.000 | 0.000 | 0.001 | 5 | 2.06 KB | 0 B | 0.0 MB | ok: blessed output match: samples/expected/raytrace.out |
| raytrace | self-hosted | front end (sh2) | 0.008 | 0.008 | 0.008 | 1 | 5.46 KB | 0 B | 28.3 MB | FAIL: unsupported: stdlib/vec.goose:60:44: error: numeric operands required |
| raytrace | self-hosted@0aa09be4 | front end (sh2) | 0.005 | 0.005 | 0.005 | 1 | 5.46 KB | 0 B | 28.3 MB | FAIL: unsupported: stdlib/std.goose:1348:34: error: expected ')', got '=' |
| mini_doom | stock optimized | front end (C++) | 0.103 | 0.126 | 0.144 | 5 | 69.61 KB | 962.99 KB | 31.2 MB | ok: - |
| mini_doom | stock optimized | C compiler (gcc -O2) | 1.934 | 2.085 | 2.154 | 5 | 962.99 KB | 3.99 MB | 108.6 MB | ok: - |
| mini_doom | stock optimized | run | 0.509 | 0.531 | 0.635 | 5 | 4.10 KB | 42 B | 238.9 MB | ok: - |
| mini_doom | stock optimized | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | stock fast | front end+TinyCC+run | 0.635 | 0.713 | 0.755 | 5 | 69.61 KB | 42 B | 253.8 MB | ok: - |
| mini_doom | stock fast | check | 0.000 | 0.000 | 0.000 | 5 | 41 B | 0 B | 0.0 MB | ok: blessed output match: samples/expected/mini_doom.out |
| mini_doom | self-hosted | front end (sh2) | 0.005 | 0.005 | 0.005 | 1 | 69.61 KB | 0 B | 28.3 MB | FAIL: unsupported: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer |
| mini_doom | self-hosted@0aa09be4 | front end (sh2) | 0.006 | 0.006 | 0.006 | 1 | 69.61 KB | 0 B | 28.3 MB | FAIL: unsupported: samples/31_mini_doom.goose:134:1: error: global declarations require an initializer |

Source to running program (W3, stages before the check, summed per run):

| item | rung | min s | median s | max s |
|---|---|---:|---:|---:|
| vm | stock optimized | 0.129 | 0.165 | 0.177 |
| vm | stock fast | 0.019 | 0.027 | 0.039 |
| vm | self-hosted | does not run | | |
| vm | self-hosted@0aa09be4 | does not run | | |
| raytrace | stock optimized | 0.229 | 0.273 | 0.326 |
| raytrace | stock fast | 0.075 | 0.084 | 0.104 |
| raytrace | self-hosted | does not run | | |
| raytrace | self-hosted@0aa09be4 | does not run | | |
| mini_doom | stock optimized | 2.591 | 2.767 | 2.858 |
| mini_doom | stock fast | 0.635 | 0.713 | 0.755 |
| mini_doom | self-hosted | does not run | | |
| mini_doom | self-hosted@0aa09be4 | does not run | | |

### W2

| item | rung | stage | min s | median s | max s | runs | bytes in | bytes out | peak RSS | check |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| - | stock optimized | goose build (sum) | 161.174 | 256.500 | 263.422 | 5 | 1.95 MB | 0 B | 115.6 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | run (sum) | 5.536 | 7.735 | 9.107 | 5 | 1.95 MB | 0 B | 115.6 MB | ok: blessed output match: 771/771 pass |
| - | stock optimized | wall, 771 fixtures -j8 | 21.328 | 33.621 | 34.741 | 5 | 1.95 MB | 0 B | 115.6 MB | ok: blessed output match: 771/771 pass |
| - | stock fast | goose x.goose (fe+tcc+run) (sum) | 16.444 | 29.939 | 35.862 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
| - | stock fast | wall, 771 fixtures -j8 | 2.400 | 4.171 | 5.068 | 5 | 1.95 MB | 0 B | 134.1 MB | ok: blessed output match: 733/733 pass |
| - | self-hosted | front end (sh2) (sum) | 2.950 | 5.365 | 6.903 | 5 | 1.95 MB | 0 B | 53.0 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | C compiler (gcc -O2) (sum) | 12.271 | 21.269 | 27.803 | 5 | 1.95 MB | 0 B | 53.0 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | run (sum) | 1.109 | 1.611 | 2.603 | 5 | 1.95 MB | 0 B | 53.0 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted | wall, 771 fixtures -j8 | 2.294 | 3.809 | 5.032 | 5 | 1.95 MB | 0 B | 53.0 MB | FAIL: blessed output match: 73/771 pass |
| - | self-hosted@0aa09be4 | front end (sh2) (sum) | 2.400 | 4.664 | 5.557 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted@0aa09be4 | C compiler (gcc -O2) (sum) | 4.983 | 7.999 | 10.116 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted@0aa09be4 | run (sum) | 0.083 | 0.169 | 0.194 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| - | self-hosted@0aa09be4 | wall, 771 fixtures -j8 | 1.193 | 1.935 | 2.395 | 5 | 1.95 MB | 0 B | 49.0 MB | FAIL: blessed output match: 30/771 pass |
| selfhost-pass | stock optimized | goose build (sum) | 9.211 | 14.681 | 17.483 | 5 | 99.33 KB | 0 B | 45.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | stock optimized | run (sum) | 0.138 | 0.231 | 0.328 | 5 | 99.33 KB | 0 B | 45.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | stock optimized | wall, 73 fixtures -j8 | 1.231 | 1.978 | 2.341 | 5 | 99.33 KB | 0 B | 45.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | stock fast | goose x.goose (fe+tcc+run) (sum) | 1.091 | 1.571 | 2.383 | 5 | 99.33 KB | 0 B | 31.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | stock fast | wall, 73 fixtures -j8 | 0.516 | 0.659 | 0.986 | 5 | 99.33 KB | 0 B | 31.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted | front end (sh2) (sum) | 0.371 | 0.592 | 0.723 | 5 | 99.33 KB | 0 B | 52.6 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted | C compiler (gcc -O2) (sum) | 11.525 | 18.018 | 20.333 | 5 | 99.33 KB | 0 B | 52.6 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted | run (sum) | 0.800 | 1.576 | 2.243 | 5 | 99.33 KB | 0 B | 52.6 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted | wall, 73 fixtures -j8 | 1.701 | 2.674 | 3.052 | 5 | 99.33 KB | 0 B | 52.6 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted gcc -O0 | front end (sh2) (sum) | 0.404 | 0.600 | 0.743 | 5 | 99.33 KB | 0 B | 40.8 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted gcc -O0 | C compiler (gcc -O0) (sum) | 11.759 | 19.340 | 22.872 | 5 | 99.33 KB | 0 B | 40.8 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted gcc -O0 | run (sum) | 4.315 | 5.250 | 6.823 | 5 | 99.33 KB | 0 B | 40.8 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted gcc -O0 | wall, 73 fixtures -j8 | 4.429 | 5.396 | 7.120 | 5 | 99.33 KB | 0 B | 40.8 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted fast | front end (sh2) (sum) | 0.421 | 0.615 | 0.811 | 5 | 99.33 KB | 0 B | 31.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted fast | C compiler (tcc -c) (sum) | 0.839 | 1.154 | 1.328 | 5 | 99.33 KB | 0 B | 31.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted fast | link (gcc) (sum) | 2.528 | 3.748 | 4.404 | 5 | 99.33 KB | 0 B | 31.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted fast | run (sum) | 4.168 | 4.941 | 5.806 | 5 | 99.33 KB | 0 B | 31.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted fast | wall, 73 fixtures -j8 | 3.977 | 4.613 | 5.389 | 5 | 99.33 KB | 0 B | 31.2 MB | ok: blessed output match: 73/73 pass |
| selfhost-pass | self-hosted@0aa09be4 | front end (sh2) (sum) | 0.280 | 0.475 | 0.568 | 5 | 99.33 KB | 0 B | 36.4 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted@0aa09be4 | C compiler (gcc -O2) (sum) | 3.929 | 4.922 | 7.013 | 5 | 99.33 KB | 0 B | 36.4 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted@0aa09be4 | run (sum) | 0.054 | 0.084 | 0.139 | 5 | 99.33 KB | 0 B | 36.4 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted@0aa09be4 | wall, 73 fixtures -j8 | 0.627 | 0.813 | 1.087 | 5 | 99.33 KB | 0 B | 36.4 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted gcc -O0@0aa09be4 | front end (sh2) (sum) | 0.245 | 0.280 | 0.503 | 5 | 99.33 KB | 0 B | 32.1 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted gcc -O0@0aa09be4 | C compiler (gcc -O0) (sum) | 3.718 | 3.968 | 6.479 | 5 | 99.33 KB | 0 B | 32.1 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted gcc -O0@0aa09be4 | run (sum) | 0.043 | 0.091 | 0.128 | 5 | 99.33 KB | 0 B | 32.1 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted gcc -O0@0aa09be4 | wall, 73 fixtures -j8 | 0.584 | 0.619 | 1.053 | 5 | 99.33 KB | 0 B | 32.1 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted fast@0aa09be4 | front end (sh2) (sum) | 0.287 | 0.377 | 0.574 | 5 | 99.33 KB | 0 B | 31.2 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted fast@0aa09be4 | C compiler (tcc -c) (sum) | 0.268 | 0.358 | 0.534 | 5 | 99.33 KB | 0 B | 31.2 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted fast@0aa09be4 | link (gcc) (sum) | 0.719 | 0.942 | 1.610 | 5 | 99.33 KB | 0 B | 31.2 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted fast@0aa09be4 | run (sum) | 0.088 | 0.121 | 0.163 | 5 | 99.33 KB | 0 B | 31.2 MB | FAIL: blessed output match: 30/73 pass |
| selfhost-pass | self-hosted fast@0aa09be4 | wall, 73 fixtures -j8 | 0.271 | 0.335 | 0.491 | 5 | 99.33 KB | 0 B | 31.2 MB | FAIL: blessed output match: 30/73 pass |
