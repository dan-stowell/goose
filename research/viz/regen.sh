#!/bin/sh
# Regenerate every picture from real runs, in one command:
#   research/viz/regen.sh [WORKDIR]        (from the repo root; default /tmp/viz-regen)
# Environment: BEFORE=<commit> (default aa0092db: selfhost before the symbol
# index, the overload chain walk and emit-dedup), AFTER=<commit> (default
# HEAD), GOOSE=<C++ compiler> (default /home/exedev/goose/build/goose),
# CC1_SAMPLE=N (default 1024), SKIP_CC1=1 to reuse earlier cc1 traces in
# WORKDIR (they take ~10 minutes), NO_CC1=1 to skip tracing cc1 (keeps the
# committed cc1 data), RUNS=N counter runs (default 5), NO_COUNTERS=1 to skip them.
#
# 1. Builds the bytemove Valgrind tool, and for BEFORE and AFTER the
#    self-hosted compiler from its own selfhost/: sh1 (C++ front end + gcc),
#    sh2.c (sh1), sh2 (gcc -O2), checking the fixed point sh2.c == sh3.c,
#    and sh2m (sh2.c with the stage functions noinline, -no-pie, -g).
# 2. Traces, in parallel: before on the before input, after on the after
#    input, after on the before input (like for like), the C++ compiler on
#    both, and cc1 -O2 on before/sh2.c and after/sh2.c.
# 3. Counters (trace/measure.py), reduction (trace/reduce.py), then
#    build.py writes index.html, also reading research/runs/*.json.
set -e
root=$(pwd)
viz=$root/research/viz
w=${1:-/tmp/viz-regen}
goose=${GOOSE:-/home/exedev/goose/build/goose}
before=${BEFORE:-aa0092db}
after=${AFTER:-HEAD}
data=$viz/data
mkdir -p "$w" "$data"
"$viz/trace/build.sh" "$w/vglib" >/dev/null
vg() { VALGRIND_LIB=$w/vglib valgrind -q --tool=bytemove "$@"; }
CPP_MARKS='goose::ParseProgram=parse:s,goose::ResolveTypeNames=check:s,goose::Optimizer::Optimizer=optimize:s,goose::BCE::RunAll=optimize:s,goose::CodeGen::CodeGen=emit:s,goose::WriteFileMakingDirs=write:s'

for v in before after; do
  eval c=\$$v
  rm -rf "$w/$v"; mkdir -p "$w/$v"
  git -C "$root" archive "$c" selfhost | tar -x -C "$w/$v"
  git -C "$root" rev-parse --short "$c" > "$w/$v/commit"
  (cd "$w/$v"
   "$goose" build selfhost/main.goose -o sh1 >/dev/null
   ./sh1 -o sh2.c selfhost/main.goose
   gcc -O2 sh2.c -o sh2 -lm
   ./sh2 -o sh3.c selfhost/main.goose
   cmp sh2.c sh3.c
   python3 "$viz/trace/stagemarks.py" sh2.c sh2m.c > marks
   gcc -O2 -g -no-pie sh2m.c -o sh2m -lm
   nm sh2m | awk '/ gg_stacks$/ {print $1}' > stacks)
  echo "$v $(cat "$w/$v/commit"): fixed point holds, sh2.c $(wc -c < "$w/$v/sh2.c") bytes"
done

