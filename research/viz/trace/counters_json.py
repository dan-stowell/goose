#!/usr/bin/env python3
"""counters.csv (from counters.sh) -> JSON: min/median/max per front end,
mode and event, and per-stage medians as differences between cumulative
modes (parse; check = --check minus --parse; emit = -o minus --check).
usage: counters_json.py counters.csv uptime.txt out.json"""
import csv, json, statistics, sys
rows = list(csv.reader(open(sys.argv[1])))
d = {}
for fe, mode, run, ev, val in rows:
    try: v = float(val)
    except ValueError: continue
    d.setdefault(fe, {}).setdefault(mode, {}).setdefault(ev.replace(':u', ''), []).append(v)
out = {'uptime': open(sys.argv[2]).read().strip().split('\n'), 'modes': {}, 'stages': {}}
for fe, modes in d.items():
    out['modes'][fe] = {m: {e: [min(v), statistics.median(v), max(v), len(v)] for e, v in evs.items()}
                        for m, evs in modes.items()}
    med = {m: {e: statistics.median(v) for e, v in evs.items()} for m, evs in modes.items()}
    prev = None
    out['stages'][fe] = {}
    for m in ['parse', 'check', 'emit']:
        out['stages'][fe][m] = {e: med[m][e] - (med[prev][e] if prev else 0) for e in med[m]}
        prev = m
json.dump(out, open(sys.argv[3], 'w'), indent=1)
