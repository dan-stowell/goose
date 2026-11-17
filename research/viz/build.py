#!/usr/bin/env python3
"""Build research/viz/index.html from the committed data.

Inputs (all real runs, never edited by hand):
  data/selfhost_w1.json, data/cpp_w1.json  bytemove traces reduced by trace/reduce.py
  data/counters.json                       hardware counters, trace/counters.sh
  ../runs/*.json                           the ladder (another builder writes these):
                                           [{workload, rung, stage, run, seconds, bytes_in,
                                             bytes_out, peak_rss_kb, check, ok}]
The page is one self-contained file: the data is inlined, no network needed.
usage: python3 research/viz/build.py
"""
import glob, json, os, statistics, subprocess, datetime

here = os.path.dirname(os.path.abspath(__file__))
def load(p):
    p = os.path.join(here, p)
    return json.load(open(p)) if os.path.exists(p) else None

traces = [t for t in (load('data/selfhost_w1.json'), load('data/cpp_w1.json')) if t]
counters = load('data/counters.json')
runs = []
for p in sorted(glob.glob(os.path.join(here, '..', 'runs', '*.json'))):
    try:
        d = json.load(open(p))
        runs += d if isinstance(d, list) else [d]
    except Exception as e:
        print('skipping', p, e)

# ladder: per workload, rung, stage -> min/median/max over runs
ladder = {}
for r in runs:
    k = (r.get('workload'), r.get('rung'), r.get('stage'))
    ladder.setdefault(k, []).append(r)
ladder_rows = []
for (w, rung, st), rs in sorted(ladder.items(), key=lambda kv: tuple(str(x) for x in kv[0])):
    secs = [float(r.get('seconds') or 0) for r in rs]
    ladder_rows.append({'workload': w, 'rung': rung, 'stage': st, 'n': len(rs),
                        'min': min(secs), 'median': statistics.median(secs), 'max': max(secs),
                        'bytes_out': rs[-1].get('bytes_out'), 'peak_rss_kb': rs[-1].get('peak_rss_kb'),
                        'check': rs[-1].get('check'), 'ok': all(r.get('ok') for r in rs)})
try:
    commit = subprocess.check_output(['git', '-C', here, 'rev-parse', '--short', 'HEAD'], text=True).strip()
except Exception:
    commit = '?'
meta = {'built': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC'), 'commit': commit}

html = open(os.path.join(here, 'page.html')).read()
html = html.replace('/*DATA*/', 'const TRACES = %s;\nconst COUNTERS = %s;\nconst LADDER = %s;\nconst META = %s;' % (
    json.dumps(traces, separators=(',', ':')), json.dumps(counters, separators=(',', ':')),
    json.dumps(ladder_rows, separators=(',', ':')), json.dumps(meta)))
open(os.path.join(here, 'index.html'), 'w').write(html)
print('wrote index.html: %d bytes, %d traces, %d ladder rows' % (len(html), len(traces), len(ladder_rows)))
