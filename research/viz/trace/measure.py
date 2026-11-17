#!/usr/bin/env python3
"""Hardware counters for every job the pictures compare, 5 interleaved runs.

usage: measure.py WORKDIR GOOSE OUT.json [RUNS]
WORKDIR is regen.sh's: before/ and after/ each hold selfhost/ and its sh2,
sh2.c. Jobs:
  front ends, by cumulative mode (--parse, --check, -o out.c), so a stage is
  a difference: before sh2 on the before input, after sh2 on the after
  input, after sh2 on the before input (like for like), C++ on both;
  gcc -O2 -c on before/sh2.c and after/sh2.c (the whole C compiler).
Two event groups per job (each fits Zen 4's six counters, nothing is
multiplexed). Medians and min/max are written per job, mode and event.
"""
import json, os, statistics, subprocess, sys, tempfile

w, goose, out = sys.argv[1], sys.argv[2], sys.argv[3]
runs = int(sys.argv[4]) if len(sys.argv) > 4 else 5
A = 'duration_time,instructions:u,cycles:u,ls_dispatch.ld_dispatch:u,ls_dispatch.store_dispatch:u,ls_any_fills_from_sys.all:u'
B = 'ls_dmnd_fills_from_sys.local_l2:u,ls_dmnd_fills_from_sys.local_ccx:u,ls_dmnd_fills_from_sys.dram_io_near:u,ls_dmnd_fills_from_sys.dram_io_far:u,l2_request_g1.all_dc:u'
tmp = tempfile.mkdtemp()
def fe(binary, cwd):
    return {m: (cwd, [binary] + a + ['selfhost/main.goose']) for m, a in
            [('parse', ['--parse']), ('check', ['--check']), ('emit', ['-o', os.path.join(tmp, 'o.c')])]}
jobs = {
    'fe_before': fe(os.path.join(w, 'before/sh2'), os.path.join(w, 'before')),
    'fe_after': fe(os.path.join(w, 'after/sh2'), os.path.join(w, 'after')),
    'fe_after_on_before': fe(os.path.join(w, 'after/sh2'), os.path.join(w, 'before')),
    'cpp_after': fe(goose, os.path.join(w, 'after')),
    'cpp_before': fe(goose, os.path.join(w, 'before')),
    'gcc_before': {'cc': (os.path.join(w, 'before'), ['gcc', '-O2', '-c', 'sh2.c', '-o', os.path.join(tmp, 'b.o')])},
    'gcc_after': {'cc': (os.path.join(w, 'after'), ['gcc', '-O2', '-c', 'sh2.c', '-o', os.path.join(tmp, 'a.o')])},
}
uptime = [subprocess.check_output(['uptime'], text=True).strip()]
vals = {}
for r in range(runs):
    for job, modes in jobs.items():
        for mode, (cwd, cmd) in modes.items():
            for ev in (A, B):
                f = os.path.join(tmp, 'p.txt')
                subprocess.run(['perf', 'stat', '-x,', '-e', ev, '-o', f] + cmd, cwd=cwd,
                               stdout=subprocess.DEVNULL, check=True)
                for line in open(f):
                    p = line.strip().split(',')
                    if len(p) < 3 or line.startswith('#'): continue
                    try: v = float(p[0])
                    except ValueError: continue
                    vals.setdefault(job, {}).setdefault(mode, {}).setdefault(p[2].replace(':u', ''), []).append(v)
    print('run', r + 1, 'done', file=sys.stderr)
uptime.append(subprocess.check_output(['uptime'], text=True).strip())
res = {'uptime': uptime, 'runs': runs, 'jobs': {}, 'stages': {}}
for job, modes in vals.items():
    res['jobs'][job] = {m: {e: [min(v), statistics.median(v), max(v)] for e, v in evs.items()} for m, evs in modes.items()}
    if 'emit' in modes:
        med = {m: {e: statistics.median(v) for e, v in evs.items()} for m, evs in modes.items()}
        res['stages'][job] = {m: {e: med[m][e] - (med[p][e] if p else 0) for e in med[m]}
                              for m, p in [('parse', None), ('check', 'parse'), ('emit', 'check')]}
json.dump(res, open(out, 'w'), indent=1)
