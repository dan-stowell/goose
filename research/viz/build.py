#!/usr/bin/env python3
"""Build research/viz/index.html from the committed data. Run regen.sh to
refresh the data from real runs first; this step only lays it out.

Inputs (never edited by hand):
  data/fe_*.json, data/cpp_*.json, data/cc1_*.json  bytemove traces (trace/reduce.py)
  data/counters.json                                hardware counters (trace/measure.py)
  data/compare.json                                 which commits are before/after, C sizes
  ../runs/*.json + *.meta.json                      the ladder, from research/demo --ladder
The page is one self-contained file: the data is inlined, no network needed.
usage: python3 research/viz/build.py
"""
import datetime, glob, json, os, statistics, subprocess

here = os.path.dirname(os.path.abspath(__file__))
def load(name):
    p = os.path.join(here, 'data', name)
    return json.load(open(p)) if os.path.exists(p) else None

TRACE_NAMES = ['fe_before', 'fe_after_on_before', 'fe_after', 'cpp_before', 'cpp_after', 'cc1_before', 'cc1_after']
traces = {k: load(k + '.json') for k in TRACE_NAMES}
traces = {k: v for k, v in traces.items() if v}

# ---------------------------------------------------------------- the ladder over time
def include(rung, stage):
    """Stages that add up to source -> program: not the bootstrap, not the
    fixed-point check, not running the result (except where it cannot be
    separated: stock fast's in-process TinyCC run). W2 uses its wall time."""
    if rung == 'bootstrap' or stage == 'check': return False
    if stage.startswith('run'): return False
    return True
history = []
for p in sorted(glob.glob(os.path.join(here, '..', 'runs', '*.json'))):
    if p.endswith('.meta.json'): continue
    try:
        rows = json.load(open(p))
    except Exception as e:
        print('skipping', p, e); continue
    mp = p[:-5] + '.meta.json'
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    per = {}   # (workload, rung, run) -> [seconds, ok, checks]
    for r in rows:
        w, rung, st = r.get('workload'), r.get('rung'), r.get('stage') or ''
        if r.get('item'): w = '%s %s' % (w, r['item'])
        if w.startswith('W2'):
            if not st.startswith('wall'): continue
        elif not include(rung, st): continue
        k = (w, rung, r.get('run'))
        e = per.setdefault(k, [0.0, True, set()])
        e[0] += float(r.get('seconds') or 0)
        e[1] = e[1] and bool(r.get('ok'))
        if r.get('check') and r['check'] != '-': e[2].add(r['check'])
    # checks live on the 'check' rows; attach them per (workload, rung)
    checks = {}
    for r in rows:
        w = r.get('workload') + (' ' + r['item'] if r.get('item') else '')
        if r.get('stage') == 'check' or w.startswith('W2'):
            checks.setdefault((w, r.get('rung')), set()).add(r.get('check'))
            if not r.get('ok'):
                checks.setdefault(('fail', w, r.get('rung')), set()).add(r.get('check'))
    agg = {}
    for (w, rung, run), (s, ok, ch) in per.items():
        a = agg.setdefault((w, rung), {'secs': [], 'ok': True})
        a['secs'].append(s); a['ok'] = a['ok'] and ok and not checks.get(('fail', w, rung))
    out = []
    for (w, rung), a in sorted(agg.items()):
        s = a['secs']
        out.append({'workload': w, 'rung': rung, 'n': len(s), 'min': min(s), 'median': statistics.median(s),
                    'max': max(s), 'ok': a['ok'], 'check': sorted(c for c in checks.get((w, rung), []) if c)[:2]})
    history.append({'file': os.path.basename(p), 'commit': meta.get('commit', '?'), 'utc': meta.get('utc', ''),
                    'uptime': meta.get('uptime', ''), 'command': meta.get('command', ''), 'rows': out})
history.sort(key=lambda h: h['utc'])

try:
    commit = subprocess.check_output(['git', '-C', here, 'rev-parse', '--short', 'HEAD'], text=True).strip()
except Exception:
    commit = '?'
meta = {'built': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M UTC'), 'commit': commit}

html = open(os.path.join(here, 'page.html')).read()
html = html.replace('/*DATA*/', 'const TR = %s;\nconst COUNTERS = %s;\nconst COMPARE = %s;\nconst HISTORY = %s;\nconst META = %s;' % (
    json.dumps(traces, separators=(',', ':')), json.dumps(load('counters.json'), separators=(',', ':')),
    json.dumps(load('compare.json')), json.dumps(history, separators=(',', ':')), json.dumps(meta)))
open(os.path.join(here, 'index.html'), 'w').write(html)
print('wrote index.html: %d bytes, traces %s, %d ladder runs' % (len(html), sorted(traces), len(history)))
