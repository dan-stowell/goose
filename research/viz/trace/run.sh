#!/bin/sh
# The whole pictures pipeline for W1, from source: build the bytemove tool,
# build the self-hosted compiler (sh1, then sh2 from its own C), make a
# stage-marked copy of sh2, trace both front ends compiling selfhost/,
# count with perf, reduce to research/viz/data/*.json, build index.html.
# Usage (repo root): research/viz/trace/run.sh [WORKDIR]   (default /tmp/bytemove-w1)
# Needs: valgrind 3.22 (headers + static libs, Ubuntu's package has them), gcc, perf.
set -e
root=$(pwd)
goose=${GOOSE:-/home/exedev/goose/build/goose}
w=${1:-/tmp/bytemove-w1}
viz=$root/research/viz
mkdir -p "$w"
"$viz/trace/build.sh" "$w/vglib" >/dev/null

"$goose" build selfhost/main.goose -o "$w/sh1" >/dev/null
"$w/sh1" -o "$w/sh2.c" selfhost/main.goose
gcc -O2 "$w/sh2.c" -o "$w/sh2" -lm
marks=$(python3 "$viz/trace/stagemarks.py" "$w/sh2.c" "$w/sh2m.c")
gcc -O2 -g -no-pie "$w/sh2m.c" -o "$w/sh2m" -lm
stacks=$(nm "$w/sh2m" | awk '/ gg_stacks$/ {print $1}')

rm -rf "$w/tsh" "$w/tcpp"; mkdir -p "$w/tsh" "$w/tcpp"
t0=$(date +%s.%N)
VALGRIND_LIB=$w/vglib valgrind -q --tool=bytemove --out="$w/tsh" --sample=64 --marks="$marks" \
  --dump="$stacks:196608" "$w/sh2m" -o "$w/tsh/out.c" selfhost/main.goose
t1=$(date +%s.%N)
cmp "$w/tsh/out.c" "$w/sh2.c"     # the traced run wrote the same C (the fixed point)
VALGRIND_LIB=$w/vglib valgrind -q --tool=bytemove --out="$w/tcpp" --sample=64 \
  --marks='goose::ParseProgram=parse:s,goose::ResolveTypeNames=check:s,goose::Optimizer::Optimizer=optimize:s,goose::BCE::RunAll=optimize:s,goose::CodeGen::CodeGen=emit:s,goose::WriteFileMakingDirs=write:s' \
  "$goose" -o "$w/tcpp/out.c" selfhost/main.goose
t2=$(date +%s.%N)
"$goose" -o "$w/cpp.c" selfhost/main.goose
cmp "$w/tcpp/out.c" "$w/cpp.c"
echo "traced: self-hosted $(echo "$t1 - $t0" | bc) s, C++ $(echo "$t2 - $t1" | bc) s"

python3 "$viz/trace/reduce.py" goose "$w/tsh" "$w/tsh/out.c" "Self-hosted front end (sh2, built from its own C)" "$viz/data/selfhost_w1.json"
python3 "$viz/trace/reduce.py" cpp "$w/tcpp" "$w/tcpp/out.c" "C++ front end (build/goose -o out.c)" "$viz/data/cpp_w1.json"
"$viz/trace/counters.sh" "$w/sh2" "$goose" "$w/ctr"
python3 "$viz/trace/counters_json.py" "$w/ctr/counters.csv" "$w/ctr/uptime.txt" "$viz/data/counters.json"
python3 "$viz/build.py"
