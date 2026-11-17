#!/bin/bash
# Compare the C two selfhost emitters write for one fixed input (W1 by default).
# usage: research/tools/emit_bench.sh OUT_DIR INPUT.goose NAME=SH1 [NAME=SH1 ...]
# For each emitter: bytes of C; gcc -O2 and gcc -O0 compile time; tcc -c time; and the
# W1 time of the tcc-built and gcc -O2-built compilers (each compiling INPUT). Runs are
# interleaved across emitters, RUNS (default 5) times. Prints one line per measurement.
set -e
OUT=$1; INPUT=$2; shift 2
RUNS=${RUNS:-5}
TCC=/home/exedev/goose/build/tcc/tcc; LIB=/home/exedev/goose/build/tcclib
mkdir -p "$OUT"
names=()
for pair in "$@"; do
  n=${pair%%=*}; sh1=${pair#*=}; names+=("$n")
  "$sh1" -o "$OUT/$n.c" "$INPUT"
  echo "bytes $n $(stat -c %s "$OUT/$n.c")"
  gcc -O2 "$OUT/$n.c" -o "$OUT/$n.gcc" -lm
  $TCC -B$LIB -I/usr/include/x86_64-linux-gnu -I/usr/include -c "$OUT/$n.c" -o "$OUT/$n.o"
  gcc -Wl,--no-eh-frame-hdr -z noexecstack "$OUT/$n.o" $LIB/libtcc1.a -lm -o "$OUT/$n.tcc"
  "$OUT/$n.gcc" -o "$OUT/$n.check.c" "$INPUT"; "$OUT/$n.tcc" -o "$OUT/$n.check2.c" "$INPUT"
  cmp "$OUT/$n.check.c" "$OUT/$n.check2.c"
  # Instruction counts (user space, children included): deterministic on a shared VM.
  I() { /usr/local/bin/perf stat -x, -e instructions:u "${@:2}" 2>&1 >/dev/null | grep instructions | cut -d, -f1 | sed "s/^/instr $1 $n /"; }
  I gcc-O2 gcc -O2 "$OUT/$n.c" -o "$OUT/$n.x" -lm
  I gcc-O0 gcc -O0 "$OUT/$n.c" -o "$OUT/$n.x" -lm
  I tcc $TCC -B$LIB -I/usr/include/x86_64-linux-gnu -I/usr/include -c "$OUT/$n.c" -o "$OUT/$n.x.o"
  I run-tcc "$OUT/$n.tcc" -o "$OUT/$n.r.c" "$INPUT"
  I run-gcc "$OUT/$n.gcc" -o "$OUT/$n.r.c" "$INPUT"
done
uptime
t() { /usr/bin/time -f "$1 %e s %M KB" "${@:2}" > /dev/null; }
for i in $(seq $RUNS); do for n in "${names[@]}"; do
  t "gcc-O2 $n" gcc -O2 "$OUT/$n.c" -o "$OUT/$n.x" -lm
  t "gcc-O0 $n" gcc -O0 "$OUT/$n.c" -o "$OUT/$n.x" -lm
  t "tcc $n" $TCC -B$LIB -I/usr/include/x86_64-linux-gnu -I/usr/include -c "$OUT/$n.c" -o "$OUT/$n.x.o"
  t "run-tcc $n" "$OUT/$n.tcc" -o "$OUT/$n.r.c" "$INPUT"
  t "run-gcc $n" "$OUT/$n.gcc" -o "$OUT/$n.r.c" "$INPUT"
done; done 2>&1
uptime
