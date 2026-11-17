#!/bin/sh
# Real hardware counters for each front end on W1, by cumulative mode
# (parse only, parse+check, the whole compile to C), so a stage's share is
# the difference between modes. Zen 4 has six general counters; each group
# below fits in them, so nothing is multiplexed. Five interleaved runs.
# Usage: counters.sh SH2 GOOSE OUTDIR    (run from the repo root)
set -e
sh2=$1; goose=$2; out=$3; mkdir -p "$out"
A=instructions:u,cycles:u,ls_dispatch.ld_dispatch:u,ls_dispatch.store_dispatch:u,ls_any_fills_from_sys.all:u
B=ls_dmnd_fills_from_sys.local_l2:u,ls_dmnd_fills_from_sys.local_ccx:u,ls_dmnd_fills_from_sys.near_cache:u,ls_dmnd_fills_from_sys.dram_io_near:u,ls_dmnd_fills_from_sys.far_cache:u,ls_dmnd_fills_from_sys.dram_io_far:u
C=ls_any_fills_from_sys.local_l2:u,ls_any_fills_from_sys.local_ccx:u,ls_any_fills_from_sys.dram_io_near:u,l2_request_g1.all_dc:u,l2_cache_req_stat.dc_hit_in_l2:u,l2_pf_hit_l2.all:u
uptime > "$out/uptime.txt"
: > "$out/counters.csv"
for run in 1 2 3 4 5; do
  for fe in sh2 cpp; do
    for mode in parse check emit; do
      if [ $fe = sh2 ]; then bin=$sh2; else bin=$goose; fi
      case $mode in parse) args="--parse";; check) args="--check";; emit) args="-o $out/tmp.c";; esac
      for g in A B C; do
        eval ev=\$$g
        perf stat -x, -e "$ev" -o "$out/p.txt" $bin $args selfhost/main.goose >/dev/null
        grep -v '^#' "$out/p.txt" | grep . | awk -F, -v fe=$fe -v m=$mode -v r=$run '{print fe","m","r","$3","$1}' >> "$out/counters.csv"
      done
    done
  done
done
rm -f "$out/p.txt" "$out/tmp.c"
uptime >> "$out/uptime.txt"