trace_fe() { # name compiler-dir input-dir
  t=$w/t_$1; rm -rf "$t"; mkdir -p "$t"
  (cd "$w/$3" && vg --out="$t" --sample=64 --marks="$(cat "$w/$2/marks")" \
     --dump="$(cat "$w/$2/stacks"):196608" "$w/$2/sh2m" -o "$t/out.c" selfhost/main.goose)
  (cd "$w/$3" && "$w/$2/sh2" -o "$t/ref.c" selfhost/main.goose)
  cmp "$t/out.c" "$t/ref.c"
}
trace_cpp() { # name input-dir
  t=$w/t_$1; rm -rf "$t"; mkdir -p "$t"
  (cd "$w/$2" && vg --out="$t" --sample=64 --marks="$CPP_MARKS" "$goose" -o "$t/out.c" selfhost/main.goose)
}
trace_cc1() { # name dir
  t=$w/t_$1
  if [ -n "$NO_CC1" ] || { [ -n "$SKIP_CC1" ] && [ -f "$t/agg.tsv" ]; }; then return; fi
  rm -rf "$t"; mkdir -p "$t"
  cc1=$(gcc -print-prog-name=cc1)
  # the cc1 command gcc -O2 -c runs (gcc -### shows it); as and ld are not traced
  (cd "$w/$2" && /usr/bin/time -f %e -o "$t/seconds" env VALGRIND_LIB=$w/vglib valgrind -q --tool=bytemove \
     --out="$t" --sample="${CC1_SAMPLE:-1024}" "$cc1" -quiet -imultiarch x86_64-linux-gnu sh2.c \
     -D_FORTIFY_SOURCE=3 -dumpbase sh2.c -dumpbase-ext .c -mtune=generic -march=x86-64 -O2 \
     -fasynchronous-unwind-tables -fstack-protector-strong -Wformat -Wformat-security \
     -fstack-clash-protection -fcf-protection -o "$t/out.s")
}
trace_cc1 cc1_before before & p1=$!
trace_cc1 cc1_after after & p2=$!
trace_fe fe_before before before
trace_fe fe_after after after
trace_fe fe_after_on_before after before
trace_cpp cpp_after after
trace_cpp cpp_before before
wait $p1; wait $p2
echo "traces done"

ctx() { echo "$w/$1/selfhost/context.goose"; }
bc=$(cat "$w/before/commit"); ac=$(cat "$w/after/commit")
python3 "$viz/trace/reduce.py" goose "$w/t_fe_before" "$w/t_fe_before/out.c" "before ($bc) compiling its own selfhost" "$data/fe_before.json" "$(ctx before)"
python3 "$viz/trace/reduce.py" goose "$w/t_fe_after" "$w/t_fe_after/out.c" "after ($ac) compiling its own selfhost" "$data/fe_after.json" "$(ctx after)"
python3 "$viz/trace/reduce.py" goose "$w/t_fe_after_on_before" "$w/t_fe_after_on_before/out.c" "after ($ac) compiling the before selfhost ($bc)" "$data/fe_after_on_before.json" "$(ctx after)"
python3 "$viz/trace/reduce.py" cpp "$w/t_cpp_after" "$w/t_cpp_after/out.c" "C++ front end compiling the after selfhost ($ac)" "$data/cpp_after.json"
python3 "$viz/trace/reduce.py" cpp "$w/t_cpp_before" "$w/t_cpp_before/out.c" "C++ front end compiling the before selfhost ($bc)" "$data/cpp_before.json"
for v in before after; do
  if [ -f "$w/t_cc1_$v/agg.tsv" ]; then
    python3 "$viz/trace/reduce.py" gcc "$w/t_cc1_$v" "$w/$v/sh2.c" "cc1 -O2 on the $v C ($(cat "$w/$v/commit"), $(wc -c < "$w/$v/sh2.c") bytes)" "$data/cc1_$v.json"
  fi
done
printf '{"before": "%s", "after": "%s", "before_c": %s, "after_c": %s, "after_on_before_c": %s, "cc1_traced_seconds": [%s, %s]}\n' \
  "$bc" "$ac" "$(wc -c < "$w/before/sh2.c")" "$(wc -c < "$w/after/sh2.c")" "$(wc -c < "$w/t_fe_after_on_before/out.c")" \
  "$(cat "$w/t_cc1_before/seconds" 2>/dev/null || echo null)" "$(cat "$w/t_cc1_after/seconds" 2>/dev/null || echo null)" > "$data/compare.json"

[ -n "$NO_COUNTERS" ] || python3 "$viz/trace/measure.py" "$w" "$goose" "$data/counters.json" "${RUNS:-5}"
python3 "$viz/build.py"
